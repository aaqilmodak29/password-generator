import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:password_generator/model/passwords.dart';
import 'package:password_generator/services/backup_service.dart';

// PBKDF2 is deliberately slow, and each of these runs it at least once. The
// default 30s timeout is tight on a loaded CI runner.
const _slow = Timeout(Duration(minutes: 2));

List<Passwords> _entries() => [
      Passwords(
        id: 'a1',
        name: 'someone@example.com',
        webName: 'Example Store',
        webURL: 'example.com',
        pwd: r'c0rrect-h0rse$battery',
      ),
      Passwords(
        id: 'b2',
        name: 'another@example.com',
        webName: 'Example Mail',
        webURL: 'mail.example.com',
        pwd: 'πassword with spaces & symbols ✓',
      ),
    ];

void main() {
  group('BackupService', () {
    test('a backup round-trips unchanged', () async {
      final original = _entries();
      final file = await BackupService.export(original, 'correct passphrase');
      final restored = await BackupService.import(file, 'correct passphrase');

      expect(restored, hasLength(original.length));
      for (var i = 0; i < original.length; i++) {
        expect(restored[i].id, original[i].id);
        expect(restored[i].name, original[i].name);
        expect(restored[i].webName, original[i].webName);
        expect(restored[i].webURL, original[i].webURL);
        // The whole point: non-ASCII and symbols must survive verbatim.
        expect(restored[i].pwd, original[i].pwd);
      }
    }, timeout: _slow);

    test('the file does not leak passwords in cleartext', () async {
      final file = await BackupService.export(_entries(), 'a passphrase');
      // The envelope is readable, but nothing sensitive may appear in it.
      expect(file, isNot(contains('battery')));
      expect(file, isNot(contains('example.com')));
      expect(file, isNot(contains('Example Store')));
      expect(file, contains(BackupService.formatId));
    }, timeout: _slow);

    test('the wrong passphrase is rejected, not silently mangled', () async {
      final file = await BackupService.export(_entries(), 'the right one');
      await expectLater(
        BackupService.import(file, 'the wrong one'),
        throwsA(isA<BackupException>()),
      );
    }, timeout: _slow);

    test('a tampered payload is rejected', () async {
      final file = await BackupService.export(_entries(), 'a passphrase');
      final envelope = jsonDecode(file) as Map<String, dynamic>;

      // Flip a bit in the ciphertext. GCM authenticates, so this must fail
      // rather than decrypt to garbage.
      final payload = base64.decode(envelope['payload'] as String);
      payload[0] ^= 0x01;
      envelope['payload'] = base64.encode(payload);

      await expectLater(
        BackupService.import(jsonEncode(envelope), 'a passphrase'),
        throwsA(isA<BackupException>()),
      );
    }, timeout: _slow);

    test('two exports of the same data differ', () async {
      // A fresh salt and nonce each time, so identical input must not produce
      // identical files — otherwise the file reveals when nothing changed.
      final a = await BackupService.export(_entries(), 'same passphrase');
      final b = await BackupService.export(_entries(), 'same passphrase');
      expect(a, isNot(equals(b)));
    }, timeout: _slow);

    test('a short passphrase is refused', () async {
      await expectLater(
        BackupService.export(_entries(), 'short'),
        throwsA(isA<BackupException>()),
      );
    });

    test('a file that is not a backup is named as such', () async {
      await expectLater(
        BackupService.import('{"hello":"world"}', 'a passphrase'),
        throwsA(
          isA<BackupException>().having(
            (e) => e.message,
            'message',
            contains('not a Password Manager backup'),
          ),
        ),
      );
      await expectLater(
        BackupService.import('this is not json at all', 'a passphrase'),
        throwsA(isA<BackupException>()),
      );
    });

    test('a backup from a newer version is refused clearly', () async {
      final file = await BackupService.export(_entries(), 'a passphrase');
      final envelope = jsonDecode(file) as Map<String, dynamic>;
      envelope['version'] = BackupService.formatVersion + 1;

      await expectLater(
        BackupService.import(jsonEncode(envelope), 'a passphrase'),
        throwsA(
          isA<BackupException>().having(
            (e) => e.message,
            'message',
            contains('newer version'),
          ),
        ),
      );
    }, timeout: _slow);

    test('suggested filenames are dated and zero-padded', () {
      expect(
        BackupService.suggestedName(DateTime(2026, 8, 3)),
        'password-generator-backup-2026-08-03',
      );
    });
  });
}
