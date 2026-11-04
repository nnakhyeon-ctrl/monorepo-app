import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/design.dart';
import 'assets.dart';
import 'combat_model.dart';
import 'engine.dart';
import 'deck_status.dart';

extension _CanvasVec on Vec {
  Offset get offset => Offset(dx, dy);
}

/// Texture layers move at different speeds, always behind combat information.
class SkyPainter extends CustomPainter {
  const SkyPainter(
    this.time, {
    this.biome = 0,
    this.assets,
    this.coastal = false,
  });
  final double time;
  final int biome;
  final bool coastal;
  final BattleAssets? assets;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final p = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const [
            Color(0xFF163847),
            Color(0xFF243A32),
            Color(0xFF343749),
            Color(0xFF163549),
            Color(0xFF3B303E),
          ][biome % 5],
          Palette.navy,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, p);
    p.shader = null;
    final coast = assets?.coast;
    if (coast != null) {
      final h = size.width * coast.height / coast.width;
      final scroll = time * 14 % (h * 2);
      // Alternating mirrored tiles share exactly the same edge at each join.
      for (var i = -2; i <= (size.height / h).ceil(); i++) {
        canvas.save();
        canvas.translate(0, i * h + scroll);
        if (i.isOdd) {
          canvas.translate(0, h);
          canvas.scale(1, -1);
        }
        canvas.drawImageRect(
          coast,
          _source(coast),
          Rect.fromLTWH(0, 0, size.width, h),
          p
            ..color = Colors.white
            ..filterQuality = FilterQuality.medium,
        );
        canvas.restore();
      }
      canvas.drawRect(Offset.zero & size, p..color = const Color(0x3B09131E));
      if (biome != 0) {
        canvas.drawRect(
          Offset.zero & size,
          p
            ..color = [
              const Color(0x00133447),
              const Color(0x18399982),
              const Color(0x188E7CCC),
              const Color(0x1868B5D9),
              const Color(0x18D38CAB),
            ][biome % 5],
        );
      }
    }
    final cloud = assets?.cloud;
    if (cloud != null) {
      for (var i = 0; i < 4; i++) {
        final span = size.width * (i.isEven ? .85 : 1.15);
        final x = i.isEven ? size.width * .04 : size.width * .86;
        final y =
            (i * 211 + time * (i.isEven ? 21 : 32)) % (size.height + span) -
            span * .5;
        canvas.drawImageRect(
          cloud,
          _source(cloud),
          Rect.fromCenter(center: Offset(x, y), width: span, height: span),
          p..color = Colors.white.withValues(alpha: i.isEven ? .20 : .12),
        );
      }
    }
    p.shader = const RadialGradient(
      radius: .9,
      colors: [Colors.transparent, Color(0x65040C15)],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(SkyPainter oldDelegate) =>
      time != oldDelegate.time ||
      biome != oldDelegate.biome ||
      assets != oldDelegate.assets ||
      coastal != oldDelegate.coastal;
}

Rect _source(ui.Image image) =>
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());

/// Art stays centered on simulation coordinates. Rendering never changes input,
/// collision, random state or rewards.
class BattlePainter extends CustomPainter {
  const BattlePainter(
    this.game,
    this.playerImage, {
    this.assets,
    this.reduceEffects = false,
    super.repaint,
  });
  final BattleEngine game;
  final bool reduceEffects;
  final ui.Image? playerImage;
  final BattleAssets? assets;
  static Rect playerBounds(Vec position) =>
      Rect.fromCenter(center: position.offset, width: 74, height: 74);
  static Rect enemyBounds(Enemy enemy) => Rect.fromCenter(
    center: enemy.position.offset,
    width: (enemy.radius + 4) * 2,
    height: (enemy.radius + 4) * 2,
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(
      size.width / BattleEngine.width,
      size.height / BattleEngine.height,
    );
    const world = Size(BattleEngine.width, BattleEngine.height);
    SkyPainter(
      game.elapsed,
      biome: game.stage.biome,
      assets: assets,
      coastal: game.stage.number == 1,
    ).paint(canvas, world);
    _effects(canvas);
    _animalEffects(canvas);
    for (final enemy in game.enemies) {
      _enemy(canvas, enemy);
    }
    final second = game.partner;
    if (second != null && second.health > 0) {
      _player(canvas, second, partner: true);
    }
    if (game.health > 0) _player(canvas, game);
    // Dangerous projectiles and player centers are above all VFX.
    for (final bullet in game.bullets) {
      _projectile(canvas, bullet);
    }
    if (game.health > 0) _hitCenter(canvas, game.player);
    if (second != null && second.health > 0) _hitCenter(canvas, second.player);
    canvas.restore();
  }

