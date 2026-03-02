import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/user.dart';
import '../../../core/storage/secure_storage.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final ApiClient _api;

  /// Holds registration data between [startRegistration] → OTP → [verifyOtp].
  /// Cleared on every [sendOtp] (plain login) or after [verifyOtp] consumes it.
  Map<String, dynamic>? _pendingRegistration;

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
    _pendingRegistration = null; // plain login — clear any leftover registration data
    emit(AuthLoading());
    try {
      final resp = await _api.post('/auth/otp/send/', data: {'phone': phone});
      final otpDebug = resp.data['otp_debug']?.toString();
      emit(AuthOtpSent(phone, otpDebug: otpDebug));
    } catch (e) {
      emit(AuthError(_parseError(e)));
    }
  }

  /// Called from the registration form on the landing page.
  /// Stores profile + location data, then sends OTP for phone verification.
  Future<void> startRegistration({
    required String phone,
    required String firstName,
    String lastName = '',
    int? existingVillageId,
    int? districtId,
    String? panchayatName,
    String? villageName,
  }) async {
    _pendingRegistration = {
      'first_name': firstName,
      'last_name': lastName,
      if (existingVillageId != null) 'village_id': existingVillageId,
      if (districtId != null) 'district_id': districtId,
      if (panchayatName != null) 'panchayat_name': panchayatName,
      if (villageName != null) 'village_name': villageName,
    };
    emit(AuthLoading());
    try {
      final resp = await _api.post('/auth/otp/send/', data: {'phone': phone});
      final otpDebug = resp.data['otp_debug']?.toString();
      emit(AuthOtpSent(phone, otpDebug: otpDebug));
    } catch (e) {
      _pendingRegistration = null;
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
      if (_pendingRegistration != null) {
        await _completeRegistration();
        return;
      }
      final profileResp = await _api.get('/auth/profile/');
      emit(AuthAuthenticated(User.fromJson(profileResp.data)));
    } catch (e) {
      emit(AuthError(_parseError(e)));
    }
  }

  /// After OTP verification for a new registration: update name + location.
  Future<void> _completeRegistration() async {
    final data = _pendingRegistration!;
    _pendingRegistration = null;

    try {
      // 1. Update name if provided
      final nameData = <String, dynamic>{};
      if ((data['first_name'] as String?)?.isNotEmpty == true) {
        nameData['first_name'] = data['first_name'];
      }
      if ((data['last_name'] as String?)?.isNotEmpty == true) {
        nameData['last_name'] = data['last_name'];
      }
      if (nameData.isNotEmpty) {
        await _api.patch('/auth/profile/', data: nameData);
      }

      // 2. Set location (either existing village or new GP/village creation)
      if (data['district_id'] != null && data['panchayat_name'] != null) {
        await _api.post('/locations/setup-location/', data: {
          'district_id': data['district_id'],
          'panchayat_name': data['panchayat_name'],
          'village_name': data['village_name'] ?? data['panchayat_name'],
        });
      } else if (data['village_id'] != null) {
        await _api.post('/map/provision-village/', data: {
          'village_id': data['village_id'],
        });
      }
    } catch (_) {
      // Best-effort: don't fail auth if profile update fails
    }

    // 3. Fetch final profile
    try {
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

  /// Returns the currently logged-in user, or null if not authenticated.
  User? get currentUser {
    final s = state;
    if (s is AuthAuthenticated) return s.user;
    if (s is AuthProfileLoaded) return s.user;
    return null;
  }

  /// Returns the logged-in user's village ID, falling back to 1 for demo.
  int get currentVillageId {
    final s = state;
    if (s is AuthAuthenticated) return s.user.villageId ?? 1;
    if (s is AuthProfileLoaded) return s.user.villageId ?? 1;
    return 1;
  }

  /// Returns the logged-in user's panchayat ID, falling back to 1 for demo.
  int get currentPanchayatId {
    final s = state;
    if (s is AuthAuthenticated) return s.user.panchayatId ?? 1;
    if (s is AuthProfileLoaded) return s.user.panchayatId ?? 1;
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
      if (data is String && data.isNotEmpty) return data;
    } catch (_) {}
    try {
      final msg = (e as dynamic).message?.toString() ?? '';
      if (msg.isNotEmpty) return 'Network error. Please try again.';
    } catch (_) {}
    return 'An error occurred. Please try again.';
  }
}
