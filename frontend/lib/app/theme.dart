import 'package:flutter/material.dart';

/// PrajaShakti AI — Civic Design System
///
/// Palette 1 "Trust & Stability" (primary):
///   Deep Navy  #1A237E — headers, primary buttons
///   State Blue #3F51B5 — active states, links
///   Gold/Amber #FFC107 — vote, action-required highlights
///   Background #F5F7FA — cool grey white
///
/// Palette 2 "Modern Transparency" (accents):
///   Teal Green #00695C — positive progress, go-ahead
///   Coral Red  #FF5252 — closed, critical markers
///
/// Palette 3 "Active Citizen" (high-contrast):
///   Charcoal   #263238 — text, structural elements
///   Sky Blue   #03A9F4 — progress bars
///   Vibrant Orange #FF9800 — voting call-to-action (distinct)
class AppTheme {
  AppTheme._();

  // ── Palette 1: Trust & Stability ──────────────────────────────────────────
  static const Color deepNavy = Color(0xFF1A237E);
  static const Color stateBlue = Color(0xFF3F51B5);
  static const Color goldAmber = Color(0xFFFFC107);
  static const Color bgGrey = Color(0xFFF5F7FA);

  // ── Palette 2: Modern Transparency ────────────────────────────────────────
  static const Color tealGreen = Color(0xFF00695C);
  static const Color coralRed = Color(0xFFFF5252);

  // ── Palette 3: Active Citizen ─────────────────────────────────────────────
  static const Color charcoal = Color(0xFF263238);
  static const Color skyBlue = Color(0xFF03A9F4);
  static const Color vibrantOrange = Color(0xFFFF9800);

  // ── App-wide semantic colors ──────────────────────────────────────────────
  static const Color primaryColor = deepNavy;
  static const Color secondaryColor = stateBlue;
  static const Color accentColor = goldAmber;
  static const Color actionGreen = Color(0xFF00C853);
  static const Color surfaceBg = bgGrey;

  // ── Tricolour branding ────────────────────────────────────────────────────
  static const Color saffron = Color(0xFFFF9933);
  static const Color green = Color(0xFF138808);
  static const Color navy = deepNavy;
  static const Color white = Color(0xFFFFFFFF);

  // ── Status colours (WCAG: neutral grey for in-progress, green only completed) ─
  static const Color reported = coralRed;
  static const Color adopted = goldAmber;
  static const Color inProgress = Color(0xFF90A4AE);
  static const Color completed = Color(0xFF2E7D32);
  static const Color delayed = Color(0xFFB71C1C);

  /// Distinct voting colour not used elsewhere — prevents click fatigue
  static const Color voteColor = vibrantOrange;

  // ── Light Theme ───────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: stateBlue,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgGrey,
      appBarTheme: const AppBarTheme(
        backgroundColor: deepNavy,
        foregroundColor: white,
        elevation: 0,
        centerTitle: false,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: stateBlue,
        foregroundColor: white,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: stateBlue,
          foregroundColor: white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: charcoal,
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: stateBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: white,
        indicatorColor: stateBlue.withValues(alpha: 0.12),
      ),
      dividerTheme: DividerThemeData(color: Colors.grey.shade200, thickness: 1),
    );
  }

  // ── Dark Theme ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: stateBlue,
      brightness: Brightness.dark,
    );
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'reported': return reported;
      case 'adopted': return adopted;
      case 'in_progress': return inProgress;
      case 'completed': return completed;
      case 'delayed': return delayed;
      default: return Colors.grey;
    }
  }
}
