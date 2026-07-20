import 'package:flutter/material.dart';

class AppTheme {
  // Pure black saves battery on OLED screens and increases contrast for premium UI
  static const Color _trueBlack = Color(0xFF000000);
  
  // Slightly elevated surface color for cards and containers
  static const Color _surfaceDark = Color(0xFF101016);
  
  static const Color _accentBlue = Colors.blueAccent;
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Colors.white54;

  static ThemeData get amoledDarkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _trueBlack, // True AMOLED Black
      primaryColor: _accentBlue,
      canvasColor: _trueBlack,
      cardColor: _surfaceDark,
      
      // Global AppBar styling
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: _textPrimary),
        titleTextStyle: TextStyle(
          color: _textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5, // Modern tighter typography
        ),
      ),

      // Premium Bottom Sheet styling
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _surfaceDark,
        modalBackgroundColor: _surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // Global Card styling
      cardTheme: CardTheme(
        color: _surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
      ),

      // Custom Typography
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: _textPrimary, fontWeight: FontWeight.w900),
        displayMedium: TextStyle(color: _textPrimary, fontWeight: FontWeight.w800),
        bodyLarge: TextStyle(color: _textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: _textSecondary, fontSize: 14),
      ),

      // Input Field styling
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _accentBlue, width: 1),
        ),
        hintStyle: const TextStyle(color: Colors.white38),
      ),

      // Elevated Button styling
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      
      // Page Transitions - Fluid across platforms
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
