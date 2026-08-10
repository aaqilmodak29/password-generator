import 'package:flutter/material.dart';

import 'package:password_generator/services/updater.dart';

/// Shows the running version and offers the newer one when there is one.
///
/// Checks once when it first appears rather than behind a button: an update
/// nobody thinks to look for is an update nobody installs.
class UpdateSection extends StatefulWidget {
  const UpdateSection({super.key});

  @override
  State<UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends State<UpdateSection> {
  final _updater = Updater();

  @override
  void initState() {
    super.initState();
    // Quiet: a failed check on a phone with no signal should not open with an
    // error about GitHub.
    _updater.check();
  }

  @override
  void dispose() {
    _updater.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _updater,
      builder: (context, _) {
        final release = _updater.release;
        final status = _updater.status;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Updates', style: theme.textTheme.titleLarge),
                    const Spacer(),
                    if (status == UpdateStatus.checking)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (status != UpdateStatus.downloading)
                      IconButton(
                        tooltip: 'Check again',
                        icon: const Icon(Icons.refresh),
                        onPressed: () => _updater.check(quiet: false),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_updater.currentVersion.isNotEmpty)
                  Text(
                    'Installed: ${_updater.currentVersion}',
                    style: theme.textTheme.bodyMedium,
                  ),

                if (status == UpdateStatus.available && release != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Version ${release.version} is available',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  ...Updater.summarise(release.notes).map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('• $line'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (Updater.canSelfInstall)
                    FilledButton.icon(
                      onPressed: _updater.downloadAndInstall,
                      icon: const Icon(Icons.system_update),
                      label: Text(
                        release.apkBytes > 0
                            ? 'Download and install '
                                '(${(release.apkBytes / (1024 * 1024)).toStringAsFixed(1)} MB)'
                            : 'Download and install',
                      ),
                    )
                  else
                    // Nothing here can install a package, so say where to get
                    // it rather than offering a button that cannot work.
                    SelectableText(
                      'Download it from ${Updater.releasesPage}',
                      style: theme.textTheme.bodySmall,
                    ),
                ],

                if (status == UpdateStatus.downloading) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: _updater.progress),
                  const SizedBox(height: 6),
                  Text('Downloading… ${(_updater.progress * 100).round()}%'),
                ],

                if (_updater.message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _updater.message!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: status == UpdateStatus.failed
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],

                if (status == UpdateStatus.failed &&
                    _updater.progress == 1) ...[
                  const SizedBox(height: 8),
                  // The download succeeded; only the handoff to the installer
                  // failed, usually because the install permission was refused.
                  // Re-opening the file is all that is needed once granted.
                  OutlinedButton(
                    onPressed: _updater.retryInstall,
                    child: const Text('Open the installer again'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
