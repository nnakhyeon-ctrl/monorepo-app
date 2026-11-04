import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/design.dart';

/// Original vector artwork; no screenshots or game sprites are embedded.
class AircraftArt extends StatelessWidget {
  const AircraftArt({this.variant = 0, super.key});
  final int variant;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      painter: AircraftPainter(variant),
      size: const Size(240, 170),
    ),
  );
}

class AircraftPainter extends CustomPainter {
  const AircraftPainter(this.variant);
  final int variant;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    final scale = math.min(size.width / 240, size.height / 170);
    canvas.scale(scale);
    final accent = variant == 1 ? const Color(0xFFFFC078) : Palette.teal;
    final paint = Paint();
    canvas.drawOval(
      const Rect.fromLTWH(-87, -45, 174, 115),
      paint..color = accent.withValues(alpha: .06),
    );
    final wing = Path()
      ..moveTo(0, -49)
      ..lineTo(variant == 2 ? 102 : 88, 27)
      ..lineTo(81, 43)
      ..lineTo(19, 17)
      ..lineTo(11, 65)
      ..lineTo(-11, 65)
      ..lineTo(-19, 17)
      ..lineTo(-81, 43)
      ..lineTo(variant == 2 ? -102 : -88, 27)
      ..close();
    canvas.drawPath(wing, paint..color = const Color(0xFF718893));
    canvas.drawPath(
      wing,
      paint
        ..color = accent.withValues(alpha: .6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    paint.style = PaintingStyle.fill;
    for (final x in [-42.0, 42.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 9, -41, 18, 105),
          const Radius.circular(9),
        ),
        paint..color = const Color(0xFFB0C4CC),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 5, 55, 10, 19),
          const Radius.circular(5),
        ),
        paint..color = accent,
      );
      canvas.drawLine(
        Offset(x - 21, -26),
        Offset(x + 21, -26),
        paint
          ..color = accent
          ..strokeWidth = 3,
      );
    }
    final body = Path()
      ..moveTo(0, -73)
      ..quadraticBezierTo(24, -30, 13, 45)
      ..lineTo(0, 61)
      ..lineTo(-13, 45)
      ..quadraticBezierTo(-24, -30, 0, -73)
      ..close();
    canvas.drawPath(body, paint..color = const Color(0xFFDCE9EB));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-7, -35, 14, 32),
        const Radius.circular(7),
      ),
      paint..color = const Color(0xFF163342),
    );
    canvas.drawLine(
      const Offset(0, 6),
      const Offset(0, 43),
      paint
        ..color = accent
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(AircraftPainter oldDelegate) =>
      oldDelegate.variant != variant;
}

class BattleConceptPainter extends CustomPainter {
  const BattleConceptPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Paint();
    canvas.drawRect(
      Offset.zero & size,
      p
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF152F3C), Color(0xFF09131E)],
        ).createShader(Offset.zero & size),
    );
    p.shader = null;
    for (var i = 0; i < 7; i++) {
      final x = (i * 79 % 240) / 240 * w;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, h * (i + 1) / 8),
          width: w * .8,
          height: h * .12,
        ),
        p..color = Colors.white.withValues(alpha: .025),
      );
    }
    for (var i = 1; i < 5; i++) {
      canvas.drawLine(
        Offset(w * i / 5, 0),
        Offset(w * i / 5, h),
        p
          ..color = Palette.teal.withValues(alpha: .045)
          ..strokeWidth = 1,
      );
    }
    // A new angular sky fortress, independent of the reference boss silhouette.
    final boss = Path()
      ..moveTo(w * .5, h * .24)
      ..lineTo(w * .78, h * .31)
      ..lineTo(w * .87, h * .40)
      ..lineTo(w * .66, h * .36)
      ..lineTo(w * .5, h * .45)
      ..lineTo(w * .34, h * .36)
      ..lineTo(w * .13, h * .40)
      ..lineTo(w * .22, h * .31)
      ..close();
    canvas.drawPath(boss, p..color = const Color(0xFF516C78));
    canvas.drawPath(
      boss,
      p
        ..color = const Color(0xFF9DAFB6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    p.style = PaintingStyle.fill;
    for (final x in [.32, .68]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(w * x, h * .35),
            width: w * .08,
            height: h * .05,
          ),
          const Radius.circular(6),
        ),
        p..color = const Color(0xFFFF9C7D),
      );
      for (var i = 0; i < 7; i++) {
        final t = i / 6;
        final point = Offset(
          w * x + math.sin((t - .5) * 2.3) * w * .26,
          h * .40 + math.cos((t - .5) * 2.3) * h * .16,
        );
        canvas.drawCircle(point, 5, p..color = const Color(0xFFFFAE82));
        canvas.drawCircle(point, 2, p..color = const Color(0xFFFFE4BD));
      }
    }
    // Dashed warning lane: a different shape as well as a different color.
    for (var i = 0; i < 9; i++) {
      final y = h * (.4 + i * .038);
      canvas.drawLine(
        Offset(w * .77, y),
        Offset(w * .77, y + h * .018),
        p
          ..color = const Color(0xFFFFB583).withValues(alpha: .65)
          ..strokeWidth = 2,
      );
    }
    for (var row = 0; row < 7; row++) {
      final y = h * (.43 + row * .052);
      for (final side in [-1, 1]) {
        final x = w * .5 + side * w * (.035 + row * .007);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 2.5, y, 5, h * .022),
            const Radius.circular(3),
          ),
          p..color = Palette.teal,
        );
      }
    }
    canvas.save();
    canvas.translate(w * .5 - 60, h * .75);
    const AircraftPainter(0).paint(canvas, const Size(120, 85));
    canvas.restore();
    canvas.drawCircle(
      Offset(w * .5, h * .75 + 42.5),
      4,
      p..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(w * .5, h * .75 + 42.5),
      8,
      p
        ..color = Palette.teal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(BattleConceptPainter oldDelegate) => false;
}
