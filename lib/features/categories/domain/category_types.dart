/// The kind of transaction a category describes.
enum CategoryType {
  income('Income'),
  expense('Expense'),
  transfer('Transfer');

  const CategoryType(this.label);

  final String label;

  String get key => name;

  static CategoryType fromKey(String? key) => values.firstWhere(
        (t) => t.key == key,
        orElse: () => CategoryType.expense,
      );
}
