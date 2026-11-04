import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/game/animal_roster.dart';
import 'package:raikeopeu2026/game/combat_model.dart';
import 'package:raikeopeu2026/game/engine.dart';
import 'package:raikeopeu2026/game/catalog.dart';
import 'package:raikeopeu2026/game/stages.dart';

import 'fixtures.dart';

class Trial implements CombatLoadout {
  Trial(this.id);
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

Enemy target(
  BattleEngine g,
  Vec position, {
  EnemyKind kind = EnemyKind.armored,
}) {
  final e = Enemy(position, kind);
  g.enemies.add(e);
  return e;
}

void main() {
  test(
    'free roster is exactly rabbit fox turtle; no signature grant',
    () async {
      final c = LoadoutController();
      await c.ready;
      expect(
        catalogEntries
            .where((e) => e.category == CatalogCategory.character && !e.premium)
            .map((e) => e.id),
        ['pilot', 'rion', 'eden'],
      );
      for (final p in animalPilots) {
        expect(c.select(catalogEntry(p.id)), p.free);
      }
      expect(c.select(catalogEntry('signature')), false);
      expect(animalPilots.map((p) => p.id).toSet().length, 12);
    },
  );
  for (final p in animalPilots) {
    test('${p.id} basic fire, signature end, damage and fresh stage reset', () {
      final loadout = Trial(p.id), g = BattleEngine(Trial(p.id));
      g.step(.01);
      expect(g.bullets.any((b) => b.friendly), true);
      expect(g.activateSkill(), true);
      expect(g.cooldown, p.balance.cooldown);
      expect(g.activateSkill(), false);
      advance(g, p.balance.duration + .2);
      expect(g.animalActive, false);
      expect(g.protected, false);
      final hp = g.health;
      g.bullets.add(Projectile(g.player, Vec.zero));
      g.step(.01);
      expect(g.health, lessThan(hp));
      final next = BattleEngine(loadout, stage: stages[1]);
      expect(next.animal.active, false);
      expect(next.animal.beacons, isEmpty);
      expect(next.animal.history, isEmpty);
      expect(next.cooldown, 0);
      expect(next.bullets, isEmpty);
      expect(next.health, next.maxHealth);
      final retry = BattleEngine(loadout);
      expect(retry.elapsed, 0);
      expect(retry.animal.spent, 0);
    });
  }
  test('rabbit stitches recent motion and spends a finite damage budget', () {
    final g = BattleEngine(Trial('pilot'));
    for (var i = 0; i < 8; i++) {
      g.moveBy(const Vec(12, 0));
      advance(g, .13);
    }
    expect(g.animal.history.length, lessThanOrEqualTo(8));
    g.activateSkill();
    final e = target(g, g.animal.stitch[3]);
    advance(g, .7);
    expect(e.health, lessThan(70));
    expect(g.animal.spent, lessThanOrEqualTo(g.pilot.balance.budget));
    advance(g, 3);
    expect(g.animal.stitch, isEmpty);
  });
  test('fox replaces basic spread with reduced damage angled projectiles', () {
    final g = BattleEngine(Trial('rion'))..activateSkill();
    g.step(.01);
    final shots = g.bullets.where((b) => b.friendly).toList();
    expect(shots.length, 3);
    expect(shots.first.damage, closeTo(g.shotDamage * .4, .0001));
    expect(shots.first.velocity.dx, lessThan(0));
    expect(shots.last.velocity.dx, greaterThan(0));
  });
  test(
    'bear collects six ordinary bullets, rejects boss bullets and releases',
    () {
      final g = BattleEngine(Trial('tw_bear'))..activateSkill();
      for (var i = 0; i < 8; i++) {
        g.bullets.add(Projectile(g.player + const Vec(20, -20), Vec.zero));
      }
      final boss = Projectile(
        g.player + const Vec(10, -20),
        Vec.zero,
        collectible: false,
      );
      g.bullets.add(boss);
      g.step(.01);
      expect(g.animal.captured.length, 6);
      expect(g.bullets.contains(boss), true);
      advance(g, 2);
      expect(g.animal.captured, isEmpty);
      expect(g.bullets.where((b) => b.friendly && b.precision).length, 6);
    },
  );
  test('turtle only blocks five forward normal rounds, never side or boss', () {
    final g = BattleEngine(Trial('eden'))..activateSkill();
    for (var i = 0; i < 6; i++) {
      g.bullets.add(Projectile(g.player + const Vec(0, -35), const Vec(0, 30)));
    }
    final boss = Projectile(
      g.player + const Vec(2, -35),
      const Vec(0, 30),
      collectible: false,
    );
    final side = Projectile(g.player + const Vec(45, 0), const Vec(-20, 0));
    g.bullets.addAll([boss, side]);
    g.step(.01);
    expect(g.animal.durability, 0);
    expect(g.bullets.contains(boss), true);
    expect(g.bullets.contains(side), true);
    expect(g.bullets.where((b) => !b.friendly).length, 3);
  });
  test(
    'otter relays only among distinct nearby targets within shared budget',
    () {
      final g = BattleEngine(Trial('tw_otter'))..activateSkill();
      target(g, const Vec(100, 250));
      final nearby = target(g, const Vec(145, 250));
      final far = target(g, const Vec(330, 100));
      g.bullets.add(Projectile(const Vec(100, 250), Vec.zero, friendly: true));
      g.step(.01);
      expect(nearby.health, lessThan(70));
      expect(far.health, 70);
      expect(g.animal.spent, lessThanOrEqualTo(48));
      expect(g.animal.links.length, lessThanOrEqualTo(3));
    },
  );
  test('owl prioritizes boss and telegraphs before limited precise shots', () {
    final g = BattleEngine(Trial('tw_owl'));
    target(g, const Vec(100, 200));
    final boss = target(g, const Vec(200, 90), kind: EnemyKind.boss);
    g.activateSkill();
    expect(g.animal.target, same(boss));
    advance(g, .5);
    expect(g.animal.precisionShots, 0);
    advance(g, 1.5);
    expect(g.animal.precisionShots, 3);
  });
  test('seed has bounded lifetime/count and actual proximity explosion', () {
    final g = BattleEngine(Trial('tw_squirrel'))..activateSkill();
    final e = target(g, g.player + const Vec(32, 0));
    g.step(.01);
    expect(e.health, 50);
    expect(g.animal.beacons, isEmpty);
    final empty = BattleEngine(Trial('tw_squirrel'))..activateSkill();
    advance(empty, 6.1);
    expect(empty.animal.beacons, isEmpty);
  });
  test('hedgehog proximity damage gives no automatic invulnerability', () {
    final g = BattleEngine(Trial('tw_hedgehog'))..activateSkill();
    final e = target(g, g.player + const Vec(35, 0));
    g.bullets.add(Projectile(g.player, Vec.zero));
    g.step(.01);
    expect(e.health, lessThan(70));
    expect(g.health, g.maxHealth - 1);
    expect(g.protected, false);
  });
  test('penguin slows normal, resists armor and excludes boss/old bullets', () {
    final g = BattleEngine(Trial('tw_penguin'))..activateSkill();
    final scout = target(
      g,
      g.player + const Vec(0, -120),
      kind: EnemyKind.scout,
    );
    final armor = target(g, g.player + const Vec(20, -120));
    final boss = target(
      g,
      g.player + const Vec(-20, -120),
      kind: EnemyKind.boss,
    );
    final scoutBefore = scout.position;
    final bullet = Projectile(const Vec(1, 1), const Vec(30, 100));
    g.bullets.add(bullet);
    g.step(.01);
    expect(scout.slowRemaining, greaterThan(0));
    expect(
      scout.position.dy - scoutBefore.dy,
      closeTo(64 * .01 * g.pilot.balance.slowFactor, .001),
    );
    expect(
      scout.position.dx - scoutBefore.dx,
      lessThan(.008),
      reason: 'lateral weaving is slowed too',
    );
    expect(armor.slowRemaining, greaterThan(0));
    expect(boss.slowRemaining, 0);
    expect(bullet.velocity.dx, 30);
    expect(bullet.velocity.dy, 100);
    g.moveBy(const Vec(0, -250));
    advance(g, .2);
    expect(scout.slowImmunity, greaterThan(0));
  });
  test(
    'decoy redirects new armored aim, preserves already telegraphed aim',
    () {
      final g = BattleEngine(Trial('tw_chameleon'));
      g.activateSkill();
      final anchor = g.player;
      g.moveBy(const Vec(90, 0));
      final fresh = target(g, const Vec(180, 200))..fireClock = 2;
      final old = target(g, const Vec(100, 200))
        ..telegraph = true
        ..aim = .77
        ..fireClock = 2;
      g.step(.01);
      expect(fresh.aim, closeTo(0, .001));
      expect(old.aim, .77);
      expect(g.animal.anchor, same(anchor));
    },
  );
  test('eagle has a warning then exactly four feather shots', () {
    final g = BattleEngine(Trial('tw_eagle'))..activateSkill();
    advance(g, .4);
    expect(g.animal.precisionShots, 0);
    advance(g, .2);
    expect(g.animal.precisionShots, 4);
    expect(g.protected, false);
  });
  test(
    'electric shrew delays each ordinary enemy only once, excludes boss',
    () {
      final g = BattleEngine(Trial('tw_volt'));
      final e = target(g, g.player + const Vec(40, -20))..fireClock = 1;
      final boss = target(
        g,
        g.player + const Vec(-40, -20),
        kind: EnemyKind.boss,
      )..fireClock = 1;
      g.activateSkill();
      g.step(.01);
      expect(e.fireClock, closeTo(.31, .001));
      expect(boss.fireClock, closeTo(1.01, .001));
      advance(g, .4);
      expect(g.animal.disrupted.length, 1);
      expect(e.health, 66);
    },
  );
  test(
    'expiry/account switch clear signature fields and paid character selection',
    () async {
      var now = DateTime.utc(2026, 10, 29);
      final c = LoadoutController(
        repository: FixtureEntitlements(
          SubscriptionAccess(
            AccessStatus.active,
            validUntil: now.add(const Duration(seconds: 5)),
          ),
        ),
        clock: () => now,
      );
      await c.refresh();
      c.select(catalogEntry('tw_squirrel'));
      c.select(catalogEntry('signature'));
      final g = BattleEngine(c)..activateSkill();
      expect(g.animal.beacons.length, 1);
      final stale = target(g, const Vec(30, 100))..slowRemaining = 2;
      now = now.add(const Duration(seconds: 6));
      g.step(.01);
      expect(g.character, 'pilot');
      expect(g.skill, 'barrier');
      expect(g.animal.beacons, isEmpty);
      expect(stale.slowRemaining, 0);
      c.accountChanged();
      await c.ready;
      expect(c.premiumActive, false);
      expect(c.selected(CatalogCategory.character), 'pilot');
    },
  );
}
