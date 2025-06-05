import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Main theme configuration for the Brainrot Wallet
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // Core colors
  static const Color deepPurple = Color(0xFF6B46C1);
  static const Color limeGreen = Color(0xFF84CC16);
  static const Color hotPink = Color(0xFFEC4899);
  static const Color darkGrey = Color(0xFF1F2937);
  static const Color lightGrey = Color(0xFF374151);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // Semantic colors
  static const Color success = limeGreen;
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Gradient definitions
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [deepPurple, Color(0xFF9333EA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient chaosGradient = LinearGradient(
    colors: [deepPurple, limeGreen, hotPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Text styles
  static TextStyle get headerStyle => GoogleFonts.bebasNeue(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: white,
    letterSpacing: 2,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontFamily: 'ComicSans',
    fontSize: 16,
    color: white,
  );

  static const TextStyle monoStyle = TextStyle(
    fontFamily: 'Monaco',
    fontSize: 14,
    color: limeGreen,
  );

  // Dark theme configuration
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: deepPurple,
      scaffoldBackgroundColor: darkGrey,

      // Color scheme
      colorScheme: const ColorScheme.dark(
        primary: deepPurple,
        secondary: limeGreen,
        tertiary: hotPink,
        surface: lightGrey,
        error: error,
        onPrimary: white,
        onSecondary: black, // Or white, depending on contrast with limeGreen
        onTertiary: white, // Or black, depending on contrast with hotPink
        onSurface: white,
        onError: white,
      ),

      // App bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: headerStyle.copyWith(fontSize: 24),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: lightGrey,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: deepPurple,
            width: 2,
          ),
        ),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: deepPurple,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'ComicSans',
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // Text theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'ComicSans',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: white,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'ComicSans',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: white,
        ),
        bodyLarge: bodyStyle,
        bodyMedium: TextStyle(
          fontFamily: 'ComicSans',
          fontSize: 14,
          color: white,
        ),
      ),
    );
  }
}
