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

extension Shuffle on String {
  String get shuffled => (split('')..shuffle()).join('');
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
  String manualButtonText = 'Add Manually';
  final _random = Random();
  final DatabaseService _databaseService = DatabaseService.instance;

  String randomPass() {
    String password = '';
    for (int num = 0; num <= 3; num++) {
      password += numbers[_random.nextInt(numbers.length)];
    }
    for (int let = 0; let <= 3; let++) {
      password += letters[_random.nextInt(letters.length)];
    }
    for (int sym = 0; sym <= 3; sym++) {
      password += symbols[_random.nextInt(symbols.length)];
    }

    password = password.shuffled;
    passwd = password;
    return passwd;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Generator'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _passwordGeneratorFormKey,
          child: Column(
            children: [
              EmailNameField(),
              WebsiteField(),
              WebsiteURLField(),
              PasswordField(enabled: enabledField, hint: hintField),

              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextButton(
                        onPressed: enabledField
                            ? null
                            : () {
                          setState(() {
                            hintField = randomPass();
                            PasswordField.pwd.text = hintField; // important
                          });
                        },
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith<Color>(
                                (states) {
                              if (states.contains(WidgetState.disabled)) {
                                return Colors.grey.shade400;
                              }
                              return Colors.blue;
                            },
                          ),
                          shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                            const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Generate',
                          style: TextStyle(color: Colors.white, fontSize: 16.0),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            if (!enabledField) {
                              enabledField = true; // manual mode ON
                              manualButtonText = 'Add Automatically';
                              hintField = '';
                              passwd = '';
                              PasswordField.pwd.clear();
                            } else {
                              enabledField = false; // manual mode OFF
                              manualButtonText = 'Add Manually';
                              passwd = '';
                            }
                          });
                        },
                        style: ButtonStyle(
                          backgroundColor:
                          WidgetStateProperty.all<Color>(Colors.blue),
                          shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                            const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                        child: Text(
                          manualButtonText,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16.0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextButton(
                        onPressed: () async {
                          if (_passwordGeneratorFormKey.currentState!.validate()) {
                            final id = const Uuid().v4();

                            final passwordToSave = PasswordField.pwd.text.trim();
                            passwd = passwordToSave;

                            // Resolved before the await: afterwards this
                            // closure's context may be gone, and the State's
                            // `mounted` says nothing about it.
                            final messenger = ScaffoldMessenger.of(context);

                            await _databaseService.addPwd(
                              id,
                              emailUser,
                              websiteName,
                              websiteURL,
                              passwordToSave,
                            );

                            // Saved first, then copied. A password on the
                            // clipboard that never reached the database is the
                            // worst outcome here — it gets pasted into a signup
                            // form and then lost the moment anything else is
                            // copied.
                            await Clipboard.setData(
                              ClipboardData(text: passwordToSave),
                            );

                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Saved and copied to clipboard'),
                              ),
                            );
                          }
                        },
                        style: ButtonStyle(
                          backgroundColor:
                          WidgetStateProperty.all<Color>(Colors.blue),
                          shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                            const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Save Password',
                          style: TextStyle(color: Colors.white, fontSize: 16.0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
