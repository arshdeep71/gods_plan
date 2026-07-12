import 'package:flutter/material.dart';

class AppColors {
  // Base theme background (deep obsidian)
  static const Color background = Color(0xFF0C0E12);
  
  // Card and surface backgrounds (dark graphite)
  static const Color surface = Color(0xFF161922);
  static const Color surfaceElevated = Color(0xFF222634);

  // Brand Accents
  static const Color primary = Color(0xFF6366F1);       // Electric Indigo
  static const Color primaryLight = Color(0xFF818CF8);  // Soft Violet
  static const Color secondary = Color(0xFFF59E0B);     // Amber Gold
  
  // Indicators & Statuses
  static const Color success = Color(0xFF10B981);       // Emerald Green
  static const Color error = Color(0xFFEF4444);         // Crimson Red
  static const Color info = Color(0xFF3B82F6);          // Royal Blue
  static const Color warning = Color(0xFFF59E0B);       // Warning Orange
  
  // Text Colors
  static const Color textPrimary = Color(0xFFF3F4F6);   // Crisp Off-White
  static const Color textSecondary = Color(0xFF9CA3AF); // Muted Slate Gray
  static const Color textMuted = Color(0xFF6B7280);     // Dimmed Gray

  // Borders & Dividers
  static const Color border = Color(0xFF262A37);
  static const Color borderLight = Color(0xFF3A3F50);

  // Glassmorphic Gradient overlays
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1A1D27), Color(0xFF12141A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
