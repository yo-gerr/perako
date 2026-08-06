import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../domain/goal_service.dart';

/// The goal engine, backed by the ledger.
final goalServiceProvider = Provider<GoalService>((ref) {
  return GoalService(
    db: ref.watch(appDatabaseProvider),
    engine: ref.watch(ledgerEngineProvider),
    goalsDao: ref.watch(goalsDaoProvider),
  );
});

/// All active (non-archived) goals.
final goalsProvider = StreamProvider<List<Goal>>((ref) {
  return ref.watch(goalsDaoProvider).watchActive();
});

/// Archived (soft-deleted) goals.
final archivedGoalsProvider = StreamProvider<List<Goal>>((ref) {
  return ref.watch(goalsDaoProvider).watchArchived();
});

/// A single goal by id, or null.
final goalProvider = FutureProvider.family<Goal?, String>((ref, id) {
  return ref.watch(goalsDaoProvider).byId(id);
});

/// A goal paired with its current progress.
class GoalWithProgress {
  const GoalWithProgress(this.goal, this.progress);

  final Goal goal;
  final GoalProgress progress;
}

/// The active goals with their derived progress. Emits a fresh snapshot
/// whenever a goal or a ledger entry changes.
final goalsWithProgressProvider = StreamProvider<List<GoalWithProgress>>(
  (ref) async* {
    final dao = ref.watch(goalsDaoProvider);
    final ledgerDao = ref.watch(ledgerDaoProvider);
    final service = ref.watch(goalServiceProvider);

    final trigger = StreamGroup.merge<Object?>([
      dao.watchActive(),
      ledgerDao.changes(),
    ]);

    await for (final _ in trigger) {
      final goals = await dao.active();
      final rows = <GoalWithProgress>[];
      for (final g in goals) {
        rows.add(GoalWithProgress(g, service.progress(g)));
      }
      rows.sort((a, b) => a.progress.ratio.compareTo(b.progress.ratio));
      yield rows;
    }
  },
);

/// The top active goals by progress ratio, for the dashboard summary card.
final topGoalsProvider = Provider<List<GoalWithProgress>>((ref) {
  final rows =
      ref.watch(goalsWithProgressProvider).valueOrNull ?? const [];
  final sorted = [...rows];
  sorted.sort((a, b) => b.progress.ratio.compareTo(a.progress.ratio));
  return sorted.take(3).toList();
});

/// Progress for a single goal, recomputed on ledger or goal changes.
final goalProgressProvider = StreamProvider.family<GoalProgress, String>(
  (ref, id) async* {
    final dao = ref.watch(goalsDaoProvider);
    final ledgerDao = ref.watch(ledgerDaoProvider);
    final service = ref.watch(goalServiceProvider);

    final trigger = StreamGroup.merge<Object?>([
      dao.watchActive(),
      ledgerDao.changes(),
    ]);

    await for (final _ in trigger) {
      final goal = await dao.byId(id);
      if (goal == null) continue;
      yield service.progress(goal);
    }
  },
);

/// Everything the goal detail screen renders.
class GoalDetailData {
  const GoalDetailData({
    required this.goal,
    required this.progress,
    required this.contributions,
  });

  final Goal goal;
  final GoalProgress progress;
  final List<GoalContribution> contributions;
}

/// Full detail snapshot for a single goal (progress + contribution history).
final goalDetailProvider =
    StreamProvider.family<GoalDetailData?, String>((ref, id) async* {
  final dao = ref.watch(goalsDaoProvider);
  final ledgerDao = ref.watch(ledgerDaoProvider);
  final service = ref.watch(goalServiceProvider);

  final trigger = StreamGroup.merge<Object?>([
    dao.watchActive(),
    dao.watchContributionsFor(id),
    ledgerDao.changes(),
  ]);

  await for (final _ in trigger) {
    final goal = await dao.byId(id);
    if (goal == null) {
      yield null;
      continue;
    }
    final contributions = await dao.contributionsFor(id);
    contributions.sort((a, b) => b.contributedOn.compareTo(a.contributedOn));
    yield GoalDetailData(
      goal: goal,
      progress: service.progress(goal),
      contributions: contributions,
    );
  }
});
