import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/accounts_dao.dart';
import '../../../core/database/daos/bills_dao.dart';
import '../../../core/database/daos/categories_dao.dart';
import '../../../core/database/daos/transactions_dao.dart';

/// What kind of entity a search hit is. Used to filter which result groups
/// are produced and shown.
enum SearchEntityType { transaction, account, bill, category, tag }

/// The inputs for a single search pass: a free-text [term], an optional
/// [types] allow-list (empty = all), an optional inclusive [from]/[to] date
/// window, and an optional [tagId] that restricts transaction hits.
class SearchQuery {
  const SearchQuery({
    this.term = '',
    this.types = const {},
    this.from,
    this.to,
    this.tagId,
  });

  final String term;
  final Set<SearchEntityType> types;
  final DateTime? from;
  final DateTime? to;
  final String? tagId;

  bool get isBlank => term.trim().isEmpty;

  bool wants(SearchEntityType type) => types.isEmpty || types.contains(type);
}

/// A transaction that matched, enriched with the primary account name, a
/// signed amount, and (when present) its category.
class TransactionHit {
  const TransactionHit({
    required this.id,
    required this.description,
    required this.notes,
    required this.date,
    required this.signedAmountCents,
    required this.accountName,
    this.categoryName,
  });

  final String id;
  final String description;
  final String? notes;
  final DateTime date;

  /// Positive for money flowing into the primary account, negative otherwise.
  final int signedAmountCents;
  final String accountName;
  final String? categoryName;
}

class AccountHit {
  const AccountHit({required this.id, required this.name, required this.type});

  final String id;
  final String name;
  final String type;
}

class BillHit {
  const BillHit({
    required this.id,
    required this.name,
    required this.amountCents,
    required this.frequency,
    required this.nextDueDate,
  });

  final String id;
  final String name;
  final int amountCents;
  final String frequency;
  final DateTime nextDueDate;
}

class CategoryHit {
  const CategoryHit({required this.id, required this.name, required this.type});

  final String id;
  final String name;
  final String type;
}

class TagHit {
  const TagHit({required this.id, required this.name});

  final String id;
  final String name;
}

/// All matching hits for a query, grouped by entity type.
class SearchResults {
  const SearchResults({
    required this.transactions,
    required this.accounts,
    required this.bills,
    required this.categories,
    required this.tags,
  });

  static const empty = SearchResults(
    transactions: [],
    accounts: [],
    bills: [],
    categories: [],
    tags: [],
  );

  final List<TransactionHit> transactions;
  final List<AccountHit> accounts;
  final List<BillHit> bills;
  final List<CategoryHit> categories;
  final List<TagHit> tags;

  bool get isEmpty =>
      transactions.isEmpty &&
      accounts.isEmpty &&
      bills.isEmpty &&
      categories.isEmpty &&
      tags.isEmpty;

  int get total =>
      transactions.length +
      accounts.length +
      bills.length +
      categories.length +
      tags.length;
}

/// Unified, read-only search across the main user-facing entities. Matching is
/// case-insensitive (SQLite LIKE) and every query is answered live from the
/// database — no search index is maintained.
class SearchService {
  SearchService({
    required this.db,
    required this.accountsDao,
    required this.categoriesDao,
    required this.transactionsDao,
    required this.billsDao,
  });

  final AppDatabase db;
  final AccountsDao accountsDao;
  final CategoriesDao categoriesDao;
  final TransactionsDao transactionsDao;
  final BillsDao billsDao;

  Future<SearchResults> search(SearchQuery query) async {
    if (query.isBlank) return SearchResults.empty;
    final term = query.term.trim();
    return SearchResults(
      transactions: query.wants(SearchEntityType.transaction)
          ? await _transactions(term, query)
          : const [],
      accounts: query.wants(SearchEntityType.account)
          ? await _accounts(term)
          : const [],
      bills: query.wants(SearchEntityType.bill) ? await _bills(term) : const [],
      categories: query.wants(SearchEntityType.category)
          ? await _categories(term)
          : const [],
      tags: query.wants(SearchEntityType.tag) ? await _tags(term) : const [],
    );
  }

