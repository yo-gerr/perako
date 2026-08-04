import 'package:flutter_test/flutter_test.dart';

import 'package:perako/core/constants.dart';
import 'package:perako/features/ledger/domain/ledger_engine.dart';
import 'package:perako/features/transactions/domain/transaction_posting.dart';

void main() {
  group('buildLedgerLines', () {
    test('income debits the account and credits the income corpus', () {
      final lines = buildLedgerLines(
        type: TxType.income,
        accountId: 'acc_cash',
        categoryId: 'cat_salary',
        amountCents: 15000,
      );

      expect(lines, hasLength(2));
      expect(lines[0].accountId, 'acc_cash');
      expect(lines[0].type, EntryType.debit);
      expect(lines[0].amountCents, 15000);
      expect(lines[1].accountId, LedgerConstants.counterpartyIncome);
      expect(lines[1].type, EntryType.credit);
      expect(lines[1].amountCents, 15000);
      expect(lines[1].categoryId, 'cat_salary');
    });

    test('expense credits the account and debits the expense corpus', () {
      final lines = buildLedgerLines(
        type: TxType.expense,
        accountId: 'acc_cash',
        categoryId: 'cat_food',
        amountCents: 5000,
      );

      expect(lines, hasLength(2));
      expect(lines[0].accountId, 'acc_cash');
      expect(lines[0].type, EntryType.credit);
      expect(lines[1].accountId, LedgerConstants.counterpartyExpense);
      expect(lines[1].type, EntryType.debit);
      expect(lines[1].categoryId, 'cat_food');
    });

    test('transfer debits the destination and credits the source', () {
      final lines = buildLedgerLines(
        type: TxType.transfer,
        accountId: 'acc_checking',
        toAccountId: 'acc_savings',
        amountCents: 5000,
      );

      expect(lines, hasLength(2));
      expect(lines[0].accountId, 'acc_savings');
      expect(lines[0].type, EntryType.debit);
      expect(lines[1].accountId, 'acc_checking');
      expect(lines[1].type, EntryType.credit);
    });

    test('produces balanced lines for every transaction type', () {
      for (final type in TxType.values) {
        final lines = buildLedgerLines(
          type: type,
          accountId: 'a',
          toAccountId: type == TxType.transfer ? 'b' : null,
          amountCents: 1000,
        );

        final debits = lines
            .where((l) => l.type == EntryType.debit)
            .fold<int>(0, (sum, l) => sum + l.amountCents);
        final credits = lines
            .where((l) => l.type == EntryType.credit)
            .fold<int>(0, (sum, l) => sum + l.amountCents);

        expect(debits, credits, reason: '$type must be balanced');
        expect(debits, greaterThan(0));
      }
    });

    test('never attaches a category to real accounts', () {
      final lines = buildLedgerLines(
        type: TxType.expense,
        accountId: 'acc_cash',
        categoryId: 'cat_food',
        amountCents: 100,
      );
      // Only the corpus side carries the category.
      expect(lines.first.categoryId, isNull);
      expect(lines.last.categoryId, 'cat_food');
    });
  });
}
