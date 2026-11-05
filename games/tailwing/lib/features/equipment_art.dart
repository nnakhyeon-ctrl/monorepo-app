import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/design.dart';

/// Original scalable module silhouettes, no imported icons or textures.
class EquipmentArt extends CustomPainter {
  const EquipmentArt(this.id);
  final String id;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.shortestSide / 128);
    final color = switch (id) {
      'capacitor' => const Color(0xFFFFCE88),
      'gyro' => const Color(0xFFB9C5FF),
      'safety_cell' => const Color(0xFFBAE6A4),
      _ => Palette.teal,
    };
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = color;
    final shell = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-28, -36, 56, 72),
      const Radius.circular(13),
    );
    canvas.drawRRect(
      shell,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: .3), const Color(0xFF122333)],
        ).createShader(shell.outerRect),
    );
    canvas.drawRRect(shell, p);
    switch (id) {
      case 'echo':
        for (final side in [-1, 1]) {
          canvas.drawPath(
            Path()
              ..moveTo(side * 25.0, -22)
              ..lineTo(side * 52.0, 11)
              ..lineTo(side * 36.0, 28)
              ..lineTo(side * 23.0, 14),
            p,
          );
        }
      case 'prism':
        canvas.drawPath(
          Path()
            ..moveTo(0, -24)
            ..lineTo(18, -16)
            ..lineTo(14, 9)
            ..quadraticBezierTo(7, 22, 0, 26)
            ..quadraticBezierTo(-7, 22, -14, 9)
            ..lineTo(-18, -16)
            ..close(),
          p,
        );
      case 'tuner':
        for (var i = 0; i < 3; i++) {
          final y = (i - 1) * 17.0;
          canvas.drawLine(Offset(-18, y), Offset(18, y), p);
          canvas.drawCircle(
            Offset(i.isEven ? -7 : 8, y),
            4,
            Paint()..color = color,
          );
        }
      case 'gyro':
        canvas.drawCircle(Offset.zero, 19, p);
        canvas.drawOval(const Rect.fromLTWH(-34, -12, 68, 24), p);
        canvas.drawLine(const Offset(-9, 20), const Offset(9, -20), p);
      case 'capacitor':
        for (var i = 0; i < 4; i++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(-17, 17 - i * 13.0, 34, 8),
              const Radius.circular(3),
            ),
            Paint()..color = color.withValues(alpha: .4 + i * .2),
          );
        }
        canvas.drawLine(
          const Offset(-7, -42),
          const Offset(7, -42),
          p..strokeWidth = 5,
        );
      case 'safety_cell':
        canvas.drawPath(
          Path()
            ..moveTo(-15, 14)
            ..quadraticBezierTo(-24, -21, 17, -23)
            ..quadraticBezierTo(23, 16, -15, 14)
            ..close(),
          p,
        );
        canvas.drawLine(const Offset(-17, 24), const Offset(10, -14), p);
      default:
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3;
          canvas.drawCircle(Offset(math.cos(a) * 16, math.sin(a) * 16), 3, p);
        }
        canvas.drawCircle(Offset.zero, 7, p);
    }
    for (final y in [-29.0, 29.0]) {
      canvas.drawCircle(Offset(-21, y), 1.5, Paint()..color = Colors.white70);
      canvas.drawCircle(Offset(21, y), 1.5, Paint()..color = Colors.white70);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(EquipmentArt oldDelegate) => oldDelegate.id != id;
}
