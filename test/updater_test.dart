import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:password_generator/services/updater.dart';

void main() {
  group('compareVersions', () {
    test('orders numerically, not as strings', () {
      // The reason this function exists: "1.10.0" sorts before "1.9.0" as a
      // string, which is exactly when updates would stop being offered.
      expect(Updater.compareVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(Updater.compareVersions('1.9.0', '1.10.0'), lessThan(0));
    });

    test('treats equal versions as equal', () {
      expect(Updater.compareVersions('1.2.3', '1.2.3'), 0);
    });

    test('handles differing part counts', () {
      expect(Updater.compareVersions('1.2', '1.2.0'), 0);
      expect(Updater.compareVersions('1.2.1', '1.2'), greaterThan(0));
    });

    test('treats a build suffix as a lower-order part', () {
      // package_info reports the versionName ("1.2.3") so a suffix rarely
      // shows up, but when it does "1.2.3+7" must not read as older than
      // "1.2.3" — that would offer an update that reinstalls what is already
      // running.
      expect(Updater.compareVersions('1.2.3+7', '1.2.3'), greaterThan(0));
      expect(Updater.compareVersions('1.2.3', '1.2.3+7'), lessThan(0));
    });
  });

  group('parseRelease', () {
    String payload({
      String tag = 'v1.2.0',
      String body = 'notes',
      List<Map<String, dynamic>> assets = const [],
    }) =>
        jsonEncode({'tag_name': tag, 'body': body, 'assets': assets});

    test('picks the APK, not whatever is listed first', () {
      final release = Updater.parseRelease(payload(assets: [
        {
          'name': 'password-generator-v1.2.0-windows.zip',
          'browser_download_url': 'https://example.com/a.zip',
          'size': 111,
        },
        {
          'name': 'password-generator-v1.2.0.apk',
          'browser_download_url': 'https://example.com/a.apk',
          'size': 222,
        },
      ]))!;

      expect(release.apkUrl, 'https://example.com/a.apk');
      expect(release.apkBytes, 222);
    });

    test('strips the leading v so it matches what the app reports', () {
      expect(Updater.parseRelease(payload(tag: 'v1.2.0'))!.version, '1.2.0');
      // A tag without the prefix must still work rather than losing a digit.
      expect(Updater.parseRelease(payload(tag: '1.2.0'))!.version, '1.2.0');
    });

    test('a release with no APK parses, with no download', () {
      // Better than failing to parse: the app can still say a version exists
      // and point at the releases page.
      final release = Updater.parseRelease(payload())!;
      expect(release.apkUrl, isNull);
      expect(release.tag, 'v1.2.0');
    });

    test('returns null on payloads that are not a release', () {
      expect(Updater.parseRelease('[]'), isNull);
      expect(Updater.parseRelease('{"message":"Not Found"}'), isNull);
    });
  });

  group('showsBadge', () {
    test('badges only when an update is genuinely available', () {
      expect(Updater.showsBadge(UpdateStatus.available), isTrue);
    });

    test('stays silent for every other state', () {
      // A badge that appears while checking, or after a failed check on a
      // train, teaches people to dismiss it — and then it is ignored the one
      // time it matters. Enumerated rather than tested by negation so a new
      // status has to be considered here deliberately.
      for (final status in [
        UpdateStatus.idle,
        UpdateStatus.checking,
        UpdateStatus.upToDate,
        UpdateStatus.downloading,
        UpdateStatus.ready,
        UpdateStatus.failed,
      ]) {
        expect(
          Updater.showsBadge(status),
          isFalse,
          reason: '$status must not badge the tab',
        );
      }
    });

    test('covers every UpdateStatus', () {
      // Guards the list above: adding a status without deciding whether it
      // badges should fail here rather than pass by omission.
      expect(UpdateStatus.values, hasLength(7));
    });
  });

  group('summarise', () {
    test('keeps the human half of a generated changelog', () {
      const notes = '''
## What's Changed
* feat(backup): encrypted export and import by @aaqilmodak29 in https://github.com/x/y/pull/1
* fix: the installer would not open by @aaqilmodak29 in https://github.com/x/y/pull/2

## New Contributors
* @someone made their first contribution in https://github.com/x/y/pull/3

**Full Changelog**: https://github.com/x/y/compare/v1.0.0...v1.1.0
''';

      expect(Updater.summarise(notes), [
        'Encrypted export and import',
        'The installer would not open',
      ]);
    });

    test('caps the number of lines', () {
      final notes = List.generate(10, (i) => '* fix: thing number $i').join('\n');
      expect(Updater.summarise(notes, max: 3), hasLength(3));
    });

    test('empty notes produce nothing rather than a blank bullet', () {
      expect(Updater.summarise(''), isEmpty);
      expect(Updater.summarise('**Full Changelog**: https://x/y'), isEmpty);
    });
  });
}
