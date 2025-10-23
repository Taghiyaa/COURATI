import 'package:flutter/material.dart';

class AppColors {
  // Primary colors (logo + variantes harmonieuses)
  static const Color primary = Color(0xFF005676); // Bleu profond (logo)
  static const Color secondary = Color(0xFF00A8A8); // Turquoise élégant
  static const Color accent = Color(0xFFFF7F50); // Corail doux (contraste)

  // Semantic colors
  static const Color success = Color(0xFF2E7D32); // Vert forêt élégant
  static const Color warning = Color(0xFFFFB300); // Jaune doré
  static const Color error = Color(0xFFD32F2F); // Rouge soutenu

  // Background colors
  static const Color background = Color(0xFFF9FAFB); // Gris très clair
  static const Color surface = Color(0xFFFFFFFF); // Blanc pur
  static const Color surfaceSoft = Color(0xFFF1F5F9); // Gris doux

  // Text colors
  static const Color textPrimary = Color(0xFF1E293B); // Bleu-gris très foncé
  static const Color textSecondary = Color(0xFF475569); // Bleu-gris moyen
  static const Color textMuted = Color(0xFF94A3B8); // Gris bleuté clair

  // Border colors
  static const Color border = Color(0xFFE2E8F0); // Gris clair

  // Gradient basé sur la couleur du logo
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
