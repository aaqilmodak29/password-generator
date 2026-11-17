import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A file shared into the app from another app. Has [bytes] or an [error].
class SharedFile {
  const SharedFile({required this.name, this.bytes, this.error});

  final String name;
  final Uint8List? bytes;
  final String? error;
}

/// Receives backup files shared into the app on Android (Share or Open with).
///
/// The file waits in [pending] until the backup page takes it, so it survives
/// the auth gate locking and rebuilding the pages.
class SharedBackup {
  SharedBackup._();
  static final instance = SharedBackup._();

  @visibleForTesting
  static const channel =
      MethodChannel('com.aaqilmodak.passwordgenerator/shared_backup');

  final pending = ValueNotifier<SharedFile?>(null);

  Future<void> init() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'received') await _fetch();
    });
    await _fetch();
  }

  /// Hands over the waiting file, if any, and clears it.
  SharedFile? take() {
    final file = pending.value;
    pending.value = null;
    return file;
  }

  Future<void> _fetch() async {
    try {
      final raw = await channel.invokeMapMethod<String, Object?>('takePending');
      if (raw == null) return;
      pending.value = SharedFile(
        name: raw['name'] as String? ?? 'shared file',
        bytes: raw['bytes'] as Uint8List?,
        error: raw['error'] as String?,
      );
    } on PlatformException catch (e) {
      debugPrint('shared backup: $e');
    }
  }
}
