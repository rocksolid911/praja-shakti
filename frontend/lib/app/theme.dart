import 'package:flutter/material.dart';

class AppTheme {
  static const Color saffron = Color(0xFFFF9933);
  static const Color green = Color(0xFF138808);
  static const Color navy = Color(0xFF000080);
  static const Color white = Color(0xFFFFFFFF);

  static const Color primaryColor = Color(0xFF1565C0);
  static const Color secondaryColor = saffron;
  static const Color accentGreen = green;

  static const Color reported = Colors.red;
  static const Color adopted = Colors.amber;
  static const Color inProgress = Colors.blue;
  static const Color completed = Colors.green;
  static const Color delayed = Color(0xFFB71C1C);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: primaryColor,
      brightness: Brightness.light,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: white,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: saffron,
        foregroundColor: white,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: primaryColor,
      brightness: Brightness.dark,
    );
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'reported':
        return reported;
      case 'adopted':
        return adopted;
      case 'in_progress':
        return inProgress;
      case 'completed':
        return completed;
      case 'delayed':
        return delayed;
      default:
        return Colors.grey;
    }
  }
}
