import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Telegram logo — exact SVG path from the HTML prototype
class TelegramIcon extends StatelessWidget {
  final double size;
  final Color color;

  const TelegramIcon({super.key, this.size = 22, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TgPainter(color: color),
      ),
    );
  }
}

class _TgPainter extends CustomPainter {
  final Color color;
  _TgPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 512;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(102.88 * s, 236.65 * s)
      ..cubicTo(193.14 * s, 197.41 * s, 253.31 * s, 171.53 * s, 283.44 * s, 159.03 * s)
      ..cubicTo(369.40 * s, 123.36 * s, 387.26 * s, 117.17 * s, 398.90 * s, 116.96 * s)
      ..cubicTo(401.46 * s, 116.92 * s, 407.18 * s, 117.56 * s, 410.88 * s, 120.56 * s)
      ..cubicTo(414.01 * s, 123.10 * s, 414.87 * s, 126.53 * s, 415.29 * s, 128.93 * s)
      ..cubicTo(415.70 * s, 131.33 * s, 416.21 * s, 136.81 * s, 415.81 * s, 141.08 * s)
      ..cubicTo(411.14 * s, 189.98 * s, 390.97 * s, 308.64 * s, 380.71 * s, 363.47 * s)
      ..cubicTo(376.37 * s, 386.58 * s, 367.84 * s, 394.34 * s, 359.57 * s, 395.10 * s)
      ..cubicTo(341.57 * s, 396.75 * s, 327.91 * s, 383.20 * s, 310.50 * s, 371.81 * s)
      ..cubicTo(283.24 * s, 353.98 * s, 267.83 * s, 342.88 * s, 241.36 * s, 325.48 * s)
      ..cubicTo(210.78 * s, 305.36 * s, 230.60 * s, 294.30 * s, 249.94 * s, 276.21 * s)
      ..cubicTo(254.50 * s, 271.48 * s, 334.66 * s, 198.56 * s, 336.19 * s, 192.04 * s)
      ..cubicTo(336.38 * s, 191.23 * s, 336.56 * s, 188.19 * s, 334.75 * s, 186.59 * s)
      ..cubicTo(332.94 * s, 184.98 * s, 330.27 * s, 185.54 * s, 328.34 * s, 185.98 * s)
      ..cubicTo(325.61 * s, 186.59 * s, 282.09 * s, 215.36 * s, 197.82 * s, 272.28 * s)
      ..cubicTo(185.47 * s, 280.76 * s, 174.29 * s, 284.86 * s, 164.27 * s, 284.65 * s)
      ..cubicTo(153.22 * s, 284.41 * s, 131.93 * s, 278.41 * s, 116.11 * s, 273.27 * s)
      ..cubicTo(96.71 * s, 266.97 * s, 81.30 * s, 263.64 * s, 82.64 * s, 252.32 * s)
      ..cubicTo(82.58 * s, 241.77 * s, 90.26 * s, 236.08 * s, 102.88 * s, 236.65 * s)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TgPainter old) => old.color != color;
}
