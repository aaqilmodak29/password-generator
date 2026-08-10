import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:password_generator/pages/password_generator_page.dart';

void main() {
  group('generatePassword', () {
    test('is twelve characters', () {
      expect(generatePassword().length, 12);
    });

    test('draws four from each pool', () {
      // Composition is the point of the design: a password of twelve random
      // letters would be weaker against a rule requiring a digit and a symbol,
      // because the user would then edit it by hand.
      for (var i = 0; i < 20; i++) {
        final pwd = generatePassword();
        expect(pwd.split('').where(numbers.contains).length, 4);
        expect(pwd.split('').where(letters.contains).length, 4);
        expect(pwd.split('').where(symbols.contains).length, 4);
      }
    });

    test('successive passwords differ', () {
      // 20 identical results would mean the generator is not generating.
      final seen = <String>{};
      for (var i = 0; i < 20; i++) {
        seen.add(generatePassword());
      }
      expect(seen, hasLength(20));
    });

    test('is a pure function of the generator it is given', () {
      // Proves the injection point works, so the security of the default
      // source is the only thing left to get right.
      expect(
        generatePassword(random: Random(1234)),
        generatePassword(random: Random(1234)),
      );
      expect(
        generatePassword(random: Random(1)),
        isNot(generatePassword(random: Random(2))),
      );
    });

    test('the shuffle uses the supplied generator too', () {
      // The regression this guards: `List.shuffle()` with no argument falls
      // back to the default insecure Random. If that were still the case the
      // two runs below would draw the same characters but order them
      // differently, so the strings would differ while their sorted forms
      // matched.
      List<String> sorted(String s) => s.split('')..sort();

      final a = generatePassword(random: Random(99));
      final b = generatePassword(random: Random(99));

      expect(sorted(a), sorted(b), reason: 'same draws expected');
      expect(a, b, reason: 'ordering must come from the supplied generator');
    });
  });
}
