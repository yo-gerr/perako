import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../accounts/presentation/account_style.dart';
import '../../domain/category_types.dart';
import '../providers/categories_providers.dart';

class CategoriesListScreen extends ConsumerWidget {
  const CategoriesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_categories',
        onPressed: () => context.push('/categories/new'),
        tooltip: 'Add category',
        child: const Icon(Icons.add),
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No categories yet.\nUse + to create one.',
                  textAlign: TextAlign.center),
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
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.category, required this.indent});

  final Category category;
  final int indent;

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
        onTap: () => context.push('/categories/${category.id}/edit'),
        onLongPress: () => _archive(context, ref),
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
