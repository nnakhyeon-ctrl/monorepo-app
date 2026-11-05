import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/game/engine.dart';
import 'package:raikeopeu2026/game/combat_model.dart';
import 'package:raikeopeu2026/coop/protocol.dart';

import 'expanded_combat_test.dart' show subscribed;

void main() {
  test(
    'instant pulse win clears ongoing shield without another frame',
    () async {
      final c = await subscribed('pulse');
      final g = BattleEngine(c, partnerLoadout: const FreeLoadout());
      g.activateBasicShield();
      g.partner!.activateBasicShield();
      g.enemies.add(Enemy(const Vec(180, 85), EnemyKind.boss)..health = 20);
      expect(g.activateSkill(), true);
      expect(g.phase, BattlePhase.won);
      expect(g.shieldRemaining, 0);
      expect(g.cooldown, 0);
      expect(g.partner!.shieldRemaining, 0);
      expect(g.partner!.cooldown, 0);
      c.dispose();
    },
  );
  test('hostile guided round follows the surviving co-op pilot', () {
    final g = BattleEngine(
      const FreeLoadout(),
      partnerLoadout: const FreeLoadout(),
    )..health = 0;
    final b = g.projectilePool.acquire(
      const Vec(180, 300),
      const Vec(0, 85),
      homing: true,
    );
    g.bullets.add(b);
    g.step(.02);
    expect(g.partner!.health, 3);
    expect(b.velocity.dx, greaterThan(0));
  });
  test('escaped charger is removed before it can corrupt a co-op snapshot', () {
    final g = BattleEngine(
      const FreeLoadout(),
      partnerLoadout: const FreeLoadout(),
    );
    final e = Enemy(const Vec(-59, 200), EnemyKind.charger)
      ..fireClock = 3
      ..aim = -math.pi / 2;
    g.enemies.add(e);
    for (var i = 0; i < 6; i++) {
      g.step(.05);
    }
    expect(g.enemies.contains(e), false);
    expect(() => readSnapshot(battleSnapshot(g, 1)), returnsNormally);
  });
}
