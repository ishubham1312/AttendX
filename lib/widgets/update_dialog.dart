import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  final UpdateService updateService;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.updateService,
  });

  static void show(BuildContext context, UpdateInfo info, UpdateService service) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(updateInfo: info, updateService: service),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _error = '';

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _error = '';
    });

    final filePath = await widget.updateService.downloadApk(
      widget.updateInfo.apkUrl,
      (received, total) {
        if (total != -1) {
          setState(() {
            _progress = received / total;
          });
        }
      },
    );

    if (filePath != null) {
      setState(() {
        _isDownloading = false;
      });
      await widget.updateService.installApk(filePath);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      setState(() {
        _isDownloading = false;
        _error = 'Download failed. Please check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Update Available', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Version ${widget.updateInfo.latestVersion} is available!',
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.forestGreen),
          ),
          const SizedBox(height: 12),
          const Text('Release Notes:', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.forestGreen.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              child: Text(
                widget.updateInfo.releaseNotes,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_error, style: const TextStyle(color: AppColors.absent, fontSize: 13)),
          ],
          if (_isDownloading) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: AppColors.forestGreen.withValues(alpha: 0.2),
              color: AppColors.forestGreen,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${(_progress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!_isDownloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
        if (!_isDownloading)
          ElevatedButton(
            onPressed: _startDownload,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}
