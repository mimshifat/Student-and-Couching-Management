import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppUpdater {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Run this ONCE to automatically create the document in Firestore
  /// without opening the Firebase Console.
  static Future<void> createInitialDocument() async {
    try {
      await _firestore.collection('app_updates').doc('android_release').set({
        'latest_version': '1.0.0',
        'build_number': 1,
        'apk_download_url': 'https://example.com/app.apk', // Replace with your APK link later
        'is_mandatory': false,
        'release_notes': 'Initial release.',
      });
      debugPrint("✅ Firestore Update Document created successfully!");
    } catch (e) {
      debugPrint("❌ Error creating document: $e");
    }
  }

  static bool _hasCheckedThisSession = false;
  static const _storage = FlutterSecureStorage();

  /// Call this when the app starts (e.g., in HomeScreen's initState)
  static Future<void> checkForUpdates(BuildContext context, {bool force = false}) async {
    if (!Platform.isAndroid) return; // APK updates are only for Android!
    if (_hasCheckedThisSession && !force) return; // Prevent spamming the user
    
    try {
      // COOLDOWN LOGIC: Only check Firebase once every 3 hours to save read costs!
      if (!force) {
        String? lastCheckStr = await _storage.read(key: 'last_update_check');
        if (lastCheckStr != null) {
          try {
            DateTime lastCheck = DateTime.parse(lastCheckStr);
            if (DateTime.now().difference(lastCheck).inHours < 3) {
              debugPrint("Skipping update check (Checked recently).");
              return;
            }
          } catch (e) {
            // If the date is corrupted, delete it and force a check
            await _storage.delete(key: 'last_update_check');
          }
        }
      }

      // 1. Get current app version
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      int currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      // 2. Fetch latest version from Firestore (timeout after 10 seconds to prevent freezing)
      DocumentSnapshot doc = await _firestore
          .collection('app_updates')
          .doc('android_release')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      // Mark the current time as checked
      await _storage.write(key: 'last_update_check', value: DateTime.now().toIso8601String());

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        int latestBuildNumber = data['build_number'] ?? 0;
        String latestVersion = data['latest_version'] ?? '';
        String downloadUrl = data['apk_download_url'] ?? '';
        bool isMandatory = data['is_mandatory'] ?? false;
        String releaseNotes = data['release_notes'] ?? '';

        // 3. Compare versions
        if (latestBuildNumber > currentBuildNumber && context.mounted) {
          _hasCheckedThisSession = true; // Mark as checked so we don't spam them
          _showUpdateDialog(
            context,
            latestVersion,
            downloadUrl,
            releaseNotes,
            isMandatory,
          );
        } else if (force && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your app is up to date! 🎉')),
          );
        }
      }
    } catch (e) {
      debugPrint("Error checking for updates: $e");
    }
  }

  static void _showUpdateDialog(
    BuildContext context,
    String version,
    String downloadUrl,
    String releaseNotes,
    bool isMandatory,
  ) {
    showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (context) {
        return UpdateDialog(
          version: version,
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes,
          isMandatory: isMandatory,
        );
      },
    );
  }
}

class UpdateDialog extends StatefulWidget {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final bool isMandatory;

  const UpdateDialog({
    super.key,
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isMandatory,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;

  Future<void> _startDownload() async {
    if (_isDownloading) return; // Prevent user from double-clicking the button rapidly

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
    });

    try {
      // Get optimal directory for Android Package Installer (Fixes Xiaomi/Samsung Sandbox Crash)
      List<Directory>? externalDirs = await getExternalCacheDirectories();
      Directory tempDir = (externalDirs != null && externalDirs.isNotEmpty)
          ? externalDirs.first
          : await getTemporaryDirectory();
          
      String finalPath = '${tempDir.path}/update_v${widget.version}.apk';
      String downloadingPath = '$finalPath.download';

      File finalFile = File(finalPath);
      
      // Fixes the "Permission Loop": If the fully downloaded file already exists, SKIP download!
      if (await finalFile.exists()) {
        if (mounted) {
          setState(() {
            _progress = 1.0;
            _isDownloading = false;
          });
        }
        await OpenFilex.open(finalPath);
        return;
      }

      // Delete any old corrupted partial downloads
      File downloadingFile = File(downloadingPath);
      if (await downloadingFile.exists()) {
        await downloadingFile.delete();
      }

      // Download the APK with timeouts to prevent hanging
      Dio dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(minutes: 5), // allow 5 mins max for download
      ));
      await dio.download(
        widget.downloadUrl,
        downloadingPath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _progress = received / total;
            });
          }
        },
      );

      // Download complete! Rename it to mark it as 100% finished
      await downloadingFile.rename(finalPath);

      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }

      // Open and install the downloaded APK
      final result = await OpenFilex.open(finalPath);
      debugPrint("Install status: ${result.message}");

    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
      debugPrint("Download error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download update.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isMandatory && !_isDownloading,
      child: AlertDialog(
        title: Text('Update Available (v${widget.version})'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('A new version of the app is available!'),
          const SizedBox(height: 10),
          Text(widget.releaseNotes, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          if (_isDownloading)
            Column(
              children: [
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
                Text('${(_progress * 100).toStringAsFixed(0)}% downloaded'),
              ],
            ),
        ],
      ),
      actions: [
        if (!widget.isMandatory && !_isDownloading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
        if (!_isDownloading)
          ElevatedButton(
            onPressed: _startDownload,
            child: const Text('Update Now'),
          ),
      ],
    ));
  }
}
