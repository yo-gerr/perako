import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/database_sync_coordinator.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/currency_scope.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/bills/presentation/providers/bills_providers.dart';
import 'features/settings/presentation/providers/settings_providers.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: PerakoApp()));
}

class PerakoApp extends ConsumerWidget {
  const PerakoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Materialize due bills into ledger expenses as soon as a user is signed
    // in. The catch-up is idempotent, so re-firing after later sign-ins is
    // safe.
    ref.listen<AsyncValue<String?>>(authStateProvider, (prev, next) {
      if (next.valueOrNull != null) {
        ref.read(billCatchUpProvider.future);
      }
    });

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final symbol = ref.watch(currencySymbolProvider);
    return CurrencyScope(
      symbol: symbol,
      child: DatabaseWipeCoordinator(
        child: MaterialApp.router(
          title: 'PeraKo',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode ?? ThemeMode.system,
          routerConfig: router,
        ),
      ),
    );
  }
}
