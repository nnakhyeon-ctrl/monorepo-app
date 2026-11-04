import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/app.dart';
import 'package:raikeopeu2026/core/readiness.dart';
import 'package:raikeopeu2026/features/battle_hud.dart';
import 'package:raikeopeu2026/game/animal_roster.dart';
import 'package:raikeopeu2026/game/catalog.dart';
import 'package:raikeopeu2026/game/combat_model.dart';
import 'package:raikeopeu2026/game/deck_status.dart';
import 'package:raikeopeu2026/game/engine.dart';
import 'package:raikeopeu2026/game/rendering.dart';
import 'package:raikeopeu2026/game/battle_pacing.dart';

import 'basic_screens_test.dart' show open, press;
import 'fixtures.dart';
import 'animal_roster_test.dart' show Trial, advance;

void main() {
  test('battle chapter cues use actual timeline and boss health without changing combat', () {
    final g = BattleEngine(Trial('pilot'));
    expect(BattlePacing.read(g).label, '항로 진입');
    g.elapsed = 30;
    expect(BattlePacing.read(g).label, '편대 교전');
    g.elapsed = g.stage.bossAt - 10;
    expect(BattlePacing.read(g).label, '보스 접근');
    final boss = Enemy(const Vec(180, 90), EnemyKind.boss)
      ..health = g.stage.bossHealth / 2;
    g.enemies.add(boss);
    expect(BattlePacing.read(g).label, '보스 교전');
    expect(BattlePacing.read(g).progress, .5);
    expect(g.score, 0);
    expect(g.health, g.maxHealth);
  });
  for (final size in [
    const Size(396, 800),
    const Size(320, 568),
    const Size(280, 600),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'home and roster fit $size text $scale without covering art',
        (t) async {
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
          final button = t.getRect(find.byKey(const Key('startGame')));
          expect(button.bottom, lessThanOrEqualTo(size.height));
          expect(button.top, greaterThan(0));
          expect(find.text('출격'), findsOneWidget);
          final s = AppServices.of(
            t.element(find.byKey(const Key('startGame'))),
          );
          await press(t, find.byKey(const Key('home-pilot-eden')));
          expect(s.loadout.pilot.id, 'eden');
          expect(
            find.byKey(const ValueKey('home-mounted-eden')),
            findsOneWidget,
          );
          await open(t, AppRoutes.hangar);
          final a = find.byKey(const Key('character-card-pilot'));
          final b = find.byKey(const Key('character-card-rion'));
          await t.scrollUntilVisible(a, 240);
          await t.ensureVisible(a);
          await t.pumpAndSettle();
          final first = t.getRect(a), second = t.getRect(b);
          if (size.width == 396 && scale == 1) {
            final third = t.getRect(
              find.byKey(const Key('character-card-eden')),
            );
            expect(first.top, second.top);
            expect(first.top, third.top);
          }
          if (size.width == 280 && scale == 2) {
            expect(second.top, greaterThan(first.top));
          }
          await press(t, find.byKey(const Key('catalog-tw_bear')));
          expect(find.text('환경설정에서 구독 보기'), findsOneWidget);
          expect(s.loadout.pilot.id, 'eden');
          expect(s.loadout.select(catalogEntry('tw_bear')), false);
          expect(s.loadout.select(catalogEntry('signature')), false);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets('actual deck transitions count down, deplete, expire and reset', (
    t,
  ) async {
    final loadout = Trial('eden'), g = BattleEngine(Trial('eden'));
    expect(DeckStatus.read(g)!.phase, DeckPhase.ready);
    g.activateSkill();
    expect(DeckStatus.read(g)!.phase, DeckPhase.deploying);
    expect(DeckStatus.read(g)!.remaining, 5);
    advance(g, .4);
    expect(DeckStatus.read(g)!.phase, DeckPhase.active);
    expect(DeckStatus.read(g)!.seconds, closeTo(2.6, .02));
    for (var i = 0; i < 5; i++) {
      g.bullets.add(Projectile(g.player + const Vec(0, -35), const Vec(0, 30)));
      g.step(.01);
      expect(DeckStatus.read(g)!.remaining, 4 - i);
    }
    expect(DeckStatus.read(g)!.phase, DeckPhase.depleted);
    expect(DeckStatus.read(g)!.blocking, false);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: BattleHud(g))));
    expect(find.text('갑판 소진 · 방어 종료'), findsOneWidget);
    expect(g.protected, false);
    advance(g, 3);
    expect(DeckStatus.read(g)!.phase, DeckPhase.ended);
    expect(DeckStatus.read(g)!.remaining, 0);
    final fresh = BattleEngine(loadout);
    expect(DeckStatus.read(fresh)!.phase, DeckPhase.ready);
    loadout.id = 'pilot';
    fresh.step(.01);
    expect(DeckStatus.read(fresh), isNull);
    expect(BattlePainter.playerBounds(g.player).size, const Size(74, 74));
    expect(animalPilot('eden')!.balance.width, 70);
    expect(animalPilot('eden')!.balance.range, 60);
    expect(animalPilot('eden')!.balance.minimumRange, 20);
    await t.pumpWidget(const SizedBox());
  });
  test('six new versioned assets are native high resolution RGBA with preserved originals', () {
    for (final p in ['rabbit', 'turtle']) {
      for (final kind in ['portrait', 'ship', 'hero']) {
        final b = File('assets/tailwing/${p}_${kind}_v2.png').readAsBytesSync();
        expect(b.buffer.asByteData().getUint32(16), 1024);
        expect(b[25], 6);
        if (kind != 'hero' || p == 'rabbit') {
          expect(File('assets/tailwing/${p}_$kind.png').existsSync(), true);
        }
      }
    }
    expect(animalPilots.length, 12);
    expect(animalPilots.where((p) => p.free).map((p) => p.id), [
      'pilot',
      'rion',
      'eden',
    ]);
  });
}
