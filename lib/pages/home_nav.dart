import 'package:flutter/material.dart';
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

  final _pages = const [
    PasswordGeneratorPage(),
    ViewPasswords(),
    BackupPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.password),
            label: 'Generator',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Passwords',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
