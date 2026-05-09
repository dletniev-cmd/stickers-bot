import 'dart:math';
import 'package:flutter/material.dart';

class ScannerRingPainter extends CustomPainter {
  final double progress;
  final bool isDone;
  final bool isSmile;
  final Color trackColor;
  final Color accentColor;
  final Color doneColor;
  final Color innerColor;
  final Color faceColor;

  ScannerRingPainter({
    required this.progress,
    required this.isDone,
    required this.isSmile,
    required this.trackColor,
    required this.accentColor,
    required this.doneColor,
    required this.innerColor,
    required this.faceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Match prototype proportions: SVG viewBox 124, r=54 for track, r=47.1 for inner
    // Scale factor from 124px viewBox to actual size
    final scale = size.width / 124;
    final outerRadius = 54 * scale;
    final innerRadius = 47.1 * scale;
    final strokeWidth = 3.8 * scale;

    // Track circle
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, outerRadius, trackPaint);

    // Progress arc
    final arcPaint = Paint()
      ..color = isDone ? doneColor : accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius),
      -pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );

    // Inner circle
    final innerPaint = Paint()..color = innerColor;
    canvas.drawCircle(center, innerRadius, innerPaint);

    if (isDone) {
      // Draw checkmark matching prototype positions
      final checkPaint = Paint()
        ..color = doneColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      path.moveTo(center.dx + (46 - 62) * scale, center.dy + (64 - 62) * scale);
      path.lineTo(center.dx + (58 - 62) * scale, center.dy + (76 - 62) * scale);
      path.lineTo(center.dx + (78 - 62) * scale, center.dy + (50 - 62) * scale);
      canvas.drawPath(path, checkPaint);
    } else {
      // Draw face
      final facePaint = Paint()
        ..color = faceColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale;

      // Face oval
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy - 1 * scale),
          width: 29 * scale,
          height: 34 * scale,
        ),
        facePaint,
      );

      // Eyes
      final eyePaint = Paint()..color = faceColor;
      canvas.drawCircle(
        Offset(center.dx - 5.5 * scale, center.dy - 5 * scale),
        2.1 * scale,
        eyePaint,
      );
      canvas.drawCircle(
        Offset(center.dx + 5.5 * scale, center.dy - 5 * scale),
        2.1 * scale,
        eyePaint,
      );

      // Mouth - smile when in smile phase
      final mouthPaint = Paint()
        ..color = isSmile ? accentColor.withOpacity(0.7) : faceColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = (isSmile ? 1.8 : 1.5) * scale
        ..strokeCap = StrokeCap.round;

      final mouthPath = Path();
      if (isSmile) {
        // Smile curve matching prototype: M55,66 Q62,73 69,66
        mouthPath.moveTo(center.dx - 7 * scale, center.dy + 4 * scale);
        mouthPath.quadraticBezierTo(
          center.dx, center.dy + 11 * scale,
          center.dx + 7 * scale, center.dy + 4 * scale,
        );
      } else {
        // Neutral mouth
        mouthPath.moveTo(center.dx - 7 * scale, center.dy + 5 * scale);
        mouthPath.quadraticBezierTo(
          center.dx, center.dy + 5 * scale,
          center.dx + 7 * scale, center.dy + 5 * scale,
        );
      }
      canvas.drawPath(mouthPath, mouthPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ScannerRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDone != isDone ||
        oldDelegate.isSmile != isSmile ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.innerColor != innerColor;
  }
}
