import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:password_generator/model/passwords.dart';
import 'package:path/path.dart';

import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The database is present but cannot be opened.
///
/// Always means "your data is still there and we would not risk it", never
/// "your data is gone". Nothing in this file deletes a database to recover
/// from an error, so this is recoverable until the user decides otherwise.
class DatabaseLockedException implements Exception {
  const DatabaseLockedException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What to do about the database key, given what we found.
enum KeyAction { useStored, mintNew }

class DatabaseService {
  static Database? _db;
  static Completer<Database>? _opening;
  static final DatabaseService instance = DatabaseService._constructor();
  DatabaseService._constructor();

  /// Named for historical reasons — this started life in another project.
  /// Renaming it would orphan the key of every existing install.
  static const _dbKeyName = 'finumph_db_key';

  /// Decides whether it is safe to generate a new database key.
  ///
  /// Pure and separate from the I/O because it is the single most destructive
  /// decision the app makes. Minting a key when one is already in use orphans
  /// the database permanently: the data is still on disk, correctly encrypted,
  /// under a key that no longer exists anywhere.
  ///
  /// The existence of the database file is the ground truth, deliberately not
  /// secure storage's own opinion of whether it holds a key. If secure storage
  /// is the thing that is failing, asking it whether it has a key gets the
  /// same wrong answer that caused the problem.
  @visibleForTesting
  static KeyAction decideKey({
    required String? storedKey,
    required bool databaseExists,
  }) {
    if (storedKey != null && storedKey.isNotEmpty) return KeyAction.useStored;

    if (databaseExists) {
      throw const DatabaseLockedException(
        'Your passwords are still on this device, but the key that unlocks '
        'them could not be read. Do not reinstall — that would delete them. '
        'Restart the app and try again.',
      );
    }

    // No key and no database: a genuine first run.
    return KeyAction.mintNew;
  }

  Future<String> _getDbKey({required bool databaseExists}) async {
    const storage = FlutterSecureStorage();
    const aOptions = AndroidOptions(encryptedSharedPreferences: true);

    String? stored;
    try {
      stored = await storage.read(key: _dbKeyName, aOptions: aOptions);
    } catch (e) {
      // A read that throws says nothing about whether a key exists. Falling
      // through to "generate a new one" would destroy the database.
      debugPrint('DatabaseService: secure storage read failed — $e');
      if (databaseExists) {
        throw const DatabaseLockedException(
          'Your passwords are still on this device, but secure storage could '
          'not be reached. Do not reinstall — that would delete them. '
          'Restart the app and try again.',
        );
      }
      rethrow;
    }

    if (decideKey(storedKey: stored, databaseExists: databaseExists) ==
        KeyAction.useStored) {
      return stored!;
    }

    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final key = base64UrlEncode(bytes);

    await storage.write(key: _dbKeyName, value: key, aOptions: aOptions);
    return key;
  }

  final String _passGenTable = "password_details";
  final String _usernameColumnName = "username_or_email";
  final String _websiteColumnName = "website_or_app_name";
  final String _websiteURLColumnName = "website_url";
  final String _pwd = "password";
  final String _uuid = "uuid";

  Future<Database> get database async {
    // fast path: only if existing AND open
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;

    // already opening? await the same Future
    if (_opening != null) return _opening!.future;

    // start opening once
    final comp = Completer<Database>();
    _opening = comp;
    try {
      final db = await getDatabase();
      _db = db;
      comp.complete(db);
      return db;
    } catch (e, st) {
      comp.completeError(e, st);
      rethrow;
    } finally {
      _opening = null;
    }
  }

