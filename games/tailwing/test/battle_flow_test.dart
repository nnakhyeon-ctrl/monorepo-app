import 'package:raikeopeu2026/game/combat_model.dart';

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/app.dart';
import 'package:raikeopeu2026/core/readiness.dart';
import 'package:raikeopeu2026/features/battle.dart';
import 'package:raikeopeu2026/game/assets.dart';
import 'package:raikeopeu2026/game/catalog.dart';
import 'package:raikeopeu2026/game/engine.dart';
import 'package:raikeopeu2026/game/rendering.dart';

import 'fixtures.dart';
import 'basic_screens_test.dart' show open, press;

BattleEngine currentGame(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byWidgetPredicate(
                (w) => w is CustomPaint && w.painter is BattlePainter,
              ),
            )
            .painter!
        is BattlePainter
    ? (tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate(
                      (w) => w is CustomPaint && w.painter is BattlePainter,
                    ),
                  )
                  .painter!
              as BattlePainter)
          .game
    : throw StateError('Battle painter unavailable');

class PendingAssets extends BattleAssets {
  final completion = Completer<void>();
  int calls = 0;
  @override
  Future<void> prepare() {
    calls++;
    return completion.future;
  }
}

class FailingAssets extends BattleAssets {
  @override
  Future<void> prepare() async => throw StateError('fictional-private-detail');
}

