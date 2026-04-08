import 'dart:math';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Animated floating orbs background for the login screen.
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _BackgroundPainter(_controller.value),
          size: MediaQuery.of(context).size,
        );
      },
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final double progress;

  _BackgroundPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // Dark gradient base
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.background,
          const Color(0xFF151631),
          AppTheme.surface,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Floating orbs
    _drawOrb(canvas, size, 0.2, 0.15, 180, AppTheme.primary, 0.08);
    _drawOrb(canvas, size, 0.8, 0.25, 140, AppTheme.accent, 0.06);
    _drawOrb(canvas, size, 0.5, 0.7, 200, AppTheme.primaryDark, 0.05);
    _drawOrb(canvas, size, 0.15, 0.8, 120, AppTheme.accentAlt, 0.04);
    _drawOrb(canvas, size, 0.85, 0.65, 160, AppTheme.primary, 0.04);
  }

  void _drawOrb(Canvas canvas, Size size, double baseX, double baseY,
      double radius, Color color, double opacity) {
    final x = size.width * baseX +
        sin(progress * 2 * pi + baseX * 10) * 30;
    final y = size.height * baseY +
        cos(progress * 2 * pi + baseY * 10) * 25;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCircle(center: Offset(x, y), radius: radius),
      );

    canvas.drawCircle(Offset(x, y), radius, paint);
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
