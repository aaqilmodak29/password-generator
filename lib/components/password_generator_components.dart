import 'package:flutter/material.dart';

String emailUser = '';
String websiteName = '';
String websiteURL = '';
String passwd = '';

extension StringExtensions on String {
  String capitalize() {
    final s = trim();
    if (s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1);
  }
}

// These fields predate the app having a theme, so each one carried its own
// colours: green prefix icons, red borders on every field whether or not it
// was in error, and a hardcoded lavender fill that only worked in light mode.
// The decoration now comes from InputDecorationTheme, so the fields match the
// rest of the app and follow light and dark without being told.
//
// Spacing also moved out to the page. Each field padded itself with a slightly
// different value, so the gaps between them were uneven.

class EmailNameField extends StatefulWidget {
  const EmailNameField({super.key});

  @override
  State<EmailNameField> createState() => _EmailNameFieldState();
}

class _EmailNameFieldState extends State<EmailNameField> {
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      onChanged: (value) {
        emailUser = value.isEmpty ? '' : value.toLowerCase().capitalize();
      },
      validator: (val) {
        if (val == null || val.isEmpty) {
          return 'Please enter an email or username.';
        }
        return null;
      },
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(
        labelText: 'Username or email',
        prefixIcon: Icon(Icons.person_outline),
      ),
    );
  }
}

class WebsiteField extends StatefulWidget {
  const WebsiteField({super.key});

  @override
  State<WebsiteField> createState() => _WebsiteFieldState();
}

class _WebsiteFieldState extends State<WebsiteField> {
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      onChanged: (value) {
        websiteName = value.isEmpty ? '' : value.toLowerCase().capitalize();
      },
      validator: (val) {
        if (val == null || val.isEmpty) {
          return 'Please enter a website or app name.';
        }
        return null;
      },
      decoration: const InputDecoration(
        labelText: 'Website or app',
        prefixIcon: Icon(Icons.apps_outlined),
      ),
    );
  }
}

class WebsiteURLField extends StatefulWidget {
  const WebsiteURLField({super.key});

  @override
  State<WebsiteURLField> createState() => _WebsiteURLFieldState();
}

class _WebsiteURLFieldState extends State<WebsiteURLField> {
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      onChanged: (value) {
        websiteURL = value;
      },
      keyboardType: TextInputType.url,
      decoration: const InputDecoration(
        labelText: 'Website URL',
        helperText: 'Optional',
        prefixIcon: Icon(Icons.link),
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  final bool enabled;
  final String hint;

  const PasswordField({
    super.key,
    required this.enabled,
    required this.hint,
  });

  static final TextEditingController pwd = TextEditingController();

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: PasswordField.pwd,
      readOnly: !widget.enabled,
      obscureText: _obscure,
      autocorrect: false,
      enableSuggestions: false,
      // Monospace, so a generated password can be read off the screen without
      // guessing between l, I and 1.
      style: const TextStyle(fontFamily: 'monospace', letterSpacing: 0.5),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: widget.enabled ? 'Type a password' : 'Press Generate',
        prefixIcon: const Icon(Icons.key_outlined),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
          tooltip: _obscure ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Password required';
        return null;
      },
    );
  }
}
