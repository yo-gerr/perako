import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';

/// All active categories, flattened (parents and children).
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoriesDaoProvider).watchActive();
});

/// All archived (soft-deleted) categories.
final archivedCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoriesDaoProvider).watchArchived();
});

/// A single category by id, or null.
final categoryProvider = FutureProvider.family<Category?, String>((ref, id) {
  return ref.watch(categoriesDaoProvider).byId(id);
});
