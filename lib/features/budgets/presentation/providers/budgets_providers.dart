import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../domain/budget_service.dart';

/// The budget engine, backed by the ledger.
final budgetServiceProvider = Provider<BudgetService>((ref) {
  return BudgetService(ledgerDao: ref.watch(ledgerDaoProvider));
});

/// All active (non-archived) budgets.
final budgetsProvider = StreamProvider<List<Budget>>((ref) {
  return ref.watch(budgetsDaoProvider).watchActive();
});

/// Archived (soft-deleted) budgets.
final archivedBudgetsProvider = StreamProvider<List<Budget>>((ref) {
  return ref.watch(budgetsDaoProvider).watchArchived();
});

/// A single budget by id, or null.
final budgetProvider = FutureProvider.family<Budget?, String>((ref, id) {
  return ref.watch(budgetsDaoProvider).byId(id);
});

/// A budget paired with its current period progress.
class BudgetWithProgress {
  const BudgetWithProgress(this.budget, this.progress);

  final Budget budget;
  final BudgetProgress progress;
}

/// A [CategoryBudgetLimit] paired with its spent amount and category.
class CategoryLimitProgress {
  const CategoryLimitProgress(this.limit, this.spentCents, this.category);

  final CategoryBudgetLimit limit;
  final int spentCents;
  final Category? category;
}

/// Everything the budget detail screen renders.
class BudgetDetailData {
  const BudgetDetailData({
    required this.budget,
    required this.progress,
    required this.limits,
  });

  final Budget budget;
  final BudgetProgress progress;
  final List<CategoryLimitProgress> limits;
}

/// The active budgets with their derived progress. Emits a fresh snapshot
/// whenever a budget or a ledger entry changes.
final budgetsWithProgressProvider = StreamProvider<List<BudgetWithProgress>>(
  (ref) async* {
    final dao = ref.watch(budgetsDaoProvider);
    final ledgerDao = ref.watch(ledgerDaoProvider);
    final service = ref.watch(budgetServiceProvider);

    final trigger = StreamGroup.merge<Object?>([
      dao.watchActive(),
      ledgerDao.changes(),
    ]);

    await for (final _ in trigger) {
      final budgets = await dao.active();
      final rows = <BudgetWithProgress>[];
      for (final b in budgets) {
        rows.add(BudgetWithProgress(b, await service.progress(b)));
      }
      rows.sort((a, b) => a.progress.ratio.compareTo(b.progress.ratio));
      yield rows;
    }
  },
);

/// Progress for a single budget, recomputed on ledger or budget changes.
final budgetProgressProvider = StreamProvider.family<BudgetProgress, String>(
  (ref, id) async* {
    final dao = ref.watch(budgetsDaoProvider);
    final ledgerDao = ref.watch(ledgerDaoProvider);
    final service = ref.watch(budgetServiceProvider);

    final trigger = StreamGroup.merge<Object?>([
      dao.watchActive(),
      ledgerDao.changes(),
    ]);

    await for (final _ in trigger) {
      final budget = await dao.byId(id);
      if (budget == null) continue;
      yield await service.progress(budget);
    }
  },
);

/// Full detail snapshot for a single budget (progress + category limits).
final budgetDetailProvider =
    StreamProvider.family<BudgetDetailData?, String>((ref, id) async* {
  final dao = ref.watch(budgetsDaoProvider);
  final ledgerDao = ref.watch(ledgerDaoProvider);
  final categoriesDao = ref.watch(categoriesDaoProvider);
  final service = ref.watch(budgetServiceProvider);

  final trigger = StreamGroup.merge<Object?>([
    dao.watchActive(),
    dao.watchAllLimits(),
    ledgerDao.changes(),
  ]);

  await for (final _ in trigger) {
    final budget = await dao.byId(id);
    if (budget == null) {
      yield null;
      continue;
    }
    final progress = await service.progress(budget);
    final categories = await categoriesDao.all();
    final byId = {for (final c in categories) c.id: c};
    final rows = <CategoryLimitProgress>[];
    for (final l in await dao.limitsFor(id)) {
      rows.add(CategoryLimitProgress(
        l,
        await service.spentForCategory(l.categoryId, progress.period),
        byId[l.categoryId],
      ));
    }
    yield BudgetDetailData(budget: budget, progress: progress, limits: rows);
  }
});
