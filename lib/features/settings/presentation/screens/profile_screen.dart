import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = ref.read(authStateProvider).valueOrNull;
    if (uid == null) return;
    final profile = await ref.read(profilesDaoProvider).byUid(uid);
    if (!mounted) return;
    if (profile != null) _name.text = profile.displayName;
  }

  Future<void> _save() async {
    final uid = ref.read(authStateProvider).valueOrNull;
    if (uid == null) {
      setState(() => _error = 'Sign in to save a profile.');
      return;
    }
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a display name.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await ref.read(profilesDaoProvider).byUid(uid);
    try {
      await ref.read(profilesDaoProvider).upsert(ProfilesCompanion(
            uid: Value(uid),
            displayName: Value(name),
            currency: Value(existing?.currency ?? 'PHP'),
            locale: Value(existing?.locale),
            dateFormat: Value(existing?.dateFormat),
            createdAt: Value(existing?.createdAt ?? now),
            updatedAt: Value(now),
          ));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
