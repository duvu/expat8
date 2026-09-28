import 'package:flutter/material.dart';

import '../network/connectivity_monitor.dart';

/// Thin status strip shown above every screen while the device is offline.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({required this.monitor, required this.child, super.key});

  final ConnectivityMonitor monitor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, child) {
        final scheme = Theme.of(context).colorScheme;
        return Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: monitor.isOnline
                  ? const SizedBox(width: double.infinity)
                  : Material(
                      color: scheme.inverseSurface,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.cloud_off,
                                  size: 16, color: scheme.onInverseSurface),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Offline — you can keep learning. '
                                  'Progress syncs when you reconnect.',
                                  style: TextStyle(
                                    color: scheme.onInverseSurface,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: !monitor.isOnline,
                child: child!,
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}
