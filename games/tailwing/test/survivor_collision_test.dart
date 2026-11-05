import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/game/combat_model.dart';
import 'package:raikeopeu2026/game/engine.dart';

void main() {
  test('a defeated pilot cannot destroy a charger or earn contact score', () {
    final g = BattleEngine(
      const FreeLoadout(),
      partnerLoadout: const FreeLoadout(),
    )..health = 0;
    final charger = Enemy(g.player, EnemyKind.charger)..fireClock = 3;
    g.enemies.add(charger);
    g.step(.01);
    expect(g.phase, BattlePhase.playing);
    expect(g.enemies, contains(charger));
    expect(charger.health, 24);
    expect(g.score, 0);
    expect(g.defeated, 0);
    expect(g.effects.where((e) => e.kind == EffectKind.damage), isEmpty);
    charger.position = g.partner!.player;
    g.step(.01);
    expect(g.enemies, isNot(contains(charger)));
    expect(g.partner!.health, 2);
    expect(g.score, 100);
    expect(g.defeated, 1);
  });

  test(
    'a new charger warning locks on the surviving pilot and stays locked',
    () {
      final g = BattleEngine(
        const FreeLoadout(),
        partnerLoadout: const FreeLoadout(),
      )..health = 0;
      final charger = Enemy(const Vec(180, 200), EnemyKind.charger)
        ..fireClock = 1.3;
      g.enemies.add(charger);
      g.step(.01);
      final locked = charger.lockedTarget!;
      expect(locked.dx, g.partner!.player.dx);
      expect(locked.dy, g.partner!.player.dy);
      expect(charger.aim, greaterThan(0));
      g.partner!.moveBy(const Vec(35, 0));
      g.step(.01);
      expect(identical(charger.lockedTarget, locked), true);
    },
  );

  test('sentinel laser cannot create hit reactions on a defeated pilot', () {
    final g = BattleEngine(
      const FreeLoadout(),
      partnerLoadout: const FreeLoadout(),
    )..health = 0;
    g.enemies.add(Enemy(g.player, EnemyKind.sentinel)..age = 3.3);
    g.step(.01);
    expect(g.phase, BattlePhase.playing);
    expect(g.partner!.health, 3);
    expect(g.hitReaction, false);
    expect(g.effects.where((e) => e.kind == EffectKind.damage), isEmpty);
  });
}
