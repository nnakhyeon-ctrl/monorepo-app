import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/features/battle_skill_dock.dart';
import 'package:raikeopeu2026/game/catalog.dart';
import 'package:raikeopeu2026/game/engine.dart';
import 'package:raikeopeu2026/game/combat_model.dart';
import 'package:raikeopeu2026/game/animal_roster.dart';
import 'package:raikeopeu2026/game/saved_loadout.dart';
import 'package:raikeopeu2026/game/assets.dart';
import 'package:raikeopeu2026/game/advanced_skill_catalog.dart';
import 'package:raikeopeu2026/game/equipment_catalog.dart';
import 'package:raikeopeu2026/app.dart';
import 'package:raikeopeu2026/core/readiness.dart';

import 'fixtures.dart';
import 'expanded_combat_test.dart' show subscribed;
import 'animal_roster_test.dart' show advance;
import 'battle_flow_test.dart' show currentGame;

void main() {
  test('catalog cannot be mutated to inject a free permission grant', () async {
    final c = LoadoutController();
    await c.ready;
    const forged = CatalogEntry(
      'forged',
      'forged',
      '',
      CatalogCategory.skill,
      premium: false,
    );
    expect(() => catalogEntries.add(forged), throwsUnsupportedError);
    expect(c.select(forged), false);
    c.dispose();
    expect(animalPilots.length, 12);
    expect(pilotTips.keys.toSet(), animalPilots.map((p) => p.id).toSet());
    expect(equipmentSpecs.length, 7);
    expect(advancedSkillSpecs.length, 9);
  });
  testWidgets('automatic fire has no shield cooldown overlay', (t) async {
    final g = BattleEngine(const FreeLoadout())..activateSkill();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BattleSkillDock(g, onSkill: () {}, onShield: () {}),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('automaticFire')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('useSkill')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
  });
  test('new saved choices remain preferences and premium items are denied without rights', () async {
    final free = LoadoutController();
    await free.ready;
    for (final id in [
      'gyro',
      'capacitor',
      'safety_cell',
      'petal_orbit',
      'aurora_sweep',
      'landing_beacon',
    ]) {
      final entry = catalogEntry(id);
      expect(entry.isPremiumOnly, true);
      expect(free.select(entry), false);
      final saved = const SavedLoadout().select(entry.category, id);
      expect(
        SavedLoadout.fromJson(saved.toJson()).selected(entry.category),
        id,
      );
    }
    free.dispose();
  });
  test('petal drones block actual contact with ordinary bullets and have six charges', () async {
    final c = await subscribed('petal_orbit'),
        g = BattleEngine(c)..activateSkill();
    advance(g, .27);
    for (var i = 0; i < 6; i++) {
      final b = Projectile(PetalOrbitStrategy.drone(g, 0), Vec.zero);
      g.bullets.add(b);
      g.step(.001);
      expect(g.bullets.contains(b), false);
    }
    expect(g.advanced.blocks, 0);
    expect(g.protected, false);
    final boss = Projectile(
      PetalOrbitStrategy.drone(g, 0),
      Vec.zero,
      collectible: false,
    );
    g.bullets.add(boss);
    g.step(.001);
    expect(g.bullets.contains(boss), true);
    c.dispose();
  });
  test('petal contact damage has a strict total budget', () async {
    final c = await subscribed('petal_orbit'),
        g = BattleEngine(c)..activateSkill();
    advance(g, .27);
    final e = Enemy(PetalOrbitStrategy.drone(g, 0), EnemyKind.armored)
      ..health = 1000;
    g.enemies.add(e);
    for (var i = 0; i < 450; i++) {
      e.position = PetalOrbitStrategy.drone(g, 0);
      g.step(.01);
      g.health = 3;
    }
    expect(g.advanced.spent, lessThanOrEqualTo(48));
    expect(g.advanced.spent, 48);
    c.dispose();
  });
  test(
    'sweeping rays use the rendered segment for damage and expire',
    () async {
      final c = await subscribed('aurora_sweep'),
          g = BattleEngine(c)..activateSkill();
      advance(g, .41);
      final end = AuroraSweepStrategy.end(g, 1),
          at = g.player + (end - g.player) * .5;
      final e = Enemy(at, EnemyKind.armored);
      g.enemies.add(e);
      g.step(.01);
      expect(e.health, lessThan(70));
      advance(g, 3.1);
      expect(g.advanced.phase, SkillStage.idle);
      c.dispose();
    },
  );
  test('landing beacon repairs once, blocks three ordinary rounds and never boss rounds', () async {
    final c = await subscribed('landing_beacon'),
        g = BattleEngine(c)..health = 1;
    g.activateSkill();
    g.step(.01);
    expect(g.health, 2);
    expect(g.advanced.repaired, true);
    g.health = 1;
    g.step(.01);
    expect(g.health, 1);
    for (var i = 0; i < 3; i++) {
      g.bullets.add(Projectile(g.advanced.anchor + const Vec(25, 0), Vec.zero));
      g.step(.01);
    }
    expect(g.advanced.blocks, 0);
    g.bullets.add(Projectile(g.player, Vec.zero, collectible: false));
    g.step(.01);
    expect(g.health, 0);
    expect(g.advanced.phase, SkillStage.idle);
    c.dispose();
  });
  test(
    'gyro narrows basic spread while preserving damage, HP and hitbox',
    () async {
      final c = await subscribed('gyro'), g = BattleEngine(c)..step(.01);
      final free = BattleEngine(const FreeLoadout())..step(.01);
      expect(
        g.bullets.first.velocity.dx.abs(),
        lessThan(free.bullets.first.velocity.dx.abs()),
      );
      expect(g.bullets.first.damage, 10);
      expect(g.health, 3);
      expect(g.playerAircraft.hitbox.radius, 10);
      c.dispose();
    },
  );
  test(
    'capacitor counts damaging base hits and buffs exactly one volley',
    () async {
      final c = await subscribed('capacitor'), g = BattleEngine(c);
      final target = Enemy(const Vec(40, 150), EnemyKind.armored)
        ..health = 1000;
      g.enemies.add(target);
      for (var i = 0; i < 8; i++) {
        g.bullets.add(
          g.projectilePool.acquire(
            target.position,
            Vec.zero,
            friendly: true,
            baseShot: true,
          ),
        );
        g.step(.001);
      }
      expect(g.itemState.volleyReady, true);
      expect(g.itemState.hits, 8);
      for (var i = 0; i < 30; i++) {
        g.step(.01);
      }
      expect(g.bullets.where((b) => b.baseShot && b.damage == 13.5).length, 2);
      expect(g.itemState.volleyReady, false);
      final reused = g.projectilePool.acquire(
        Vec.zero,
        Vec.zero,
        baseShot: true,
      );
      g.projectilePool.release(reused);
      expect(g.projectilePool.acquire(Vec.zero, Vec.zero).baseShot, false);
      c.dispose();
    },
  );
  test(
    'emergency cell has a 24 second cooldown and revocation clears protection',
    () async {
      final c = await subscribed('safety_cell'),
          g = BattleEngine(c)..health = 1;
      g.bullets.add(Projectile(g.player, Vec.zero));
      g.step(.01);
      expect(g.health, 1);
      expect(g.shieldRemaining, 1.2);
      expect(g.itemState.emergencyCooldown, 24);
      advance(g, 1.3);
      g.bullets.add(Projectile(g.player, Vec.zero));
      g.step(.01);
      expect(g.phase, BattlePhase.lost);
      final next = BattleEngine(c)..health = 1;
      next.bullets.add(Projectile(next.player, Vec.zero));
      next.step(.01);
      (c.repository as FixtureEntitlements).result = const SubscriptionAccess(
        AccessStatus.inactive,
      );
      await c.refresh();
      next.pause();
      next.synchronizeLoadout();
      expect(next.equipment, 'standard');
      expect(next.protected, false);
      expect(next.itemState.emergencyCooldown, 0);
      c.dispose();
    },
  );
  testWidgets(
    'paused real battle clears premium charge after entitlement change',
    (t) async {
      final repo = FixtureEntitlements(
        SubscriptionAccess(
          AccessStatus.active,
          validUntil: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      await t.pumpWidget(
        RaikeopeuApp(
          assets: ImmediateAssets(),
          progress: FixtureProgress(),
          feedback: FixtureFeedback(),
          appInfo: FixtureAppInfo(),
          entitlements: repo,
        ),
      );
      await t.pumpAndSettle();
      final s = AppServices.of(t.element(find.byKey(const Key('startGame'))));
      await s.loadout.refresh();
      s.loadout.select(catalogEntry('beam'));
      await t.ensureVisible(find.byKey(const Key('startGame')));
      await t.tap(find.byKey(const Key('startGame')));
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 100));
      final g = currentGame(t);
      g.activateSkill();
      await t.tap(find.byKey(const Key('pauseBattle')));
      await t.pump();
      repo.result = const SubscriptionAccess(AccessStatus.inactive);
      await s.loadout.refresh();
      await t.pump();
      await t.pump();
      expect(g.phase, BattlePhase.paused);
      expect(g.skill, 'barrier');
      expect(g.advanced.phase, SkillStage.idle);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'three Sera assets have real alpha, high resolution and bounded runtime decoding',
    (t) async {
      final p = animalPilot('rion')!;
      expect(p.hero, 'assets/tailwing/fox_hero_v2.png');
      await t.runAsync(() async {
        for (final path in [p.portrait, p.aircraft, p.hero]) {
          final bytes = await File(path).readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final image = (await codec.getNextFrame()).image;
          expect(image.width, greaterThanOrEqualTo(1024));
          final raw = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          expect(raw.getUint8(3), 0);
          image.dispose();
          codec.dispose();
        }
        final assets = BattleAssets();
        await assets.prepare();
        await assets.preparePilot('rion');
        expect(assets.pilotImageFor('rion')!.width, 256);
        expect(assets.decodedBytes, lessThan(9 * 1024 * 1024));
        assets.dispose();
      });
    },
  );
}
