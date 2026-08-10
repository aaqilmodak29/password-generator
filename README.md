# Password Generator

A personal password manager built in Flutter. Generates passwords, stores them
on the device, and keeps them behind the device lock.

Nothing leaves the phone: there is no account, no server, and no sync. The
trade-off is that the only copy of your passwords is the one on your device —
see [Backups](#backups).

## How your passwords are stored

Three layers, each doing one job:

| Layer | What it does |
| --- | --- |
| `sqflite_sqlcipher` | The database file itself is encrypted at rest with SQLCipher (AES-256, 256k KDF iterations). |
| `flutter_secure_storage` | Holds the database key, backed by Android's `EncryptedSharedPreferences` and the platform keystore — so the key never sits in the database it unlocks. |
| `local_auth` | Gates the whole app behind the device lock, and re-locks whenever the app is backgrounded. |

The key is generated with `Random.secure()` on first launch and never leaves
the device.

> The secure-storage entry is named `finumph_db_key` for historical reasons.
> It is only a lookup name, but renaming it would orphan the key of every
> existing install and make those databases unreadable, so it stays.

## Layout

```
lib/
  main.dart                        app entry, wraps everything in the auth gate
  model/passwords.dart             the stored-credential model
  pages/
    home_nav.dart                  bottom navigation
    password_generator_page.dart   generate and save a password
    view_passwords.dart            browse, edit and delete saved entries
    backup_page.dart               encrypted export and import
  services/
    auth_gate.dart                 device-lock gate, re-locks on background
    local_storage_service.dart     encrypted database access
    backup_service.dart            backup encryption and file format
  components/                      shared widgets
```

## Building

Requires the Flutter SDK (see `environment.sdk` in `pubspec.yaml` for the
minimum Dart version).

```bash
flutter pub get
flutter run
```

To build an installable Android package:

```bash
flutter build apk --release
```

## Backups

Uninstalling the app destroys both the database and the key that decrypts it,
so **export before you uninstall** — there is no other way to get your
passwords back.

The Backup tab writes every entry to a `.pgbackup` file encrypted under a
passphrase you choose:

| | |
| --- | --- |
| Key derivation | PBKDF2-HMAC-SHA256, 210,000 iterations, 16-byte random salt |
| Encryption | AES-256-GCM, 12-byte random nonce |

A fresh salt and nonce are generated per export, so exporting the same data
twice produces different files. GCM authenticates the payload, so a modified
file is rejected rather than decrypted into nonsense.

The passphrase is never stored. **If you forget it the file is unreadable** —
that is what makes it safe to keep the backup in ordinary storage.

Importing adds entries that aren't already present, matched on their stored id.
Anything already there is left untouched, so importing the same file twice is
harmless and an import never overwrites a password you have since changed.

## Development

```bash
flutter analyze
flutter test
```
