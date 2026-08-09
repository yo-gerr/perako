import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_destinations.dart';
import '../../../../core/router/home_shell.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Overflow page shown on narrow surfaces: lists every destination that is not
/// in the bottom navigation bar, plus the account action (sign in or sign out).
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shell = HomeShell.of(context);
    final currentIndex = shell.currentIndex;
    final uid = ref.watch(authStateProvider).valueOrNull;
    final email = ref.watch(authRepositoryProvider).currentEmail;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          const _MoreSectionHeader('Tools'),
          for (final destination in toolDestinations)
            _MoreTile(
              destination: destination,
              selected: currentIndex == destination.branchIndex,
              onTap: () => _goToBranch(shell, destination.branchIndex),
            ),
          const _MoreSectionHeader('Settings'),
          _MoreTile(
            destination: settingsDestination,
            selected: currentIndex == settingsDestination.branchIndex,
            onTap: () => _goToBranch(shell, settingsDestination.branchIndex),
          ),
          const Divider(),
          if (uid == null)
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Sign in to sync'),
              subtitle: const Text(
                  'Back up your data to the cloud. No account? Keep using the '
                  'app locally.'),
              onTap: shell.goToLogin,
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(email ?? 'Signed in'),
              subtitle: const Text('Cloud sync on'),
              enabled: false,
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: shell.confirmSignOut,
            ),
          ],
        ],
      ),
    );
  }

  void _goToBranch(HomeShellState shell, int index) {
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }
}

class _MoreSectionHeader extends StatelessWidget {
  const _MoreSectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      selected: selected,
      leading: Icon(selected ? destination.selectedIcon : destination.icon),
      title: Text(destination.label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      selectedColor: colorScheme.onPrimaryContainer,
      selectedTileColor: colorScheme.primaryContainer,
      onTap: onTap,
    );
  }
}
