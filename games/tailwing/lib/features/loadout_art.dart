import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/design.dart';
import '../game/assets.dart';
import '../game/catalog.dart';
import '../game/animal_roster.dart';
import '../core/readiness.dart';

Color catalogAccent(String id) => animalPilot(id) != null
    ? Color(animalPilot(id)!.color)
    : switch (id) {
        'vector' || 'mecha' || 'rion' => const Color(0xFFB6A1FF),
        'focus' || 'echo' || 'tuner' => const Color(0xFFFFCA85),
        'pulse' => const Color(0xFFFF92B7),
        'safeguard' || 'eden' || 'prism' => const Color(0xFF81CFFF),
        _ => Palette.teal,
      };

String catalogRole(String id) =>
    animalPilot(id)?.role ??
    switch (id) {
      'aurora' => '균형형 · 처음이라면 추천',
      'vector' => '기동형 · 빠른 이동과 사격',
      'safeguard' => '방어형 · 더 높은 장갑',
      'barrier' => '방어 · 위험한 순간을 넘기세요',
      'focus' => '연사 · 짧고 강한 화력',
      'mecha' => '변신 · 넓은 범위 공격',
      'pulse' => '위기 탈출 · 적탄 제거',
      'signature' => '캐릭터별 전용 기술 · 구독',
      'pilot' => '균형 · 기본 구성',
      'rion' => '공격 · 집중 사격',
      'eden' => '방어 · 넓은 사격',
      'standard' => '기본 자동 사격',
      'echo' => '화력 지원 · 보조 탄환',
      'prism' => '생존 지원 · 자동 보호막',
      _ => '강화 지원 · 공격과 스킬',
    };

class AircraftImage extends StatefulWidget {
  const AircraftImage({required this.id, this.decodeWidth = 512, super.key});
  final String id;
  final int decodeWidth;
  @override
  State<AircraftImage> createState() => _AircraftImageState();
}

