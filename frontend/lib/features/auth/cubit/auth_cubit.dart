import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/user.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/storage/secure_storage.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final ApiClient _api;
  final FirebaseAuthService _firebaseAuth;

  /// Holds registration data between [startRegistration] -> OTP -> [verifyOtp].
  /// Cleared on every [sendOtp] (plain login) or after [verifyOtp] consumes it.
  Map<String, dynamic>? _pendingRegistration;

  /// Firebase verification ID for mobile OTP flow.
  String? _verificationId;

  AuthCubit(this._api, this._firebaseAuth) : super(AuthInitial());

  // ── Auth check ─────────────────────────────────────────────────────────

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

  // ── Send OTP via Firebase ──────────────────────────────────────────────

  Future<void> sendOtp(String phone) async {
    _pendingRegistration = null; // plain login — clear any leftover registration data
    emit(AuthLoading());
    try {
      _verificationId = await _firebaseAuth.verifyPhoneNumber(
        phone,
        onAutoVerified: (userCred) {
          // Android auto-verification succeeded — exchange token immediately
          _exchangeFirebaseToken();
        },
      );
      emit(AuthOtpSent(phone));
    } catch (e) {
      emit(AuthError(_parseFirebaseError(e)));
    }
  }

  // ── Registration flow ─────────────────────────────────────────────────

  /// Called from the registration form on the landing page.
  /// Stores profile + location data, then sends OTP via Firebase.
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
      'name': '$firstName $lastName'.trim(),
      if (existingVillageId != null) 'village_id': existingVillageId,
      if (districtId != null) 'district_id': districtId,
      if (panchayatName != null) 'panchayat_name': panchayatName,
      if (villageName != null) 'village_name': villageName,
    };
    emit(AuthLoading());
    try {
      _verificationId = await _firebaseAuth.verifyPhoneNumber(
        phone,
        onAutoVerified: (userCred) {
          // Android auto-verification succeeded
          _exchangeFirebaseToken();
        },
      );
      emit(AuthOtpSent(phone));
    } catch (e) {
      _pendingRegistration = null;
      emit(AuthError(_parseFirebaseError(e)));
    }
  }

  // ── Verify OTP ─────────────────────────────────────────────────────────

  Future<void> verifyOtp(String phone, String otp) async {
    emit(AuthLoading());
    try {
      if (_verificationId == null) {
        emit(AuthError('Verification expired. Please request a new OTP.'));
        return;
      }
      await _firebaseAuth.verifyOtp(_verificationId!, otp);
      await _exchangeFirebaseToken();
    } catch (e) {
      emit(AuthError(_parseFirebaseError(e)));
    }
  }

  // ── Exchange Firebase token for Django JWT ──────────────────────────────

  Future<void> _exchangeFirebaseToken() async {
    try {
      final idToken = await _firebaseAuth.getIdToken(forceRefresh: true);
      if (idToken == null) {
        emit(AuthError('Could not get Firebase token.'));
        return;
      }

      final data = <String, dynamic>{'firebase_token': idToken};
      // Include name for new user registration
      if (_pendingRegistration != null && _pendingRegistration!['name'] != null) {
        data['name'] = _pendingRegistration!['name'];
      }

      final resp = await _api.post('/auth/firebase-login/', data: data);
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

  // ── Anonymous Sign-In ──────────────────────────────────────────────────

  Future<void> signInAnonymously() async {
    emit(AuthLoading());
    try {
      await _firebaseAuth.signInAnonymously();
      await _exchangeFirebaseToken();
    } catch (e) {
      emit(AuthError(_parseFirebaseError(e)));
    }
  }

  // ── Post-registration profile + location setup ─────────────────────────

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

  // ── Profile ────────────────────────────────────────────────────────────

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

  // ── Computed properties ────────────────────────────────────────────────

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

  // ── Logout ─────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _firebaseAuth.signOut();
    await SecureStorage.clearTokens();
    emit(AuthInitial());
  }

  // ── Error helpers ──────────────────────────────────────────────────────

  String _parseFirebaseError(dynamic e) {
    if (e is fb.FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-phone-number':
          return 'Invalid phone number. Please check and try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'invalid-verification-code':
          return 'Invalid OTP code. Please try again.';
        case 'session-expired':
          return 'OTP expired. Please request a new one.';
        default:
          return e.message ?? 'Authentication failed. Please try again.';
      }
    }
    if (e is String) return e;
    return 'Authentication failed. Please try again.';
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