void main() {
  testWidgets(
    'first battle teaches movement/fire/shield and remembers completion',
    (tester) async {
      final records = FixtureProgress(tutorialDone: false);
      await tester.pumpWidget(
        RaikeopeuApp(
          feedback: FixtureFeedback(),
          appInfo: FixtureAppInfo(),
          progress: records,
          assets: ImmediateAssets(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('startGame')));
      await tester.tap(find.byKey(const Key('startGame')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));
      final g = currentGame(tester), time = currentGame(tester).elapsed;
      await tester.pump(const Duration(seconds: 3));
      expect(g.elapsed, time);
      await tester.drag(
        find.byKey(const Key('battleField')),
        const Offset(35, -20),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('tutorialFire')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('useSkill')));
      await tester.pump(const Duration(milliseconds: 30));
      expect(g.protected, isTrue);
      expect(records.value.tutorialDone, isTrue);
      expect(g.elapsed, greaterThan(time));
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'real collision result unlocks next stage and failure retries immediately',
    (tester) async {
      final records = FixtureProgress();
      await tester.pumpWidget(
        RaikeopeuApp(
          feedback: FixtureFeedback(),
          appInfo: FixtureAppInfo(),
          progress: records,
          assets: ImmediateAssets(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('startGame')));
      await tester.tap(find.byKey(const Key('startGame')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));
      final g = currentGame(tester);
      g.enemies.add(Enemy(const Vec(180, 100), EnemyKind.boss)..health = 10);
      g.bullets.add(Projectile(const Vec(180, 100), Vec.zero, friendly: true));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('작전 완료'), findsOneWidget);
      expect(records.value.unlocked, 2);
      await tester.tap(find.byKey(const Key('nextStage')));
      await tester.pump(const Duration(milliseconds: 30));
      expect(currentGame(tester).stage.number, 2);
      currentGame(tester).health = 0;
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('retryBattle')));
      await tester.pump(const Duration(milliseconds: 30));
      expect(currentGame(tester).health, 3);
      expect(currentGame(tester).elapsed, lessThan(1));
      expect(records.value.records[2]?.cleared, isFalse);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'failed launch clears loading and never exposes exception details',
    (tester) async {
      await tester.pumpWidget(
        RaikeopeuApp(
          feedback: FixtureFeedback(),
          appInfo: FixtureAppInfo(),
          progress: FixtureProgress(),
          assets: FailingAssets(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('startGame')));
      await tester.tap(find.byKey(const Key('startGame')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('전투를 준비하지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);
      expect(find.textContaining('fictional-private-detail'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('startGame')))
            .onPressed,
        isNotNull,
      );
      expect(find.byType(BattleScreen), findsNothing);
    },
  );

  testWidgets(
    'small phone and doubled text keep real battle controls reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        RaikeopeuApp(
          feedback: FixtureFeedback(),
          appInfo: FixtureAppInfo(),
          progress: FixtureProgress(),
          assets: ImmediateAssets(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('startGame')));
      await tester.tap(find.byKey(const Key('startGame')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.ensureVisible(find.byKey(const Key('useSkill')));
      await tester.tap(find.byKey(const Key('useSkill')));
      await tester.pump(const Duration(milliseconds: 20));
      expect(currentGame(tester).protected, isTrue);
      expect(tester.takeException(), isNull);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'start loading blocks duplicate launches and opens exactly one battle',
    (tester) async {
      final assets = PendingAssets();
      await tester.pumpWidget(
        RaikeopeuApp(
          feedback: FixtureFeedback(),
          appInfo: FixtureAppInfo(),
          progress: FixtureProgress(),
          assets: assets,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('startGame')));
      await tester.tap(find.byKey(const Key('startGame')));
      await tester.tap(find.byKey(const Key('startGame')));
      await tester.pump();
      expect(assets.calls, 1);
      expect(find.text('전투 준비 중'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('startGame')))
            .onPressed,
        isNull,
      );
      assets.completion.complete();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(BattleScreen), findsOneWidget);
      expect(
        assets.calls,
        2,
        reason: 'Screen reuses the already completed asset preparation',
      );
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      expect(find.text('출격'), findsOneWidget);
    },
  );

  testWidgets(
    'shield button absorbs damage, blocks repeat use and background pauses battle',
    (tester) async {
      await tester.pumpWidget(
        RaikeopeuApp(
          feedback: FixtureFeedback(),
          appInfo: FixtureAppInfo(),
          progress: FixtureProgress(),
          assets: ImmediateAssets(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('startGame')));
      await tester.tap(find.byKey(const Key('startGame')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));
      final g = currentGame(tester);
      final before = g.player;
      await tester.drag(
        find.byKey(const Key('battleField')),
        const Offset(45, -30),
      );
      expect(g.player.dx, greaterThan(before.dx));
      await tester.tap(find.byKey(const Key('useSkill')));
      await tester.pump(const Duration(milliseconds: 20));
      expect(g.protected, isTrue);
      expect(
        tester.widget<InkWell>(find.byKey(const Key('useSkill'))).onTap,
        isNull,
      );
      g.bullets.add(Projectile(g.player, Vec.zero));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('장갑 3/3'), findsOneWidget);
      final cooldown = g.cooldown;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(g.phase, BattlePhase.paused);
      expect(g.cooldown, cooldown);
      await tester.tap(find.text('계속하기'));
      await tester.pump();
      expect(g.phase, BattlePhase.playing);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'verified restoration unlocks paid character and applies it in next battle',
    (tester) async {
      final repo = FixtureEntitlements(
        SubscriptionAccess(
          AccessStatus.active,
          validUntil: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      await tester.pumpWidget(
        RaikeopeuApp(
          feedback: FixtureFeedback(),
          appInfo: FixtureAppInfo(),
          progress: FixtureProgress(),
          assets: ImmediateAssets(),
          entitlements: repo,
        ),
      );
      await tester.pumpAndSettle();
      await open(tester, AppRoutes.hangar);
      await press(tester, find.byKey(const Key('category-character')));
      await tester.scrollUntilVisible(
        find.byKey(const Key('select-tw_owl')),
        240,
      );
      await tester.ensureVisible(find.byKey(const Key('select-tw_owl')));
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('select-tw_owl')))
            .onPressed,
        isNull,
      );
      await open(tester, AppRoutes.restore);
      await press(tester, find.text('구매 복원 연결 확인'));
      expect(find.text('구독 이용권 확인됨'), findsOneWidget);
      expect(repo.restores, 1);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      await press(tester, find.byKey(const Key('select-tw_owl')));
      expect(find.text('선택됨'), findsWidgets);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('startGame')));
      await tester.tap(find.byKey(const Key('startGame')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));
      expect(currentGame(tester).character, 'tw_owl');
      expect(currentGame(tester).shotDamage, 10);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('actual player sprite decodes with transparent margins', (
    tester,
  ) async {
    final assets = BattleAssets();
    await tester.runAsync(assets.prepare);
    expect(assets.player, isNotNull);
    final data = await tester.runAsync(
      () => assets.player!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    expect(data!.getUint8(3), 0);
    expect(assets.player!.width, 256);
    assets.dispose();
  });
}