class _AircraftImageState extends State<AircraftImage> {
  int _attempt = 0;
  @override
  Widget build(BuildContext context) {
    final pilot = context
        .getInheritedWidgetOfExactType<AppServices>()
        ?.loadout
        .pilot;
    final path =
        pilot?.aircraft ??
        BattleAssets.aircraftPaths[widget.id] ??
        BattleAssets.playerPath;
    return Image.asset(
      path,
      key: ValueKey('$path/$_attempt'),
      cacheWidth: widget.decodeWidth,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (_, error, stack) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flight, color: Palette.teal),
            const Text('이미지를 불러오지 못했습니다', textAlign: TextAlign.center),
            TextButton(
              onPressed: () => setState(() => _attempt++),
              child: const Text('이미지 다시 읽기'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Local vector backdrop: no remote images, decorative controls or fake values.
class OrbitalBackdrop extends CustomPainter {
  const OrbitalBackdrop({this.accent = Palette.teal});
  final Color accent;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final bounds = Offset.zero & size;
    final p = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF163044), Color(0xFF131D34), Color(0xFF08141E)],
      ).createShader(bounds);
    canvas.drawRect(bounds, p);
    p.shader = null;
    for (var i = 0; i < 25; i++) {
      canvas.drawCircle(
        Offset(
          (i * 113 % 401) / 401 * size.width,
          (i * 73 % 211) / 211 * size.height,
        ),
        i % 4 == 0 ? 1.1 : .6,
        p..color = Colors.white.withValues(alpha: .22),
      );
    }
    final center = Offset(size.width * .5, size.height * .54);
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final scale in [.3, .45, .62]) {
      canvas.drawCircle(
        center,
        size.shortestSide * scale,
        p..color = accent.withValues(alpha: .15),
      );
    }
    for (var x = 0.0; x < size.width; x += 36) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        p..color = accent.withValues(alpha: .045),
      );
    }
    for (var y = 0.0; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    for (final side in [-1, 1]) {
      for (var i = 0; i < 5; i++) {
        final x = size.width * .5 + side * size.width * .42;
        final y = size.height * .5 + (i - 2) * 13;
        canvas.drawLine(
          Offset(x, y),
          Offset(x + side * (i == 2 ? 12 : 5), y),
          p..color = accent.withValues(alpha: .4),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(OrbitalBackdrop oldDelegate) =>
      oldDelegate.accent != accent;
}

class CatalogArt extends StatelessWidget {
  const CatalogArt(this.entry, {this.height = 150, super.key});
  final CatalogEntry entry;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: OrbitalBackdrop(accent: catalogAccent(entry.id)),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: entry.category == CatalogCategory.aircraft
                  ? AircraftImage(id: entry.id)
                  : entry.category == CatalogCategory.character
                  ? Image.asset(
                      animalPilot(entry.id)!.portrait,
                      cacheWidth: 256,
                      fit: BoxFit.contain,
                      errorBuilder: (_, e, s) =>
                          const Center(child: Text('캐릭터 이미지 준비 오류')),
                    )
                  : entry.id == 'signature'
                  ? Image.asset(
                      AppServices.of(context).loadout.pilot.aircraft,
                      cacheWidth: 256,
                      fit: BoxFit.contain,
                    )
                  : entry.category == CatalogCategory.skill
                  ? CustomPaint(painter: SkillArt(entry.id))
                  : Icon(entry.icon, color: catalogAccent(entry.id), size: 64),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Original code-drawn skill illustrations describe only implemented abilities.
class SkillArt extends CustomPainter {
  const SkillArt(this.id);
  final String id;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 128;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    final color = catalogAccent(id);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    if (id == 'barrier') {
      canvas.drawCircle(
        Offset.zero,
        44,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: .23),
              color.withValues(alpha: .03),
            ],
          ).createShader(const Rect.fromLTWH(-44, -44, 88, 88)),
      );
      canvas.drawCircle(Offset.zero, 44, p);
      canvas.drawArc(
        const Rect.fromLTWH(-51, -51, 102, 102),
        -.9,
        2.2,
        false,
        p..strokeWidth = 3,
      );
      p.strokeWidth = 1;
      for (var row = -1; row <= 1; row++) {
        for (var col = -1; col <= 1; col++) {
          final path = Path();
          for (var i = 0; i <= 6; i++) {
            final a = i * math.pi / 3;
            final point = Offset(
              col * 22 + math.cos(a) * 12,
              row * 21 + math.sin(a) * 12,
            );
            if (i == 0) {
              path.moveTo(point.dx, point.dy);
            } else {
              path.lineTo(point.dx, point.dy);
            }
          }
          canvas.drawPath(path, p..color = color.withValues(alpha: .55));
        }
      }
      for (final side in [-1, 1]) {
        canvas.drawLine(
          Offset(side * 57, -32),
          Offset(side * 48, -21),
          p
            ..color = Colors.white
            ..strokeWidth = 3,
        );
      }
    } else if (id == 'focus') {
      for (final x in [-26.0, 0.0, 26.0]) {
        canvas.drawLine(
          Offset(x, 35),
          Offset(x, -42),
          p
            ..strokeWidth = 7
            ..color = color.withValues(alpha: .16),
        );
        canvas.drawLine(
          Offset(x, 25),
          Offset(x, -37),
          p
            ..strokeWidth = 2
            ..color = color,
        );
        canvas.drawPath(
          Path()
            ..moveTo(x - 7, -25)
            ..lineTo(x, -43)
            ..lineTo(x + 7, -25),
          p,
        );
      }
      canvas.drawArc(
        const Rect.fromLTWH(-42, 10, 84, 50),
        0,
        math.pi,
        false,
        p..strokeWidth = 3,
      );
    } else if (id == 'mecha') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-13, -40, 26, 24),
          const Radius.circular(5),
        ),
        p,
      );
      canvas.drawPath(
        Path()
          ..moveTo(-24, -10)
          ..lineTo(24, -10)
          ..lineTo(18, 24)
          ..lineTo(-18, 24)
          ..close(),
        p,
      );
      for (final side in [-1, 1]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(side * 35 - 8, -7, 16, 39),
            const Radius.circular(3),
          ),
          p,
        );
        canvas.drawLine(
          Offset(side * 12, 25),
          Offset(side * 19, 49),
          p..strokeWidth = 5,
        );
      }
      canvas.drawCircle(const Offset(0, 4), 7, Paint()..color = Palette.teal);
      canvas.drawLine(
        const Offset(-6, -28),
        const Offset(6, -28),
        p
          ..color = Palette.teal
          ..strokeWidth = 3,
      );
    } else {
      for (final r in [16.0, 30.0, 47.0]) {
        canvas.drawCircle(
          Offset.zero,
          r,
          p
            ..color = color.withValues(alpha: 1 - r / 80)
            ..strokeWidth = r == 16 ? 4 : 2,
        );
      }
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        canvas.drawLine(
          Offset(math.cos(a) * 34, math.sin(a) * 34),
          Offset(math.cos(a) * 57, math.sin(a) * 57),
          p
            ..color = color
            ..strokeWidth = 2,
        );
      }
      canvas.drawPath(
        Path()
          ..moveTo(2, -23)
          ..lineTo(-14, 6)
          ..lineTo(0, 3)
          ..lineTo(-2, 23)
          ..lineTo(15, -7)
          ..lineTo(2, -4)
          ..close(),
        Paint()..color = Colors.white,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SkillArt oldDelegate) => id != oldDelegate.id;
}
