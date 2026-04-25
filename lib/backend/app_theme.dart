import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // COLORS FROM USER PALETTE
  static const Color primary = Color(0xFFFF5C28); // The Orange
  static const Color background = Color(0xFF111111); // Deep Dark
  static const Color surface = Color(0xFF1A1A1A); // Card Dark
  static const Color surfaceLighter = Color(0xFF2E2E2E); // Border/Detail Dark
  
  static const Color success = Color(0xFF00D0B4); // Mint Green
  static const Color info = Color(0xFF3B82F6); // Blue
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color danger = Color(0xFFEF4444); // Red
  static const Color textBody = Color(0xFFF5F5F0); // Off White
  static const Color textMuted = Color(0xFF888888); 

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: info,
        surface: surface,
        onSurface: textBody,
        onPrimary: Colors.white,
        error: danger,
      ),
      textTheme: GoogleFonts.figtreeTextTheme(
        const TextTheme(
          displayLarge: TextStyle(color: textBody, fontWeight: FontWeight.bold),
          displayMedium: TextStyle(color: textBody, fontWeight: FontWeight.bold),
          titleLarge: TextStyle(color: textBody, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(color: textBody),
          bodyMedium: TextStyle(color: textBody),
          labelLarge: TextStyle(color: textBody, fontWeight: FontWeight.bold),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(color: textBody, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  // SECONDARY FONT UTILITY
  static TextStyle monoStyle({double fontSize = 12, Color? color, FontWeight? fontWeight, double? letterSpacing}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      color: color ?? textBody,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }
}