  void _animalEffects(Canvas canvas) {
    final g = game, a = g.animal, b = g.pilot.balance;
    final p = Paint()
      ..color = Color(g.pilot.color)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final at = g.player.offset;
    for (final link in a.links) {
      canvas.drawLine(link.$1.offset, link.$2.offset, p);
      canvas.drawCircle(link.$2.offset, 5, p);
    }
    for (final seed in a.beacons) {
      canvas.drawOval(
        Rect.fromCenter(center: seed.position.offset, width: 15, height: 22),
        p,
      );
      canvas.drawCircle(
        seed.position.offset,
        b.range,
        p..color = Color(g.pilot.color).withValues(alpha: .25),
      );
      p.color = Color(g.pilot.color);
    }
    if (!g.animalActive) return;
    switch (g.character) {
      case 'pilot':
        for (var i = 0; i < a.stitch.length; i++) {
          canvas.drawCircle(a.stitch[i].offset, 5, p);
          if (i > 0) {
            canvas.drawLine(a.stitch[i - 1].offset, a.stitch[i].offset, p);
          }
        }
      case 'rion':
        for (final side in [-1, 1]) {
          canvas.save();
          canvas.translate(at.dx + side * 16, at.dy - 32);
          canvas.rotate(side * .35);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-8, -7, 16, 14),
              const Radius.circular(3),
            ),
            p,
          );
          canvas.restore();
        }
      case 'tw_bear':
        canvas.drawArc(
          Rect.fromCircle(center: at, radius: b.radius),
          math.pi,
          math.pi,
          false,
          p,
        );
        for (var i = 0; i < a.captured.length; i++) {
          canvas.drawCircle(
            at +
                Offset(
                  math.cos(i * 1.04 + g.elapsed) * 29,
                  math.sin(i * 1.04 + g.elapsed) * 29,
                ),
            3,
            p,
          );
        }
      case 'eden':
        final deck = DeckStatus.read(g)!;
        if (!deck.blocking) break;
        final rect = Rect.fromLTWH(
          at.dx - b.width / 2,
          at.dy - b.range,
          b.width,
          b.range - b.minimumRange,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(8)),
          p
            ..color = Palette.teal.withValues(alpha: .18)
            ..style = PaintingStyle.fill,
        );
        final outline = RRect.fromRectAndRadius(rect, const Radius.circular(8));
        canvas.drawRRect(
          outline,
          p
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..color = Palette.navy,
        );
        canvas.drawRRect(
          outline,
          p
            ..strokeWidth = deck.phase == DeckPhase.deploying ? 2.4 : 1.6
            ..color = deck.seconds < .5
                ? const Color(0xFFFFD08C)
                : Palette.teal,
        );
        for (var i = 0; i < a.durability; i++) {
          canvas.drawCircle(
            rect.topLeft + Offset(8 + i * 12, 6),
            2,
            p..style = PaintingStyle.fill,
          );
        }
      case 'tw_owl':
        if (a.target case final target?) {
          final center = target.position.offset;
          canvas.drawCircle(center, target.radius + 8, p);
          for (var i = 0; i < 4; i++) {
            final angle = i * math.pi / 2;
            final v = Offset(math.cos(angle), math.sin(angle));
            canvas.drawLine(
              center + v * (target.radius + 3),
              center + v * (target.radius + 12),
              p,
            );
          }
        }
      case 'tw_hedgehog':
        canvas.drawCircle(
          at,
          b.radius,
          p..color = Color(g.pilot.color).withValues(alpha: .25),
        );
        p.color = Color(g.pilot.color);
        for (var i = 0; i < 6; i++) {
          final angle = i * math.pi / 3 + g.elapsed * 4;
          final pos = at + Offset(math.cos(angle), math.sin(angle)) * b.radius;
          canvas.drawPath(
            Path()
              ..moveTo(pos.dx, pos.dy - 5)
              ..lineTo(pos.dx + 4, pos.dy + 4)
              ..lineTo(pos.dx - 4, pos.dy + 4)
              ..close(),
            p,
          );
        }
      case 'tw_penguin':
        final rect = Rect.fromLTWH(
          at.dx - b.width / 2,
          at.dy - b.range,
          b.width,
          b.range,
        );
        canvas.drawRect(
          rect,
          p
            ..color = Color(g.pilot.color).withValues(alpha: .12)
            ..style = PaintingStyle.fill,
        );
        p
          ..style = PaintingStyle.stroke
          ..color = Color(g.pilot.color).withValues(alpha: .6);
        for (var i = 1; i < 5; i++) {
          canvas.drawLine(
            rect.bottomLeft + Offset(0, -i * 38),
            rect.bottomRight + Offset(0, -i * 38),
            p,
          );
        }
      case 'tw_chameleon':
        if (a.anchor case final anchor?) {
          canvas.drawOval(
            Rect.fromCenter(center: anchor.offset, width: 40, height: 25),
            p,
          );
          canvas.drawCircle(anchor.offset, 8, p);
        }
      case 'tw_eagle':
        if (a.anchor case final anchor?) {
          canvas.drawLine(
            anchor.offset + Offset(-b.width / 2, -25),
            anchor.offset + Offset(-b.width / 2, -180),
            p,
          );
          canvas.drawLine(
            anchor.offset + Offset(b.width / 2, -25),
            anchor.offset + Offset(b.width / 2, -180),
            p,
          );
        }
      case 'tw_volt':
        canvas.drawArc(
          Rect.fromCircle(center: at, radius: b.radius),
          g.elapsed * 2,
          math.pi,
          p.style == PaintingStyle.fill,
          p,
        );
    }
  }

  void _enemy(Canvas canvas, Enemy e) {
    final p = Paint()..filterQuality = FilterQuality.medium;
    final image = assets?.enemies;
    if (image != null) {
      final cell = Size(image.width / 2, image.height / 2);
      final source = Rect.fromLTWH(
        e.kind.index % 2 * cell.width,
        e.kind.index ~/ 2 * cell.height,
        cell.width,
        cell.height,
      );
      final bounds = enemyBounds(e);
      canvas.drawImageRect(
        image,
        source,
        bounds.shift(const Offset(4, 7)),
        p
          ..color = const Color(0x55000000)
          ..colorFilter = const ColorFilter.mode(Colors.black, BlendMode.srcIn),
      );
      canvas.drawImageRect(
        image,
        source,
        bounds,
        p
          ..color = Colors.white
          ..colorFilter = null,
      );
    }
    final max = e.kind == EnemyKind.boss ? game.stage.bossHealth : e.maxHealth;
    final r = e.radius;
    if (e.slowRemaining > 0) {
      canvas.drawCircle(
        e.position.offset,
        r + 4,
        Paint()
          ..color = const Color(0xFF9CE2F2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    final rail = Rect.fromLTWH(
      e.position.dx - r,
      e.position.dy - r - 8,
      r * 2,
      3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rail, const Radius.circular(2)),
      p..color = const Color(0xD909131E),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rail.left,
          rail.top,
          rail.width * (e.health / max).clamp(0, 1),
          rail.height,
        ),
        const Radius.circular(2),
      ),
      p..color = const Color(0xFFFFA380),
    );
    if (e.kind == EnemyKind.boss) {
      for (
        var i = -game.stage.bossPattern - 1;
        i <= game.stage.bossPattern + 1;
        i++
      ) {
        canvas.drawCircle(
          e.position.offset + Offset(i * 9, 7),
          1.5,
          p..color = const Color(0xFFFFC78C),
        );
      }
    }
    if (e.telegraph) {
      p
        ..color = const Color(0xC8FFD38D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3;
      canvas.drawArc(
        Rect.fromCircle(center: e.position.offset, radius: r + 5),
        game.elapsed * 2,
        math.pi * 1.5,
        false,
        p,
      );
      final direction = Offset(math.sin(e.aim), math.cos(e.aim));
      for (var d = r + 12.0; d < 110; d += 11) {
        canvas.drawLine(
          e.position.offset + direction * d,
          e.position.offset + direction * (d + 5),
          p,
        );
      }
    }
  }

  void _projectile(Canvas canvas, Projectile b) {
    final p = Paint();
    final at = b.position.offset;
    if (b.friendly) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(at.dx - 3, at.dy - 6, 6, 21),
          const Radius.circular(3),
        ),
        p..color = const Color(0xB3092738),
      );
      if (b.precision) {
        canvas.drawOval(
          Rect.fromCenter(center: at, width: 6, height: 12),
          p..color = const Color(0xFFD3BAFF),
        );
      }
      final tail = at + const Offset(0, 14);
      p.shader =
          const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDBFFFF), Color(0xAA54EBDC), Color(0x0054EBDC)],
          ).createShader(
            Rect.fromPoints(at - const Offset(3, 3), tail + const Offset(3, 0)),
          );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(at.dx - 2, at.dy - 5, 4, 19),
          const Radius.circular(2),
        ),
        p,
      );
      p
        ..shader = null
        ..color = const Color(0xFFF0FFFF)
        ..strokeWidth = 1.2;
      canvas.drawLine(at - const Offset(0, 4), at + const Offset(0, 5), p);
    } else {
      // Direction tail is visual only; the collision radius stays unchanged.
      final speed = b.velocity.distance;
      if (speed > .001) {
        final back = at - b.velocity.offset / speed * 11;
        canvas.drawLine(
          back,
          at,
          p
            ..color = const Color(0xFF27151D)
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          back,
          at,
          p
            ..color = const Color(0xFFFFAD72)
            ..strokeWidth = 2,
        );
      }
      canvas.drawCircle(at, 6, p..color = const Color(0xFF2A1116));
      canvas.drawCircle(at, 4.8, p..color = const Color(0xFFFF8955));
      canvas.drawCircle(at, 2.4, p..color = const Color(0xFFFFE9AF));
      canvas.drawCircle(
        at,
        5.2,
        p
          ..color = const Color(0xFFFFBE83)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7,
      );
    }
  }

  void _player(Canvas canvas, BattleEngine g, {bool partner = false}) {
    canvas.save();
    canvas.translate(g.player.dx, g.player.dy);
    if (g.hitReaction) canvas.rotate(math.sin(g.elapsed * 35) * .05);
    if (g.animalActive && !reduceEffects) {
      canvas.scale(1 + math.sin(g.elapsed * 9) * .015);
    }
    final p = Paint()..filterQuality = FilterQuality.medium;
    final image =
        assets?.pilotImageFor(g.character) ??
        assets?.imageFor(g.aircraft) ??
        playerImage;
    if (g.robotMode) {
      _mecha(canvas);
    } else if (image != null) {
      final box = playerBounds(Vec.zero);
      final fitted = applyBoxFit(
        BoxFit.contain,
        Size(image.width.toDouble(), image.height.toDouble()),
        box.size,
      ).destination;
      final bounds = Rect.fromCenter(
        center: box.center,
        width: fitted.width,
        height: fitted.height,
      );
      canvas.drawImageRect(
        image,
        _source(image),
        bounds.shift(const Offset(3, 6)),
        p
          ..color = const Color(0x40000000)
          ..colorFilter = const ColorFilter.mode(Colors.black, BlendMode.srcIn),
      );
      canvas.drawImageRect(
        image,
        _source(image),
        bounds,
        p
          ..color = Colors.white
          ..colorFilter = partner
              ? const ColorFilter.mode(Color(0xFFFFD69C), BlendMode.modulate)
              : null,
      );
      p.colorFilter = null;
      if (g.aircraft == 'aurora' &&
          assets?.pilotImageFor(g.character) == null) {
        for (final side in [-1, 1]) {
          p
            ..color = Colors.white.withValues(alpha: .14)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .7;
          canvas.drawArc(
            Rect.fromCenter(
              center: Offset(side * 14, -22),
              width: 18,
              height: 3.4,
            ),
            g.elapsed * 35,
            math.pi * 1.4,
            false,
            p,
          );
        }
      } else {
        final length = 7 + math.sin(g.elapsed * 35) * 2;
        for (final side in [-1, 1]) {
          final path = Path()
            ..moveTo(side * 8 - 2, 26)
            ..lineTo(side * 8, 26 + length)
            ..lineTo(side * 8 + 2, 26)
            ..close();
          canvas.drawPath(
            path,
            p
              ..style = PaintingStyle.fill
              ..color = const Color(0x9966E2D3),
          );
        }
      }
    }
    if (g.aircraft == 'vector') {
      for (final side in [-1, 1]) {
        canvas.drawPath(
          Path()
            ..moveTo(side * 28, 14)
            ..lineTo(side * 33, 23)
            ..lineTo(side * 24, 23),
          p
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFFCAA9FF),
        );
      }
    } else if (g.aircraft == 'safeguard') {
      for (final side in [-1, 1]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(side * 29, 2), width: 7, height: 17),
            const Radius.circular(3),
          ),
          p
            ..style = PaintingStyle.fill
            ..color = const Color(0xFF8BB9D1),
        );
      }
    }
    if (g.protected) {
      p
        ..style = PaintingStyle.fill
        ..shader = const RadialGradient(
          colors: [Color(0x0066E2D3), Color(0x0066E2D3), Color(0x5066E2D3)],
          stops: [0, .65, 1],
        ).createShader(const Rect.fromLTWH(-35, -35, 70, 70));
      canvas.drawCircle(Offset.zero, 35, p);
      p
        ..shader = null
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Palette.teal;
      canvas.drawCircle(Offset.zero, 35, p);
      for (var i = 0; i < 6; i++) {
        canvas.drawArc(
          const Rect.fromLTWH(-32, -32, 64, 64),
          i * math.pi / 3 + g.elapsed,
          .45,
          false,
          p,
        );
      }
    }
    if (g.character == 'rion') {
      canvas.drawArc(
        const Rect.fromLTWH(-30, -30, 60, 60),
        math.pi,
        math.pi,
        false,
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFFFC078),
      );
    }
    if (g.repairNotice > 0) {
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Palette.teal;
      final repair = Path()
        ..moveTo(31, -29)
        ..lineTo(38, -22)
        ..lineTo(31, -15)
        ..lineTo(24, -22)
        ..close();
      canvas.drawPath(repair, p);
      canvas.drawLine(const Offset(28, -22), const Offset(34, -22), p);
      canvas.drawLine(const Offset(31, -25), const Offset(31, -19), p);
    }
    canvas.restore();
  }

  void _hitCenter(Canvas canvas, Vec at) {
    final p = Paint()..color = const Color(0xDD09131E);
    canvas.drawCircle(at.offset, 5, p);
    canvas.drawCircle(at.offset, 3, p..color = Colors.white);
    canvas.drawCircle(
      at.offset,
      10,
      p
        ..color = const Color(0x997FE3D6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6,
    );
  }

  void _mecha(Canvas canvas) {
    final p = Paint();
    for (final bounds in [
      const Rect.fromLTWH(-12, -23, 24, 38),
      for (final side in [-1, 1]) ...[
        Rect.fromLTWH(side * 24 - 7, -14, 14, 31),
        Rect.fromLTWH(side * 10 - 5, 16, 10, 20),
      ],
    ]) {
      final frame = RRect.fromRectAndRadius(bounds, const Radius.circular(3));
      p
        ..style = PaintingStyle.fill
        ..shader = const LinearGradient(
          colors: [Color(0xFFE2EDF1), Color(0xFF637785), Color(0xFF273947)],
          stops: [0, .38, 1],
        ).createShader(bounds);
      canvas.drawRRect(frame, p);
      canvas.drawRRect(
        frame,
        p
          ..shader = null
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = const Color(0xFFBCD0D9),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-8, -20, 16, 8),
        const Radius.circular(2),
      ),
      p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF66E2D3),
    );
    canvas.drawCircle(const Offset(0, -3), 4, p..color = Palette.teal);
  }

  void _effects(Canvas canvas) {
    final p = Paint()..filterQuality = FilterQuality.medium;
    for (final effect in game.effects) {
      final t = effect.progress, at = effect.position.offset;
      p
        ..shader = null
        ..style = PaintingStyle.fill
        ..color = Colors.white;
      if (effect.kind == EffectKind.explosion) {
        // Production vector VFX: timed bubble/star impact, always below hazards.
        final radius = effect.size * (.12 + t * .38),
            fade = (1 - t).clamp(0.0, 1.0);
        canvas.drawCircle(
          at,
          radius,
          p
            ..color = const Color(0xFFFFAA96).withValues(alpha: fade * .8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 * (1 - t) + .5,
        );
        for (var i = 0; i < (reduceEffects ? 2 : 6); i++) {
          final angle = i * math.pi / 3,
              spot =
                  at + Offset(math.cos(angle), math.sin(angle)) * radius * .75;
          canvas.drawCircle(
            spot,
            3 + 7 * fade,
            p
              ..color =
                  (i.isEven ? const Color(0xFFB7F4EF) : const Color(0xFFE2D5FF))
                      .withValues(alpha: fade * .65)
              ..style = PaintingStyle.fill,
          );
        }
        final star = Path();
        for (var i = 0; i < 8; i++) {
          final angle = i * math.pi / 4,
              r = i.isEven ? radius * .65 : radius * .18;
          final point = at + Offset(math.cos(angle), math.sin(angle)) * r;
          if (i == 0) {
            star.moveTo(point.dx, point.dy);
          } else {
            star.lineTo(point.dx, point.dy);
          }
        }
        canvas.drawPath(
          star..close(),
          p..color = const Color(0xFFFFF3CD).withValues(alpha: fade),
        );
      } else if (effect.kind == EffectKind.pulse ||
          effect.kind == EffectKind.skill ||
          effect.kind == EffectKind.shieldHit ||
          effect.kind == EffectKind.damage) {
        final color = effect.kind == EffectKind.damage
            ? const Color(0xFFFF936B)
            : Palette.teal;
        final radius = effect.kind == EffectKind.shieldHit
            ? effect.size
            : 8 + effect.size * t;
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = (1 - t) * 2 + .5
          ..color = color.withValues(alpha: (1 - t) * .8);
        canvas.drawCircle(at, radius, p);
        if (!reduceEffects && effect.kind == EffectKind.skill) {
          // A brief authored hologram burst, below bullets and hit centers.
          final accent = game.skill == 'signature'
              ? Color(game.pilot.color)
              : Palette.teal;
          for (var i = 0; i < 6; i++) {
            final angle = i * math.pi / 3 + t * .6;
            final direction = Offset(math.cos(angle), math.sin(angle));
            canvas.drawLine(
              at + direction * radius * .7,
              at + direction * (radius + 6 * (1 - t)),
              p
                ..color = accent.withValues(alpha: (1 - t) * .8)
                ..strokeWidth = 2,
            );
          }
          canvas.drawArc(
            Rect.fromCircle(center: at, radius: radius * .66),
            t * 2,
            math.pi * 1.2,
            false,
            p
              ..color = const Color(0xFFD8C8FF).withValues(alpha: (1 - t) * .7)
              ..strokeWidth = 1.2,
          );
        }
        if (effect.kind == EffectKind.pulse) {
          canvas.drawCircle(
            at,
            radius * .86,
            p..color = color.withValues(alpha: (1 - t) * .3),
          );
        }
      } else {
        final color = effect.kind == EffectKind.muzzle
            ? Palette.teal
            : const Color(0xFFFFCC87);
        final radius = effect.size * (.3 + t * .7);
        p.shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 1 - t),
            color.withValues(alpha: (1 - t) * .5),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: at, radius: radius));
        canvas.drawCircle(at, radius, p);
        p
          ..shader = null
          ..color = color.withValues(alpha: 1 - t)
          ..strokeWidth = 1;
        for (var i = 0; i < 4; i++) {
          final a = i * math.pi / 2 + .4;
          final direction = Offset(math.sin(a), math.cos(a));
          canvas.drawLine(
            at + direction * radius * .4,
            at + direction * radius,
            p,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(BattlePainter oldDelegate) => true;
}
