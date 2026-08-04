import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/screens/account_detail_screen.dart';
import '../../features/accounts/presentation/screens/account_form_screen.dart';
import '../../features/accounts/presentation/screens/accounts_list_screen.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/categories/presentation/screens/categories_list_screen.dart';
import '../../features/categories/presentation/screens/category_form_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/transactions/presentation/screens/transaction_detail_screen.dart';
import '../../features/transactions/presentation/screens/transaction_form_screen.dart';
import '../../features/transactions/presentation/screens/transactions_list_screen.dart';
import 'home_shell.dart';

/// Auth-aware [GoRouter] for the app.
final routerProvider = Provider<GoRouter>((ref) {
  return createRouter(ref);
});

/// Bridges auth-state changes to go_router's [refreshListenable], so redirects
/// re-run after sign-in and sign-out.
class AuthRouterRefresh extends ChangeNotifier {
  AuthRouterRefresh(Ref ref) {
    _sub = ref.listen<AsyncValue<String?>>(
      authStateProvider,
      (_, _) => notifyListeners(),
    );
  }

  ProviderSubscription<AsyncValue<String?>>? _sub;

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }
}

/// Produces the [GoRouter] for this [Ref], wired to Firebase auth so an
/// unauthenticated user is sent to the login screen.
GoRouter createRouter(Ref ref) {
  final refresh = AuthRouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final uid = ref.read(authStateProvider).valueOrNull;
      final isLogin = state.matchedLocation == '/login';

      if (uid == null && !isLogin) return '/login';
      if (uid != null && isLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
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
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                name: 'transactions',
                builder: (context, state) => const TransactionsListScreen(),
              ),
            ],
          ),
        ],
      ),
      // Full-screen pages pushed on top of the shell. Static segments are
      // listed before their parameterized siblings so 'new' wins over ':id'.
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
      GoRoute(
        path: '/transactions/new',
        name: 'transaction-new',
        builder: (context, state) => const TransactionFormScreen(),
      ),
      GoRoute(
        path: '/transactions/:id/edit',
        name: 'transaction-edit',
        builder: (context, state) =>
            TransactionFormScreen(transactionId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/transactions/:id',
        name: 'transaction-detail',
        builder: (context, state) => TransactionDetailScreen(
            transactionId: state.pathParameters['id']!),
      ),
    ],
  );
}
