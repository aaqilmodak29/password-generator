import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

import 'package:password_generator/components/update_section.dart';
import 'package:password_generator/services/backup_service.dart';
import 'package:password_generator/services/local_storage_service.dart';
import 'package:password_generator/services/updater.dart';

/// Export and import of the password database.
///
/// Uninstalling destroys the database and the key that decrypts it, so without
/// this page there is no way off a given install — including the move from a
/// debug-signed build to a signed release, which requires an uninstall.
class BackupPage extends StatefulWidget {
  const BackupPage({super.key, required this.updater});

  /// Shared with the navigation bar's badge, so both show the same answer.
  /// Created and disposed by [HomeNav].
  final Updater updater;

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final _exportPass = TextEditingController();
  final _exportConfirm = TextEditingController();
  final _importPass = TextEditingController();

  bool _busy = false;
  String? _pickedName;
  Uint8List? _pickedBytes;

  // Per-field rather than one shared flag: revealing the passphrase you are
  // confirming defeats the point of asking twice.
  bool _showExportPass = false;
  bool _showExportConfirm = false;
  bool _showImportPass = false;

  @override
  void dispose() {
    _exportPass.dispose();
    _exportConfirm.dispose();
    _importPass.dispose();
    super.dispose();
  }

  void _say(String message, {bool bad = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bad ? Theme.of(context).colorScheme.error : null,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _export() async {
    if (_exportPass.text != _exportConfirm.text) {
      _say('The two passphrases do not match.', bad: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final entries = await DatabaseService.instance.getAddedPasswords();
      if (entries.isEmpty) {
        _say('There is nothing saved to export.', bad: true);
        return;
      }

      final contents =
          await BackupService.export(entries, _exportPass.text);

      final saved = await FileSaver.instance.saveAs(
        name: BackupService.suggestedName(DateTime.now()),
        bytes: Uint8List.fromList(utf8.encode(contents)),
        // Extension and MIME type have to agree. They used to say 'pgbackup'
        // and application/json, so file_saver wrote name.pgbackup and then
        // Android's document picker appended .json to match the MIME type it
        // had been given — every backup landed as name.pgbackup.json.
        //
        // JSON is what the file honestly is: an encrypted envelope encoded as
        // JSON. Saying so means the name already ends in the extension the
        // picker would add, so it adds nothing.
        fileExtension: 'json',
        mimeType: MimeType.custom,
        customMimeType: 'application/json',
      );

      // saveAs returns null when the user backs out of the system dialog.
      if (saved == null) {
        _say('Export cancelled — nothing was written.');
        return;
      }

      _exportPass.clear();
      _exportConfirm.clear();
      _say('Exported ${entries.length} entries. Keep the passphrase safe — '
          'without it the file cannot be opened.');
    } on BackupException catch (e) {
      _say(e.message, bad: true);
    } catch (e) {
      _say('Export failed — $e', bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    // withData so the bytes come back inline; the picked file may live behind a
    // content:// URI with no readable path on Android.
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Choose a backup file',
      type: FileType.any,
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file?.bytes == null) return;

    setState(() {
      _pickedName = file!.name;
      _pickedBytes = file.bytes;
    });
  }

  Future<void> _import() async {
    final bytes = _pickedBytes;
    if (bytes == null) {
      _say('Choose a backup file first.', bad: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final entries = await BackupService.import(
        utf8.decode(bytes),
        _importPass.text,
      );
      final result = await DatabaseService.instance.importPasswords(entries);

      _importPass.clear();
      setState(() {
        _pickedName = null;
        _pickedBytes = null;
      });

      _say(result.skipped == 0
          ? 'Restored ${result.added} entries.'
          : 'Restored ${result.added} entries. '
              '${result.skipped} were already here and were left alone.');
    } on BackupException catch (e) {
      _say(e.message, bad: true);
    } catch (e) {
      _say('Import failed — $e', bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & updates')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber,
                        color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Uninstalling the app destroys your passwords and the '
                        'key that decrypts them. Export before you uninstall — '
                        'there is no other way to get them back.',
                        style: TextStyle(
                            color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            UpdateSection(updater: widget.updater),
            const SizedBox(height: 16),

            _section(
              title: 'Export',
              children: [
                const Text(
                  'Writes every saved password to a file, encrypted with a '
                  'passphrase you choose. The passphrase is not stored '
                  'anywhere — if you forget it, the file is unreadable.',
                ),
                const SizedBox(height: 16),
                _passphraseField(
                  controller: _exportPass,
                  label: 'Passphrase',
                  helperText:
                      'At least ${BackupService.minPassphraseLength} characters',
                  visible: _showExportPass,
                  onToggle: () =>
                      setState(() => _showExportPass = !_showExportPass),
                ),
                const SizedBox(height: 12),
                _passphraseField(
                  controller: _exportConfirm,
                  label: 'Confirm passphrase',
                  visible: _showExportConfirm,
                  onToggle: () =>
                      setState(() => _showExportConfirm = !_showExportConfirm),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _export,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Export to a file'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _section(
              title: 'Import',
              children: [
                const Text(
                  'Restores entries from a backup file. Anything already saved '
                  'is kept as it is, so importing twice does no harm.',
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.folder_open),
                  label: Text(_pickedName ?? 'Choose a backup file'),
                ),
                const SizedBox(height: 12),
                _passphraseField(
                  controller: _importPass,
                  label: 'Passphrase',
                  visible: _showImportPass,
                  onToggle: () =>
                      setState(() => _showImportPass = !_showImportPass),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _import,
                  icon: const Icon(Icons.download),
                  label: const Text('Restore'),
                ),
              ],
            ),

            if (_busy) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              const Center(
                child: Text('Working — this takes a moment by design.'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// A passphrase field with a reveal toggle.
  ///
  /// Typing a long passphrase blind, twice, into an obscured box is how people
  /// end up with an export they cannot open — and here a mistyped passphrase
  /// is not recoverable, because nothing stores it to check against.
  Widget _passphraseField({
    required TextEditingController controller,
    required String label,
    required bool visible,
    required VoidCallback onToggle,
    String? helperText,
  }) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
          tooltip: visible ? 'Hide passphrase' : 'Show passphrase',
          onPressed: onToggle,
        ),
      ),
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
