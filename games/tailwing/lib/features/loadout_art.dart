import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/design.dart';
import '../game/assets.dart';
import '../game/catalog.dart';
import '../game/animal_roster.dart';
import '../core/readiness.dart';
import 'equipment_art.dart';

Color catalogAccent(String id) => animalPilot(id) != null
    ? Color(animalPilot(id)!.color)
    : switch (id) {
        'vector' || 'mecha' || 'rion' => const Color(0xFFB6A1FF),
        'focus' || 'echo' || 'tuner' => const Color(0xFFFFCA85),
        'pulse' => const Color(0xFFFF92B7),
        'missile_storm' => const Color(0xFFFFC78C),
        'beam' => const Color(0xFF99F7EE),
        'absorb' => const Color(0xFFB5C6FF),
        'blackhole' => const Color(0xFFC7AEFF),
        'emp' => const Color(0xFF9BE7B7),
        'chain' => const Color(0xFFF6E4A4),
        'petal_orbit' => const Color(0xFFF9B6D6),
        'aurora_sweep' => const Color(0xFF9FDFED),
        'landing_beacon' || 'safety_cell' => const Color(0xFFBAE6A4),
        'capacitor' => const Color(0xFFFFCE88),
        'gyro' => const Color(0xFFB9C5FF),
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
      'missile_storm' => '공격 · 차지·전술 정지·유도 폭격',
      'beam' => '공격 · 전방 지속 레이저',
      'absorb' => '방어 · 적탄 흡수·반격',
      'blackhole' => '제어 · 중력 견인',
      'emp' => '제어 · 범위 이동 감속',
      'chain' => '공격 · 근접 적 연결',
      'petal_orbit' => '호위 · 드론 접촉 차단',
      'aurora_sweep' => '공격 · 전방 광선 쓸기',
      'landing_beacon' => '지원 · 제한 회복·지역 방어',
      'signature' => '캐릭터별 전용 기술 · 구독',
      'pilot' => '균형 · 기본 구성',
      'rion' => '공격 · 집중 사격',
      'eden' => '방어 · 넓은 사격',
      'standard' => '기본 자동 사격',
      'echo' => '화력 지원 · 보조 탄환',
      'prism' => '생존 지원 · 자동 보호막',
      'gyro' => '정밀 지원 · 분산·유도 제어',
      'capacitor' => '공격 지원 · 명중 축전',
      'safety_cell' => '생존 지원 · 위기 반응',
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
                  : CustomPaint(painter: EquipmentArt(entry.id)),
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
    if (id == 'petal_orbit') {
      canvas.drawCircle(
        Offset.zero,
        39,
        p..color = color.withValues(alpha: .4),
      );
      for (var i = 0; i < 3; i++) {
        final a = i * math.pi * 2 / 3;
        final at = Offset(math.sin(a) * 39, math.cos(a) * 39);
        canvas.drawOval(
          Rect.fromCenter(center: at, width: 19, height: 13),
          p..color = color,
        );
        canvas.drawCircle(at, 3, Paint()..color = Colors.white);
      }
    } else if (id == 'aurora_sweep') {
      for (final side in [-1, 1]) {
        canvas.drawPath(
          Path()
            ..moveTo(0, 45)
            ..quadraticBezierTo(side * 19.0, -6, side * 48.0, -43),
          p..strokeWidth = 4,
        );
      }
      canvas.drawArc(
        const Rect.fromLTWH(-46, -60, 92, 35),
        0,
        math.pi,
        false,
        p..strokeWidth = 2,
      );
    } else if (id == 'landing_beacon') {
      canvas.drawOval(const Rect.fromLTWH(-46, 5, 92, 41), p);
      canvas.drawLine(const Offset(0, 16), const Offset(0, -35), p);
      canvas.drawCircle(const Offset(0, -23), 17, p);
      canvas.drawLine(const Offset(-7, -23), const Offset(7, -23), p);
      canvas.drawLine(const Offset(0, -30), const Offset(0, -16), p);
    } else if (id == 'missile_storm') {
      for (final x in [-27.0, 0.0, 27.0]) {
        final y = x == 0 ? -10.0 : 10.0;
        canvas.drawPath(
          Path()
            ..moveTo(x, y - 30)
            ..lineTo(x - 7, y - 9)
            ..lineTo(x - 5, y + 14)
            ..lineTo(x + 5, y + 14)
            ..lineTo(x + 7, y - 9)
            ..close(),
          p,
        );
        canvas.drawLine(Offset(x, y + 20), Offset(x - 9, y + 43), p);
      }
    } else if (id == 'beam') {
      canvas.drawLine(
        const Offset(0, 45),
        const Offset(0, -50),
        p
          ..strokeWidth = 16
          ..color = color.withValues(alpha: .18),
      );
      canvas.drawLine(
        const Offset(0, 45),
        const Offset(0, -50),
        p
          ..strokeWidth = 5
          ..color = color,
      );
      canvas.drawOval(const Rect.fromLTWH(-24, 25, 48, 20), p..strokeWidth = 2);
    } else if (id == 'absorb') {
      canvas.drawCircle(Offset.zero, 38, p);
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        canvas.drawLine(
          Offset(math.cos(a) * 56, math.sin(a) * 56),
          Offset(math.cos(a) * 28, math.sin(a) * 28),
          p,
        );
        canvas.drawCircle(Offset(math.cos(a) * 28, math.sin(a) * 28), 3, p);
      }
      canvas.drawCircle(Offset.zero, 10, p..style = PaintingStyle.fill);
    } else if (id == 'blackhole') {
      for (var i = 0; i < 4; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: 18.0 + i * 10),
          i * .9,
          math.pi * 1.5,
          false,
          p,
        );
      }
      canvas.drawCircle(Offset.zero, 8, p..style = PaintingStyle.fill);
    } else if (id == 'emp') {
      canvas.drawOval(const Rect.fromLTWH(-50, 4, 100, 40), p);
      canvas.drawOval(const Rect.fromLTWH(-34, 12, 68, 24), p);
      canvas.drawLine(const Offset(0, 24), const Offset(0, -32), p);
      for (final r in [18.0, 32.0, 45.0]) {
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(0, -26), radius: r),
          math.pi * 1.15,
          math.pi * .7,
          false,
          p,
        );
      }
    } else if (id == 'chain') {
      const points = [
        Offset(-42, 27),
        Offset(-18, -23),
        Offset(20, 19),
        Offset(42, -31),
      ];
      for (var i = 0; i < points.length; i++) {
        canvas.drawCircle(points[i], 9, p);
        if (i > 0) canvas.drawLine(points[i - 1], points[i], p);
      }
    } else if (id == 'barrier') {
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
