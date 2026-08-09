import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/perako_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/currency_scope.dart';
import '../../../bills/domain/bill_service.dart';
import '../../domain/search_service.dart';
import '../providers/search_providers.dart';

/// Full-text search across transactions, accounts, bills, categories, and
/// tags, with entity-type, date-range, and tag filters.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final term = ref.watch(searchTermProvider);
    final results = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search…',
            border: InputBorder.none,
          ),
          onChanged: (value) =>
              ref.read(searchTermProvider.notifier).setTerm(value),
        ),
        actions: [
          if (term.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear',
              onPressed: () {
                _controller.clear();
                ref.read(searchTermProvider.notifier).setTerm('');
              },
            ),
        ],
      ),
      body: Column(
        children: [
          const _FilterBar(),
          const Divider(height: 1),
          Expanded(child: _results(context, term, results)),
        ],
      ),
    );
  }

  Widget _results(
    BuildContext context,
    String term,
    AsyncValue<SearchResults> results,
  ) {
    if (term.isEmpty) {
      return const _Hint(
        icon: Icons.search,
        message: 'Search transactions, accounts, bills, categories, and tags.',
      );
    }
    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (data) {
        if (data.isEmpty) {
          return _Hint(icon: Icons.search_off, message: 'No results for "$term".');
        }
        final symbol = CurrencyScope.of(context);
        return ListView(
          children: [
            if (data.transactions.isNotEmpty) ...[
              const _SectionHeader('Transactions'),
              for (final hit in data.transactions)
                _TransactionTile(hit: hit, symbol: symbol),
            ],
            if (data.accounts.isNotEmpty) ...[
              const _SectionHeader('Accounts'),
              for (final hit in data.accounts) _AccountTile(hit: hit),
            ],
            if (data.bills.isNotEmpty) ...[
              const _SectionHeader('Bills'),
              for (final hit in data.bills) _BillTile(hit: hit, symbol: symbol),
            ],
            if (data.categories.isNotEmpty) ...[
              const _SectionHeader('Categories'),
              for (final hit in data.categories) _CategoryTile(hit: hit),
            ],
            if (data.tags.isNotEmpty) ...[
              const _SectionHeader('Tags'),
              for (final hit in data.tags) _TagTile(hit: hit),
            ],
          ],
        );
      },
    );
  }
}

/// Type filter chips plus the date-range and tag filters.
class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(searchFiltersProvider);
    final tags = ref.watch(searchTagsProvider).valueOrNull ?? const [];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: filters.types.isEmpty,
            onSelected: (_) =>
                ref.read(searchFiltersProvider.notifier).clearTypes(),
          ),
          const SizedBox(width: 8),
          for (final type in SearchEntityType.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_typeLabel(type)),
                selected: filters.types.contains(type),
                onSelected: (_) =>
                    ref.read(searchFiltersProvider.notifier).toggleType(type),
              ),
            ),
          const SizedBox(width: 4),
          ActionChip(
            avatar: const Icon(Icons.date_range, size: 18),
            label: Text(_rangeLabel(filters)),
            onPressed: () => _pickRange(context, ref, filters),
          ),
          const SizedBox(width: 8),
          if (tags.isNotEmpty) ...[
            ActionChip(
              avatar: const Icon(Icons.label_outline, size: 18),
              label: Text(_tagLabel(filters, tags)),
              onPressed: () => _pickTag(context, ref, filters, tags),
            ),
            const SizedBox(width: 8),
          ],
          if (filters.isActive)
            ActionChip(
              label: const Text('Clear'),
              onPressed: () =>
                  ref.read(searchFiltersProvider.notifier).clear(),
            ),
        ],
      ),
    );
  }

  static String _typeLabel(SearchEntityType type) => switch (type) {
        SearchEntityType.transaction => 'Transactions',
        SearchEntityType.account => 'Accounts',
        SearchEntityType.bill => 'Bills',
        SearchEntityType.category => 'Categories',
        SearchEntityType.tag => 'Tags',
      };

  static String _rangeLabel(SearchFilters filters) {
    if (filters.from == null && filters.to == null) return 'Date';
    return '${_shortDate(filters.from!)} – ${_shortDate(filters.to ?? DateTime.now())}';
  }

  static String _tagLabel(SearchFilters filters, List<Tag> tags) {
    if (filters.tagId == null) return 'Tag';
    for (final tag in tags) {
      if (tag.id == filters.tagId) return 'Tag: ${tag.name}';
    }
    return 'Tag';
  }

  static Future<void> _pickRange(
    BuildContext context,
    WidgetRef ref,
    SearchFilters filters,
  ) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: (filters.from != null && filters.to != null)
          ? DateTimeRange(start: filters.from!, end: filters.to!)
          : null,
    );
    if (picked != null) {
      ref
          .read(searchFiltersProvider.notifier)
          .setRange(picked.start, picked.end);
    }
  }

  static Future<void> _pickTag(
    BuildContext context,
    WidgetRef ref,
    SearchFilters filters,
    List<Tag> tags,
  ) async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            if (filters.tagId != null)
              ListTile(
                leading: const Icon(Icons.filter_alt_off),
                title: const Text('No tag filter'),
                onTap: () => Navigator.of(sheetContext).pop(null),
              ),
            for (final tag in tags)
              ListTile(
                leading: const Icon(Icons.label_outline),
                title: Text(tag.name),
                trailing: tag.id == filters.tagId
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(tag.id),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      ref.read(searchFiltersProvider.notifier).setTag(selected);
    }
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.hit, required this.symbol});

  final TransactionHit hit;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInflow = hit.signedAmountCents >= 0;
    return ListTile(
      title: Text(
        hit.description.isNotEmpty ? hit.description : hit.id,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          _shortDate(hit.date),
          hit.accountName,
          if (hit.categoryName != null) hit.categoryName!,
        ].join(' · '),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${isInflow ? '+' : '-'}${formatMoney(hit.signedAmountCents.abs(), symbol: symbol)}',
        style: theme.textTheme.titleMedium?.copyWith(
          color: isInflow
              ? theme.perakoColors.incomeText
              : theme.perakoColors.expenseText,
        ),
      ),
      onTap: () => context.push('/transactions/${hit.id}'),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.hit});

  final AccountHit hit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: const Icon(Icons.account_balance_wallet),
      ),
      title: Text(hit.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(hit.type),
      onTap: () => context.push('/accounts/${hit.id}'),
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({required this.hit, required this.symbol});

  final BillHit hit;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.receipt_long_outlined),
      title: Text(hit.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${BillFrequency.fromKey(hit.frequency).label} · next due ${_shortDate(hit.nextDueDate)}',
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        formatMoney(hit.amountCents, symbol: symbol),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onTap: () => context.push('/bills/${hit.id}'),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.hit});

  final CategoryHit hit;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.category_outlined),
      title: Text(hit.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(hit.type),
      onTap: () => context.push('/categories'),
    );
  }
}

class _TagTile extends ConsumerWidget {
  const _TagTile({required this.hit});

  final TagHit hit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFiltering = ref.watch(searchFiltersProvider).tagId == hit.id;
    return ListTile(
      leading: Icon(Icons.label,
          color: isFiltering ? Theme.of(context).colorScheme.primary : null),
      title: Text(hit.name, overflow: TextOverflow.ellipsis),
      trailing: isFiltering
          ? const Icon(Icons.check)
          : const Icon(Icons.filter_alt_outlined, size: 18),
      onTap: () => ref
          .read(searchFiltersProvider.notifier)
          .setTag(isFiltering ? null : hit.id),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';
