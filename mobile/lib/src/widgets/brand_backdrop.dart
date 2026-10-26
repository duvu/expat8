import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The app's signature background: a soft vertical wash with blurred brand
/// "auroras" (indigo and teal spark). Static, so it is painted once and
/// cached by its repaint boundary.
class BrandBackdrop extends StatelessWidget {
  const BrandBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: _AuroraPainter(Theme.of(context).colorScheme),
            ),
          ),
          child,
        ],
      );
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.scheme);

  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final dark = scheme.brightness == Brightness.dark;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surface,
            Color.lerp(
                scheme.surface, scheme.primaryContainer, dark ? 0.25 : 0.45)!,
          ],
        ).createShader(rect),
    );
    void aurora(Offset center, double radius, Color color, double alpha) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    aurora(Offset(size.width * 0.9, size.height * 0.08), size.width * 0.75,
        AppTheme.brandIndigo, dark ? 0.35 : 0.14);
    aurora(Offset(size.width * 0.05, size.height * 0.7), size.width * 0.7,
        AppTheme.brandSpark, dark ? 0.16 : 0.12);
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.scheme != scheme;
}
