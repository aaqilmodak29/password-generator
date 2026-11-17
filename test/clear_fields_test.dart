import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:password_generator/components/password_generator_components.dart';
import 'package:password_generator/pages/password_generator_page.dart';
import 'package:password_generator/theme.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const PasswordGeneratorPage(),
    ));
  }

  Finder field(String label) =>
      find.widgetWithText(TextFormField, label);

  testWidgets('Clear fields empties every field and the stored values',
      (tester) async {
    await pumpPage(tester);

    await tester.enterText(field('Username or email'), 'me@example.com');
    await tester.enterText(field('Website or app'), 'github');
    await tester.enterText(field('Website URL'), 'https://github.com');
    await tester.tap(find.text('Generate'));
    await tester.pump();
    expect(PasswordField.pwd.text, isNotEmpty);

    await tester.tap(find.text('Clear fields'));
    await tester.pump();

    for (final label in ['Username or email', 'Website or app', 'Website URL']) {
      final text = tester.widget<EditableText>(
          find.descendant(of: field(label), matching: find.byType(EditableText)));
      expect(text.controller.text, isEmpty, reason: label);
    }
    expect(PasswordField.pwd.text, isEmpty);
    expect([emailUser, websiteName, websiteURL, passwd], everyElement(isEmpty));
  });

  testWidgets('Clear fields is the same size as Save, outlined in its colour',
      (tester) async {
    await pumpPage(tester);

    // .icon constructors build private subclasses, so match by `is`.
    Finder button<T>(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is T));
    final save = button<FilledButton>('Save password');
    final clear = button<OutlinedButton>('Clear fields');

    expect(tester.getSize(clear), tester.getSize(save));
    expect(tester.getTopLeft(clear).dy, greaterThan(tester.getTopLeft(save).dy));

    final context = tester.element(clear);
    final theme = Theme.of(context);
    final style = tester.widget<OutlinedButton>(clear).style!;
    expect(style.backgroundColor!.resolve({}), theme.scaffoldBackgroundColor);
    expect(style.side!.resolve({})!.color, theme.colorScheme.primary);
  });
}
