import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Brightness-aware semantic colors for financial meaning, exposed on every
/// [ThemeData] so widgets can use `Theme.of(context).perakoColors.income`.
@immutable
class PerakoColors extends ThemeExtension<PerakoColors> {
  const PerakoColors({
    required this.income,
    required this.incomeText,
    required this.expense,
    required this.expenseText,
    required this.transfer,
    required this.interest,
    required this.investment,
    required this.dividend,
    required this.warning,
    required this.warningText,
    required this.highlight,
    required this.highlightText,
  });

  /// Bright green for icons, charts, badges, and indicators.
  final Color income;

  /// Readable green for income amounts shown as text.
  final Color incomeText;

  /// Neutral slate for expense icons/charts (expenses are NOT errors).
  final Color expense;

  /// Readable neutral for expense amounts shown as text.
  final Color expenseText;

  /// Blue for transfers.
  final Color transfer;

  /// Green for interest earned.
  final Color interest;

  /// Magenta for investment activity.
  final Color investment;

  /// Magenta for dividends.
  final Color dividend;

  /// Gold for attention and goals.
  final Color warning;

  /// Readable gold for text on light surfaces.
  final Color warningText;

  /// Lime for achievements and highlights.
  final Color highlight;

  /// Readable lime for text on light surfaces.
  final Color highlightText;

  static const PerakoColors light = PerakoColors(
    income: AppColors.success,
    incomeText: AppColors.successText,
    expense: AppColors.expense,
    expenseText: AppColors.lightTextSecondary,
    transfer: AppColors.transfer,
    interest: AppColors.successText,
    investment: AppColors.investment,
    dividend: AppColors.dividend,
    warning: AppColors.warning,
    warningText: AppColors.warningText,
    highlight: AppColors.highlight,
    highlightText: AppColors.highlightText,
  );

  static const PerakoColors dark = PerakoColors(
    income: AppColors.successDark,
    incomeText: AppColors.successDark,
    expense: AppColors.darkTextSecondary,
    expenseText: AppColors.darkTextSecondary,
    transfer: AppColors.transfer,
    interest: AppColors.successDark,
    investment: AppColors.investment,
    dividend: AppColors.dividend,
    warning: AppColors.warning,
    warningText: Color(0xFFFFE8A3),
    highlight: AppColors.highlight,
    highlightText: AppColors.highlight,
  );

  @override
  PerakoColors copyWith({
    Color? income,
    Color? incomeText,
    Color? expense,
    Color? expenseText,
    Color? transfer,
    Color? interest,
    Color? investment,
    Color? dividend,
    Color? warning,
    Color? warningText,
    Color? highlight,
    Color? highlightText,
  }) {
    return PerakoColors(
      income: income ?? this.income,
      incomeText: incomeText ?? this.incomeText,
      expense: expense ?? this.expense,
      expenseText: expenseText ?? this.expenseText,
      transfer: transfer ?? this.transfer,
      interest: interest ?? this.interest,
      investment: investment ?? this.investment,
      dividend: dividend ?? this.dividend,
      warning: warning ?? this.warning,
      warningText: warningText ?? this.warningText,
      highlight: highlight ?? this.highlight,
      highlightText: highlightText ?? this.highlightText,
    );
  }

  @override
  PerakoColors lerp(ThemeExtension<PerakoColors>? other, double t) {
    if (other is! PerakoColors) return this;
    return PerakoColors(
      income: Color.lerp(income, other.income, t)!,
      incomeText: Color.lerp(incomeText, other.incomeText, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      expenseText: Color.lerp(expenseText, other.expenseText, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      interest: Color.lerp(interest, other.interest, t)!,
      investment: Color.lerp(investment, other.investment, t)!,
      dividend: Color.lerp(dividend, other.dividend, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      highlightText: Color.lerp(highlightText, other.highlightText, t)!,
    );
  }
}

/// Convenience accessor: `Theme.of(context).perakoColors.income`.
extension PerakoColorsX on ThemeData {
  PerakoColors get perakoColors =>
      extension<PerakoColors>() ?? PerakoColors.light;
}
