import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../accounts/presentation/account_style.dart';
import '../../domain/category_types.dart';
import '../providers/categories_providers.dart';

class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({super.key, this.categoryId});

  final String? categoryId;

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _name = TextEditingController();
  CategoryType _type = CategoryType.expense;
  String? _parentId;
  String _color = 'green';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.categoryId != null;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final id = widget.categoryId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    final category = await ref.read(categoriesDaoProvider).byId(id);
    if (!mounted) return;
    setState(() {
      if (category != null) {
        _name.text = category.name;
        _type = CategoryType.fromKey(category.type);
        _parentId = category.parentId;
        _color = category.color;
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final dao = ref.read(categoriesDaoProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      if (_isEdit) {
        await dao.updateCategory(CategoriesCompanion(
          id: Value(widget.categoryId!),
          name: Value(name),
          type: Value(_type.key),
          color: Value(_color),
          updatedAt: Value(now),
        ));
      } else {
        await dao.insertCategory(CategoriesCompanion(
          id: Value('cat_${DateTime.now().microsecondsSinceEpoch}'),
          name: Value(name),
          parentId: Value(_parentId),
          type: Value(_type.key),
          color: Value(_color),
          icon: const Value('category'),
          isArchived: const Value(false),
          updatedAt: Value(now),
          version: const Value(1),
        ));
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentOptions =
        ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];

    return Scaffold(
      appBar:
          AppBar(title: Text(_isEdit ? 'Edit category' : 'New category')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<CategoryType>(
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final t in CategoryType.values)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? _type),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: _parentId,
                    decoration: const InputDecoration(
                      labelText: 'Parent (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('None')),
                      for (final c in parentOptions)
                        if (c.id != widget.categoryId)
                          DropdownMenuItem(
                              value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _parentId = v),
                  ),
                  const SizedBox(height: 16),
                  _ColorSelector(
                    selected: _color,
                    onChanged: (c) => setState(() => _color = c),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isEdit ? 'Save' : 'Create'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ColorSelector extends StatelessWidget {
  const _ColorSelector({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final c in colorChoices)
          InkWell(
            onTap: () => onChanged(c),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorFromName(c),
                shape: BoxShape.circle,
                border: selected == c
                    ? Border.all(
                        width: 3, color: Theme.of(context).colorScheme.onSurface)
                    : null,
              ),
              child: selected == c
                  ? Icon(Icons.check,
                      color: Theme.of(context).colorScheme.onPrimary, size: 18)
                  : null,
            ),
          ),
      ],
    );
  }
}
