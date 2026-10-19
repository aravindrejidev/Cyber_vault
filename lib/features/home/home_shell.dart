import 'package:cyber_vault/core/security/auto_lock.dart';
import 'package:cyber_vault/core/theme/app_theme.dart';
import 'package:cyber_vault/features/documents/presentation/document_list_page.dart';
import 'package:cyber_vault/features/notes/presentation/note_list_page.dart';
import 'package:cyber_vault/features/passwords/presentation/password_list_page.dart';
import 'package:cyber_vault/features/settings/presentation/settings_page.dart';
import 'package:cyber_vault/features/update/presentation/update_coordinator.dart';
import 'package:flutter/material.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const List<Widget> _pages = <Widget>[
    PasswordListPage(),
    DocumentListPage(),
    NoteListPage(),
    SettingsPage(),
  ];

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem('Passwords', Icons.key_outlined, Icons.key),
    _NavItem('Documents', Icons.folder_outlined, Icons.folder),
    _NavItem('Notes', Icons.sticky_note_2_outlined, Icons.sticky_note_2),
    _NavItem('Settings', Icons.settings_outlined, Icons.settings),
  ];

  @override
  void initState() {
    super.initState();
    // Look for a new release once per app start (after the vault is unlocked).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        UpdateCoordinator.runStartupCheck(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: _BrutalNavBar(
        items: _items,
        selected: _index,
        onSelect: (int i) {
          reportUserActivity();
          setState(() => _index = i);
        },
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Four equal blocks under a heavy white line; the active one is solid lime.
class _BrutalNavBar extends StatelessWidget {
  const _BrutalNavBar({
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  final List<_NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.black,
        border: Border(top: BorderSide(color: AppColors.ink, width: 3)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < items.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: i == selected ? AppColors.accent : AppColors.black,
                        border: Border(
                          left: i == 0
                              ? BorderSide.none
                              : const BorderSide(color: AppColors.ink, width: 2),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            i == selected ? items[i].activeIcon : items[i].icon,
                            size: 24,
                            color: i == selected ? AppColors.black : AppColors.ink,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            items[i].label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              color: i == selected ? AppColors.black : AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
