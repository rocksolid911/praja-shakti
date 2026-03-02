import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import '../core/cubit/locale_cubit.dart';
import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/cubit/auth_state.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';

class PrajaShaktiApp extends StatelessWidget {
  final GoRouter router;
  const PrajaShaktiApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        // Sync app locale to the logged-in user's language preference.
        // This prevents one user's language from leaking into another user's session.
        if (state is AuthAuthenticated) {
          context.read<LocaleCubit>().setLocale(
            Locale(state.user.languagePreference),
          );
        } else if (state is AuthInitial) {
          // On logout, reset to English so the next user starts fresh.
          context.read<LocaleCubit>().setLocale(const Locale('en'));
        }
      },
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) {
          return MaterialApp.router(
            title: 'PrajaShakti AI',
            locale: locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('hi'),
              Locale('or'),
              Locale('te'),
              Locale('ta'),
              Locale('mr'),
              Locale('bn'),
              Locale('gu'),
              Locale('kn'),
              Locale('ml'),
              Locale('pa'),
            ],
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
