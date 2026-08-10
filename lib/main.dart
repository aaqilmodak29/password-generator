import 'package:flutter/material.dart';

import 'package:password_generator/services/auth_gate.dart';

import 'pages/home_nav.dart';
import 'theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Password Generator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Follows the system setting. This is an app opened in odd places, and
      // a forced light theme at night is its own kind of unusable.
      themeMode: ThemeMode.system,
      home: const AuthGate(child: HomeNav()),
    );
  }
}
