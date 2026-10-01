import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Static mesh background, built from the app's own brand tokens
/// (`AppColors.primary`, `AppColors.liveTeal`) instead of an arbitrary
/// third color. No animation — this is chrome behind the glass layer, not
/// a focal element; it exists so glass surfaces have something colorful
/// to refract, per the visual-language-reset motion rules.
///
/// Four blobs give the whole canvas color coverage (not just two corners),
/// since most cards actually sit center-screen — a glass panel over flat
/// white has nothing to refract. A fixed-seed grain layer adds tactile
/// depth and breaks up gradient banding; it's painted once and never
/// repaints (see [_GrainPainter.shouldRepaint]), so it costs nothing
/// after the first frame.
class BrandMeshBackground extends StatelessWidget {
  final Widget child;

  const BrandMeshBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: AppColors.background),

        // Top-left: teal
        Positioned(
          top: -size.height * 0.22,
          left: -size.width * 0.18,
          width: size.width * 0.8,
          height: size.height * 0.65,
          child: _blob(AppColors.liveTeal, 0.34),
        ),

        // Center: a soft blend bridge so mid-screen cards have color to
        // refract too, not just the corners — this is the one that matters
        // most, since cards cover nearly the whole viewport and only leave
        // thin gaps exposed.
        Positioned(
          top: size.height * 0.18,
          left: size.width * 0.22,
          width: size.width * 0.62,
          height: size.height * 0.58,
          child: _blob(AppColors.primary, 0.20),
        ),

        // Bottom-right: blue
        Positioned(
          bottom: -size.height * 0.28,
          right: -size.width * 0.22,
          width: size.width * 0.85,
          height: size.height * 0.7,
          child: _blob(AppColors.primary, 0.36),
        ),

        // Bottom-left: a smaller teal echo for balance.
        Positioned(
          bottom: -size.height * 0.1,
          left: -size.width * 0.1,
          width: size.width * 0.5,
          height: size.height * 0.4,
          child: _blob(AppColors.liveTeal, 0.24),
        ),

        RepaintBoundary(
          child: CustomPaint(
            painter: _GrainPainter(),
            size: Size.infinite,
          ),
        ),

        child,
      ],
    );
  }

  Widget _blob(Color color, double alpha) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }
}

/// Fixed-seed grain — deterministic, so it paints identically every run
/// and never needs to repaint.
class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(7);
    final paint = Paint();
    const dotCount = 900;
    for (var i = 0; i < dotCount; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final isLight = rng.nextBool();
      paint.color = (isLight ? Colors.white : AppColors.textPrimary)
          .withValues(alpha: 0.015 + rng.nextDouble() * 0.02);
      canvas.drawCircle(Offset(dx, dy), 0.6 + rng.nextDouble() * 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter oldDelegate) => false;
}
