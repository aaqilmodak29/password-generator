import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_generator/services/shared_backup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final shared = SharedBackup.instance;

  void reply(Map<String, Object?>? pending) {
    messenger.setMockMethodCallHandler(SharedBackup.channel, (call) async {
      expect(call.method, 'takePending');
      return pending;
    });
  }

  tearDown(() {
    messenger.setMockMethodCallHandler(SharedBackup.channel, null);
    shared.pending.value = null;
  });

  test('nothing shared leaves pending empty', () async {
    reply(null);
    await shared.init();
    expect(shared.pending.value, isNull);
  });

  test('shared file waits until taken, then clears', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    reply({'name': 'backup.json', 'bytes': bytes});
    await shared.init();

    final file = shared.take();
    expect(file?.name, 'backup.json');
    expect(file?.bytes, bytes);
    expect(file?.error, isNull);
    expect(shared.take(), isNull);
  });

  test('read failure comes through as an error', () async {
    reply({'name': 'huge.json', 'error': 'huge.json is too large to be a backup.'});
    await shared.init();

    final file = shared.take();
    expect(file?.bytes, isNull);
    expect(file?.error, contains('too large'));
  });

  test('a later share is fetched when Android says one arrived', () async {
    reply(null);
    await shared.init();
    expect(shared.pending.value, isNull);

    reply({'name': 'second.json', 'bytes': Uint8List(1)});
    await messenger.handlePlatformMessage(
      SharedBackup.channel.name,
      SharedBackup.channel.codec
          .encodeMethodCall(const MethodCall('received')),
      (_) {},
    );
    expect(shared.pending.value?.name, 'second.json');
  });
}
