import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../features/settings/domain/app_settings.dart';
import '../../../features/settings/presentation/providers/settings_providers.dart';
import 'app_destinations.dart';
import 'app_side_bar.dart';

/// Responsive shell: surfaces wider than [HomeShellState.expandedBreakpoint]
/// show an expanded labeled sidebar (collapsible to a slim icon rail);
/// surfaces down to [HomeShellState.railBreakpoint] show the icon rail;
/// narrower surfaces show a bottom [NavigationBar] with the primary
/// destinations plus a More page that lists the rest.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Hands the current [HomeShellState] to descendant branch pages so they can
  /// switch branches and sign out from inside their own Scaffolds.
  static HomeShellState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ShellScope>();
    assert(scope != null, 'HomeShell not found in widget tree');
    return scope!.state;
  }

  @override
  ConsumerState<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends ConsumerState<HomeShell> {
  /// Minimum width for the slim icon rail.
  static const double railBreakpoint = 1024;

  /// Minimum width for the expanded labeled sidebar.
  static const double expandedBreakpoint = 1280;

  /// Width of the slim icon rail.
  static const double railWidth = 72;

  /// Width of the expanded labeled sidebar.
  static const double expandedSidebarWidth = 280;

  int get currentIndex => widget.navigationShell.currentIndex;

  bool get isExpanded =>
      MediaQuery.sizeOf(context).width >= expandedBreakpoint;

  bool get isRail => MediaQuery.sizeOf(context).width >= railBreakpoint;

  bool get isCollapsed =>
      ref.read(settingsProvider).valueOrNull?.sidebarCollapsed ??
      AppSettings.defaults.sidebarCollapsed;

  void goBranch(int index, {bool initialLocation = false}) {
    widget.navigationShell.goBranch(index, initialLocation: initialLocation);
  }

  /// Collapses (or re-expands) the wide-surface sidebar, persisting the choice.
  Future<void> toggleSidebarCollapsed() async {
    await ref
        .read(settingsProvider.notifier)
        .setSidebarCollapsed(!isCollapsed);
  }

  Future<void> confirmSignOut() async {
    final ref = ProviderScope.containerOf(context, listen: false);
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

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    final expanded = isExpanded;
    final rail = isRail;
    final collapsed = ref.watch(settingsProvider).valueOrNull?.sidebarCollapsed ??
        AppSettings.defaults.sidebarCollapsed;
    final showExpandedSidebar = expanded && !collapsed;

    final transition = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);

    return _ShellScope(
      state: this,
      child: Scaffold(
        body: rail
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedContainer(
                    duration: transition,
                    curve: Curves.easeInOut,
                    width: showExpandedSidebar
                        ? expandedSidebarWidth
                        : railWidth,
                    child: AnimatedSwitcher(
                      duration: transition,
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: Alignment.centerLeft,
                        clipBehavior: Clip.hardEdge,
                        children: [...previousChildren, ?currentChild],
                      ),
                      child: showExpandedSidebar
                          ? OverflowBox(
                              key: const ValueKey('expandedSidebar'),
                              alignment: Alignment.centerLeft,
                              minWidth: expandedSidebarWidth,
                              maxWidth: expandedSidebarWidth,
                              child: AppSideBar(
                                navigationShell: navigationShell,
                                onToggleCollapsed: toggleSidebarCollapsed,
                              ),
                            )
                          : OverflowBox(
                              key: const ValueKey('navigationRail'),
                              alignment: Alignment.centerLeft,
                              minWidth: railWidth,
                              maxWidth: railWidth,
                              child: AppNavigationRail(
                                navigationShell: navigationShell,
                                canExpand: expanded,
                                onToggleCollapsed: toggleSidebarCollapsed,
                              ),
                            ),
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: navigationShell),
                ],
              )
            : navigationShell,
        bottomNavigationBar:
            rail ? null : _BottomNavigationBar(navigationShell: navigationShell),
      ),
    );
  }
}

class _BottomNavigationBar extends StatelessWidget {
  const _BottomNavigationBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final destinations = [...primaryDestinations, moreDestination];
    return NavigationBar(
      selectedIndex: _indexForBranch(navigationShell.currentIndex),
      onDestinationSelected: (position) {
        final branch = destinations[position].branchIndex;
        navigationShell.goBranch(
          branch,
          initialLocation: branch == navigationShell.currentIndex,
        );
      },
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label,
          ),
      ],
    );
  }

  /// Maps any branch to its bottom-navigation slot; every non-primary branch
  /// lives behind the More page.
  int _indexForBranch(int branchIndex) {
    for (var i = 0; i < primaryDestinations.length; i++) {
      if (primaryDestinations[i].branchIndex == branchIndex) return i;
    }
    return primaryDestinations.length;
  }
}

class _ShellScope extends InheritedWidget {
  const _ShellScope({required this.state, required super.child});

  final HomeShellState state;

  @override
  bool updateShouldNotify(_ShellScope oldWidget) => false;
}
