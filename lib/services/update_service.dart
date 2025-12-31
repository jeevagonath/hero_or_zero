import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ota_update/ota_update.dart';

class UpdateService {
  // Raw GitHub URL for version.json
  // Using 'main' branch. ensure this file exists in repo after push.
  static const String _versionUrl = 'https://raw.githubusercontent.com/jeevagonath/hero_or_zero/main/version.json';

  /// Checks for updates and shows a dialog if a newer version is available.
  Future<void> checkForUpdate(BuildContext context) async {
    try {
      // 1. Get current app version
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;
      final int currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      debugPrint('UpdateService: Current Version: $currentVersion+$currentBuildNumber');

      // 2. Fetch remote version info with cache killing
      final String url = '$_versionUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('UpdateService: Fetching from $url');
      
      final response = await http.get(Uri.parse(url));
      
      debugPrint('UpdateService: Response Code: ${response.statusCode}');
      debugPrint('UpdateService: Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String remoteVersion = data['version'] ?? '0.0.0';
        final int remoteBuildNumber = data['buildNumber'] ?? 0;
        final bool forceUpdate = data['forceUpdate'] ?? false;
        final String downloadUrl = data['downloadUrl'] ?? '';
        final String title = data['title'] ?? 'Update Available';
        final String message = data['message'] ?? 'A new version is available.';

        debugPrint('UpdateService: Remote Version: $remoteVersion+$remoteBuildNumber');

        // 3. Compare versions
        // Simple comparison: Check if remote build number is higher
        // Or strictly parse semver if needed. For now, Build Number is reliable for Flutter apps.
        bool updateAvailable = false;
        
        if (remoteBuildNumber > currentBuildNumber) {
           updateAvailable = true;
        } else if (remoteBuildNumber == currentBuildNumber) {
           // Fallback to version string comparison if build numbers match (rare)
           if (_compareVersions(remoteVersion, currentVersion) > 0) {
             updateAvailable = true;
           }
        }

        if (updateAvailable && context.mounted) {
          _showUpdateDialog(
            context, 
            title: title, 
            message: message, 
            downloadUrl: downloadUrl, 
            forceUpdate: forceUpdate
          );
        }
      } else {
        debugPrint('UpdateService: Failed to fetch version info. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('UpdateService: Error checking for update: $e');
    }
  }

  int _compareVersions(String v1, String v2) {
    List<int> v1Parts = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> v2Parts = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      int part1 = (i < v1Parts.length) ? v1Parts[i] : 0;
      int part2 = (i < v2Parts.length) ? v2Parts[i] : 0;
      if (part1 > part2) return 1;
      if (part1 < part2) return -1;
    }
    return 0;
  }

  void _showUpdateDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String downloadUrl,
    required bool forceUpdate,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => !forceUpdate,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(message, style: const TextStyle(color: Colors.white70)),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('LATER', style: TextStyle(color: Colors.grey)),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D97E)),
              onPressed: () {
                Navigator.pop(ctx); // Close alert
                _tryOtaUpdate(context, downloadUrl);
              },
              child: const Text('UPDATE NOW', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tryOtaUpdate(BuildContext context, String url) async {
    // Show Progress Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DownloadProgressDialog(url: url),
    );
  }
}

class _DownloadProgressDialog extends StatefulWidget {
  final String url;
  const _DownloadProgressDialog({required this.url});

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  String _status = 'Starting download...';
  double _progress = 0.0;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  void _startDownload() {
    try {
      OtaUpdate()
          .execute(widget.url, destinationFilename: 'hero_zero_update.apk')
          .listen(
        (OtaEvent event) {
          if (!mounted) return;
          setState(() {
            _status = _getStatusMessage(event.status);
            if (event.value != null && event.value!.isNotEmpty) {
               _progress = (double.tryParse(event.value!) ?? 0) / 100;
            }
          });
          
          if (event.status == OtaStatus.INSTALLING) {
             // Close dialog when installing starts or let user close? 
             // Usually better to leave it or close it. 
             // Navigator.pop(context); 
          }
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _status = 'Download Failed: $e';
            _error = true;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error: $e';
          _error = true;
        });
      }
    }
  }

  String _getStatusMessage(OtaStatus status) {
    switch (status) {
      case OtaStatus.DOWNLOADING: return 'Downloading...';
      case OtaStatus.INSTALLING: return 'Installing...';
      case OtaStatus.ALREADY_RUNNING_ERROR: return 'Download already running';
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR: return 'Permission denied';
      case OtaStatus.INTERNAL_ERROR: return 'Internal error';
      case OtaStatus.DOWNLOAD_ERROR: return 'Download failed';
      case OtaStatus.CHECKSUM_ERROR: return 'Checksum error';
      default: return 'Status: $status';
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => _error, // Only fully dismissible on error
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Updating App', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_status, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _error ? 0 : (_progress > 0 ? _progress : null),
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                  _error ? Colors.redAccent : const Color(0xFF00D97E)
              ),
            ),
            if (_error) ...[
               const SizedBox(height: 16),
               SizedBox(
                 width: double.infinity,
                 child: ElevatedButton(
                   onPressed: () {
                     // Fallback to browser
                     Navigator.pop(context);
                     launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication);
                   }, 
                   style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                   child: const Text('OPEN IN BROWSER'),
                 ),
               ),
               TextButton(
                 onPressed: () => Navigator.pop(context),
                 child: const Text('CLOSE'),
               )
            ]
          ],
        ),
      ),
    );
  }
}
