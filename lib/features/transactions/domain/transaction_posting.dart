import '../../../core/constants.dart';
import '../../ledger/domain/ledger_engine.dart';

/// The kind of financial event a transaction records.
enum TxType { income, expense, transfer }

/// Builds the balanced double-entry [LedgerLine]s for a [type] transaction.
///
/// - income: debit the account, credit the hidden income corpus.
/// - expense: credit the account, debit the hidden expense corpus.
/// - transfer: debit the destination, credit the source.
///
/// The category is attached to the corpus side so spending/income can be
/// reported per category without polluting real account balances.
List<LedgerLine> buildLedgerLines({
  required TxType type,
  required String accountId,
  String? toAccountId,
  String? categoryId,
  required int amountCents,
}) {
  assert(amountCents > 0, 'Amount must be positive');
  switch (type) {
    case TxType.income:
      return [
        LedgerLine(
            accountId: accountId,
            type: EntryType.debit,
            amountCents: amountCents),
        LedgerLine(
            accountId: LedgerConstants.counterpartyIncome,
            type: EntryType.credit,
            amountCents: amountCents,
            categoryId: categoryId),
      ];
    case TxType.expense:
      return [
        LedgerLine(
            accountId: accountId,
            type: EntryType.credit,
            amountCents: amountCents),
        LedgerLine(
            accountId: LedgerConstants.counterpartyExpense,
            type: EntryType.debit,
            amountCents: amountCents,
            categoryId: categoryId),
      ];
    case TxType.transfer:
      return [
        LedgerLine(
            accountId: toAccountId!,
            type: EntryType.debit,
            amountCents: amountCents),
        LedgerLine(
            accountId: accountId,
            type: EntryType.credit,
            amountCents: amountCents),
      ];
  }
}
