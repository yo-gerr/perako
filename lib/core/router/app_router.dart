import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/screens/account_detail_screen.dart';
import '../../features/accounts/presentation/screens/account_form_screen.dart';
import '../../features/accounts/presentation/screens/accounts_list_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/bills/presentation/screens/bill_detail_screen.dart';
import '../../features/bills/presentation/screens/bill_form_screen.dart';
import '../../features/bills/presentation/screens/bills_list_screen.dart';
import '../../features/bonds/presentation/screens/bond_detail_screen.dart';
import '../../features/bonds/presentation/screens/bond_form_screen.dart';
import '../../features/bonds/presentation/screens/bonds_list_screen.dart';
import '../../features/budgets/presentation/screens/budget_detail_screen.dart';
import '../../features/budgets/presentation/screens/budget_form_screen.dart';
import '../../features/budgets/presentation/screens/budgets_list_screen.dart';
import '../../features/categories/presentation/screens/categories_list_screen.dart';
import '../../features/categories/presentation/screens/category_form_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/goals/presentation/screens/goal_detail_screen.dart';
import '../../features/goals/presentation/screens/goal_form_screen.dart';
import '../../features/goals/presentation/screens/goals_list_screen.dart';
import '../../features/more/presentation/screens/more_screen.dart';
import '../../features/mp2/presentation/screens/mp2_detail_screen.dart';
import '../../features/mp2/presentation/screens/mp2_form_screen.dart';
import '../../features/mp2/presentation/screens/mp2_list_screen.dart';
import '../../features/reports/presentation/screens/budget_performance_screen.dart';
import '../../features/reports/presentation/screens/cash_flow_report_screen.dart';
import '../../features/reports/presentation/screens/category_analysis_screen.dart';
import '../../features/reports/presentation/screens/net_worth_report_screen.dart';
import '../../features/reports/presentation/screens/reports_hub_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/savings/presentation/screens/savings_detail_screen.dart';
import '../../features/savings/presentation/screens/savings_settings_screen.dart';
import '../../features/settings/presentation/screens/profile_screen.dart';
import '../../features/settings/presentation/screens/security_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/time_deposits/presentation/screens/time_deposit_detail_screen.dart';
import '../../features/time_deposits/presentation/screens/time_deposit_form_screen.dart';
import '../../features/time_deposits/presentation/screens/time_deposits_list_screen.dart';
import '../../features/transactions/presentation/screens/transaction_detail_screen.dart';
import '../../features/transactions/presentation/screens/transaction_form_screen.dart';
import '../../features/transactions/presentation/screens/transactions_list_screen.dart';
import 'home_shell.dart';

/// The [GoRouter] for the app.
///
/// Auth is optional: every destination is reachable without signing in. The
/// login page is a plain route pushed from the sidebar / More page / Settings,
/// never enforced by redirect logic.
final routerProvider = Provider<GoRouter>((ref) {
  return createRouter(ref);
});

