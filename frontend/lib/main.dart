import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app/app.dart';
import 'app/router.dart';
import 'core/api/api_client.dart';
import 'core/cubit/locale_cubit.dart';
import 'core/services/firebase_auth_service.dart';
import 'features/auth/cubit/auth_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final apiClient = ApiClient();
  final firebaseAuthService = FirebaseAuthService();
  final authCubit = AuthCubit(apiClient, firebaseAuthService)..checkAuth();
  final localeCubit = LocaleCubit()..loadSavedLocale();
  final router = createRouter(authCubit);

  runApp(
    RepositoryProvider<ApiClient>.value(
      value: apiClient,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<LocaleCubit>.value(value: localeCubit),
        ],
        child: PrajaShaktiApp(router: router),
      ),
    ),
  );
}
