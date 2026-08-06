import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../domain/search_service.dart';

/// The search engine, backed by the local database.
final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService(
    db: ref.watch(appDatabaseProvider),
    accountsDao: ref.watch(accountsDaoProvider),
    categoriesDao: ref.watch(categoriesDaoProvider),
    transactionsDao: ref.watch(transactionsDaoProvider),
    billsDao: ref.watch(billsDaoProvider),
  );
});

/// The live search term. Typing debounces for 300ms before the value commits,
/// so keystrokes do not trigger a query per character.
class SearchTermNotifier extends StateNotifier<String> {
  SearchTermNotifier() : super('');

  Timer? _debounce;

  void setTerm(String term) {
    _debounce?.cancel();
    _debounce =
        Timer(const Duration(milliseconds: 300), () => state = term.trim());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchTermProvider = StateNotifierProvider<SearchTermNotifier, String>(
  (ref) => SearchTermNotifier(),
);

/// Active filters applied on top of the search term.
class SearchFilters {
  const SearchFilters({
    this.types = const {},
    this.from,
    this.to,
    this.tagId,
  });

  /// Empty set means "search every entity type".
  final Set<SearchEntityType> types;
  final DateTime? from;
  final DateTime? to;
  final String? tagId;

  bool get isActive =>
      types.isNotEmpty || from != null || to != null || tagId != null;

  SearchFilters copyWith({
    Set<SearchEntityType>? types,
    Object? from = _unset,
    Object? to = _unset,
    Object? tagId = _unset,
  }) {
    return SearchFilters(
      types: types ?? this.types,
      from: identical(from, _unset) ? this.from : from as DateTime?,
      to: identical(to, _unset) ? this.to : to as DateTime?,
      tagId: identical(tagId, _unset) ? this.tagId : tagId as String?,
    );
  }

  static const _unset = Object();
}

class SearchFiltersNotifier extends StateNotifier<SearchFilters> {
  SearchFiltersNotifier() : super(const SearchFilters());

  void toggleType(SearchEntityType type) {
    final types = {...state.types};
    if (!types.remove(type)) types.add(type);
    state = state.copyWith(types: types);
  }

  void clearTypes() => state = state.copyWith(types: const <SearchEntityType>{});

  void setRange(DateTime? from, DateTime? to) =>
      state = state.copyWith(from: from, to: to);

  void setTag(String? tagId) => state = state.copyWith(tagId: tagId);

  void clear() => state = const SearchFilters();
}

final searchFiltersProvider =
    StateNotifierProvider<SearchFiltersNotifier, SearchFilters>(
  (ref) => SearchFiltersNotifier(),
);

/// Matches the committed term against the entity allow-list and filters. When
/// the term is blank no work is done.
final searchResultsProvider = FutureProvider<SearchResults>((ref) async {
  final term = ref.watch(searchTermProvider);
  final filters = ref.watch(searchFiltersProvider);
  if (term.isEmpty) return SearchResults.empty;
  return ref.watch(searchServiceProvider).search(SearchQuery(
        term: term,
        types: filters.types,
        from: filters.from,
        to: filters.to,
        tagId: filters.tagId,
      ));
});

/// All non-deleted tags, ordered by name. Used to filter transaction results.
final searchTagsProvider = FutureProvider<List<Tag>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.tags)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .get();
});
