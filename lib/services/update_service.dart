import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/foundation.dart';

class UpdateInfo {
  final String latestVersion;
  final String releaseNotes;
  final String apkUrl;
  final String releaseDate;

  UpdateInfo({
    required this.latestVersion,
    required this.releaseNotes,
    required this.apkUrl,
    required this.releaseDate,
  });
}

class UpdateService {
  // Configuration for GitHub Releases
  static const String owner =
      'ishubham1312'; // Replace with actual GitHub username
  static const String repo = 'AttendX'; // Replace with actual repository name
  static const String apiUrl =
      'https://api.github.com/repos/ishubham1312/AttendX/releases/latest';

  final Dio _dio = Dio();
  bool _isChecking = false;

  Future<UpdateInfo?> checkForUpdate() async {
    if (_isChecking || kIsWeb || !Platform.isAndroid) return null;
    _isChecking = true;
    try {
      final response = await _dio.get(
        apiUrl,
        options: Options(
          headers: {'Accept': 'application/vnd.github.v3+json'},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final tagName = data['tag_name'] as String;
        final latestVersion = tagName.replaceAll('v', '');

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (_isNewerVersion(currentVersion, latestVersion)) {
          final assets = data['assets'] as List;
          String apkUrl = '';
          for (var asset in assets) {
            if (asset['name'].toString().endsWith('.apk')) {
              apkUrl = asset['browser_download_url'];
              break;
            }
          }

          if (apkUrl.isNotEmpty) {
            return UpdateInfo(
              latestVersion: latestVersion,
              releaseNotes: data['body'] ?? 'No release notes provided.',
              apkUrl: apkUrl,
              releaseDate: data['published_at'] ?? '',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    } finally {
      _isChecking = false;
    }
    return null;
  }

  bool _isNewerVersion(String current, String latest) {
    final currParts = current
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    final lateParts = latest
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();

    for (int i = 0; i < 3; i++) {
      final c = i < currParts.length ? currParts[i] : 0;
      final l = i < lateParts.length ? lateParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  Future<String?> downloadApk(String url, Function(int, int) onProgress) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/update.apk';

      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      await _dio.download(url, filePath, onReceiveProgress: onProgress);

      return filePath;
    } catch (e) {
      debugPrint('Download failed: $e');
      return null;
    }
  }

  Future<void> installApk(String filePath) async {
    await OpenFilex.open(filePath);
  }
}