  Future<Database> getDatabase() async {
    final databaseDirPath = await getDatabasesPath();
    final databasePath = join(databaseDirPath, "pwd_gen.db");

    // Checked before the key is fetched, because it is what decides whether
    // generating a new key is safe.
    final databaseExists =
        await databaseFactory.databaseExists(databasePath);
    final dbPassword = await _getDbKey(databaseExists: databaseExists);

    Future<Database> open() {
      return openDatabase(
        databasePath,
        password: dbPassword,
        version: 1,
        onConfigure: (db) async {
          await db.rawQuery('PRAGMA cipher_compatibility = 4');
          await db.rawQuery('PRAGMA kdf_iter = 256000');
          await db.rawQuery('PRAGMA cipher_page_size = 4096');
          await db.rawQuery('PRAGMA journal_mode = WAL');
        },
        onCreate: (db, version) async {
          await db.execute(
            '''
            CREATE TABLE $_passGenTable (
              $_uuid TEXT PRIMARY KEY,
              $_usernameColumnName TEXT NOT NULL,
              $_websiteColumnName TEXT NOT NULL,
              $_websiteURLColumnName TEXT NOT NULL,
              $_pwd TEXT NOT NULL
            )
            '''
          );
        }
      );
    }

    try {
      return await open();
    } on DatabaseException catch (e) {
      final msg = e.toString();
      final unreadable = msg.contains('open_failed') ||
          msg.contains('file is not a database');

      // This used to delete the database and open a fresh one. That turns a
      // recoverable problem — usually the wrong key, from the bug above —
      // into permanent loss, and does it silently: the app opens looking
      // empty and perfectly healthy, so the damage is invisible until the
      // user goes looking for a password that is no longer there.
      //
      // Refusing to open is worse UX and better behaviour. The file stays on
      // disk, still correctly encrypted, so whatever went wrong stays fixable.
      if (unreadable && databaseExists) {
        throw const DatabaseLockedException(
          'Your passwords are still on this device, but the database could '
          'not be opened. Nothing has been deleted. Do not reinstall — that '
          'would remove them. Restart the app and try again.',
        );
      }
      rethrow;
    }
  }

  Future<void> deleteCurrentDatabase() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
    }

    _db = null;
    _opening = null;

    final databaseDirPath = await getDatabasesPath();
    final databasePath = join(databaseDirPath, "pwd_gen.db");

    final file = File(databasePath);
    debugPrint('Deleting database at: $databasePath');

    if (await file.exists()) {
      await deleteDatabase(databasePath);
      debugPrint('Database deleted.');
    } else {
      debugPrint('Database file not found.');
    }
  }

  /// Deliberate, user-invoked reset. Distinct from anything above: nothing in
  /// the open path may call this, or a transient error becomes data loss.
  Future<void> deleteDbKey() async {
    const storage = FlutterSecureStorage();
    await storage.delete(
      key: _dbKeyName,
      aOptions: const AndroidOptions(encryptedSharedPreferences: true),
    );
  }

  Future<void> addPwd(String id, String name, String webName, String url, String pwd) async {
    final db = await database;
    await db.insert(
      _passGenTable,
      {
        _uuid: id,
        _usernameColumnName: name,
        _websiteColumnName: webName,
        _websiteURLColumnName: url,
        _pwd: pwd
      }
    );
  }

  Future<void> delPwd(String id, String name, String webName, String url, String pwd) async {
    final db = await database;
    await db.delete(
        _passGenTable,
        where: '''
        $_uuid = ?
        ''',
        whereArgs: [id]
    );
  }

  Future<void> updatePwd({
    required String id,
    required String name,
    required String webName,
    required String url,
    required String pwd,
  }) async {
    final db = await database;

    await db.update(
      _passGenTable,
      {
        _usernameColumnName: name,
        _websiteColumnName: webName,
        _websiteURLColumnName: url,
        _pwd: pwd,
      },
      where: '$_uuid = ?',
      whereArgs: [id],
    );
  }

  /// Writes restored entries, returning how many were added and how many
  /// already existed.
  ///
  /// Keyed on the stored uuid, so re-importing the same backup is harmless
  /// rather than producing a second copy of every entry. Existing rows are
  /// left alone: an import is a restore, and silently overwriting a password
  /// the user has since changed would lose the newer one.
  ///
  /// The whole thing runs in a transaction so a failure part-way through
  /// leaves the database as it was, rather than half-restored.
  Future<({int added, int skipped})> importPasswords(
    List<Passwords> entries,
  ) async {
    final db = await database;
    var added = 0;

    await db.transaction((txn) async {
      for (final e in entries) {
        final existing = await txn.query(
          _passGenTable,
          columns: [_uuid],
          where: '$_uuid = ?',
          whereArgs: [e.id],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;

        await txn.insert(_passGenTable, {
          _uuid: e.id,
          _usernameColumnName: e.name,
          _websiteColumnName: e.webName,
          _websiteURLColumnName: e.webURL,
          _pwd: e.pwd,
        });
        added++;
      }
    });

    return (added: added, skipped: entries.length - added);
  }

  Future<List<Passwords>> getAddedPasswords() async {
    final db = await database;
    final data = await db.query(
      _passGenTable,
    );
    List<Passwords> addedPasswords = data.map((e) => Passwords(
        id: e[_uuid] as String,
        name: e[_usernameColumnName] as String,
        webName: e[_websiteColumnName] as String,
        webURL: (e[_websiteURLColumnName] as String?) ?? 'No Desc',
        pwd: e[_pwd] as String
    )).toList();

    return addedPasswords;
  }
}
