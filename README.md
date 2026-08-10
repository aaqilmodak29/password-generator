# Password Manager

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

Nothing in the startup path ever deletes the database. If the key cannot be
read, or the database cannot be opened, the app **refuses to start and says
so** rather than beginning again with an empty one. A new key is only ever
generated when there is no database file at all — a genuine first run.

That matters because the failure is otherwise invisible: an app that quietly
recreates an empty database looks perfectly healthy, and you find out when you
go looking for a password that is no longer there. If you ever see that error,
**do not reinstall** — the data is still on the device and still recoverable.

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

The Backup tab writes every entry to a `password-generator-backup-<date>.json`
file encrypted under a passphrase you choose. It is JSON only in the sense that
the envelope is — the passwords inside it are ciphertext:

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

## Releases and updates

The app checks this repository's latest GitHub Release **at launch**. If there
is a newer one, the **More** tab is badged; open it to see what changed and
install. Nothing has to be copied to the phone by hand.

The check is quiet: no signal, or GitHub being unreachable, leaves the app
looking exactly as it did. The badge appears only when there is genuinely
something newer — never while checking, and never after a failed check.

Cutting a release is one command:

```bash
git tag v1.1.0 && git push origin v1.1.0
```

Windows PowerShell has no `&&` operator, so there it is `git tag v1.1.0 ; git
push origin v1.1.0`.

That triggers `.github/workflows/release.yml`, which analyses, tests, builds a
signed APK and publishes it as a release. `versionCode` comes from the workflow
run number rather than `pubspec.yaml`, because Android refuses an update whose
`versionCode` has not increased.

### Why signing matters

Android will only install an update signed with the **same key** as the
installed app. Flutter's default debug key is generated per machine, so a
debug-signed build can only ever be updated from the one computer that made it.
Releases therefore use a stable keystore, held in repository secrets and never
committed.

`android/build.gradle.kts` falls back to the debug key when `key.properties` is
absent, so a fresh clone still builds — but it logs a warning, and the release
workflow fails outright rather than publishing an APK nobody can install.

### One-time setup

Generate a keystore and keep it somewhere safe **outside** this repository —
if you lose it, you can never update an installed app again and everyone has
to uninstall and start over:

```bash
keytool -genkey -v -keystore password-generator.keystore -alias passwordgenerator -keyalg RSA -keysize 2048 -validity 10000
```

Then add three repository secrets under **Settings → Secrets and variables →
Actions**:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 password-generator.keystore` |
| `ANDROID_KEYSTORE_PASSWORD` | the password you chose |
| `ANDROID_KEY_ALIAS` | `passwordgenerator` |

To build a signed APK locally, create `android/key.properties` (gitignored):

```properties
storePassword=...
keyPassword=...
keyAlias=passwordgenerator
storeFile=/absolute/path/to/password-generator.keystore
```

## Development

```bash
flutter analyze
flutter test
```
