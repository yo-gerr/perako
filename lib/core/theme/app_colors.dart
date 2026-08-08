import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ============================================================
  // BRAND
  // ============================================================

  static const Color primary = Color(0xFF001278);
  static const Color primaryDark = Color(0xFF6D7CFF);
  static const Color primaryLight = Color(0xFFE8EDFF);
  static const Color primaryDarkContainer = Color(0xFF202A52);

  // ============================================================
  // SECONDARY / ACCENTS
  // ============================================================

  static const Color secondary = Color(0xFF00A6A6);
  static const Color secondaryDark = Color(0xFF2DD4BF);

  static const Color accent = Color(0xFF7C5CFC);
  static const Color accentDark = Color(0xFFA78BFA);

  // ============================================================
  // SEMANTIC COLORS
  // ============================================================

  static const Color success = Color(0xFF22A06B);
  static const Color successDark = Color(0xFF34D399);

  static const Color warning = Color(0xFFF4B942);
  static const Color warningDark = Color(0xFFFBBF24);

  static const Color error = Color(0xFFE85D5D);
  static const Color errorDark = Color(0xFFFB7185);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoDark = Color(0xFF60A5FA);

  // ============================================================
  // LIGHT THEME
  // ============================================================

  static const Color lightBackground = Color(0xFFF7F8FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F3F9);

  static const Color lightTextPrimary = Color(0xFF172033);
  static const Color lightTextSecondary = Color(0xFF667085);
  static const Color lightTextDisabled = Color(0xFF98A2B3);

  static const Color lightBorder = Color(0xFFE4E7EC);
  static const Color lightDivider = Color(0xFFEAECF0);

  // ============================================================
  // DARK THEME
  // ============================================================

  static const Color darkBackground = Color(0xFF0B1020);
  static const Color darkSurface = Color(0xFF131A2A);
  static const Color darkSurfaceElevated = Color(0xFF1B2438);
  static const Color darkSurfaceVariant = Color(0xFF202A3D);

  static const Color darkTextPrimary = Color(0xFFF5F7FF);
  static const Color darkTextSecondary = Color(0xFFA7AEC0);
  static const Color darkTextDisabled = Color(0xFF667085);

  static const Color darkBorder = Color(0xFF293248);
  static const Color darkDivider = Color(0xFF20283A);

  // ============================================================
  // TRANSACTION COLORS
  // ============================================================

  static const Color income = success;
  static const Color incomeDark = successDark;

  static const Color expense = error;
  static const Color expenseDark = errorDark;

  static const Color transfer = info;
  static const Color transferDark = infoDark;

  static const Color interest = secondary;
  static const Color interestDark = secondaryDark;

  static const Color investment = accent;
  static const Color investmentDark = accentDark;
}
