import 'package:flutter_test/flutter_test.dart';

import 'package:password_generator/services/local_storage_service.dart';

/// The single most destructive decision the app makes.
///
/// Generating a database key when one is already in use does not fail loudly —
/// it orphans the database. The data stays on disk, correctly encrypted, under
/// a key that no longer exists anywhere. The app then opens looking empty and
/// perfectly healthy.
void main() {
  group('decideKey', () {
    test('uses the stored key when there is one', () {
      expect(
        DatabaseService.decideKey(storedKey: 'abc', databaseExists: true),
        KeyAction.useStored,
      );
      expect(
        DatabaseService.decideKey(storedKey: 'abc', databaseExists: false),
        KeyAction.useStored,
      );
    });

    test('mints a key only on a genuine first run', () {
      expect(
        DatabaseService.decideKey(storedKey: null, databaseExists: false),
        KeyAction.mintNew,
      );
    });

    test('refuses to mint a key when a database already exists', () {
      // The regression this guards. A null key plus an existing database means
      // the key was lost, not that this is a first run — and minting here
      // destroys every password.
      expect(
        () => DatabaseService.decideKey(
          storedKey: null,
          databaseExists: true,
        ),
        throwsA(isA<DatabaseLockedException>()),
      );
    });

    test('treats an empty key as no key, not as a usable one', () {
      // An empty string would otherwise be handed to SQLCipher as the
      // password, failing to open a database that is perfectly fine.
      expect(
        DatabaseService.decideKey(storedKey: '', databaseExists: false),
        KeyAction.mintNew,
      );
      expect(
        () => DatabaseService.decideKey(storedKey: '', databaseExists: true),
        throwsA(isA<DatabaseLockedException>()),
      );
    });

    test('the failure tells the user not to reinstall', () {
      // The instinct when an app opens empty is to reinstall it, which is
      // exactly what makes the loss permanent. The message has to say so.
      try {
        DatabaseService.decideKey(storedKey: null, databaseExists: true);
        fail('expected DatabaseLockedException');
      } on DatabaseLockedException catch (e) {
        expect(e.message.toLowerCase(), contains('still on this device'));
        expect(e.message.toLowerCase(), contains('do not reinstall'));
      }
    });
  });
}
