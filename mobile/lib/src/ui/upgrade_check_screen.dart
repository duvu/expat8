import 'package:flutter/material.dart';

import '../api/backend_api_client.dart';
import '../models/release_info.dart';

/// Compile-time version code from --dart-define=APP_VERSION_CODE=<int>.
const int kAppVersionCode = int.fromEnvironment('APP_VERSION_CODE', defaultValue: 1);

/// Compile-time version name from --dart-define=APP_VERSION_NAME=<string>.
const String kAppVersionName =
    String.fromEnvironment('APP_VERSION_NAME', defaultValue: '1.0.0');

class UpgradeCheckScreen extends StatefulWidget {
  const UpgradeCheckScreen({
    required this.apiClient,
    this.onInstallApk,
    super.key,
  });

  final BackendApiClient apiClient;

  /// Called with the downloaded APK file path when the user triggers install.
  /// If null, the install button is hidden (useful for tests).
  final Future<void> Function(String apkPath)? onInstallApk;

  @override
  State<UpgradeCheckScreen> createState() => _UpgradeCheckScreenState();
}

enum _ScreenState { loading, upToDate, updateAvailable, downloading, error }

class _UpgradeCheckScreenState extends State<UpgradeCheckScreen> {
  _ScreenState _state = _ScreenState.loading;
  ReleaseInfo? _latestRelease;
  String? _errorMessage;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _state = _ScreenState.loading;
      _errorMessage = null;
    });
    try {
      final release = await widget.apiClient.fetchLatestRelease();
      if (!mounted) return;
      if (release == null || release.versionCode <= kAppVersionCode) {
        setState(() {
          _state = _ScreenState.upToDate;
          _latestRelease = release;
        });
      } else {
        setState(() {
          _state = _ScreenState.updateAvailable;
          _latestRelease = release;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ScreenState.error;
        _errorMessage = 'Could not check for updates. Please try again.';
      });
    }
  }

  Future<void> _downloadAndInstall() async {
    if (_latestRelease == null) return;
    setState(() {
      _state = _ScreenState.downloading;
      _downloadProgress = 0.0;
    });
    try {
      final filePath = await widget.apiClient.downloadRelease(
        _latestRelease!.id,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _downloadProgress = total > 0 ? received / total : 0.0;
          });
        },
      );
      if (!mounted) return;
      if (widget.onInstallApk != null) {
        await widget.onInstallApk!(filePath);
      }
      // Reset to updateAvailable state after install attempt
      setState(() {
        _state = _ScreenState.updateAvailable;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ScreenState.error;
        _errorMessage = 'Download failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check for updates')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _ScreenState.loading:
        return const Center(child: CircularProgressIndicator());

      case _ScreenState.upToDate:
        return _buildUpToDate();

      case _ScreenState.updateAvailable:
        return _buildUpdateAvailable();

      case _ScreenState.downloading:
        return _buildDownloading();

      case _ScreenState.error:
        return _buildError();
    }
  }

  Widget _buildUpToDate() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        const Text(
          'App is up to date',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          'Current version: $kAppVersionName ($kAppVersionCode)',
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildUpdateAvailable() {
    final release = _latestRelease!;
    final sizeMB = (release.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.system_update_outlined, size: 64, color: Colors.blue),
        const SizedBox(height: 16),
        const Text(
          'Update available',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text('Current version: $kAppVersionName ($kAppVersionCode)'),
        const SizedBox(height: 4),
        Text(
          'Latest version: ${release.versionName} (${release.versionCode})',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text('Size: $sizeMB MB', style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _downloadAndInstall,
          icon: const Icon(Icons.download),
          label: const Text('Download & Install'),
        ),
      ],
    );
  }

  Widget _buildDownloading() {
    final percent = (_downloadProgress * 100).toStringAsFixed(0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Downloading update...',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),
        LinearProgressIndicator(value: _downloadProgress),
        const SizedBox(height: 8),
        Text('$percent%'),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Text(
          _errorMessage ?? 'An error occurred.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _checkForUpdates,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}
