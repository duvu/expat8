import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'github_release_service.dart';

/// A dismissable top banner that notifies the user when a newer app version
/// is available on GitHub Releases.
///
/// Wrap your root widget with this widget.  It runs a background update check
/// on mount and renders a thin banner if a newer version is found.
class UpdateBannerWrapper extends StatefulWidget {
  const UpdateBannerWrapper({required this.child, super.key});

  final Widget child;

  @override
  State<UpdateBannerWrapper> createState() => _UpdateBannerWrapperState();
}

class _UpdateBannerWrapperState extends State<UpdateBannerWrapper> {
  final _service = GithubReleaseService();
  UpdateCheckResult? _result;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final result = await _service.checkForUpdate();
    if (mounted && result.hasUpdate) {
      setState(() => _result = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    if (r == null || _dismissed || !r.hasUpdate) return widget.child;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: _UpdateBanner(
              version: r.latestVersion!,
              releaseUrl: r.releaseUrl!,
              onDismiss: () => setState(() => _dismissed = true),
            ),
          ),
        ),
      ],
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({
    required this.version,
    required this.releaseUrl,
    required this.onDismiss,
  });

  final String version;
  final String releaseUrl;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.primaryContainer,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.system_update_alt,
              size: 18,
              color: colors.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Version $version available',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colors.onPrimaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: () async {
                final uri = Uri.parse(releaseUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Download'),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 16, color: colors.onPrimaryContainer),
              onPressed: onDismiss,
              tooltip: 'Dismiss',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
