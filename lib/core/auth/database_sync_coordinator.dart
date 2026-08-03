import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';

/// Wipes the local SQLite DB when the signed-in user changes on this device.
///
/// SQLite is a per-account local mirror; Firestore (scoped per user) is
/// authoritative. When a *different* user signs in, or the current user signs
/// out, all local ledger data + sync cursors are cleared so the next pull
/// starts clean and the prior user's data never leaks into the new session.
class DatabaseWipeCoordinator extends ConsumerStatefulWidget {
  const DatabaseWipeCoordinator({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DatabaseWipeCoordinator> createState() =>
      _DatabaseWipeCoordinatorState();
}

class _DatabaseWipeCoordinatorState
    extends ConsumerState<DatabaseWipeCoordinator> {
  String? _handledUid;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final authRepo = ref.read(authRepositoryProvider);
    authRepo.authStateChanges.listen((uid) {
      _handleUid(uid);
    });
  }

  Future<void> _handleUid(String? uid) async {
    final previous = _handledUid;
    _handledUid = uid;

    // First emission: just record it, never wipe on startup.
    if (previous == null) return;
    if (previous == uid) return;

    final wipe = ref.read(databaseWipeServiceProvider);
    await wipe.wipeAll();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}