import 'package:raikeopeu2026/game/combat_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/game/catalog.dart';
import 'package:raikeopeu2026/game/engine.dart';
import 'package:raikeopeu2026/game/stages.dart';

import 'fixtures.dart';

void advance(BattleEngine g, double seconds) {
  for (var i = 0; i < (seconds / .01).ceil(); i++) {
    g.step(.01);
  }
}

void main() {
  test('free defaults include character, automatic fire and real shield', () {
    final controller = LoadoutController();
    final g = BattleEngine(controller);
    expect(g.character, 'pilot');
    expect(g.skill, 'barrier');
    g.step(.01);
    expect(g.bullets.where((b) => b.friendly), hasLength(2));
    expect(g.activateSkill(), isTrue);
    expect(g.shieldRemaining, 2);
    expect(g.cooldown, 10);
    expect(g.activateSkill(), isFalse);
    g.bullets.add(Projectile(g.player, Vec.zero));
    g.step(.01);
    expect(g.health, 3, reason: 'Shield must absorb a real collision');
    expect(g.bullets.where((b) => !b.friendly), isEmpty);
    advance(g, 2.01);
    expect(g.protected, isFalse);
    g.bullets.add(Projectile(g.player, Vec.zero));
    g.step(.01);
    expect(g.health, 2, reason: 'Damage must return after shield expires');
    expect(g.activateSkill(), isFalse);
    advance(g, 8.1);
    expect(g.activateSkill(), isTrue);
  });

  test(
    'pause freezes cooldown, enemies and damage; movement stays in bounds',
    () {
      final g = BattleEngine(LoadoutController());
      g.activateSkill();
      g.pause();
      final before = g.player;
      g.moveBy(const Vec(100, 100));
      g.step(.05);
      expect(g.player, before);
      expect(g.cooldown, 10);
      expect(g.elapsed, 0);
      g.resume();
      g.moveBy(const Vec(100000, -100000));
      expect(g.player.dx, BattleEngine.width - 22);
      expect(g.player.dy, 30);
      g.step(double.nan);
      g.step(-3);
      expect(g.elapsed, 0);
      g.step(100);
      expect(g.elapsed, .05, reason: 'A stalled frame cannot skip the battle');
    },
  );

  test(
    'unverified, expired and inactive access cannot equip paid content',
    () async {
      final clock = DateTime.utc(2026, 10, 18);
      for (final access in [
        const SubscriptionAccess(AccessStatus.unverified),
        const SubscriptionAccess(AccessStatus.inactive),
        SubscriptionAccess(AccessStatus.active, validUntil: clock),
        const SubscriptionAccess(AccessStatus.active),
      ]) {
        final c = LoadoutController(
          repository: FixtureEntitlements(access),
          clock: () => clock,
        );
        await c.refresh();
        for (final e in catalogEntries.where((e) => e.premium)) {
          expect(c.select(e), isFalse);
        }
        expect(c.selected(CatalogCategory.character), 'pilot');
      }
      expect(
        LoadoutController().select(
          const CatalogEntry(
            'forged',
            'forged',
            '',
            CatalogCategory.skill,
            premium: false,
          ),
        ),
        isFalse,
      );
    },
  );

  test(
    'verified restoration enables selection and applies character stats',
    () async {
      final now = DateTime.utc(2026, 10, 18);
      final repo = FixtureEntitlements(
        SubscriptionAccess(
          AccessStatus.active,
          validUntil: now.add(const Duration(hours: 1)),
        ),
      );
      final c = LoadoutController(repository: repo, clock: () => now);
      expect(await c.refresh(restore: true), isTrue);
      expect(repo.restores, 1);
      expect(c.select(catalogEntry('rion')), isTrue);
      expect(BattleEngine(c).shotDamage, 12);
      c.select(catalogEntry('eden'));
      final defense = BattleEngine(c);
      expect(defense.maxHealth, 4);
      defense.activateSkill();
      expect(defense.shieldRemaining, 2.5);
    },
  );

  test('paid skills, aircraft and equipment change actual combat', () async {
    final now = DateTime.utc(2026, 10, 18);
    final c = LoadoutController(
      repository: FixtureEntitlements(
        SubscriptionAccess(
          AccessStatus.active,
          validUntil: now.add(const Duration(hours: 1)),
        ),
      ),
      clock: () => now,
    );
    await c.refresh();
    c.select(catalogEntry('focus'));
    final focus = BattleEngine(c);
    expect(focus.shotInterval, .24);
    focus.activateSkill();
    expect(focus.shotInterval, .12);
    c.select(catalogEntry('mecha'));
    final mecha = BattleEngine(c)..activateSkill();
    mecha.step(.01);
    expect(mecha.robotMode, isTrue);
    expect(mecha.bullets.where((b) => b.friendly), hasLength(3));
    expect(mecha.bullets.first.damage, 15);
    c.select(catalogEntry('pulse'));
    final pulse = BattleEngine(c);
    pulse.bullets.add(Projectile(const Vec(20, 20), Vec.zero));
    pulse.enemies.add(Enemy(const Vec(180, 80), EnemyKind.armored));
    pulse.activateSkill();
    expect(pulse.bullets, isEmpty);
    expect(pulse.enemies.single.health, 30);
    c.select(catalogEntry('barrier'));
    c.select(catalogEntry('echo'));
    final echo = BattleEngine(c)..step(.01);
    expect(echo.bullets.where((b) => b.friendly), hasLength(4));
    c.select(catalogEntry('tuner'));
    final tuner = BattleEngine(c)..activateSkill();
    expect(tuner.shotDamage, 11);
    expect(tuner.cooldown, 9);
    c.select(catalogEntry('prism'));
    final prism = BattleEngine(c);
    // Keep this equipment timing check separate from random wave collisions.
    for (var i = 0; i < 1201; i++) {
      prism.enemies.clear();
      prism.bullets.clear();
      prism.step(.01);
    }
    expect(prism.protected, isTrue);
    c.select(catalogEntry('vector'));
    expect(BattleEngine(c).moveSpeed, 1.15);
    c.select(catalogEntry('safeguard'));
    expect(BattleEngine(c).maxHealth, 4);
  });

  test(
    'expiry during combat removes premium effects and returns to free kit',
    () async {
      var now = DateTime.utc(2026, 10, 18);
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
      c.select(catalogEntry('tw_owl'));
      c.select(catalogEntry('mecha'));
      c.select(catalogEntry('echo'));
      final g = BattleEngine(c)..activateSkill();
      expect(g.robotMode, isTrue);
      now = now.add(const Duration(seconds: 6));
      g.step(.01);
      expect(g.robotMode, isFalse);
      expect(g.character, 'pilot');
      expect(g.skill, 'barrier');
      expect(g.equipment, 'standard');
      expect(g.shotDamage, 10);
      expect(g.score, 0);
    },
  );

  test(
    'different enemy patterns and boss phases fire distinguishable attacks',
    () {
      final counts = <EnemyKind, int>{};
      for (final kind in EnemyKind.values) {
        final g = BattleEngine(LoadoutController());
        g.enemies.add(Enemy(const Vec(120, 80), kind)..fireClock = 3);
        g.step(.01);
        counts[kind] = g.bullets.where((b) => !b.friendly).length;
      }
      expect(counts[EnemyKind.scout], 1);
      expect(counts[EnemyKind.sweeper], 3);
      expect(counts[EnemyKind.armored], 2);
      final g = BattleEngine(LoadoutController(), stage: stages[1]);
      g.enemies.add(
        Enemy(const Vec(180, 80), EnemyKind.boss)
          ..health = 190
          ..fireClock = 2,
      );
      g.step(.01);
      expect(g.bullets.where((b) => !b.friendly), hasLength(7));
    },
  );

  test(
    'one bullet cannot damage twice and a defeated boss ends the battle',
    () {
      final g = BattleEngine(LoadoutController());
      g.enemies.add(Enemy(const Vec(180, 100), EnemyKind.boss)..health = 10);
      g.bullets.add(Projectile(const Vec(180, 100), Vec.zero, friendly: true));
      g.step(.01);
      expect(g.phase, BattlePhase.won);
      expect(g.score, 1000);
      final t = g.elapsed;
      g.step(.01);
      expect(g.score, 1000);
      expect(g.elapsed, t);
    },
  );
}
