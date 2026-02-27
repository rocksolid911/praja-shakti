import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import '../core/cubit/locale_cubit.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';

class PrajaShaktiApp extends StatelessWidget {
  final GoRouter router;
  const PrajaShaktiApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleCubit, Locale>(
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
    );
  }
}
