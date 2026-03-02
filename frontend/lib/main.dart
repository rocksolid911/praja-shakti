import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'app/app.dart';
import 'app/router.dart';
import 'core/api/api_client.dart';
import 'core/cubit/locale_cubit.dart';
import 'features/auth/cubit/auth_cubit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = ApiClient();
  final authCubit = AuthCubit(apiClient)..checkAuth();
  final localeCubit = LocaleCubit();
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
