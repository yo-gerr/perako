import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/presentation/providers/auth_providers.dart';

/// Hands the current [HomeShellState] to descendant branch pages so they can
/// open the drawer and switch tabs (navigationShell.goBranch) from inside
/// their own Scaffolds.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static HomeShellState of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_ShellScope>();
    assert(scope != null, 'HomeShell not found in widget tree');
    return scope!.state;
  }

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void openDrawer() => _scaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    return _ShellScope(
      state: this,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _buildDrawer(context),
        body: widget.navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: (index) =>
              widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          ),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Accounts',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Transactions',
            ),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final shellIndex = widget.navigationShell.currentIndex;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Text('PeraKo',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            const Divider(),
            ListTile(
              selected: shellIndex == 0,
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard'),
              onTap: () => _goToBranch(0),
            ),
            ListTile(
              selected: shellIndex == 1,
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Accounts'),
              onTap: () => _goToBranch(1),
            ),
            ListTile(
              selected: shellIndex == 2,
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Transactions'),
              onTap: () => _goToBranch(2),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Categories'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/categories');
              },
            ),
            ListTile(
              leading: const Icon(Icons.savings_outlined),
              title: const Text('Budgets'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/budgets');
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Bills'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/bills');
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Goals'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/goals');
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Time Deposits'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/time-deposits');
              },
            ),
            ListTile(
              leading: const Icon(Icons.savings_outlined),
              title: const Text('MP2'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/mp2');
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: const Text('Reports'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/reports');
              },
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Search'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/search');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/settings');
              },
            ),
            const SizedBox(height: 16),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () => _confirmSignOut(context),
            ),
          ],
        ),
      ),
    );
  }

  void _goToBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
    Navigator.of(context).pop(); // Close the drawer.
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ref = ProviderScope.containerOf(context, listen: false);
    Navigator.of(context).pop(); // Close the drawer.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'Local data will be cleared. Your data is kept in the cloud.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }
}

class _ShellScope extends InheritedWidget {
  const _ShellScope({required this.state, required super.child});

  final HomeShellState state;

  @override
  bool updateShouldNotify(_ShellScope oldWidget) => false;
}
