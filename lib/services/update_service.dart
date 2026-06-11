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

enum UpdateStatus {
  noUpdate,
  updateAvailable,
  failed,
}

class UpdateCheckResult {
  final UpdateStatus status;
  final UpdateInfo? info;
  final String? errorMessage;

  UpdateCheckResult({
    required this.status,
    this.info,
    this.errorMessage,
  });
}

class UpdateService {
  // Configuration for GitHub Releases
  static const String owner = 'ishubham1312';
  static const String repo = 'AttendX';
  static const String apiUrl = 'https://api.github.com/repos/ishubham1312/AttendX/releases/latest';

  // For private repositories, paste your GitHub Personal Access Token (PAT) here.
  // Leave empty if the repository is public.
  static const String githubToken = '';

  final Dio _dio = Dio();
  bool _isChecking = false;

  Future<UpdateCheckResult> checkForUpdate() async {
    if (_isChecking) {
      return UpdateCheckResult(
        status: UpdateStatus.failed,
        errorMessage: 'An update check is already in progress.',
      );
    }
    _isChecking = true;
    try {
      final Map<String, dynamic> headers = {
        'Accept': 'application/vnd.github.v3+json',
      };
      if (githubToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $githubToken';
      }

      final response = await _dio.get(
        apiUrl,
        options: Options(
          headers: headers,
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

          if (apkUrl.isEmpty && assets.isNotEmpty) {
            // Fallback to HTML URL of release if no APK asset is present
            apkUrl = data['html_url'] ?? '';
          }

          if (apkUrl.isNotEmpty) {
            final info = UpdateInfo(
              latestVersion: latestVersion,
              releaseNotes: data['body'] ?? 'No release notes provided.',
              apkUrl: apkUrl,
              releaseDate: data['published_at'] ?? '',
            );
            return UpdateCheckResult(
              status: UpdateStatus.updateAvailable,
              info: info,
            );
          } else {
            return UpdateCheckResult(
              status: UpdateStatus.failed,
              errorMessage: 'No download asset found in the latest release.',
            );
          }
        } else {
          return UpdateCheckResult(
            status: UpdateStatus.noUpdate,
          );
        }
      } else {
        return UpdateCheckResult(
          status: UpdateStatus.failed,
          errorMessage: 'Server returned HTTP ${response.statusCode}.',
        );
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
      String msg = 'Failed to connect to update server.';
      if (e is DioException) {
        if (e.response?.statusCode == 404) {
          msg = 'GitHub repository is private or has no releases (404).\n\nTo resolve this:\n1. Make sure your repository is public and has a published release, OR\n2. Add a GitHub Personal Access Token in "UpdateService.githubToken" to access your private repository.';
        } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
          msg = 'Connection timed out. Please check your network.';
        } else {
          msg = e.message ?? msg;
        }
      }
      return UpdateCheckResult(
        status: UpdateStatus.failed,
        errorMessage: msg,
      );
    } finally {
      _isChecking = false;
    }
  }

  bool _isNewerVersion(String current, String latest) {
    final currParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final lateParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

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
