import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/database/app_database.dart';
import 'package:perako/core/database/daos/accounts_dao.dart';
import 'package:perako/core/database/daos/bills_dao.dart';
import 'package:perako/core/database/daos/categories_dao.dart';
import 'package:perako/core/database/daos/transactions_dao.dart';
import 'package:perako/features/ledger/domain/ledger_engine.dart';
import 'package:perako/features/search/domain/search_service.dart';

void main() {
  late AppDatabase db;
  late LedgerEngine engine;
  late SearchService service;
  late int clock;
  late Set<String> addedAccounts;
  int idCounter = 0;
  String nextId() => 'id_${idCounter++}';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = 1_000_000;
    idCounter = 0;
    addedAccounts = {};
    engine = LedgerEngine(
      db: db,
      idGenerator: nextId,
      clock: () => clock,
    );
    service = SearchService(
      db: db,
      accountsDao: AccountsDao(db),
      categoriesDao: CategoriesDao(db),
      transactionsDao: TransactionsDao(db),
      billsDao: BillsDao(db),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> addAccount(String id, {String? name}) async {
    if (!addedAccounts.add(id)) return;
    await db.into(db.accounts).insert(AccountsCompanion(
      id: Value(id),
      name: Value(
          name ?? (id == 'savings' ? 'Savings Bank' : 'Everyday Wallet')),
      type: const Value('checking'),
      currency: const Value('PHP'),
      color: const Value('blue'),
      icon: const Value('wallet'),
      isArchived: const Value(false),
      openingDate: Value(clock),
      updatedAt: Value(clock),
      version: const Value(1),
    ));
  }

  Future<void> addCategory(String id, String name,
          {String type = 'expense'}) =>
      db.into(db.categories).insert(CategoriesCompanion(
        id: Value(id),
        name: Value(name),
        type: Value(type),
        color: const Value('orange'),
        icon: const Value('category'),
        isArchived: const Value(false),
        updatedAt: Value(clock),
        version: const Value(1),
      ));

  Future<void> addBill(String id, String name) => db.into(db.bills).insert(
        BillsCompanion(
          id: Value(id),
          name: Value(name),
          accountId: const Value('checking'),
          categoryId: const Value(null),
          amountCents: const Value(150000),
          frequency: const Value('monthly'),
          dayOfMonth: const Value(null),
          nextDueDate: Value(clock + 10),
          createdAt: const Value(1),
          updatedAt: const Value(1),
          version: const Value(1),
        ),
      );

  Future<void> addTag(String id, String name) => db.into(db.tags).insert(
        TagsCompanion(
          id: Value(id),
          name: Value(name),
          color: const Value('teal'),
          updatedAt: Value(clock),
          version: const Value(1),
        ),
      );

  Future<String> addTransaction({
    required String description,
    String? notes,
    required int onDay,
    String? categoryId,
    String accountId = 'checking',
    bool income = false,
  }) async {
    await addAccount(accountId);
    return engine.postTransaction(
      description: description,
      notes: notes,
      on: DateTime(2026, 1, onDay, 12),
      lines: income
          ? const [
              LedgerLine(
                accountId: 'checking',
                type: EntryType.debit,
                amountCents: 100000,
              ),
              LedgerLine(
                accountId: 'counterparty_income',
                type: EntryType.credit,
                amountCents: 100000,
                categoryId: 'salary',
              ),
            ]
          : [
              LedgerLine(
                accountId: accountId,
                type: EntryType.credit,
                amountCents: 15000,
                categoryId: categoryId,
              ),
              LedgerLine(
                accountId: 'counterparty_expense',
                type: EntryType.debit,
                amountCents: 15000,
                categoryId: categoryId,
              ),
            ],
    );
  }

  group('search', () {
    test('blank term returns no results', () async {
      await addAccount('checking');
      final results = await service.search(const SearchQuery());
      expect(results.isEmpty, isTrue);
    });

    test('finds a transaction by description and enriches it', () async {
      await addCategory('salary', 'Salary', type: 'income');
      final txId = await addTransaction(
        description: 'January payroll',
        onDay: 5,
        categoryId: 'salary',
        income: true,
      );

      final results = await service.search(const SearchQuery(term: 'payroll'));
      expect(results.transactions, hasLength(1));
      final hit = results.transactions.single;
      expect(hit.id, txId);
      expect(hit.description, 'January payroll');
      expect(hit.date, DateTime(2026, 1, 5, 12));
      expect(hit.accountName, 'Everyday Wallet');
      expect(hit.categoryName, 'Salary');
      expect(hit.signedAmountCents, greaterThan(0));
    });

    test('matches notes and is case-insensitive', () async {
      await addTransaction(
        description: 'Lunch',
        notes: "Mikayla's birthday",
        onDay: 10,
      );
      await addTransaction(description: 'Dinner', notes: 'Other', onDay: 11);

      final results = await service.search(const SearchQuery(term: 'mikayla'));
      expect(results.transactions, hasLength(1));
      expect(results.transactions.single.description, 'Lunch');

      final upper = await service.search(const SearchQuery(term: 'LUNCH'));
      expect(upper.transactions, hasLength(1));
      expect(upper.transactions.single.notes, "Mikayla's birthday");
    });

    test('expense hits are negative and inflow hits positive', () async {
      await addCategory('salary', 'Salary', type: 'income');
      await addTransaction(
        description: 'Groceries',
        onDay: 4,
        categoryId: 'food',
      );
      await addTransaction(
        description: 'Payroll credit',
        onDay: 6,
        categoryId: 'salary',
        income: true,
      );

      final results = await service.search(const SearchQuery(term: 'r'));
      final byDescription = {
        for (final h in results.transactions) h.description: h,
      };
      expect(byDescription['Groceries']!.signedAmountCents, lessThan(0));
      expect(byDescription['Payroll credit']!.signedAmountCents,
          greaterThan(0));
    });

    test('applies the date window inclusively', () async {
      await addTransaction(description: 'Early', onDay: 2);
      await addTransaction(description: 'Late', onDay: 20);

      final results = await service.search(SearchQuery(
        term: 'e',
        from: DateTime(2026, 1, 10),
        to: DateTime(2026, 1, 31),
      ));
      expect(results.transactions.map((h) => h.description), ['Late']);
    });

    test('filters by tag and only transaction hits are affected', () async {
      await addTag('tag_travel', 'travel');
      final flight = await addTransaction(description: 'Flight', onDay: 3);
      await addTransaction(description: 'Bus ride', onDay: 4);
      await db.into(db.transactionTags).insert(TransactionTagsCompanion(
        transactionId: Value(flight),
        tagId: const Value('tag_travel'),
      ));

      final tagged = await service.search(SearchQuery(
        term: 'i',
        tagId: 'tag_travel',
      ));
      expect(tagged.transactions.map((h) => h.description), ['Flight']);

      final unfiltered = await service.search(const SearchQuery(term: 'i'));
      expect(unfiltered.transactions, hasLength(2));
    });

    test('excludes archived transactions, accounts, bills, categories, and tags',
        () async {
      await addAccount('checking');
      await addCategory('food', 'Snacks');
      await addBill('bill_rent', 'Rent');
      await addTag('tag_x', 'night out');
      await addTransaction(description: 'Shown', onDay: 5);
      await addTransaction(description: 'Hidden', onDay: 6);

      final now = clock;
      await (db.update(db.transactions)
            ..where((t) => t.description.equals('Hidden')))
          .write(TransactionsCompanion(deletedAt: Value(now)));
      await (db.update(db.categories))
          .write(CategoriesCompanion(deletedAt: Value(now)));
      await (db.update(db.bills)).write(BillsCompanion(deletedAt: Value(now)));
      await (db.update(db.tags)).write(TagsCompanion(deletedAt: Value(now)));
      await db.into(db.accounts).insert(AccountsCompanion(
        id: const Value('archived_acc'),
        name: const Value('Archived Wallet'),
        type: const Value('checking'),
        currency: const Value('PHP'),
        color: const Value('blue'),
        icon: const Value('wallet'),
        isArchived: const Value(false),
        openingDate: Value(clock),
        updatedAt: Value(clock),
        version: const Value(1),
        deletedAt: Value(now),
      ));
      await addAccount('savings');

      final results = await service.search(const SearchQuery(term: 'n'));
      expect(results.transactions.map((h) => h.description), ['Shown']);
      expect(results.accounts, hasLength(1));
      expect(results.accounts.single.name, 'Savings Bank');
      expect(results.bills, isEmpty);
      expect(results.categories, isEmpty);
      expect(results.tags, isEmpty);
    });
  });

  group('entity matching', () {
    test('accounts match by name', () async {
      await addAccount('savings');
      final results = await service.search(const SearchQuery(term: 'savings'));
      expect(results.accounts, hasLength(1));
      expect(results.accounts.single.name, 'Savings Bank');
    });

    test('bills match by name and surface due date', () async {
      await addBill('bill_rent', 'Apartment Rent');
      final results = await service.search(const SearchQuery(term: 'rent'));
      expect(results.bills, hasLength(1));
      expect(results.bills.single.amountCents, 150000);
      expect(results.bills.single.frequency, 'monthly');
      expect(results.bills.single.nextDueDate,
          DateTime.fromMillisecondsSinceEpoch(clock + 10));
    });

    test('categories match by name', () async {
      await addCategory('food', 'Food and Drink');
      final results = await service.search(const SearchQuery(term: 'food'));
      expect(results.categories, hasLength(1));
      expect(results.categories.single.type, 'expense');
    });

    test('tags match by name', () async {
      await addTag('tag_work', 'work projects');
      final results = await service.search(const SearchQuery(term: 'work'));
      expect(results.tags, hasLength(1));
      expect(results.tags.single.name, 'work projects');
    });
  });

  group('type filtering', () {
    test('restricts results to the requested entity types', () async {
      await addAccount('checking');
      await addAccount('foodbank', name: 'Food Bank');
      await addCategory('food', 'Food');
      await addTransaction(description: 'Food stall', onDay: 3);

      final results = await service.search(const SearchQuery(
        term: 'food',
        types: {SearchEntityType.transaction},
      ));
      expect(results.transactions, hasLength(1));
      expect(results.accounts, isEmpty);
      expect(results.categories, isEmpty);

      final all = await service.search(const SearchQuery(term: 'food'));
      expect(all.transactions, isNotEmpty);
      expect(all.accounts, isNotEmpty);
      expect(all.categories, isNotEmpty);
    });

    test('caps transactions at fifty', () async {
      await addAccount('checking');
      for (var i = 0; i < 60; i++) {
        await addTransaction(description: 'Item $i', onDay: (i % 28) + 1);
      }
      final results = await service.search(const SearchQuery(term: 'item'));
      expect(results.transactions, hasLength(50));
    });
  });
}
