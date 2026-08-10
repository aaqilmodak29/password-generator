import 'package:flutter/material.dart';
import 'package:password_generator/services/auth_gate.dart';
import 'pages/home_nav.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthGate(child: HomeNav()),
    );
  }
}
