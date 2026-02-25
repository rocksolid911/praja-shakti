import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'theme.dart';

class PrajaShaktiApp extends StatelessWidget {
  final GoRouter router;
  const PrajaShaktiApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PrajaShakti AI',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
