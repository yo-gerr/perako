import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../features/accounts/presentation/account_style.dart';

/// Maximum grid width so tiles keep a usable size on tablets and desktop.
const double _maxGridWidth = 520;

/// Approximate tile width used to derive the column count.
const double _tileIdealWidth = 64;

const int _minColumns = 4;
const int _maxColumns = 8;
const double _gridSpacing = 8;
const EdgeInsets _gridPadding = EdgeInsets.fromLTRB(16, 4, 16, 16);

/// The number of icon columns for a sheet of [width] pixels, so tiles stay
/// between ~48dp and ~64dp on phones and are capped on wide screens.
int iconGridColumns(double width) {
  final effective = width < _maxGridWidth ? width : _maxGridWidth;
  final columns = (effective / _tileIdealWidth).floor();
  if (columns < _minColumns) return _minColumns;
  if (columns > _maxColumns) return _maxColumns;
  return columns;
}

/// The vertical scroll offset that brings the tile at [index] to the top of
/// the grid, for a sheet of [width] pixels laid out with [columns] columns.
double iconGridScrollOffset({
  required int index,
  required int columns,
  required double width,
}) {
  final gridWidth = width < _maxGridWidth ? width : _maxGridWidth;
  final tileWidth =
      (gridWidth - _gridPadding.horizontal - (columns - 1) * _gridSpacing) /
          columns;
  final row = index ~/ columns;
  return _gridPadding.top + row * (tileWidth + _gridSpacing);
}

/// A tappable box showing the currently selected icon; opens the searchable
/// icon picker bottom sheet when tapped.
class IconPickerField extends StatelessWidget {
  const IconPickerField({
    super.key,
    required this.selected,
    required this.color,
    required this.onChanged,
  });

  /// The stored icon name.
  final String selected;

  /// The current account/category color, used to tint the icon avatar.
  final Color color;

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: color.withValues(alpha: 0.2),
          child: FaIcon(iconFromName(selected), color: color, size: 22),
        ),
        title: const Text('Icon'),
        subtitle: Text(iconSearchLabel(selected)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showIconPickerSheet(
          context,
          selected: selected,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Opens a modal bottom sheet with a search field and a grid of icons to pick
/// from. The picked icon name is delivered through [onChanged].
Future<void> showIconPickerSheet(
  BuildContext context, {
  required String selected,
  required ValueChanged<String> onChanged,
}) async {
  final picked = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _IconPickerSheet(selected: selected),
  );
  if (picked != null) onChanged(picked);
}

class _IconPickerSheet extends StatefulWidget {
  const _IconPickerSheet({required this.selected});

  final String selected;

  @override
  State<_IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends State<_IconPickerSheet> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  List<IconOption> _filtered = const [];
  bool _revealedSelection = false;

  @override
  void initState() {
    super.initState();
    _filtered = iconCatalog;
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _updateQuery(String value) {
    final q = value.trim().toLowerCase();
    setState(() {
      _query = value;
      _filtered = _matching(q);
    });
  }

  List<IconOption> _matching(String q) {
    if (q.isEmpty) return iconCatalog;
    return [
      for (final option in iconCatalog)
        if (iconSearchLabel(option.name).toLowerCase().contains(q) ||
            option.name.contains(q))
          option,
    ];
  }

  void _clearSearch() {
    _search.clear();
    _updateQuery('');
  }

  /// Scrolls the grid once, after the first frame, so the already-selected
  /// icon is visible when the sheet opens.
  void _revealSelection(int columns, double width) {
    if (_revealedSelection || _query.isNotEmpty) return;
    final index = iconCatalog.indexWhere((o) => o.name == widget.selected);
    if (index <= 0) return;
    _revealedSelection = true;
    final target = iconGridScrollOffset(index: index, columns: columns, width: width);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final maxExtent = _scroll.position.maxScrollExtent;
      _scroll.jumpTo(target.clamp(0.0, maxExtent));
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = iconGridColumns(width);
    _revealSelection(columns, width);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: 0.8,
          child: Column(
            children: [
              Text(
                'Choose icon · ${_filtered.length}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  key: const Key('icon-search-field'),
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  decoration: InputDecoration(
                    hintText: 'Search icons',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            key: const Key('icon-search-clear'),
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          ),
                  ),
                  onChanged: _updateQuery,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _filtered.isEmpty
                    ? _EmptySearch(onClear: _clearSearch)
                    : Center(
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: _maxGridWidth),
                          child: GridView.builder(
                            controller: _scroll,
                            padding: _gridPadding,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              mainAxisSpacing: _gridSpacing,
                              crossAxisSpacing: _gridSpacing,
                            ),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final option = _filtered[index];
                              return _IconTile(
                                option: option,
                                isSelected: option.name == widget.selected,
                                onTap: () =>
                                    Navigator.pop(context, option.name),
                              );
                            },
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off,
              size: 40, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 8),
          const Text('No icons match your search.'),
          const SizedBox(height: 4),
          TextButton(onPressed: onClear, child: const Text('Clear search')),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final IconOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isSelected ? scheme.primary : scheme.onSurfaceVariant;
    final label = iconSearchLabel(option.name);
    return Semantics(
      label: label,
      selected: isSelected,
      button: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? scheme.primary.withValues(alpha: 0.12)
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? scheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: FaIcon(option.icon, color: color, size: 26),
          ),
        ),
      ),
    );
  }
}
