import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/update_info.dart';
import '../services/update_service.dart';

final updateServiceProvider = Provider((ref) => UpdateService());

final currentVersionProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.version;
});

final updateCheckProvider = FutureProvider<UpdateInfo?>((ref) {
  final service = ref.read(updateServiceProvider);
  return service.checkForUpdate();
});

final versionHistoryProvider = FutureProvider<List<UpdateInfo>>((ref) {
  final service = ref.read(updateServiceProvider);
  return service.fetchVersionHistory();
});

class UpdateScreen extends ConsumerStatefulWidget {
  const UpdateScreen({super.key});

  @override
  ConsumerState<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends ConsumerState<UpdateScreen> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';

  Future<void> _startDownload(UpdateInfo update) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatus = 'Downloading...';
    });

    try {
      final service = ref.read(updateServiceProvider);
      await service.downloadAndInstall(
        update,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
              _downloadStatus = 'Downloading: ${(received / 1024 / 1024).toStringAsFixed(2)} MB / ${(total / 1024 / 1024).toStringAsFixed(2)} MB';
            });
          }
        },
      );
      setState(() {
        _downloadStatus = 'Download complete. Launching installer...';
      });
    } catch (e) {
      setState(() {
        _downloadStatus = 'Download failed: $e';
      });
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentVersion = ref.watch(currentVersionProvider);
    final updateCheck = ref.watch(updateCheckProvider);
    final versionHistory = ref.watch(versionHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Software Updates'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.system_update, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Current Version',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    currentVersion.when(
                      data: (version) => Text(
                        'v$version',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (err, stack) => Text('Error loading version: $err'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Update Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            updateCheck.when(
              data: (update) {
                if (update == null) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('You are on the latest version.'),
                    ),
                  );
                }
                return Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Version Available: v${update.version}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text('Release Notes:\n${update.releaseNotes}'),
                        const SizedBox(height: 16),
                        if (_isDownloading)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LinearProgressIndicator(value: _downloadProgress),
                              const SizedBox(height: 8),
                              Text(_downloadStatus, textAlign: TextAlign.center),
                            ],
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () => _startDownload(update),
                            icon: const Icon(Icons.download),
                            label: const Text('Download & Install Update'),
                          ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error checking for updates: $err'),
            ),
            const SizedBox(height: 24),
            Text(
              'Version History & Rollback',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: versionHistory.when(
                data: (history) {
                  if (history.isEmpty) {
                    return const Center(child: Text('No history available.'));
                  }
                  return ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[index];
                      return Card(
                        child: ListTile(
                          title: Text('Version ${item.version}'),
                          subtitle: Text(
                              'Released: ${DateFormat.yMMMd().format(item.releaseDate)}\n${item.releaseNotes}'),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.restore),
                            tooltip: 'Rollback to this version',
                            onPressed: _isDownloading
                                ? null
                                : () => _startDownload(item),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Error loading history: $err'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