  Future<List<TransactionHit>> _transactions(
    String term,
    SearchQuery query,
  ) async {
    final taggedTxIds = <String>{};
    if (query.tagId != null) {
      final links = await (db.select(db.transactionTags)
            ..where((t) => t.tagId.equals(query.tagId!)))
          .get();
      taggedTxIds.addAll(links.map((l) => l.transactionId));
    }

    final rows = await (db.select(db.transactions)
          ..where((t) {
            var condition = t.deletedAt.isNull() &
                (t.description.contains(term) |
                    ifNull<String>(t.notes, const Constant(''))
                        .contains(term));
            if (query.from != null) {
              condition = condition &
                  t.date.isBiggerOrEqualValue(
                      query.from!.millisecondsSinceEpoch);
            }
            if (query.to != null) {
              condition = condition &
                  t.date.isSmallerOrEqualValue(
                      query.to!.millisecondsSinceEpoch);
            }
            if (query.tagId != null) {
              condition = condition & t.id.isIn(taggedTxIds);
            }
            return condition;
          })
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(50))
        .get();

    if (rows.isEmpty) return const [];
    return _enrich(rows);
  }

  Future<List<TransactionHit>> _enrich(List<Transaction> transactions) async {
    final accounts = await accountsDao.all();
    final accountsById = {for (final a in accounts) a.id: a};
    final categories = await categoriesDao.all();
    final categoriesById = {for (final c in categories) c.id: c};

    final txIds = [for (final t in transactions) t.id];
    final entries = await (db.select(db.ledgerEntries)
          ..where((t) =>
              t.transactionId.isIn(txIds) & t.deletedAt.isNull()))
        .get();
    final byTx = <String, List<LedgerEntry>>{};
    for (final e in entries) {
      byTx.putIfAbsent(e.transactionId, () => []).add(e);
    }

    final hits = <TransactionHit>[];
    for (final t in transactions) {
      final txEntries = byTx[t.id] ?? const <LedgerEntry>[];
      if (txEntries.isEmpty) continue;

      final amount =
          txEntries.fold<int>(0, (sum, e) => sum + e.amount) ~/ 2;
      final real = txEntries
          .where((e) => accountsById.containsKey(e.accountId))
          .toList();
      if (real.isEmpty) continue;

      LedgerEntry? corpus;
      for (final e in txEntries) {
        if (!accountsById.containsKey(e.accountId)) {
          corpus = e;
          break;
        }
      }
      final categoryName = (corpus?.categoryId != null &&
              categoriesById.containsKey(corpus!.categoryId))
          ? categoriesById[corpus.categoryId]!.name
          : null;

      final primary = real.first;
      final isInflow = primary.type == 'debit';
      hits.add(TransactionHit(
        id: t.id,
        description: t.description,
        notes: t.notes,
        date: DateTime.fromMillisecondsSinceEpoch(t.date),
        signedAmountCents: isInflow ? amount : -amount,
        accountName: accountsById[primary.accountId]!.name,
        categoryName: categoryName,
      ));
    }
    return hits;
  }

  Future<List<AccountHit>> _accounts(String term) async {
    final rows = await (db.select(db.accounts)
          ..where((t) => t.deletedAt.isNull() & t.name.contains(term))
          ..orderBy([(t) => OrderingTerm.asc(t.name)])
          ..limit(20))
        .get();
    return [
      for (final a in rows) AccountHit(id: a.id, name: a.name, type: a.type),
    ];
  }

  Future<List<BillHit>> _bills(String term) async {
    final rows = await (db.select(db.bills)
          ..where((t) => t.deletedAt.isNull() & t.name.contains(term))
          ..orderBy([(t) => OrderingTerm.asc(t.name)])
          ..limit(20))
        .get();
    return [
      for (final b in rows)
        BillHit(
          id: b.id,
          name: b.name,
          amountCents: b.amountCents,
          frequency: b.frequency,
          nextDueDate: DateTime.fromMillisecondsSinceEpoch(b.nextDueDate),
        ),
    ];
  }

  Future<List<CategoryHit>> _categories(String term) async {
    final rows = await (db.select(db.categories)
          ..where((t) => t.deletedAt.isNull() & t.name.contains(term))
          ..orderBy([(t) => OrderingTerm.asc(t.name)])
          ..limit(20))
        .get();
    return [
      for (final c in rows)
        CategoryHit(id: c.id, name: c.name, type: c.type),
    ];
  }

  Future<List<TagHit>> _tags(String term) async {
    final rows = await (db.select(db.tags)
          ..where((t) => t.deletedAt.isNull() & t.name.contains(term))
          ..orderBy([(t) => OrderingTerm.asc(t.name)])
          ..limit(20))
        .get();
    return [
      for (final t in rows) TagHit(id: t.id, name: t.name),
    ];
  }
}