/// Produces the [GoRouter] for this [Ref].
GoRouter createRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      // The stateful shell hosts every signed-in destination so the sidebar
      // and bottom navigation persist. Branches are built lazily on first
      // visit and kept alive afterwards (indexedStack container).
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/accounts',
                name: 'accounts',
                builder: (context, state) => const AccountsListScreen(),
              ),
              // Static segments are listed before their parameterized
              // siblings so 'new' wins over ':id'.
              GoRoute(
                path: '/accounts/new',
                name: 'account-new',
                builder: (context, state) => const AccountFormScreen(),
              ),
              GoRoute(
                path: '/accounts/:id',
                name: 'account-detail',
                builder: (context, state) =>
                    AccountDetailScreen(accountId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: '/accounts/:id/edit',
                name: 'account-edit',
                builder: (context, state) =>
                    AccountFormScreen(accountId: state.pathParameters['id']),
              ),
              GoRoute(
                path: '/accounts/:id/savings',
                name: 'savings-detail',
                builder: (context, state) => SavingsDetailScreen(
                    accountId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: '/accounts/:id/savings/settings',
                name: 'savings-settings',
                builder: (context, state) => SavingsSettingsScreen(
                    accountId: state.pathParameters['id']!),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                name: 'transactions',
                builder: (context, state) => const TransactionsListScreen(),
              ),
              GoRoute(
                path: '/transactions/new',
                name: 'transaction-new',
                builder: (context, state) => const TransactionFormScreen(),
              ),
              GoRoute(
                path: '/transactions/:id/edit',
                name: 'transaction-edit',
                builder: (context, state) => TransactionFormScreen(
                    transactionId: state.pathParameters['id']),
              ),
              GoRoute(
                path: '/transactions/:id',
                name: 'transaction-detail',
                builder: (context, state) => TransactionDetailScreen(
                    transactionId: state.pathParameters['id']!),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/categories',
                name: 'categories',
                builder: (context, state) => const CategoriesListScreen(),
              ),
              GoRoute(
                path: '/categories/new',
                name: 'category-new',
                builder: (context, state) => const CategoryFormScreen(),
              ),
              GoRoute(
                path: '/categories/:id/edit',
                name: 'category-edit',
                builder: (context, state) =>
                    CategoryFormScreen(categoryId: state.pathParameters['id']),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/budgets',
                name: 'budgets',
                builder: (context, state) => const BudgetsListScreen(),
              ),
              GoRoute(
                path: '/budgets/new',
                name: 'budget-new',
                builder: (context, state) => const BudgetFormScreen(),
              ),
              GoRoute(
                path: '/budgets/:id/edit',
                name: 'budget-edit',
                builder: (context, state) =>
                    BudgetFormScreen(budgetId: state.pathParameters['id']),
              ),
              GoRoute(
                path: '/budgets/:id',
                name: 'budget-detail',
                builder: (context, state) =>
                    BudgetDetailScreen(budgetId: state.pathParameters['id']!),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/bills',
                name: 'bills',
                builder: (context, state) => const BillsListScreen(),
              ),
              GoRoute(
                path: '/bills/new',
                name: 'bill-new',
                builder: (context, state) => const BillFormScreen(),
              ),
              GoRoute(
                path: '/bills/:id/edit',
                name: 'bill-edit',
                builder: (context, state) =>
                    BillFormScreen(billId: state.pathParameters['id']),
              ),
              GoRoute(
                path: '/bills/:id',
                name: 'bill-detail',
                builder: (context, state) =>
                    BillDetailScreen(billId: state.pathParameters['id']!),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/goals',
                name: 'goals',
                builder: (context, state) => const GoalsListScreen(),
              ),
              GoRoute(
                path: '/goals/new',
                name: 'goal-new',
                builder: (context, state) => const GoalFormScreen(),
              ),
              GoRoute(
                path: '/goals/:id/edit',
                name: 'goal-edit',
                builder: (context, state) =>
                    GoalFormScreen(goalId: state.pathParameters['id']),
              ),
              GoRoute(
                path: '/goals/:id',
                name: 'goal-detail',
                builder: (context, state) =>
                    GoalDetailScreen(goalId: state.pathParameters['id']!),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/time-deposits',
                name: 'time-deposits',
                builder: (context, state) => const TimeDepositsListScreen(),
              ),
              GoRoute(
                path: '/time-deposits/new',
                name: 'time-deposit-new',
                builder: (context, state) => const TimeDepositFormScreen(),
              ),
              GoRoute(
                path: '/time-deposits/:id/edit',
                name: 'time-deposit-edit',
                builder: (context, state) =>
                    TimeDepositFormScreen(depositId: state.pathParameters['id']),
              ),
              GoRoute(
                path: '/time-deposits/:id',
                name: 'time-deposit-detail',
                builder: (context, state) => TimeDepositDetailScreen(
                    depositId: state.pathParameters['id']!),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mp2',
                name: 'mp2',
                builder: (context, state) => const Mp2ListScreen(),
              ),
              GoRoute(
                path: '/mp2/new',
                name: 'mp2-new',
                builder: (context, state) => const Mp2FormScreen(),
              ),
              GoRoute(
                path: '/mp2/:id/edit',
                name: 'mp2-edit',
                builder: (context, state) =>
                    Mp2FormScreen(mp2Id: state.pathParameters['id']),
              ),
              GoRoute(
                path: '/mp2/:id',
                name: 'mp2-detail',
                builder: (context, state) =>
                    Mp2DetailScreen(mp2Id: state.pathParameters['id']!),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/bonds',
                name: 'bonds',
                builder: (context, state) => const BondsListScreen(),
              ),
              GoRoute(
                path: '/bonds/new',
                name: 'bond-new',
                builder: (context, state) => const BondFormScreen(),
              ),
              GoRoute(
                path: '/bonds/:id/edit',
                name: 'bond-edit',
                builder: (context, state) =>
                    BondFormScreen(bondId: state.pathParameters['id']),
              ),
              GoRoute(
                path: '/bonds/:id',
                name: 'bond-detail',
                builder: (context, state) =>
                    BondDetailScreen(bondId: state.pathParameters['id']!),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                name: 'reports',
                builder: (context, state) => const ReportsHubScreen(),
              ),
              GoRoute(
                path: '/reports/net-worth',
                name: 'reports-net-worth',
                builder: (context, state) => const NetWorthReportScreen(),
              ),
              GoRoute(
                path: '/reports/cash-flow',
                name: 'reports-cash-flow',
                builder: (context, state) => const CashFlowReportScreen(),
              ),
              GoRoute(
                path: '/reports/spending',
                name: 'reports-spending',
                builder: (context, state) => const SpendingAnalysisScreen(),
              ),
              GoRoute(
                path: '/reports/income',
                name: 'reports-income',
                builder: (context, state) => const IncomeAnalysisScreen(),
              ),
              GoRoute(
                path: '/reports/budget-performance',
                name: 'reports-budget-performance',
                builder: (context, state) => const BudgetPerformanceScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                name: 'search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
              GoRoute(
                path: '/settings/profile',
                name: 'settings-profile',
                builder: (context, state) => const ProfileScreen(),
              ),
              GoRoute(
                path: '/settings/security',
                name: 'settings-security',
                builder: (context, state) => const SecurityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                name: 'more',
                builder: (context, state) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
