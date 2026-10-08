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
        
        // Safely parse Firestore data (prevents crashes if admin accidentally types a String instead of a Number)
        int latestBuildNumber = 0;
        if (data['build_number'] is int) {
          latestBuildNumber = data['build_number'];
        } else if (data['build_number'] is String) {
          latestBuildNumber = int.tryParse(data['build_number']) ?? 0;
        }

        String latestVersion = data['latest_version']?.toString() ?? '';
        String downloadUrl = data['apk_download_url']?.toString() ?? '';
        
        bool isMandatory = false;
        if (data['is_mandatory'] is bool) {
          isMandatory = data['is_mandatory'];
        } else if (data['is_mandatory'] is String) {
          isMandatory = data['is_mandatory'].toString().toLowerCase() == 'true';
        }

        String releaseNotes = data['release_notes']?.toString() ?? '';

        // 3. Compare versions
        if (latestBuildNumber > currentBuildNumber && context.mounted) {
          _hasCheckedThisSession = true; // Mark as checked so we don't spam them
          if (force) ScaffoldMessenger.of(context).hideCurrentSnackBar();
          _showUpdateDialog(
            context,
            latestVersion,
            downloadUrl,
            releaseNotes,
            isMandatory,
          );
        } else if (force && context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your app is already up to date! 🎉')),
          );
        }
      } else if (force && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your app is already up to date! 🎉')),
        );
      }
    } catch (e) {
      debugPrint("Error checking for updates: $e");
      if (force && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update check failed: ${e.toString().split(']').last.trim()}')),
        );
      }
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
  bool _isDownloaded = false;
  double _progress = 0.0;

  String? _apkFilePath;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyDownloaded();
  }

  Future<void> _checkIfAlreadyDownloaded() async {
    List<Directory>? externalDirs = await getExternalCacheDirectories();
    Directory tempDir = (externalDirs != null && externalDirs.isNotEmpty)
        ? externalDirs.first
        : await getTemporaryDirectory();
    String safeVersion = widget.version.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '_');
    String finalPath = '${tempDir.path}/update_v$safeVersion.apk';
    _apkFilePath = finalPath;
    
    File finalFile = File(finalPath);
    if (await finalFile.exists()) {
      int size = await finalFile.length();
      if (size < 5000000) { // < 5MB means it's corrupted/incomplete
        try { await finalFile.delete(); } catch (_) {}
        return;
      }
      if (mounted) {
        setState(() {
          _isDownloaded = true;
        });
      }
    }
  }

  Future<void> _forceRedownload() async {
    if (_apkFilePath != null) {
      File f = File(_apkFilePath!);
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    setState(() {
      _isDownloaded = false;
      _progress = 0.0;
    });
    _startDownload();
  }

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
          
      String safeVersion = widget.version.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '_');
      String finalPath = '${tempDir.path}/update_v$safeVersion.apk';
      String downloadingPath = '$finalPath.download';

      File finalFile = File(finalPath);
      
      // Fixes the "Permission Loop": If the fully downloaded file already exists, SKIP download!
      if (await finalFile.exists()) {
        if (mounted) {
          setState(() {
            _progress = 1.0;
            _isDownloading = false;
            _isDownloaded = true;
          });
        }
        final result = await OpenFilex.open(
          finalPath,
          type: 'application/vnd.android.package-archive',
        );
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to open installer: ${result.message}')),
          );
        }
        return;
      }

      // Delete any old corrupted partial downloads
      File downloadingFile = File(downloadingPath);
      try {
        if (await downloadingFile.exists()) {
          await downloadingFile.delete();
        }
      } catch (_) {}

      // Download the APK with timeouts to prevent hanging
      Dio dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(minutes: 5), // allow 5 mins max for download
      ));
      await dio.download(
        widget.downloadUrl,
        downloadingPath,
        onReceiveProgress: (received, total) {
          if (mounted) {
            setState(() {
              if (total > 0) {
                _progress = received / total;
              } else {
                // If total is -1 (unknown length) or 0, just show indeterminate progress
                _progress = -1.0; 
              }
            });
          }
        },
      );

      // Download complete! Rename it to mark it as 100% finished
      await downloadingFile.rename(finalPath);

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isDownloaded = true;
        });
      }

      final result = await OpenFilex.open(
        finalPath,
        type: 'application/vnd.android.package-archive',
      );
      debugPrint("Install status: ${result.message}");
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open installer: ${result.message}')),
        );
      }

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
      canPop: !widget.isMandatory && !_isDownloading && !_isDownloaded,
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
                LinearProgressIndicator(value: _progress >= 0 ? _progress : null),
                const SizedBox(height: 8),
                Text(_progress >= 0 ? '${(_progress * 100).toStringAsFixed(0)}% downloaded' : 'Downloading...'),
              ],
            ),
        ],
      ),
      actions: [
        if (!widget.isMandatory && !_isDownloading && !_isDownloaded)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
        if (_isDownloaded && !_isDownloading)
          TextButton(
            onPressed: _forceRedownload,
            child: const Text('Redownload', style: TextStyle(color: Colors.red)),
          ),
        if (!_isDownloading)
          ElevatedButton(
            onPressed: _startDownload,
            child: Text(_isDownloaded ? 'Install Now' : 'Update Now'),
          ),
      ],
    ));
  }
}
