import '../../../core/models/user.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthOtpSent extends AuthState {
  final String phone;
  AuthOtpSent(this.phone);
}

class AuthAuthenticated extends AuthState {
  final User user;
  AuthAuthenticated(this.user);
}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

class AuthProfileLoaded extends AuthState {
  final User user;
  AuthProfileLoaded(this.user);
}
