import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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

      // 2. Fetch remote version info
      final response = await http.get(Uri.parse(_versionUrl));
      
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
      barrierDismissible: !forceUpdate, // Prevent dismissing if forced
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
              onPressed: () async {
                 final Uri url = Uri.parse(downloadUrl);
                 if (await canLaunchUrl(url)) {
                   await launchUrl(url, mode: LaunchMode.externalApplication);
                 } else {
                   debugPrint('Could not launch $downloadUrl');
                 }
              },
              child: const Text('UPDATE NOW', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }
}
