import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'app/app.dart';
import 'app/router.dart';
import 'core/api/api_client.dart';
import 'features/auth/cubit/auth_cubit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = ApiClient();
  final authCubit = AuthCubit(apiClient)..checkAuth();
  final router = createRouter(authCubit);

  runApp(
    RepositoryProvider<ApiClient>.value(
      value: apiClient,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
        ],
        child: PrajaShaktiApp(router: router),
      ),
    ),
  );
}
