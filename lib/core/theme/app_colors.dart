import 'package:flutter/material.dart';

/// Perako Design System color palette.
///
/// "Your Personal Finance Operating System"
///
/// Professional enough for financial data, friendly enough for a personal
/// finance application, and colorful without being visually overwhelming.
/// Blue is the primary brand color; every other color communicates financial
/// meaning (green = growth, gold = attention, magenta = investments, lime =
/// achievements, red = problems) and provides visual variety.
abstract final class AppColors {
  // ========================================================================
  // BRAND
  // ========================================================================

  /// Primary Perako brand color — `#008BF8`.
  ///
  /// Primary buttons, FAB, active navigation, selected tabs, links, primary
  /// icons, important interactive controls, main charts.
  static const Color primary = Color(0xFF008BF8);

  /// Dark-mode primary color. `#008BF8` has enough intensity on dark surfaces.
  static const Color primaryDark = Color(0xFF008BF8);

  /// Light container for selected states and subtle backgrounds — `#E5F3FF`.
  static const Color primaryContainer = Color(0xFFE5F3FF);

  /// Dark container for selected states and highlighted surfaces — `#063A63`.
  static const Color primaryContainerDark = Color(0xFF063A63);

  // ========================================================================
  // SUCCESS / FINANCIAL GROWTH
  // ========================================================================

  /// Bright success green — `#04E762`. For icons, indicators, charts, badges,
  /// and positive amounts. Do NOT use as body text on a white background.
  static const Color success = Color(0xFF04E762);

  /// Accessible success text for light mode — `#087A3E`.
  static const Color successText = Color(0xFF087A3E);

  /// Dark-mode success color. The bright green works well on dark surfaces.
  static const Color successDark = Color(0xFF04E762);

  /// Light success container — `#E7FBEF`.
  static const Color successContainer = Color(0xFFE7FBEF);

  /// Dark success container — `#073A23`.
  static const Color successContainerDark = Color(0xFF073A23);

  // ========================================================================
  // WARNING / GOALS
  // ========================================================================

  /// Gold warning and attention color — `#F5B700`.
  ///
  /// Budget warnings, upcoming bills, savings goals, pending interest,
  /// financial milestones, approaching limits. Communicates "pay attention"
  /// rather than "error".
  static const Color warning = Color(0xFFF5B700);

  /// Accessible warning text on light backgrounds — `#8A6200`.
  static const Color warningText = Color(0xFF8A6200);

  /// Light warning container — `#FFF5D6`.
  static const Color warningContainer = Color(0xFFFFF5D6);

  /// Dark warning container — `#443708`.
  static const Color warningContainerDark = Color(0xFF443708);

  // ========================================================================
  // INVESTMENT / SPECIAL ACCENT
  // ========================================================================

  /// Investment and special-event accent — `#DC0073`.
  ///
  /// Stocks, bonds, REITs, dividends, special financial events, achievements.
  /// Intentionally NOT used for errors.
  static const Color accent = Color(0xFFDC0073);

  /// Light accent container — `#FCE5F1`.
  static const Color accentContainer = Color(0xFFFCE5F1);

  /// Dark accent container — `#4A0A2C`.
  static const Color accentContainerDark = Color(0xFF4A0A2C);

  // ========================================================================
  // ACHIEVEMENT / HIGHLIGHT
  // ========================================================================

  /// Bright highlight color — `#89FC00`.
  ///
  /// Goal completion, achievement badges, milestones, chart highlights.
  /// Use sparingly; never for body text, large backgrounds, or primary
  /// buttons.
  static const Color highlight = Color(0xFF89FC00);

  /// Accessible highlight text for light mode — `#4F8F00`.
  static const Color highlightText = Color(0xFF4F8F00);

  // ========================================================================
  // ERROR
  // ========================================================================

  /// Error color — `#D64545`. Reserved for actual problems: failed
  /// transactions, invalid input, overdue bills, invalid states, system
  /// errors. Expenses are NOT errors and must not use this color.
  static const Color error = Color(0xFFD64545);

  /// Light error container — `#FDECEC`.
  static const Color errorContainer = Color(0xFFFDECEC);

  /// Dark-mode error color — `#FF6B6B`.
  static const Color errorDark = Color(0xFFFF6B6B);

  /// Dark error container — `#4A1E1E`.
  static const Color errorContainerDark = Color(0xFF4A1E1E);

  // ========================================================================
  // INFORMATION
  // ========================================================================

  /// Informational color — neutral info that is neither income, expense,
  /// warning, nor error. Shares the brand blue.
  static const Color info = Color(0xFF008BF8);

  /// Light information container — `#E5F3FF`.
  static const Color infoContainer = Color(0xFFE5F3FF);

  /// Dark information container — `#063A63`.
  static const Color infoContainerDark = Color(0xFF063A63);

  // ========================================================================
  // TRANSACTION SEMANTIC COLORS
  // ========================================================================

  /// Income transactions: salary, freelance, bonus, interest, dividends.
  static const Color income = success;

  /// Accessible income text.
  static const Color incomeText = successText;

  /// Expense transactions.
  ///
  /// Expenses are normal financial events and intentionally NOT red. The
  /// default UI uses a neutral slate so red stays reserved for actual
  /// problems (failed payments, overdue bills, automation failures).
  static const Color expense = Color(0xFF475467);

  /// Transfers move money between accounts — neither income nor expense.
  static const Color transfer = primary;

  /// Interest earned is positive financial growth.
  static const Color interest = success;

  /// Investment activity is distinguished by magenta.
  static const Color investment = accent;

  /// Dividend transactions.
  static const Color dividend = accent;

  // ========================================================================
  // LIGHT THEME SURFACES
  // ========================================================================

  /// Neutral light background — `#F8FAFC` — keeps the palette from feeling
  /// overwhelming.
  static const Color lightBackground = Color(0xFFF8FAFC);

  /// Standard light surface.
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Elevated light surface (dialogs, sheets, menus, elevated cards).
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);

  /// Secondary light surface.
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9);

  // ========================================================================
  // LIGHT THEME TEXT
  // ========================================================================

  static const Color lightTextPrimary = Color(0xFF172033);
  static const Color lightTextSecondary = Color(0xFF667085);
  static const Color lightTextDisabled = Color(0xFF98A2B3);

  // ========================================================================
  // LIGHT THEME BORDERS
  // ========================================================================

  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightDivider = Color(0xFFEAECF0);

  // ========================================================================
  // DARK THEME SURFACES
  // ========================================================================

  /// Neutral near-black background — `#0B0F14` — lets the vibrant brand
  /// colors stand out without a strongly blue or purple interface.
  static const Color darkBackground = Color(0xFF0B0F14);

  /// Standard dark surface — `#121820`.
  static const Color darkSurface = Color(0xFF121820);

  /// Elevated dark surface — `#1A222C` (cards, dialogs, sheets, panels).
  static const Color darkSurfaceElevated = Color(0xFF1A222C);

  /// Secondary dark surface — `#202A34`.
  static const Color darkSurfaceVariant = Color(0xFF202A34);

  // ========================================================================
  // DARK THEME TEXT
  // ========================================================================

  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFA8B2BF);
  static const Color darkTextDisabled = Color(0xFF667085);

  // ========================================================================
  // DARK THEME BORDERS
  // ========================================================================

  static const Color darkBorder = Color(0xFF293340);
  static const Color darkDivider = Color(0xFF202832);
}
