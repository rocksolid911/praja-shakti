import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/user.dart';
import '../../../core/storage/secure_storage.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final ApiClient _api;

  AuthCubit(this._api) : super(AuthInitial());

  // Legacy constructor for main.dart compatibility
  AuthCubit.withRepository({required dynamic authRepository}) : _api = authRepository.apiClient, super(AuthInitial());

  Future<void> checkAuth() async {
    final token = await SecureStorage.getAccessToken();
    if (token == null) {
      emit(AuthInitial());
      return;
    }
    try {
      final resp = await _api.get('/auth/profile/');
      emit(AuthAuthenticated(User.fromJson(resp.data)));
    } catch (_) {
      await SecureStorage.clearTokens();
      emit(AuthInitial());
    }
  }

  Future<void> sendOtp(String phone) async {
    emit(AuthLoading());
    try {
      await _api.post('/auth/otp/send/', data: {'phone': phone});
      emit(AuthOtpSent(phone));
    } catch (e) {
      emit(AuthError(_parseError(e)));
    }
  }

  Future<void> verifyOtp(String phone, String otp) async {
    emit(AuthLoading());
    try {
      final resp = await _api.post('/auth/login/', data: {'phone': phone, 'otp': otp});
      await SecureStorage.saveTokens(
        access: resp.data['access'],
        refresh: resp.data['refresh'],
      );
      final profileResp = await _api.get('/auth/profile/');
      emit(AuthAuthenticated(User.fromJson(profileResp.data)));
    } catch (e) {
      emit(AuthError(_parseError(e)));
    }
  }

  Future<void> loadProfile() async {
    try {
      final resp = await _api.get('/auth/profile/');
      emit(AuthProfileLoaded(User.fromJson(resp.data)));
    } catch (e) {
      emit(AuthError(_parseError(e)));
    }
  }

  Future<void> updateProfile({String? firstName, String? lastName, String? language}) async {
    emit(AuthLoading());
    try {
      final data = <String, dynamic>{};
      if (firstName != null) data['first_name'] = firstName;
      if (lastName != null) data['last_name'] = lastName;
      if (language != null) data['language_preference'] = language;
      final resp = await _api.patch('/auth/profile/', data: data);
      emit(AuthProfileLoaded(User.fromJson(resp.data)));
    } catch (e) {
      emit(AuthError(_parseError(e)));
    }
  }

  /// Returns the logged-in user's village ID, falling back to 1 for demo.
  int get currentVillageId {
    final s = state;
    if (s is AuthAuthenticated) return s.user.villageId ?? 1;
    if (s is AuthProfileLoaded) return s.user.villageId ?? 1;
    return 1;
  }

  Future<void> logout() async {
    await SecureStorage.clearTokens();
    emit(AuthInitial());
  }

  String _parseError(dynamic e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map) {
        return data.values.first?.toString() ?? 'An error occurred';
      }
    } catch (_) {}
    return 'An error occurred. Please try again.';
  }
}
