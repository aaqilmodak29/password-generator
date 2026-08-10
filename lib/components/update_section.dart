import 'package:flutter/material.dart';

import 'package:password_generator/services/updater.dart';

/// Shows the running version and offers the newer one when there is one.
///
/// Takes its [Updater] rather than creating one. The same instance drives the
/// badge on the navigation bar, and two instances would mean two checks and
/// two disagreeing answers — the badge could say an update exists while this
/// section, having checked a moment later on a dropped connection, said
/// nothing was available.
class UpdateSection extends StatelessWidget {
  const UpdateSection({super.key, required this.updater});

  /// Owned by whoever created it, which is also who disposes it.
  final Updater updater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: updater,
      builder: (context, _) {
        final release = updater.release;
        final status = updater.status;

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
                        onPressed: () => updater.check(quiet: false),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (updater.currentVersion.isNotEmpty)
                  Text(
                    'Installed: ${updater.currentVersion}',
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
                      onPressed: updater.downloadAndInstall,
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
                  LinearProgressIndicator(value: updater.progress),
                  const SizedBox(height: 6),
                  Text('Downloading… ${(updater.progress * 100).round()}%'),
                ],

                if (updater.message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    updater.message!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: status == UpdateStatus.failed
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],

                if (status == UpdateStatus.failed &&
                    updater.progress == 1) ...[
                  const SizedBox(height: 8),
                  // The download succeeded; only the handoff to the installer
                  // failed, usually because the install permission was refused.
                  // Re-opening the file is all that is needed once granted.
                  OutlinedButton(
                    onPressed: updater.retryInstall,
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
