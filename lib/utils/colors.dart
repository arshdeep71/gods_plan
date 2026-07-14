import 'package:flutter/material.dart';

class AppColors {
  // Base theme background (pure apple black)
  static const Color background = Color(0xFF000000);
  
  // Card and surface backgrounds (iOS system dark gray)
  static const Color surface = Color(0xFF1C1C1E);
  static const Color surfaceElevated = Color(0xFF2C2C2E);

  // Brand Accents
  static const Color primary = Color(0xFFFF004F);       // Hot Pink / Move Red
  static const Color accent = Color(0xFFA4F300);        // Neon Lime Green / Highlight Accent
  static const Color primaryLight = Color(0xFFFF3366);  // Soft Pink/Red
  static const Color secondary = Color(0xFF0A84FF);     // Cyan Blue / Steps Blue
  
  // Indicators & Statuses
  static const Color success = Color(0xFF30D158);       // iOS Green
  static const Color error = Color(0xFFFF453A);         // iOS Red
  static const Color info = Color(0xFF0A84FF);          // iOS Blue
  static const Color warning = Color(0xFFFF9F0A);       // iOS Orange
  
  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);   // Crisp White
  static const Color textSecondary = Color(0xFF8E8E93); // iOS Muted Gray
  static const Color textMuted = Color(0xFF48484A);     // Dark Muted Gray

  // Borders & Dividers
  static const Color border = Color(0xFF2C2C2E);
  static const Color borderLight = Color(0xFF3A3A3C);

  // Glassmorphic Gradient overlays
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF004F), Color(0xFFFF3B30)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFCCFF00), Color(0xFFA4F300)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1C1C1E), Color(0xFF121214)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
