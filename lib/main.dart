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
import 'features/sync/presentation/providers/sync_providers.dart';
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
    // Local bookkeeping (materializing due bills) runs for every user, signed
    // in or not — the app is fully usable without an account. Idempotent, so
    // the cached future is safe to fire from build.
    ref.read(billCatchUpProvider.future);

    // Cloud sync is opt-in: when a session appears (mid-session sign-in, or a
    // restored session after a web refresh) push local changes up and pull the
    // account's data down once. Signing out stops sync but keeps local data.
    ref.listen<AsyncValue<String?>>(authStateProvider, (prev, next) {
      final uid = next.valueOrNull;
      if (uid != null && prev?.valueOrNull == null) {
        ref.read(syncStateProvider.notifier).syncNow(uid);
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
