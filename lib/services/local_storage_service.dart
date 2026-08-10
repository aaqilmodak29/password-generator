import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:password_generator/model/passwords.dart';
import 'package:path/path.dart';

import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DatabaseService {
  static Database? _db;
  static Completer<Database>? _opening;
  static final DatabaseService instance = DatabaseService._constructor();
  DatabaseService._constructor();

  Future<String> _getDbKey() async {
    const storage = FlutterSecureStorage();

    var key = await storage.read(
      key: 'finumph_db_key',
      aOptions: const AndroidOptions(encryptedSharedPreferences: true),
    );
    if (key != null && key.isNotEmpty) return key;

    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    key = base64UrlEncode(bytes);

    await storage.write(
        key: 'finumph_db_key',
        value: key,
        aOptions: const AndroidOptions(encryptedSharedPreferences: true)
    );
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
    final dbPassword = await _getDbKey();

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
      if (msg.contains('open_failed') || msg.contains('file is not a database')) {
        if (await databaseFactory.databaseExists(databasePath)) {
          await deleteDatabase(databasePath);
        }
        return await open();
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

  Future<void> deleteDbKey() async {
    const storage = FlutterSecureStorage();
    await storage.delete(
      key: 'finumph_db_key',
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
