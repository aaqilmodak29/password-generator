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

class EmailNameField extends StatefulWidget {
  const EmailNameField({super.key});

  @override
  State<EmailNameField> createState() => _EmailNameFieldState();
}

class _EmailNameFieldState extends State<EmailNameField> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextFormField(
          onChanged: (value) {
            emailUser = value.isEmpty ? '' : value.toLowerCase().capitalize();
          },
          validator: (val) {
            if(val!.isEmpty){
              return 'Please enter an email or username.';
            }
            return null;
          },
          decoration: InputDecoration(
              hintText: 'Username/Email',
              labelText: 'Username/Email',
              prefixIcon: Icon(
                Icons.mail,
                color: Colors.green,
              ),
              errorStyle: TextStyle(fontSize: 18.0),
              border: OutlineInputBorder(
                  borderSide:
                  BorderSide(color: Colors.red),
                  borderRadius: BorderRadius.all(
                      Radius.circular(9.0)
                  )
              )
          )
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
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextFormField(
          onChanged: (value) {
            websiteName = value.isEmpty ? '' : value.toLowerCase().capitalize();
          },
          validator: (val) {
            if(val!.isEmpty){
              return 'Please enter a website/app name.';
            }
            return null;
          },
          decoration: InputDecoration(
              hintText: 'Website/App',
              labelText: 'Website/App',
              prefixIcon: Icon(
                Icons.web_asset,
                color: Colors.green,
              ),
              errorStyle: TextStyle(fontSize: 18.0),
              border: OutlineInputBorder(
                  borderSide:
                  BorderSide(color: Colors.red),
                  borderRadius: BorderRadius.all(
                      Radius.circular(9.0)
                  )
              )
          )
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
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextFormField(
          onChanged: (value) {
            websiteURL = value;
          },
          decoration: InputDecoration(
              hintText: 'Website URL',
              labelText: 'Website URL (Optional)',
              prefixIcon: Icon(
                Icons.web,
                color: Colors.green,
              ),
              errorStyle: TextStyle(fontSize: 18.0),
              border: OutlineInputBorder(
                  borderSide:
                  BorderSide(color: Colors.red),
                  borderRadius: BorderRadius.all(
                      Radius.circular(9.0)
                  )
              )
          )
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
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextFormField(
        controller: PasswordField.pwd,
        readOnly: !widget.enabled,
        obscureText: _obscure,
        decoration: InputDecoration(
          hintText: widget.hint.isEmpty ? 'Password' : null,
          filled: true,
          fillColor: const Color(0xFFF8F3FF), // adjust if needed
          prefixIcon: const Icon(Icons.key, color: Colors.green),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blue),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Password required';
          return null;
        },
      ),
    );
  }
}
