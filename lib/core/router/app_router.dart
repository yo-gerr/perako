import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';

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
      GoRoute(
        path: '/',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
  );
}