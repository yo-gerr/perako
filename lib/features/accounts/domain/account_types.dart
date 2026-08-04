/// The account types PeraKo supports, mapped from the string stored in the
/// [Accounts] table.
enum AccountType {
  cash('Cash'),
  wallet('Wallet'),
  checking('Checking'),
  savings('Savings'),
  timeDeposit('Time Deposit'),
  digitalWallet('Digital Wallet'),
  investment('Investment'),
  creditCard('Credit Card'),
  loan('Loan');

  const AccountType(this.label);

  final String label;

  /// Liability accounts carry a credit balance (what you owe); everything else
  /// is an asset (what you own).
  bool get isLiability =>
      this == AccountType.creditCard || this == AccountType.loan;

  /// Stable string stored in the database (matches the enum name).
  String get key => name;

  static AccountType fromKey(String? key) => values.firstWhere(
        (t) => t.key == key,
        orElse: () => AccountType.cash,
      );
}
