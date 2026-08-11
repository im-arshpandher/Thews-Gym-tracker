import 'package:flutter/material.dart';

/// Centralized color schema for Thews app.
/// Designed for easy theme customization, supporting both Dark and Light modes
/// with the signature Volt Lime / Neon Pulse accent.
class AppColors {
  // Brand / Neon Accent Colors
  static const Color primaryVolt = Color(0xFFC3F400); // Volt Lime
  static const Color primaryVoltDim = Color(0xFFABD600);
  static const Color primaryVoltDark = Color(0xFF506600);
  static const Color primaryVoltOn = Color(0xFF161E00);
  static const Color primaryGlow = Color(0x66C3F400); // 40% opacity glow

  // Light Theme Dedicated High-Contrast Tokens
  static const Color lightPrimary = Color(
    0xFF356500,
  ); // Deep Forest-Volt Green for text/icons/accents on light bg
  static const Color lightPrimaryDark = Color(0xFF234400);
  static const Color lightPrimaryContainer = Color(0xFFD5FA40);

  // Dark Theme Surface Tokens
  static const Color darkBackground = Color(0xFF131313);
  static const Color darkSurfaceContainerLowest = Color(0xFF0E0E0E);
  static const Color darkSurfaceContainerLow = Color(0xFF1C1B1B);
  static const Color darkSurfaceContainer = Color(0xFF201F1F);
  static const Color darkSurfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color darkSurfaceContainerHighest = Color(0xFF353534);
  static const Color darkTextPrimary = Color(0xFFE5E2E1);
  static const Color darkTextSecondary = Color(0xFFC4C9AC);
  static const Color darkOutline = Color(0xFF444933);
  static const Color darkOutlineVariant = Color(0xFF8E9379);

  // Light Theme Surface Tokens
  static const Color lightBackground = Color(0xFFF9F9F8);
  static const Color lightSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerLow = Color(0xFFF4F3F1);
  static const Color lightSurfaceContainer = Color(0xFFEEEEEC);
  static const Color lightSurfaceContainerHigh = Color(0xFFE5E3E0);
  static const Color lightSurfaceContainerHighest = Color(0xFFDDDCD9);
  static const Color lightTextPrimary = Color(0xFF1C1B1B);
  static const Color lightTextSecondary = Color(
    0xFF43483E,
  ); // High-contrast slate (WCAG AAA)
  static const Color lightOutline = Color(
    0xFF747969,
  ); // High-contrast border (WCAG AA)
  static const Color lightOutlineVariant = Color(0xFFA8AD9A);

  // Semantic & Muscle Group Colors
  static const Color error = Color(0xFFFF5252);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onError = Color(0xFF690005);
  static const Color success = Color(0xFF00E676);

  // Muscle Group Accent Badges
  static const Color chestAccent = Color(0xFFFF6D00);
  static const Color backAccent = Color(0xFF2979FF);
  static const Color legsAccent = Color(0xFF00E5FF);
  static const Color shouldersAccent = Color(0xFFAA00FF);
  static const Color bicepsAccent = Color(0xFFFF007F);
  static const Color tricepsAccent = Color(0xFFE91E63);
  static const Color forearmsAccent = Color(0xFFFFC107);
  static const Color coreAccent = Color(0xFFFFD600);
  static const Color neckAccent = Color(0xFF00BFA5);
  static const Color armsAccent = Color(0xFFFF007F);
  static const Color cardioAccent = Color(0xFF00E676);
  static const Color fullBodyAccent = Color(0xFFC3F400);

  static Color getMuscleGroupColor(String group) {
    final lower = group.toLowerCase().trim();
    if (lower.contains('chest')) return chestAccent;
    if (lower.contains('back') || lower.contains('lat') || lower.contains('trap')) return backAccent;
    if (lower.contains('leg') || lower.contains('quad') || lower.contains('thigh') || lower.contains('calf') || lower.contains('calves') || lower.contains('hamstring') || lower.contains('glute')) return legsAccent;
    if (lower.contains('shoulder') || lower.contains('delt')) return shouldersAccent;
    if (lower.contains('bicep')) return bicepsAccent;
    if (lower.contains('tricep')) return tricepsAccent;
    if (lower.contains('forearm') || lower.contains('wrist')) return forearmsAccent;
    if (lower.contains('arm')) return armsAccent;
    if (lower.contains('core') || lower.contains('ab')) return coreAccent;
    if (lower.contains('neck')) return neckAccent;
    if (lower.contains('cardio') || lower.contains('run')) return cardioAccent;
    return fullBodyAccent;
  }

  /// Returns high-contrast text color for muscle group tags based on brightness.
  static Color getMuscleGroupTextColor(String group, bool isDark) {
    if (isDark) {
      return getMuscleGroupColor(group);
    }
    final lower = group.toLowerCase().trim();
    if (lower.contains('chest')) return const Color(0xFFD35400);
    if (lower.contains('back')) return const Color(0xFF1565C0);
    if (lower.contains('leg') || lower.contains('quad') || lower.contains('thigh') || lower.contains('calf')) return const Color(0xFF00838F);
    if (lower.contains('shoulder')) return const Color(0xFF7B1FA2);
    if (lower.contains('bicep')) return const Color(0xFFC2185B);
    if (lower.contains('tricep')) return const Color(0xFFAD1457);
    if (lower.contains('forearm')) return const Color(0xFFE65100);
    if (lower.contains('core') || lower.contains('ab')) return const Color(0xFFD35400);
    if (lower.contains('neck')) return const Color(0xFF00695C);
    if (lower.contains('cardio')) return const Color(0xFF2E7D32);
    return lightPrimary;
  }

  /// Returns appropriate background color for muscle group tags based on brightness.
  static Color getMuscleGroupBgColor(String group, bool isDark) {
    if (isDark) {
      return getMuscleGroupColor(group).withValues(alpha: 0.2);
    }
    final lower = group.toLowerCase().trim();
    if (lower.contains('chest')) return const Color(0xFFFFF0E6);
    if (lower.contains('back')) return const Color(0xFFE8F0FE);
    if (lower.contains('leg') || lower.contains('quad') || lower.contains('thigh') || lower.contains('calf')) return const Color(0xFFE0F7FA);
    if (lower.contains('shoulder')) return const Color(0xFFF3E5F5);
    if (lower.contains('bicep') || lower.contains('tricep') || lower.contains('arm')) return const Color(0xFFFCE4EC);
    if (lower.contains('forearm')) return const Color(0xFFFFF8E1);
    if (lower.contains('core') || lower.contains('ab')) return const Color(0xFFFFFDE7);
    if (lower.contains('neck')) return const Color(0xFFE0F2F1);
    if (lower.contains('cardio')) return const Color(0xFFE8F5E9);
    return const Color(0xFFF4FCE3);
  }
}
