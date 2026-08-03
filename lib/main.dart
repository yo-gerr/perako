import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/database_sync_coordinator.dart';
import 'core/router/app_router.dart';
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
    final router = ref.watch(routerProvider);
    return DatabaseWipeCoordinator(
      child: MaterialApp.router(
        title: 'PeraKo',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
        routerConfig: router,
      ),
    );
  }
}