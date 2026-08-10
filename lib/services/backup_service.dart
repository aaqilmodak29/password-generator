import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'package:password_generator/model/passwords.dart';

/// Reading a backup failed. The message is safe to show the user.
class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Encrypted export and import of the password database.
///
/// This exists because uninstalling the app destroys both the SQLCipher
/// database and the key that decrypts it, so there was previously no way to
/// move passwords to a new install — including the one needed to switch from a
/// debug-signed build to a signed release.
///
/// The file is encrypted rather than plain JSON because it holds every
/// credential the user owns and has to survive sitting in Downloads. A plain
/// export would be readable by anything with storage access, which would make
/// the backup a bigger risk than not having one.
class BackupService {
  /// Identifies our own files, so picking the wrong one fails clearly instead
  /// of as a decryption error that reads like a wrong passphrase.
  static const formatId = 'password-generator-backup';
  static const formatVersion = 1;

  /// PBKDF2 work factor. Deliberately slow: the passphrase is the only thing
  /// standing between a stolen file and every password in it, so guessing has
  /// to be expensive. Stored in the file so it can be raised later without
  /// stranding backups written at the old value.
  static const _iterations = 210000;

  /// Short passphrases make the KDF's cost irrelevant — the search space is
  /// small enough to brute force whatever the iteration count.
  static const minPassphraseLength = 8;

  static final _rng = Random.secure();

  static Uint8List _randomBytes(int n) =>
      Uint8List.fromList(List<int>.generate(n, (_) => _rng.nextInt(256)));

  static Future<SecretKey> _deriveKey(String passphrase, List<int> salt) {
    return Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: passphrase, nonce: salt);
  }

  /// Encrypts [entries] under [passphrase] and returns the file's contents.
  ///
  /// A fresh salt and nonce are generated per export, so exporting the same
  /// passwords twice under the same passphrase produces different files and
  /// reveals nothing by comparison.
  static Future<String> export(
    List<Passwords> entries,
    String passphrase,
  ) async {
    if (passphrase.length < minPassphraseLength) {
      throw const BackupException(
        'Use a passphrase of at least $minPassphraseLength characters.',
      );
    }

    final plain = utf8.encode(
      jsonEncode({
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'entries': entries
            .map((e) => {
                  'id': e.id,
                  'name': e.name,
                  'webName': e.webName,
                  'webURL': e.webURL,
                  'pwd': e.pwd,
                })
            .toList(),
      }),
    );

    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final box = await AesGcm.with256bits().encrypt(
      plain,
      secretKey: await _deriveKey(passphrase, salt),
      nonce: nonce,
    );

    // Pretty-printed so the envelope is legible; the payload is opaque anyway.
    return const JsonEncoder.withIndent('  ').convert({
      'format': formatId,
      'version': formatVersion,
      'kdf': {
        'algorithm': 'pbkdf2-hmac-sha256',
        'iterations': _iterations,
        'salt': base64.encode(salt),
      },
      'cipher': {
        'algorithm': 'aes-gcm-256',
        'nonce': base64.encode(nonce),
        'mac': base64.encode(box.mac.bytes),
      },
      'payload': base64.encode(box.cipherText),
    });
  }

  /// Decrypts a file produced by [export].
  ///
  /// Throws [BackupException] with a message worth showing: the difference
  /// between "this is not a backup file" and "that passphrase is wrong"
  /// decides what the user should try next.
  static Future<List<Passwords>> import(
    String contents,
    String passphrase,
  ) async {
    Map<String, dynamic> envelope;
    try {
      final decoded = jsonDecode(contents);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      envelope = decoded;
    } on FormatException {
      throw const BackupException(
        'That file is not a Password Generator backup.',
      );
    }

    if (envelope['format'] != formatId) {
      throw const BackupException(
        'That file is not a Password Generator backup.',
      );
    }
    // Guards against a future format being read by an older build, which would
    // otherwise surface as a confusing decryption failure.
    final version = envelope['version'];
    if (version is! int || version > formatVersion) {
      throw const BackupException(
        'That backup was written by a newer version of the app. Update, then '
        'import it again.',
      );
    }

    final int iterations;
    final List<int> salt, nonce, mac, payload;
    try {
      final kdf = envelope['kdf'] as Map<String, dynamic>;
      final cipher = envelope['cipher'] as Map<String, dynamic>;
      iterations = kdf['iterations'] as int;
      salt = base64.decode(kdf['salt'] as String);
      nonce = base64.decode(cipher['nonce'] as String);
      mac = base64.decode(cipher['mac'] as String);
      payload = base64.decode(envelope['payload'] as String);
    } catch (_) {
      throw const BackupException('That backup file is damaged.');
    }

    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: passphrase, nonce: salt);

    final List<int> clear;
    try {
      clear = await AesGcm.with256bits().decrypt(
        SecretBox(payload, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
    } on SecretBoxAuthenticationError {
      // GCM cannot tell a wrong key from a tampered file; a wrong passphrase is
      // overwhelmingly the likelier of the two, so say that.
      throw const BackupException(
        'Wrong passphrase, or the file has been altered.',
      );
    }

    try {
      final data = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      return (data['entries'] as List)
          .cast<Map<String, dynamic>>()
          .map((e) => Passwords(
                id: e['id'] as String,
                name: e['name'] as String,
                webName: e['webName'] as String,
                webURL: e['webURL'] as String? ?? '',
                pwd: e['pwd'] as String,
              ))
          .toList();
    } catch (_) {
      throw const BackupException('That backup file is damaged.');
    }
  }

  /// The filename to suggest, dated so successive exports do not overwrite
  /// each other.
  static String suggestedName(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'password-generator-backup-'
        '${now.year}-${two(now.month)}-${two(now.day)}';
  }
}
