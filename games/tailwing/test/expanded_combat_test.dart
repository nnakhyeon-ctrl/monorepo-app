import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/app.dart';
import 'package:raikeopeu2026/core/readiness.dart';
import 'package:raikeopeu2026/game/advanced_skill_catalog.dart';
import 'package:raikeopeu2026/game/catalog.dart';
import 'package:raikeopeu2026/game/combat_model.dart';
import 'package:raikeopeu2026/game/engine.dart';
import 'package:raikeopeu2026/game/saved_loadout.dart';
import 'package:raikeopeu2026/coop/protocol.dart';

import 'fixtures.dart';
import 'basic_screens_test.dart' show open, press;
import 'animal_roster_test.dart' show advance;
import 'battle_flow_test.dart' show currentGame;

Future<LoadoutController> subscribed(String id) async {
  final c = LoadoutController(
    repository: FixtureEntitlements(
      SubscriptionAccess(
        AccessStatus.active,
        validUntil: DateTime.now().add(const Duration(hours: 1)),
        subscriptionType: SubscriptionType.monthly,
      ),
    ),
  );
  await c.refresh();
  expect(c.select(catalogEntry(id)), true);
  return c;
}

void main() {
  test('aircraft component exposes actual HP, speed, velocity and unrotated hitbox', () {
    final g = BattleEngine(const FreeLoadout());
    g.moveBy(const Vec(18, -4));
    g.step(.02);
    expect(g.playerAircraft.x, 198);
    expect(g.playerAircraft.hp, g.health);
    expect(g.playerAircraft.velocity.dx, 900);
    expect(g.playerAircraft.speed, 1);
    expect(g.playerAircraft.tilt, inExclusiveRange(0, .16));
    expect(g.playerAircraft.hitbox.width, 20);
    expect(
      g.playerAircraft.hitbox.contains(g.player, g.player + const Vec(9.99, 0)),
      true,
    );
    expect(
      g.playerAircraft.hitbox.contains(g.player, g.player + const Vec(10, 0)),
      false,
    );
    advance(g, 1);
    expect(g.playerAircraft.tilt.abs(), lessThan(.001));
    g.moveBy(const Vec(double.nan, 0));
    expect(g.player.dx.isFinite, true);
  });

  test('projectile pool resets all fields, rejects duplicate release and bounds memory', () {
    final pool = ProjectilePool(capacity: 2);
    final first = pool.acquire(
      Vec.zero,
      const Vec(10, 20),
      friendly: true,
      damage: 34,
      collectible: false,
      precision: true,
      homing: true,
    )..steeringRemaining = .1;
    pool.release(first);
    pool.release(first);
    expect(pool.retained, 1);
    final reused = pool.acquire(const Vec(1, 2), Vec.zero);
    expect(identical(first, reused), true);
    expect(
      [reused.friendly, reused.precision, reused.homing],
      [false, false, false],
    );
    expect(reused.collectible, true);
    expect(reused.damage, 10);
    expect(reused.steeringRemaining, 1.2);
    final others = List.generate(5, (_) => pool.acquire(Vec.zero, Vec.zero));
    pool.release(reused);
    for (final b in others) {
      pool.release(b);
    }
    expect(pool.retained, 2);
    expect(pool.reuses, 1);
  });

  test('long free simulation reuses projectiles without changing shot count or cap', () {
    final g = BattleEngine(const FreeLoadout());
    for (var i = 0; i < 1600; i++) {
      g.enemies.clear();
      g.health = 3;
      g.step(.01);
    }
    expect(g.projectilePool.reuses, greaterThan(60));
    expect(g.projectilePool.allocations, lessThan(40));
    expect(g.effects.length, lessThanOrEqualTo(BattleEngine.maxEffects));
  });

  test('guided enemy missile turns at bounded rate then follows readable straight path', () {
    final g = BattleEngine(const FreeLoadout());
    g.enemies.add(
      Enemy(const Vec(90, 100), EnemyKind.interceptor)..fireClock = 2.79,
    );
    g.step(.02);
    final missile = g.bullets.singleWhere((b) => !b.friendly);
    expect(missile.homing, true);
    expect(missile.velocity.dx, greaterThan(0));
    expect(
      math.atan2(missile.velocity.dx, missile.velocity.dy).abs(),
      lessThanOrEqualTo(.65 * .02 + .0001),
    );
    advance(g, 1.25);
    final velocity = missile.velocity;
    g.moveBy(const Vec(-130, 0));
    g.step(.01);
    expect(missile.velocity, same(velocity));
  });

  test('charger telegraphs locked destination before formation dive', () {
    final g = BattleEngine(const FreeLoadout());
    final e = Enemy(const Vec(60, 120), EnemyKind.charger)..fireClock = 1.2;
    g.enemies.add(e);
    g.step(.01);
    expect(e.telegraph, true);
    final aim = e.aim, at = e.position;
    g.moveBy(const Vec(-130, 0));
    advance(g, .5);
    expect(e.position, same(at));
    expect(e.aim, aim);
    advance(g, .5);
    expect(e.telegraph, false);
    expect(e.position.dy, greaterThan(at.dy));
  });

  test('sentinel shield, laser warning, active damage and expiry match actual simulation', () {
    final g = BattleEngine(const FreeLoadout());
    final e = Enemy(const Vec(180, 125), EnemyKind.sentinel)..age = 6 - .005;
    g.enemies.add(e);
    g.step(.01);
    expect(e.shield, 30);
    g.damageEnemy(e, 40);
    expect(e.shield, 0);
    expect(e.health, 100);
    e.age = 14.9;
    g.step(.01);
    expect(e.laserWarning, true);
    final hp = g.health;
    g.step(.01);
    expect(g.health, hp);
    e.age = 15.25;
    g.step(.01);
    expect(e.laserActive, true);
    // Put the player on the actual ray; shield follows the existing protection rule.
    g.player =
        e.position + Vec(math.sin(e.laserAngle), math.cos(e.laserAngle)) * 30;
    g.step(.01);
    expect(g.health, hp - 1);
    e.age = 16.5;
    g.step(.01);
    expect(e.laserActive, false);
  });

  test('boss changes three health phases; destroying one module removes its emitter', () {
    final g = BattleEngine(const FreeLoadout());
    final boss = Enemy(const Vec(180, 85), EnemyKind.boss)
      ..health = g.stage.bossHealth;
    expect(boss.bossPhase(g.stage.bossHealth), 1);
    boss.health = g.stage.bossHealth * .5;
    expect(boss.bossPhase(g.stage.bossHealth), 2);
    g.damageEnemy(boss, 55, impact: boss.position + const Vec(-28, 12));
    expect(boss.parts, [0, 55]);
    boss.health = g.stage.bossHealth * .25;
    expect(boss.bossPhase(g.stage.bossHealth), 3);
    g.enemies.add(boss..fireClock = 2);
    g.step(.01);
    expect(
      g.bullets.where((b) => !b.friendly).length,
      6,
    ); // base3 + surviving1 + phase3 pair
  });

  for (final id in advancedSkillSpecs.keys) {
    test(
      '$id requires verified subscription; activation, pause, expiry and retry are isolated',
      () async {
        final free = LoadoutController();
        await free.ready;
        expect(catalogEntry(id).isPremiumOnly, true);
        expect(free.select(catalogEntry(id)), false);
        free.dispose();
        final c = await subscribed(id);
        final g = BattleEngine(c);
        expect(g.activateSkill(), true);
        expect(g.activateSkill(), false);
        final before = g.advanced.chargeRemaining;
        g.pause();
        g.step(.05);
        expect(g.advanced.chargeRemaining, before);
        g.resume();
        advance(g, .2);
        (c.repository as FixtureEntitlements).result = const SubscriptionAccess(
          AccessStatus.inactive,
        );
        await c.refresh();
        g.step(.01);
        expect(g.skill, 'barrier');
        expect(g.advanced.phase, SkillStage.idle);
        expect(g.advanced.energy, 0);
        expect(g.advanced.links, isEmpty);
        expect(g.bullets.any((b) => b.friendly && b.homing), false);
        final retry = BattleEngine(c);
        expect(retry.cooldown, 0);
        expect(retry.advanced.freeze, 0);
        c.dispose();
      },
    );
  }

  test('missile storm charges, briefly freezes hazards, emits exactly six guided rounds', () async {
    final c = await subscribed('missile_storm'), g = BattleEngine(c);
    final bullet = g.projectilePool.acquire(
      const Vec(50, 150),
      const Vec(0, 50),
    );
    g.bullets.add(bullet);
    g.activateSkill();
    advance(g, .64);
    expect(g.bullets.any((b) => b.friendly && b.homing), false);
    advance(g, .02);
    expect(g.advanced.freeze, greaterThan(0));
    final at = bullet.position;
    advance(g, .2);
    expect(bullet.position, same(at));
    advance(g, 1.5);
    expect(g.advanced.emitted, 6);
    expect(g.advanced.phase, SkillStage.idle);
    c.dispose();
  });

  test(
    'beam deals continuous damage only after charge and only in forward column',
    () async {
      final c = await subscribed('beam'), g = BattleEngine(c);
      final inside = Enemy(const Vec(180, 200), EnemyKind.armored),
          outside = Enemy(const Vec(280, 200), EnemyKind.armored);
      g.enemies.addAll([inside, outside]);
      g.activateSkill();
      advance(g, .54);
      expect(inside.health, 70);
      advance(g, .52);
      expect(inside.health, lessThan(57));
      expect(outside.health, 70);
      c.dispose();
    },
  );

  test('absorption includes boss rounds, caps energy, ends in exactly six counter rounds', () async {
    final c = await subscribed('absorb'), g = BattleEngine(c)..activateSkill();
    for (var i = 0; i < 8; i++) {
      g.bullets.add(Projectile(g.player, Vec.zero, collectible: false));
    }
    g.step(.01);
    expect(g.health, 3);
    expect(g.advanced.energy, 60);
    expect(g.bullets.any((b) => !b.friendly), false);
    advance(g, 3.1);
    expect(g.advanced.phase, SkillStage.idle);
    expect(g.bullets.where((b) => b.precision).length, 6);
    expect(g.bullets.where((b) => b.precision).first.damage, 15);
    c.dispose();
  });

  test(
    'blackhole pulls ordinary enemies but cannot drag the main boss',
    () async {
      final c = await subscribed('blackhole'),
          g = BattleEngine(c)..activateSkill();
      advance(g, .41);
      final e = Enemy(g.advanced.anchor + const Vec(60, 0), EnemyKind.armored);
      final boss = Enemy(g.advanced.anchor + const Vec(-60, 0), EnemyKind.boss);
      g.enemies.addAll([e, boss]);
      final x = e.position.dx;
      g.step(.05);
      expect(e.position.dx, lessThan(x));
      expect(e.health, lessThan(70));
      expect(boss.health, lessThan(400));
      c.dispose();
    },
  );

  test('EMP reduces movement exactly 80 percent inside its radius', () async {
    final c = await subscribed('emp'), g = BattleEngine(c)..activateSkill();
    final slowed = Enemy(g.advanced.anchor, EnemyKind.armored),
        normal = Enemy(const Vec(20, 60), EnemyKind.armored);
    g.enemies.addAll([slowed, normal]);
    final y = slowed.position.dy, normalY = normal.position.dy;
    g.step(.05);
    expect(
      slowed.position.dy - y,
      closeTo((normal.position.dy - normalY) * .2, .000001),
    );
    // Slow boss movement without changing its attack timer.
    final bossGame = BattleEngine(c)..player = const Vec(180, 250);
    bossGame.activateSkill();
    final boss = Enemy(const Vec(180, 85), EnemyKind.boss);
    bossGame.enemies.add(boss);
    bossGame.step(.01);
    expect(boss.motionAge, .002);
    expect(boss.fireClock, .01);
    c.dispose();
  });

  test(
    'chain damages only connected targets and records visible links',
    () async {
      final c = await subscribed('chain'), g = BattleEngine(c);
      final a = Enemy(const Vec(230, 300), EnemyKind.armored),
          b = Enemy(const Vec(300, 300), EnemyKind.armored),
          far = Enemy(const Vec(30, 40), EnemyKind.armored);
      g.enemies.addAll([a, b, far]);
      g.activateSkill();
      advance(g, .36);
      expect(a.health, 36);
      expect(b.health, 36);
      expect(far.health, 70);
      expect(g.advanced.links.length, 2);
      g.damageEnemy(a, 20);
      expect(a.health, 16);
      expect(b.health, 30);
      advance(g, 3.1);
      expect(g.advanced.tethered, isEmpty);
      c.dispose();
    },
  );

  test('free shield remains independently usable with an equipped advanced technique', () async {
    final c = await subscribed('beam'), g = BattleEngine(c);
    expect(g.activateSkill(), true);
    expect(g.activateBasicShield(), true);
    expect(g.activateBasicShield(), false);
    expect(g.shieldRemaining, 2);
    expect(g.basicShieldCooldown, 10);
    expect(g.advanced.phase, SkillStage.charging);
    g.bullets.add(Projectile(g.player, Vec.zero));
    g.step(.01);
    expect(g.health, 3);
    c.dispose();
  });

  test(
    'defeat cancels pending charge and absorption without a late attack',
    () async {
      for (final id in advancedSkillSpecs.keys) {
        final c = await subscribed(id), g = BattleEngine(c)..activateSkill();
        g.health = 0;
        g.step(.01);
        expect(g.phase, BattlePhase.lost);
        expect(g.advanced.phase, SkillStage.idle);
        expect(g.bullets.any((b) => b.friendly), false);
        c.dispose();
      }
    },
  );

  test('co-op transferred rounds return to their original pool', () {
    final g = BattleEngine(
      const FreeLoadout(),
      partnerLoadout: const FreeLoadout(),
    );
    g.step(.01);
    final allocations = g.partner!.projectilePool.allocations;
    for (var i = 0; i < 400; i++) {
      g.enemies.clear();
      g.step(.01);
    }
    expect(g.partner!.projectilePool.reuses, greaterThan(0));
    expect(g.partner!.projectilePool.allocations, lessThan(allocations + 30));
  });

  test('account projection distinguishes monthly/yearly and never reads local premium flags', () {
    final now = DateTime.utc(2026, 11, 5);
    for (final type in [SubscriptionType.monthly, SubscriptionType.yearly]) {
      var clock = now;
      final p = PermissionManager(
        SubscriptionAccess(
          AccessStatus.active,
          validUntil: now.add(const Duration(seconds: 1)),
          subscriptionType: type,
        ),
        () => clock,
      );
      expect(p.accountStatus.isSubscribed, true);
      expect(p.accountStatus.subscriptionType, type);
      clock = now.add(const Duration(seconds: 1));
      expect(p.canUse(catalogEntry('beam')), false);
      expect(p.accountStatus.subscriptionType, SubscriptionType.none);
    }
    final old = SavedLoadout.fromJson({'skill': 'beam', 'isSubscribed': true});
    expect(old.selected(CatalogCategory.skill), 'beam');
    expect(
      PermissionManager(
        const SubscriptionAccess(AccessStatus.unverified),
        () => now,
      ).canUse(catalogEntry('beam')),
      false,
    );
  });

  test('cooperative snapshot preserves hazard warnings, parts, homing and rejects old version', () {
    final g = BattleEngine(
      const FreeLoadout(),
      partnerLoadout: const FreeLoadout(),
    );
    g.enemies.add(
      Enemy(const Vec(180, 120), EnemyKind.sentinel)
        ..age = 14.8
        ..shield = 20
        ..laserAngle = 8.1,
    );
    g.bullets.add(
      Projectile(const Vec(120, 200), const Vec(0, 85))..homing = true,
    );
    final raw = battleSnapshot(g, 1), copy = readSnapshot(raw);
    expect(copy.enemies.single.laserWarning, true);
    expect(copy.enemies.single.shield, 20);
    expect(copy.bullets.single.homing, true);
    expect(() => readSnapshot({...raw, 'v': 1}), throwsFormatException);
  });

  testWidgets(
    'expiry notifies selection UI and resets advanced selection without a tap',
    (t) async {
      final now = t.binding.clock.now();
      final c = LoadoutController(
        clock: () => t.binding.clock.now(),
        repository: FixtureEntitlements(
          SubscriptionAccess(
            AccessStatus.active,
            validUntil: now.add(const Duration(seconds: 1)),
            subscriptionType: SubscriptionType.yearly,
          ),
        ),
      );
      await c.refresh();
      c.select(catalogEntry('emp'));
      var notifications = 0;
      c.addListener(() => notifications++);
      await t.pump(const Duration(seconds: 1));
      expect(c.premiumActive, false);
      expect(c.selected(CatalogCategory.skill), 'barrier');
      expect(notifications, greaterThan(0));
      c.dispose();
    },
  );

  testWidgets(
    'locked premium details explain policy and link directly to existing subscription screen',
    (t) async {
      await t.pumpWidget(
        RaikeopeuApp(
          assets: ImmediateAssets(),
          progress: FixtureProgress(),
          feedback: FixtureFeedback(),
          appInfo: FixtureAppInfo(),
        ),
      );
      await t.pumpAndSettle();
      await open(t, AppRoutes.hangar);
      await press(t, find.byKey(const Key('catalog-tw_bear')));
      expect(
        find.byKey(const Key('subscriptionUnlockMessage')),
        findsOneWidget,
      );
      await press(t, find.byKey(const Key('openSubscriptionUnlock')));
      expect(find.widgetWithText(AppBar, '구독 관리'), findsOneWidget);
      final services = AppServices.of(t.element(find.byType(AppBar)));
      expect(services.loadout.premiumActive, false);
      await t.pumpWidget(const SizedBox());
    },
  );

  for (final size in [
    const Size(280, 600),
    const Size(320, 568),
    const Size(396, 860),
    const Size(800, 400),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('combat HUD and skill controls fit $size text $scale', (
        t,
      ) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        await t.pumpWidget(
          RaikeopeuApp(
            assets: ImmediateAssets(),
            progress: FixtureProgress(),
            feedback: FixtureFeedback(),
            appInfo: FixtureAppInfo(),
          ),
        );
        await t.pumpAndSettle();
        await t.ensureVisible(find.byKey(const Key('startGame')));
        await t.tap(find.byKey(const Key('startGame')));
        await t.pump(const Duration(milliseconds: 300));
        await t.pump(const Duration(milliseconds: 100));
        final g = currentGame(t);
        await t.ensureVisible(find.byKey(const Key('useSkill')));
        await t.pump();
        await t.tap(find.byKey(const Key('useSkill')));
        await t.pump();
        expect(g.protected, true);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
