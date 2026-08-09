import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';

/// Wipes the local SQLite DB when the *signed-in account* changes.
///
/// SQLite is the local source of truth and survives sign-out, so a user who
/// chooses not to sign in keeps their data on the device. Sync cursors are
/// stored per-collection (not per-account), so signing into a *different*
/// account on the same device clears the prior account's local mirror before
/// pulling that account's own data — otherwise two accounts would share one
/// cursor set and could lose changes during sync.
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

    // Signing out keeps local data. Only switching between two different
    // signed-in accounts clears the local mirror.
    if (uid == null) return;

    final wipe = ref.read(databaseWipeServiceProvider);
    await wipe.wipeAll();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}