import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/game/animal_roster.dart';
import 'package:raikeopeu2026/game/combat_model.dart';
import 'package:raikeopeu2026/game/engine.dart';

// Synthetic selections only: never used by normal or release code.
class LifecycleLoadout implements CombatLoadout {
  LifecycleLoadout(this.id);
  String id;
  @override
  String selected(CatalogCategory c) => switch (c) {
    CatalogCategory.character => id,
    CatalogCategory.skill => 'signature',
    _ => const FreeLoadout().selected(c),
  };
  @override
  bool sanitize() => false;
}

void advance(BattleEngine g, double seconds) {
  for (var i = 0; i < (seconds / .01).ceil(); i++) {
    g.step(.01);
  }
}

void expectNoTechnique(BattleEngine g) {
  expect(g.animal.active, false);
  expect(g.animal.beacons, isEmpty);
  expect(g.animal.history, isEmpty);
  expect(g.animal.stitch, isEmpty);
  expect(g.animal.links, isEmpty);
  expect(g.animal.captured, isEmpty);
  expect(g.animal.disrupted, isEmpty);
  expect(g.animal.anchor, isNull);
  expect(g.animal.target, isNull);
  expect(g.animal.durability, 0);
  expect(g.skillRemaining, 0);
  expect(
    g.enemies.every((e) => e.slowRemaining == 0 && e.slowImmunity == 0),
    true,
  );
}

void main() {
  for (final p in animalPilots) {
    test(
      '${p.id}: defeat clears technique; retry has no inherited effects',
      () {
        final loadout = LifecycleLoadout(p.id);
        final g = BattleEngine(loadout)..activateSkill();
        g.enemies.add(
          Enemy(const Vec(60, 100), EnemyKind.armored)
            ..slowRemaining = 2
            ..slowImmunity = 1,
        );
        g.health = 1;
        g.bullets.add(Projectile(g.player, Vec.zero, collectible: false));
        g.step(.01);
        expect(g.phase, BattlePhase.lost);
        expectNoTechnique(g);
        final retry = BattleEngine(loadout);
        expectNoTechnique(retry);
        expect(retry.elapsed, 0);
        expect(retry.cooldown, 0);
        expect(retry.health, retry.maxHealth);
        expect(retry.activateSkill(), true);
      },
    );
  }

  test('victory clears a live seed and slow state without changing score', () {
    final g = BattleEngine(LifecycleLoadout('tw_squirrel'))..activateSkill();
    expect(g.animal.beacons, hasLength(1));
    g.enemies.addAll([
      Enemy(const Vec(60, 100), EnemyKind.armored)..slowRemaining = 1,
      Enemy(const Vec(180, 80), EnemyKind.boss)..health = 0,
    ]);
    g.step(.01);
    expect(g.phase, BattlePhase.won);
    expect(g.score, 1000);
    expectNoTechnique(g);
    expect(g.activateSkill(), false);
  });

  test(
    'timeout cancels collected rounds instead of releasing a late counter',
    () {
      final g = BattleEngine(LifecycleLoadout('tw_bear'));
      g.elapsed = g.stage.timeLimit - .02;
      g.activateSkill();
      g.animal.captured.add(Projectile(g.player, Vec.zero));
      g.step(.03);
      expect(g.phase, BattlePhase.lost);
      expectNoTechnique(g);
      expect(g.bullets.where((b) => b.precision), isEmpty);
    },
  );

  test('switching while paused clears old pilot effects on resume', () {
    for (final p in animalPilots) {
      final loadout = LifecycleLoadout(p.id);
      final g = BattleEngine(loadout)..activateSkill();
      g.enemies.add(
        Enemy(const Vec(60, 100), EnemyKind.armored)
          ..slowRemaining = 2
          ..slowImmunity = 1,
      );
      g.pause();
      loadout.id = p.id == 'pilot' ? 'rion' : 'pilot';
      g.resume();
      expectNoTechnique(g);
      expect(g.character, loadout.id);
      expect(g.phase, BattlePhase.playing);
    }
  });

  test(
    'expired deck has no durability and expired decoy cannot redirect new aim',
    () {
      final deck = BattleEngine(LifecycleLoadout('eden'))..activateSkill();
      advance(deck, 3.1);
      expect(deck.animal.durability, 0);
      final frog = BattleEngine(LifecycleLoadout('tw_chameleon'))
        ..activateSkill();
      frog.moveBy(const Vec(90, 0));
      advance(frog, 3.1);
      final e = Enemy(const Vec(180, 200), EnemyKind.armored)..fireClock = 2;
      frog.enemies.add(e);
      frog.step(.01);
      expect(frog.animal.anchor, isNull);
      expect(e.aim, greaterThan(.1));
    },
  );

  test('pause freezes skill lifetime; resuming expires a seed once', () {
    final g = BattleEngine(LifecycleLoadout('tw_squirrel'))..activateSkill();
    g.pause();
    advance(g, 30);
    expect(g.elapsed, 0);
    expect(g.animal.beacons, hasLength(1));
    g.resume();
    advance(g, 6.1);
    expect(g.animal.beacons, isEmpty);
    expect(g.animalActive, false);
  });
}
