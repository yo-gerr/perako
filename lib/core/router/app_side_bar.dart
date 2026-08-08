import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_destinations.dart';
import 'home_shell.dart';

void _goToBranch(HomeShellState shell, int index) {
  shell.goBranch(index, initialLocation: index == shell.currentIndex);
}

/// Expanded labeled sidebar shown on the widest surfaces. Mirrors the desktop
/// navigation sample: wordmark, a primary group, a flex-grow tools group
/// (Settings included), and an isolated danger Sign out footer — each tile a
/// 56px-tall / 28px-radius pill with an active `secondaryContainer` state.
/// The wordmark header carries a chevron that collapses the sidebar to the
/// slim icon rail.
class AppSideBar extends StatelessWidget {
  const AppSideBar({
    super.key,
    required this.navigationShell,
    required this.onToggleCollapsed,
  });

  final StatefulNavigationShell navigationShell;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shell = HomeShell.of(context);
    final currentIndex = navigationShell.currentIndex;

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'PeraKo',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: -0.24,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Collapse sidebar',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: onToggleCollapsed,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                children: [
                  for (final destination in primaryDestinations)
                    _SideBarTile(
                      icon: destination.icon,
                      selectedIcon: destination.selectedIcon,
                      label: destination.label,
                      selected: currentIndex == destination.branchIndex,
                      onTap: () => _goToBranch(shell, destination.branchIndex),
                    ),
                ],
              ),
            ),
            const _SideDivider(),
            Expanded(
              flex: 3,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                children: [
                  for (final destination
                      in [...toolDestinations, settingsDestination])
                    _SideBarTile(
                      icon: destination.icon,
                      selectedIcon: destination.selectedIcon,
                      label: destination.label,
                      selected: currentIndex == destination.branchIndex,
                      onTap: () => _goToBranch(shell, destination.branchIndex),
                    ),
                ],
              ),
            ),
            const _SideDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: _SideBarTile(
                icon: Icons.logout,
                selectedIcon: Icons.logout,
                label: 'Sign out',
                selected: false,
                danger: true,
                onTap: shell.confirmSignOut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slim icon rail shown on medium surfaces and on collapsed wide surfaces.
/// Uses the same tile component as [AppSideBar] in [compact] mode: icons with
/// hover tooltips, an active pill, a monogram mark, and a pinned Sign out
/// footer. When [canExpand] (the surface is wide enough for the expanded
/// sidebar), a chevron re-expands the sidebar.
class AppNavigationRail extends StatelessWidget {
  const AppNavigationRail({
    super.key,
    required this.navigationShell,
    required this.onToggleCollapsed,
    this.canExpand = false,
  });

  final StatefulNavigationShell navigationShell;
  final VoidCallback onToggleCollapsed;

  /// Whether the surface is wide enough for the expanded sidebar.
  final bool canExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shell = HomeShell.of(context);
    final currentIndex = navigationShell.currentIndex;

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Center(child: _BrandMonogram(theme: theme)),
                  if (canExpand) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: IconButton(
                        tooltip: 'Expand sidebar',
                        icon: const Icon(Icons.chevron_right),
                        onPressed: onToggleCollapsed,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (final destination in primaryDestinations)
                    _SideBarTile(
                      icon: destination.icon,
                      selectedIcon: destination.selectedIcon,
                      label: destination.label,
                      selected: currentIndex == destination.branchIndex,
                      compact: true,
                      onTap: () => _goToBranch(shell, destination.branchIndex),
                    ),
                ],
              ),
            ),
            const _SideDivider(),
            Expanded(
              flex: 3,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (final destination
                      in [...toolDestinations, settingsDestination])
                    _SideBarTile(
                      icon: destination.icon,
                      selectedIcon: destination.selectedIcon,
                      label: destination.label,
                      selected: currentIndex == destination.branchIndex,
                      compact: true,
                      onTap: () => _goToBranch(shell, destination.branchIndex),
                    ),
                ],
              ),
            ),
            const _SideDivider(),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SideBarTile(
                icon: Icons.logout,
                selectedIcon: Icons.logout,
                label: 'Sign out',
                selected: false,
                danger: true,
                compact: true,
                onTap: shell.confirmSignOut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact brand mark for the icon rail.
class _BrandMonogram extends StatelessWidget {
  const _BrandMonogram({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    return Tooltip(
      message: 'PeraKo',
      child: Semantics(
        label: 'PeraKo',
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'P',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SideDivider extends StatelessWidget {
  const _SideDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

class _SideBarTile extends StatelessWidget {
  const _SideBarTile({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.danger = false,
    this.compact = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Renders the tile in the `error` color, used by the Sign out action.
  final bool danger;

  /// Icon-only tile for the slim rail; the label is still announced via
  /// [Tooltip] and [Semantics].
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = danger
        ? colorScheme.error
        : (selected
            ? colorScheme.onSecondaryContainer
            : colorScheme.onSurface);
    final iconColor = danger
        ? colorScheme.error
        : (selected
            ? colorScheme.onSecondaryContainer
            : colorScheme.onSurfaceVariant);

    final tileIcon = Icon(
      selected ? selectedIcon : icon,
      size: 24,
      color: iconColor,
    );

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        selected: selected,
        child: Material(
          color: selected && !danger
              ? colorScheme.secondaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 16),
                child: compact
                    ? Center(child: tileIcon)
                    : Row(
                        children: [
                          tileIcon,
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                letterSpacing: 0.08,
                                fontWeight:
                                    selected ? FontWeight.w600 : FontWeight.w400,
                                color: foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
