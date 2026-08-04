import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../accounts/presentation/account_style.dart';
import '../../domain/category_types.dart';
import '../providers/categories_providers.dart';

class CategoriesListScreen extends ConsumerStatefulWidget {
  const CategoriesListScreen({super.key});

  @override
  ConsumerState<CategoriesListScreen> createState() =>
      _CategoriesListScreenState();
}

class _CategoriesListScreenState extends ConsumerState<CategoriesListScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(_showArchived
        ? archivedCategoriesProvider
        : categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton(
              heroTag: 'fab_categories',
              onPressed: () => context.push('/categories/new'),
              tooltip: 'Add category',
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false,
                    label: Text('Active'),
                    icon: Icon(Icons.check_circle_outline)),
                ButtonSegment(
                    value: true,
                    label: Text('Archived'),
                    icon: Icon(Icons.archive_outlined)),
              ],
              selected: {_showArchived},
              onSelectionChanged: (s) => setState(() => _showArchived = s.first),
            ),
          ),
          Expanded(
            child: categories.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      _showArchived
                          ? 'No archived categories.'
                          : 'No categories yet.\nUse + to create one.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                if (_showArchived) {
                  return ListView(
                    children: [
                      for (final c in list)
                        _CategoryTile(
                          category: c,
                          indent: 0,
                          onReopen: () => _reopen(c),
                        ),
                    ],
                  );
                }
                final byParent = <String?, List<Category>>{};
                for (final c in list) {
                  byParent.putIfAbsent(c.parentId, () => []).add(c);
                }
                final roots = byParent[null] ?? const [];

                return ListView(
                  children: [
                    for (final root in roots) ...[
                      _CategoryTile(category: root, indent: 0),
                      for (final child in byParent[root.id] ?? const [])
                        _CategoryTile(category: child, indent: 1),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reopen(Category category) async {
    await ref
        .read(categoriesDaoProvider)
        .reopen(category.id, nowMillis: DateTime.now().millisecondsSinceEpoch);
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({
    required this.category,
    required this.indent,
    this.onReopen,
  });

  final Category category;
  final int indent;
  final VoidCallback? onReopen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = CategoryType.fromKey(category.type);
    return Card(
      margin: EdgeInsets.symmetric(
          horizontal: 12, vertical: 2).copyWith(left: 12 + indent * 20),
      child: ListTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: colorFromName(category.color).withValues(alpha: 0.2),
          child: Icon(iconFromName(category.icon),
              size: 18, color: colorFromName(category.color)),
        ),
        title: Text(category.name),
        subtitle: Text(type.label),
        trailing: onReopen != null
            ? IconButton(
                icon: const Icon(Icons.restore),
                tooltip: 'Reopen',
                onPressed: onReopen,
              )
            : null,
        onTap: onReopen != null
            ? null
            : () => context.push('/categories/${category.id}/edit'),
        onLongPress: onReopen != null ? null : () => _archive(context, ref),
      ),
    );
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Archive category?'),
        content: Text('"${category.name}" will be hidden.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Archive')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(categoriesDaoProvider)
          .archive(category.id, nowMillis: DateTime.now().millisecondsSinceEpoch);
    }
  }
}
