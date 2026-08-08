import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/color_selector.dart';
import '../../../../core/widgets/custom_dropdown_button2.dart';
import '../../../../core/widgets/icon_picker.dart';
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
  String _icon = 'category';
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
        _icon = category.icon;
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
          icon: Value(_icon),
          updatedAt: Value(now),
        ));
      } else {
        await dao.insertCategory(CategoriesCompanion(
          id: Value('cat_${DateTime.now().microsecondsSinceEpoch}'),
          name: Value(name),
          parentId: Value(_parentId),
          type: Value(_type.key),
          color: Value(_color),
          icon: Value(_icon),
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      _isEdit ? 'Edit category' : 'New category',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
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
                          CustomDropdownButton2<CategoryType>(
                            hint: 'Type',
                            dropdownItems: [
                              for (final t in CategoryType.values) t
                            ],
                            itemLabel: (t) => t.label,
                            initialValue: _type,
                            onChanged: (v) =>
                                setState(() => _type = v ?? _type),
                          ),
                          const SizedBox(height: 16),
                          CustomDropdownButton2<String?>(
                            hint: 'Parent (optional)',
                            dropdownItems: [
                              for (final c in parentOptions)
                                if (c.id != widget.categoryId) c.id,
                            ],
                            itemLabel: (id) => parentOptions
                                .firstWhere((c) => c.id == id)
                                .name,
                            initialValue: _parentId,
                            onChanged: (v) => setState(() => _parentId = v),
                          ),
                          const SizedBox(height: 16),
                          ColorSelectorRow(
                            selected: _color,
                            onChanged: (c) => setState(() => _color = c),
                          ),
                          const SizedBox(height: 16),
                          IconPickerField(
                            selected: _icon,
                            color: colorFromName(_color),
                            onChanged: (i) => setState(() => _icon = i),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .error)),
                          ],
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : Text(_isEdit ? 'Save' : 'Create'),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

