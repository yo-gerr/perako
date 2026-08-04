import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/app_settings.dart';
import '../../domain/currencies.dart';
import '../providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final themePreference =
        settings.valueOrNull?.themePreference ?? AppSettings.defaults.themePreference;
    final currencyCode =
        settings.valueOrNull?.currencyCode ?? AppSettings.defaults.currencyCode;
    final uid = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemePreference>(
              segments: [
                for (final p in ThemePreference.values)
                  ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {themePreference},
              onSelectionChanged: (s) => ref
                  .read(settingsProvider.notifier)
                  .setThemePreference(s.first),
            ),
          ),
          const Divider(),
          const _SectionHeader('Currency'),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('Currency'),
            subtitle: Text(
                '${currencyName(currencyCode)} (${currencySymbol(currencyCode)}1,234.56)'),
            trailing: DropdownButton<String>(
              value: currencyCode,
              underline: const SizedBox.shrink(),
              items: [
                for (final c in supportedCurrencies)
                  DropdownMenuItem(value: c.code, child: Text('${c.code} — ${c.name}')),
              ],
              onChanged: (code) {
                if (code != null) {
                  ref.read(settingsProvider.notifier).setCurrencyCode(code);
                }
              },
            ),
          ),
          const Divider(),
          const _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            subtitle: Text(uid ?? 'Not signed in'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/profile'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Security'),
            subtitle: const Text('Coming soon'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/security'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}
