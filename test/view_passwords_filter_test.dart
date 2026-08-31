import 'package:flutter_test/flutter_test.dart';

import 'package:password_generator/model/passwords.dart';
import 'package:password_generator/pages/view_passwords.dart';

Passwords entry(String id, String webName, String name) => Passwords(
      id: id,
      name: name,
      webName: webName,
      webURL: 'https://$webName.example',
      pwd: 'pwd-$id',
    );

void main() {
  final items = [
    entry('1', 'GitHub', 'me@example.com'),
    entry('2', 'Gitlab', 'work@example.com'),
    entry('3', 'Netflix', 'me@example.com'),
    entry('4', 'example.com', 'someone@else.test'),
  ];

  group('filterPasswords', () {
    test('an empty query and no filter keeps everything', () {
      expect(filterPasswords(items), hasLength(4));
    });

    test('matches the website or app name', () {
      final hit = filterPasswords(items, query: 'git');
      expect(hit.map((p) => p.webName), ['GitHub', 'Gitlab']);
    });

    test('ignores case and surrounding space in the query', () {
      expect(filterPasswords(items, query: '  NETFLIX '), hasLength(1));
    });

    test('does not match the username', () {
      // The whole point of the change: searching for an address used to drag
      // in every entry saved under it, so a site search could not be trusted.
      expect(filterPasswords(items, query: 'me@example.com'), isEmpty);
    });

    test('does not match the URL', () {
      // "example.com" is in every stored URL, and one entry's website name.
      final hit = filterPasswords(items, query: 'example.com');
      expect(hit.map((p) => p.id), ['4']);
    });

    test('filters to one username exactly', () {
      final hit = filterPasswords(items, username: 'me@example.com');
      expect(hit.map((p) => p.webName), ['GitHub', 'Netflix']);
    });

    test('the username filter is not a substring match', () {
      // 'me@example.com' must not sweep up 'work@example.com'.
      expect(filterPasswords(items, username: 'example.com'), isEmpty);
    });

    test('ignores case in the username filter', () {
      expect(
        filterPasswords(items, username: 'ME@Example.COM'),
        hasLength(2),
      );
    });

    test('search and filter compose', () {
      final hit = filterPasswords(
        items,
        query: 'git',
        username: 'me@example.com',
      );
      expect(hit.map((p) => p.webName), ['GitHub']);
    });
  });

  group('distinctUsernames', () {
    test('is empty for no items', () {
      expect(distinctUsernames(const []), isEmpty);
    });

    test('lists each username once, alphabetically', () {
      expect(distinctUsernames(items), [
        'me@example.com',
        'someone@else.test',
        'work@example.com',
      ]);
    });

    test('treats differently-cased spellings as one account', () {
      // Otherwise picking one of the two spellings hides half the passwords.
      final mixed = [
        entry('1', 'GitHub', 'Me@Example.com'),
        entry('2', 'Netflix', 'me@example.com'),
      ];
      expect(distinctUsernames(mixed), ['Me@Example.com']);
      expect(filterPasswords(mixed, username: 'Me@Example.com'), hasLength(2));
    });

    test('skips entries saved with no username', () {
      final withBlank = [...items, entry('5', 'Nowhere', '   ')];
      expect(distinctUsernames(withBlank), hasLength(3));
    });
  });
}
