// ignore_for_file: use_build_context_synchronously, avoid_print, deprecated_member_use, depend_on_referenced_packages

import 'package:devlink/utility/customTheme.dart';
import 'package:devlink/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carbon_icons/carbon_icons.dart';
import 'package:dio/dio.dart';
import 'package:devlink/config/config.dart';
import 'package:devlink/utility/font_styles.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

class UpdateChecker {
  static bool _hasAutoChecked = false;

  static Future<void> checkForUpdate(BuildContext context) async {
    if (_hasAutoChecked) return;
    _hasAutoChecked = true;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('appUpdates')
          .doc('devlink')
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final String latestVersion = data['version'] ?? '';
          final String updateLink = data['link'] ?? '';
          final String whatNew = data['whatNew'] ?? '';

          if (_isVersionNewer(latestVersion, Config.appVersion)) {
            _showUpdateDialog(context, latestVersion, whatNew, updateLink);
          }
        }
      }
    } catch (e) {
      print(e.toString());
    }
  }

  static Future<void> checkForUpdateFromButton(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 8),
              Loading.medium(color: primaryColor),
              const SizedBox(width: 18),
              Flexible(
                child: Text(
                  'Checking for Updates...',
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    try {
      final doc = await FirebaseFirestore.instance
          .collection('appUpdates')
          .doc('devlink')
          .get();
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final String latestVersion = data['version'] ?? '';
          final String updateLink = data['link'] ?? '';
          final String whatNew = data['whatNew'] ?? '';

          if (latestVersion.isNotEmpty && updateLink.isNotEmpty) {
            if (_isVersionNewer(latestVersion, Config.appVersion)) {
              _showUpdateDialog(context, latestVersion, whatNew, updateLink);
            } else {
              _showLatestVersionDialog(context);
            }
          } else {
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
            _showErrorDialog(context, 'Missing required update data.');
          }
        } else {
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
          _showErrorDialog(context, 'No update information found.');
        }
      } else {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        _showErrorDialog(context, 'No update information found.');
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      debugPrint('Error: $e');
      _showErrorDialog(context, e.toString());
    }
  }

  static bool _isVersionNewer(String latestVersion, String currentVersion) {
    List<int> latest = latestVersion.split('.').map(int.parse).toList();
    List<int> current = currentVersion.split('.').map(int.parse).toList();

    for (int i = 0; i < latest.length; i++) {
      if (i >= current.length || latest[i] > current[i]) return true;
      if (latest[i] < current[i]) return false;
    }
    return false;
  }

  static Future<void> _downloadAndInstallApp(
    BuildContext context,
    String downloadUrl,
    String version,
  ) async {
    try {
      // Get the download directory
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception('Could not access storage directory');
      }
      final downloadPath = '${directory.path}/Innova_Store_v$version.apk';
      debugPrint('Resolved download URL: $downloadUrl');
      debugPrint('Resolved download path: $downloadPath');
      final file = File(downloadPath);

      // Check if file already exists
      if (await file.exists()) {
        _showInstallDialog(context, downloadPath);
        return;
      }

      // Show download progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => DownloadDialog(
          downloadUrl: downloadUrl,
          downloadPath: downloadPath,
          onDownloadComplete: (path) {
            Navigator.of(ctx).pop();
            _showInstallDialog(context, path);
          },
        ),
      );
    } catch (e) {
      debugPrint(e.toString());
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      _showErrorDialog(context, 'Download failed: ${e.toString()}');
    }
  }

  static void _showInstallDialog(BuildContext context, String filePath) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Theme.of(ctx).colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CarbonIcons.arrow_up, size: 48, color: primaryColor),
                const SizedBox(height: 16),
                Text('Install Update', style: titleStyle()),
                const SizedBox(height: 8),
                Text(
                  'The update has been downloaded successfully',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(
                          ctx,
                        ).colorScheme.onSurface.withOpacity(0.7),
                      ),
                      child: const Text('Later'),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        try {
                          // Check if installation permission is granted
                          var status =
                              await Permission.requestInstallPackages.status;
                          if (!status.isGranted) {
                            // Request permission
                            status = await Permission.requestInstallPackages
                                .request();
                            if (!status.isGranted) {
                              throw Exception(
                                'Permission denied: You need to allow app installations from this source',
                              );
                            }
                          }

                          // Check if file exists
                          final file = File(filePath);
                          if (!await file.exists()) {
                            throw Exception('APK file not found');
                          }

                          // Use OpenFile to open the APK file directly
                          final result = await OpenFile.open(filePath);
                          if (result.type != ResultType.done) {
                            throw Exception(
                              'Installation failed: ${result.message}',
                            );
                          }
                        } catch (e) {
                          print('Installation error: ${e.toString()}');
                          _showErrorDialog(
                            context,
                            'Installation failed: ${e.toString()}',
                          );
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                      ),
                      child: const Text('Install Now'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _showUpdateDialog(
    BuildContext context,
    String version,
    String whatNew,
    String link,
  ) {
    showModalBottomSheet(
      backgroundColor: Theme.of(context).colorScheme.surface,
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Icon(
                    CarbonIcons.upgrade,
                    color: primaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Update Available',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 18,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Installed: ${Config.appVersion}   →   Latest: $version',
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "What's New:",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        whatNew.isEmpty ? 'No details provided.' : whatNew,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(ctx).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(
                            ctx,
                          ).colorScheme.onSurface.withOpacity(0.7),
                          side: BorderSide(color: Theme.of(ctx).dividerColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Later'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _downloadAndInstallApp(context, link, version);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Update Now'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _showLatestVersionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Icon(
                  CarbonIcons.checkmark_filled,
                  size: 50,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 10),
                Text('No Updates Available', style: titleStyle()),
                Text(
                  'You are already using the latest version',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _showErrorDialog(BuildContext context, String error) {
    debugPrint('Update error: $error');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          'Error',
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
        ),
        content: Text(
          error,
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class DownloadDialog extends StatefulWidget {
  final String downloadUrl;
  final String downloadPath;
  final Function(String) onDownloadComplete;

  const DownloadDialog({
    super.key,
    required this.downloadUrl,
    required this.downloadPath,
    required this.onDownloadComplete,
  });

  @override
  State<DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<DownloadDialog> {
  double _progress = 0.0;
  double _totalSize = 0.0;
  double _downloadedSize = 0.0;
  bool _isDownloading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      debugPrint('Starting APK download');
      debugPrint('Download URL: ${widget.downloadUrl}');
      debugPrint('Download path: ${widget.downloadPath}');

      final dio = Dio();
      await dio.download(
        widget.downloadUrl,
        widget.downloadPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
              _totalSize = total.toDouble();
              _downloadedSize = received.toDouble();
            });
          }
        },
      );

      debugPrint('Download completed successfully');
      widget.onDownloadComplete(widget.downloadPath);
    } catch (e, stackTrace) {
      debugPrint('Download failed: $e');
      debugPrint('Stack trace: $stackTrace');

      // Try to log HTTP details if this is a Dio HTTP error
      try {
        final dynamic error = e;
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;
        final headers = error.response?.headers;

        debugPrint('HTTP status code: $statusCode');
        debugPrint('Response headers: $headers');
        debugPrint('Response data: $data');
      } catch (_) {}

      setState(() {
        _isDownloading = false;
        _error = e.toString();
      });
    }
  }

  String _formatSize(double bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isDownloading)
                const Icon(CarbonIcons.download, size: 48, color: Colors.green)
              else if (_error.isNotEmpty)
                const Icon(CarbonIcons.warning, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _isDownloading ? 'Downloading Update' : 'Download Failed',
                style: titleStyle(),
              ),
              const SizedBox(height: 8),
              if (_isDownloading)
                const Text(
                  'Please wait while we download the latest version',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                )
              else
                Text(
                  _error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 24),
              if (_isDownloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.green.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.green,
                    ),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${(_progress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_totalSize > 0)
                      Text(
                        '(${_formatSize(_downloadedSize)} / ${_formatSize(_totalSize)})',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                        ),
                      ),
                  ],
                ),
              ],
              if (!_isDownloading) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
