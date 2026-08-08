import 'package:flutter/material.dart';

/// A single navigation destination in the app's shell.
class AppDestination {
  const AppDestination({
    required this.branchIndex,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
  });

  /// Index of the [StatefulShellBranch] this destination opens. Must match the
  /// branch order in [createRouter].
  final int branchIndex;

  final String label;

  final IconData icon;

  final IconData selectedIcon;

  /// Root path of the branch this destination opens.
  final String path;
}

/// All destinations in branch order. Keep in sync with the branches in
/// `createRouter` (app_router.dart).
const List<AppDestination> allDestinations = [
  AppDestination(
    branchIndex: 0,
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    path: '/',
  ),
  AppDestination(
    branchIndex: 1,
    label: 'Accounts',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
    path: '/accounts',
  ),
  AppDestination(
    branchIndex: 2,
    label: 'Transactions',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    path: '/transactions',
  ),
  AppDestination(
    branchIndex: 3,
    label: 'Categories',
    icon: Icons.category_outlined,
    selectedIcon: Icons.category,
    path: '/categories',
  ),
  AppDestination(
    branchIndex: 4,
    label: 'Budgets',
    icon: Icons.savings_outlined,
    selectedIcon: Icons.savings,
    path: '/budgets',
  ),
  AppDestination(
    branchIndex: 5,
    label: 'Bills',
    icon: Icons.request_quote_outlined,
    selectedIcon: Icons.request_quote,
    path: '/bills',
  ),
  AppDestination(
    branchIndex: 6,
    label: 'Goals',
    icon: Icons.flag_outlined,
    selectedIcon: Icons.flag,
    path: '/goals',
  ),
  AppDestination(
    branchIndex: 7,
    label: 'Time Deposits',
    icon: Icons.timer_outlined,
    selectedIcon: Icons.timer,
    path: '/time-deposits',
  ),
  AppDestination(
    branchIndex: 8,
    label: 'MP2',
    icon: Icons.account_balance_outlined,
    selectedIcon: Icons.account_balance,
    path: '/mp2',
  ),
  AppDestination(
    branchIndex: 9,
    label: 'Bonds',
    icon: Icons.trending_up_outlined,
    selectedIcon: Icons.trending_up,
    path: '/bonds',
  ),
  AppDestination(
    branchIndex: 10,
    label: 'Reports',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
    path: '/reports',
  ),
  AppDestination(
    branchIndex: 11,
    label: 'Search',
    icon: Icons.search,
    selectedIcon: Icons.search,
    path: '/search',
  ),
  AppDestination(
    branchIndex: 12,
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    path: '/settings',
  ),
  AppDestination(
    branchIndex: 13,
    label: 'More',
    icon: Icons.more_horiz,
    selectedIcon: Icons.more_horiz,
    path: '/more',
  ),
];

/// Destinations shown in the bottom navigation bar on narrow surfaces.
final List<AppDestination> primaryDestinations = [
  allDestinations[0],
  allDestinations[1],
  allDestinations[2],
];

/// Secondary destinations listed on the sidebar and the More page.
final List<AppDestination> toolDestinations = [
  allDestinations[3],
  allDestinations[4],
  allDestinations[5],
  allDestinations[6],
  allDestinations[7],
  allDestinations[8],
  allDestinations[9],
  allDestinations[10],
  allDestinations[11],
];

/// The settings destination, kept on its own section.
final AppDestination settingsDestination = allDestinations[12];

/// The More page itself, the fourth bottom-navigation destination.
final AppDestination moreDestination = allDestinations[13];
