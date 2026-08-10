import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:password_generator/components/password_generator_components.dart';
import 'package:uuid/uuid.dart';
import '../services/local_storage_service.dart';

List numbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
List letters = [
  'a','b','c','d','e','f','g','h','i','j','k','l','m',
  'n','o','p','q','r','s','t','u','v','w','x','y','z',
  'A','B','C','D','E','F','G','H','I','J','K','L','M',
  'N','O','P','Q','R','S','T','U','V','W','X','Y','Z'
];
List symbols = ['!', '#', '^', '%', '&', '(', ')', '*', '+'];

/// The source of every generated password.
///
/// `Random.secure()`, never plain `Random()`. Dart's default `Random` is a
/// fast pseudo-random generator seeded from the clock — reproducible by
/// anyone who can guess when a password was created, which for a password
/// manager makes the generated passwords guessable rather than random. It is
/// the one place in this app where the choice of RNG is load-bearing.
final Random _secureRandom = Random.secure();

/// Generates a password: four digits, four letters, four symbols, shuffled.
///
/// Takes its randomness so tests can supply a seeded generator and assert the
/// output is a pure function of it. Defaults to the secure source; a caller
/// passing a plain `Random` is doing so knowingly, which is the point.
String generatePassword({Random? random}) {
  final rng = random ?? _secureRandom;

  final chars = <String>[
    for (var i = 0; i < 4; i++) numbers[rng.nextInt(numbers.length)] as String,
    for (var i = 0; i < 4; i++) letters[rng.nextInt(letters.length)] as String,
    for (var i = 0; i < 4; i++) symbols[rng.nextInt(symbols.length)] as String,
  ];

  // Shuffled with the same generator. `List.shuffle()` with no argument uses
  // the default insecure Random, which would have left the ordering
  // predictable even once the character choices were not.
  chars.shuffle(rng);
  return chars.join();
}

class PasswordGeneratorPage extends StatefulWidget {
  const PasswordGeneratorPage({super.key});

  @override
  State<PasswordGeneratorPage> createState() => _PasswordGeneratorPageState();
}

class _PasswordGeneratorPageState extends State<PasswordGeneratorPage> {
  final _passwordGeneratorFormKey = GlobalKey<FormState>();
  bool enabledField = false; // true = manual typing
  String hintField = '';
  final DatabaseService _databaseService = DatabaseService.instance;

  String randomPass() {
    passwd = generatePassword();
    return passwd;
  }

  void _toggleMode() {
    setState(() {
      if (!enabledField) {
        enabledField = true; // manual mode ON
        hintField = '';
        passwd = '';
        PasswordField.pwd.clear();
      } else {
        enabledField = false; // manual mode OFF
        passwd = '';
      }
    });
  }

  Future<void> _save() async {
    if (!_passwordGeneratorFormKey.currentState!.validate()) return;

    final id = const Uuid().v4();
    final passwordToSave = PasswordField.pwd.text.trim();
    passwd = passwordToSave;

    // Resolved before the await: afterwards this closure's context may be
    // gone, and the State's `mounted` says nothing about it.
    final messenger = ScaffoldMessenger.of(context);

    await _databaseService.addPwd(
      id,
      emailUser,
      websiteName,
      websiteURL,
      passwordToSave,
    );

    // Saved first, then copied. A password on the clipboard that never reached
    // the database is the worst outcome here — it gets pasted into a signup
    // form and then lost the moment anything else is copied.
    await Clipboard.setData(ClipboardData(text: passwordToSave));

    messenger.showSnackBar(
      const SnackBar(content: Text('Saved and copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Generate a password')),
      body: Form(
        key: _passwordGeneratorFormKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const EmailNameField(),
            const SizedBox(height: 16),
            const WebsiteField(),
            const SizedBox(height: 16),
            const WebsiteURLField(),
            const SizedBox(height: 16),
            PasswordField(enabled: enabledField, hint: hintField),
            const SizedBox(height: 24),

            // Generate and the mode toggle are peers, so they share a row and
            // the same height. They used to be square-cornered blue blocks
            // that ignored the theme entirely.
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    // Disabled in manual mode: generating would overwrite what
                    // is being typed.
                    onPressed: enabledField
                        ? null
                        : () {
                            setState(() {
                              hintField = randomPass();
                              PasswordField.pwd.text = hintField;
                            });
                          },
                    icon: const Icon(Icons.autorenew),
                    label: const Text('Generate'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _toggleMode,
                    icon: Icon(enabledField
                        ? Icons.auto_awesome_outlined
                        : Icons.edit_outlined),
                    label: Text(enabledField ? 'Automatic' : 'Manual'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              enabledField
                  ? 'Typing your own password. Switch to Automatic to generate one.'
                  : 'Press Generate for a random password, or switch to Manual to type your own.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // Save is the page's primary action, so it is full width and the
            // only filled button on the screen.
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save password'),
            ),
          ],
        ),
      ),
    );
  }
}
