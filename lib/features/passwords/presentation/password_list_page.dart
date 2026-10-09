import 'package:cyber_vault/core/security/clipboard_guard.dart';
import 'package:cyber_vault/core/theme/app_theme.dart';
import 'package:cyber_vault/core/widgets/common_widgets.dart';
import 'package:cyber_vault/features/passwords/domain/password_entry.dart';
import 'package:cyber_vault/features/passwords/presentation/password_edit_page.dart';
import 'package:cyber_vault/features/passwords/presentation/password_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PasswordListPage extends ConsumerStatefulWidget {
  const PasswordListPage({super.key});

  @override
  ConsumerState<PasswordListPage> createState() => _PasswordListPageState();
}

class _PasswordListPageState extends ConsumerState<PasswordListPage> {
  String _query = '';

  Future<void> _open([PasswordEntry? entry]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => PasswordEditPage(entry: entry),
      ),
    );
  }

  Future<void> _copy(PasswordEntry entry) async {
    if (entry.password.isEmpty) {
      showSnack(context, 'This entry has no password.');
      return;
    }
    await ClipboardGuard.copySecret(entry.password);
    if (!mounted) return;
    showSnack(context, 'Password copied. Clipboard clears in 30 s.');
  }

  List<PasswordEntry> _filter(List<PasswordEntry> items) {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where(
          (PasswordEntry e) =>
              e.title.toLowerCase().contains(q) ||
              e.username.toLowerCase().contains(q) ||
              e.url.toLowerCase().contains(q),
        )
        .toList();
  }

  String _initial(String title) {
    if (title.isEmpty) return '?';
    return String.fromCharCode(title.runes.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<PasswordEntry>> entries =
        ref.watch(passwordListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Passwords')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: Column(
        children: <Widget>[
          SearchField(
            hint: 'Search passwords',
            onChanged: (String v) => setState(() => _query = v),
          ),
          Expanded(
            child: entries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace st) =>
                  Center(child: Text('Could not load passwords: $e')),
              data: (List<PasswordEntry> items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.key_outlined,
                    title: 'No passwords yet',
                    message: 'Tap Add to store your first password.',
                  );
                }
                final List<PasswordEntry> visible = _filter(items);
                if (visible.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'No matches',
                    message: 'Try a different search.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: visible.length,
                  separatorBuilder: (BuildContext c, int i) =>
                      const SizedBox(height: 8),
                  itemBuilder: (BuildContext c, int i) {
                    final PasswordEntry entry = visible[i];
                    return NeonCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surfaceHigh,
                          foregroundColor: AppColors.neonCyan,
                          child: Text(_initial(entry.title)),
                        ),
                        title: Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                entry.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (entry.favorite) ...<Widget>[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.star,
                                size: 16,
                                color: AppColors.warning,
                              ),
                            ],
                          ],
                        ),
                        subtitle: entry.username.isEmpty
                            ? null
                            : Text(
                                entry.username,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                        trailing: IconButton(
                          tooltip: 'Copy password',
                          icon: const Icon(Icons.copy),
                          onPressed: () => _copy(entry),
                        ),
                        onTap: () => _open(entry),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
