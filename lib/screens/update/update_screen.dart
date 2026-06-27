import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:aricie/theme/app_theme.dart';
import 'package:aricie/services/update_service.dart';

class UpdateScreen extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateScreen({super.key, required this.updateInfo});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final _updateService = UpdateService.instance;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _downloadedPath;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startDownload() async {
    if (widget.updateInfo.apkUrl == null) return;
    final url = widget.updateInfo.apkUrl!;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _errorMessage = null;
    });

    try {
      await for (final progress in _updateService.downloadApk(url)) {
        if (!mounted) return;
        if (progress < 0) {
          setState(() {
            _isDownloading = false;
            _errorMessage = 'Téléchargement impossible. Vérifiez votre connexion et réessayez.';
          });
          return;
        }
        setState(() => _downloadProgress = progress);
      }
      if (!mounted) return;
      final path = await _updateService.apkDestination();
      setState(() {
        _isDownloading = false;
        _downloadedPath = path;
      });
      // Auto-launch the installer once the APK is on disk.
      if (path != null) {
        await _updateService.installApk(path);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Téléchargement impossible. Vérifiez votre connexion et réessayez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = widget.updateInfo;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Mise à jour'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s6),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.s4),
              SizedBox(
                width: 200,
                height: 200,
                child: Lottie.asset(
                  'assets/animations/update.json',
                  controller: _animationController,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: AppSpacing.s6),
              Text(
                'Nouvelle version disponible',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s3),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s4,
                  vertical: AppSpacing.s2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  'v${info.version ?? "?"}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'Mettez Aricie à jour pour profiter des dernières améliorations et continuer à suivre votre consommation.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s6),
              if (_isDownloading) ...[
                LinearProgressIndicator(
                  value: _downloadProgress,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  '${(_downloadProgress * 100).toInt()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
              ],
              if (_downloadedPath != null) ...[
                Icon(Icons.check_circle,
                  color: AppColors.accentMint, size: 48),
                const SizedBox(height: AppSpacing.s3),
                Text(
                  'Installation en cours...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.accentMint,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
              ],
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.accentDot,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s4),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isDownloading
                      ? null
                      : _downloadedPath != null
                          ? () => _updateService.installApk(_downloadedPath!)
                          : _startDownload,
                  icon: Icon(
                    _downloadedPath != null
                        ? Icons.system_update_alt
                        : _isDownloading
                            ? Icons.hourglass_top
                            : Icons.download,
                  ),
                  label: Text(
                    _downloadedPath != null
                        ? 'Installer maintenant'
                        : _isDownloading
                            ? 'Téléchargement...'
                            : 'Télécharger',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                  ),
                ),
              ),
              if (!info.forceUpdate) ...[
                const SizedBox(height: AppSpacing.s3),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Plus tard',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
