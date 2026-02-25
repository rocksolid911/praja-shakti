import 'package:flutter/material.dart';
import 'router.dart';
import 'theme.dart';

class PrajaShaktiApp extends StatelessWidget {
  const PrajaShaktiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PrajaShakti AI',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
