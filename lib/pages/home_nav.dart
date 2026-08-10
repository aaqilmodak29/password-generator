import 'package:flutter/material.dart';

import 'package:password_generator/services/updater.dart';

import 'backup_page.dart';
import 'password_generator_page.dart';
import 'view_passwords.dart';

class HomeNav extends StatefulWidget {
  const HomeNav({super.key});

  @override
  State<HomeNav> createState() => _HomeNavState();
}

class _HomeNavState extends State<HomeNav> {
  int _index = 0;

  /// One updater for the whole app: the More tab renders it, and the
  /// navigation bar badges from the same instance so the two cannot disagree.
  final _updater = Updater();

  late final List<Widget> _pages = [
    const PasswordGeneratorPage(),
    const ViewPasswords(),
    BackupPage(updater: _updater),
  ];

  @override
  void initState() {
    super.initState();

    // Checked here, on launch, rather than left to the More tab.
    //
    // A check did already happen at startup, but only as a side effect of
    // IndexedStack building every child eagerly — so it would have stopped
    // silently the day this became a PageView or a lazy builder, and nothing
    // would have failed to say so. Being explicit also means the result is
    // ready before the user has any reason to go looking for it.
    //
    // Quiet: a failed check on a phone with no signal must not greet the user
    // with an error about GitHub.
    _updater.check();

    _updater.addListener(_onUpdaterChanged);
  }

  void _onUpdaterChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _updater.removeListener(_onUpdaterChanged);
    _updater.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badged = Updater.showsBadge(_updater.status);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.password),
            label: 'Generator',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Passwords',
          ),
          BottomNavigationBarItem(
            // A dot rather than a count: there is only ever one newer release,
            // and a number would imply otherwise.
            icon: Badge(
              isLabelVisible: badged,
              child: const Icon(Icons.settings),
            ),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
