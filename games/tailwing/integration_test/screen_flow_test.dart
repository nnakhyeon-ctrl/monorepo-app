import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raikeopeu2026/app.dart';
import 'package:raikeopeu2026/game/engine.dart';
import 'package:raikeopeu2026/game/rendering.dart';

import 'package:path_provider/path_provider.dart';
import 'package:raikeopeu2026/game/progress.dart';
import 'package:raikeopeu2026/game/combat_model.dart';
import 'package:raikeopeu2026/core/game_feedback.dart';
import 'package:raikeopeu2026/core/readiness.dart';
import 'package:raikeopeu2026/game/catalog.dart';
import 'package:raikeopeu2026/security/backend_session.dart';
import 'package:raikeopeu2026/security/email_auth.dart';
import 'package:raikeopeu2026/security/firebase_email.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../test/fixtures.dart' show FixtureEntitlements;
import '../test/fixtures.dart' show FixtureProgress, FixtureFeedback;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native billing bridge and unconfigured checkout preserve the free guest',
    (tester) async {
      expect(const bool.fromEnvironment('AIRZERO_INTEGRATION'), true);
      // Query service availability only: no product registration, account data,
      // purchase, restore or payment UI. A missing native plugin must fail here.
      final available = await InAppPurchase.instance.isAvailable().timeout(
        const Duration(seconds: 20),
      );
      expect(available, isA<bool>());
      final repository = FixtureProgress()
        ..value.records[1] = const StageRecord(
          cleared: true,
          best: 501,
          attempts: 1,
        );
      final saved = jsonEncode(repository.value.toJson());
      await tester.pumpWidget(
        RaikeopeuApp(progress: repository, feedback: FixtureFeedback()),
      );
      await tester.pumpAndSettle();
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed(AppRoutes.entitlement);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('billingConsent')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('billingConsent')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('billingConsent')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const Key('billingConsent')))
            .value,
        true,
      );
      await tester.ensureVisible(find.byKey(const Key('subscribePurchase')));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('subscribePurchase')))
            .onPressed,
        isNull,
      );
      expect(jsonEncode(repository.value.toJson()), saved);
      expect(tester.takeException(), isNull);
      binding.reportData = {
        'billing': {
          'nativeAvailability': available,
          'unconfiguredCheckoutDisabled': true,
          'storeVerification': 'not_run',
        },
      };
    },
  );

  testWidgets(
    'native social setup failure preserves guest records and settings',
    (tester) async {
      expect(const bool.fromEnvironment('AIRZERO_INTEGRATION'), true);
      final repository = FixtureProgress()
        ..value = CampaignProgress(
          tutorialDone: true,
          sensitivity: 1.25,
          records: {
            1: const StageRecord(cleared: true, best: 777, attempts: 2),
          },
        );
      final saved = jsonEncode(repository.value.toJson());
      final auth = EmailAuthController(initialize: createFirebaseEmailRuntime);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        RaikeopeuApp(
          progress: repository,
          emailAuth: auth,
          feedback: FixtureFeedback(),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed(AppRoutes.account);
      await tester.pumpAndSettle();
      for (final key in ['googleLogin', 'kakaoLogin', 'kakaoAccountLogin']) {
        final button = find.byKey(Key(key));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(auth.phase, EmailPhase.guest);
        expect(auth.hasIdentity, false);
        expect(jsonEncode(repository.value.toJson()), saved);
        expect(find.byKey(const Key('authNotice')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native protected session storage reloads and clears only its fictional scope',
    (tester) async {
      final scope = BackendScope.cloud(
        projectId: 'airzero-strike-native-fixture',
        environment: 'dev',
        region: 'asia-northeast3',
      );
      final vault = SecureSessionVault(scope);
      addTearDown(vault.clear);
      await vault.clear();
      expect(
        await vault.save(
          ServerSession(
            uid: 'fictional_native',
            handle: 'A' * 43,
            expiresAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
            generation: 0,
          ),
        ),
        isTrue,
      );
      final restarted = SecureSessionVault(scope);
      expect((await restarted.load())!.uid, 'fictional_native');
      await vault.clear();
      expect(await restarted.load(), isNull);
    },
  );

  testWidgets(
    'native aviation textures, effects, input and HUD render together',
    (tester) async {
      await tester.pumpWidget(
        RaikeopeuApp(progress: FixtureProgress(), feedback: FixtureFeedback()),
      );
      await tester.pumpAndSettle();
      final services = AppServices.of(
        tester.element(find.byKey(const Key('startGame'))),
      );
      await services.battleAssets.prepare();
      final scene = services.battleAssets;
      expect(scene.enemies, isNotNull);
      expect(scene.explosion, isNotNull);
      expect(scene.cloud, isNotNull);
      expect(scene.coast, isNotNull);
      expect(scene.decodedBytes, lessThan(9 * 1024 * 1024));
      await tester.tap(find.byKey(const Key('startGame')));
      for (
        var i = 0;
        i < 80 && find.byKey(const Key('battleField')).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate(
                      (w) => w is CustomPaint && w.painter is BattlePainter,
                    ),
                  )
                  .painter!
              as BattlePainter;
      expect(identical(painter.assets, scene), isTrue);
      final g = painter.game;
      final previousX = g.player.dx;
      await tester.drag(
        find.byKey(const Key('battleField')),
        const Offset(40, 0),
      );
      expect(g.player.dx, greaterThan(previousX));
      // Synthetic encounter uses the real renderer, collision and skill path.
      g.enemies.clear();
      for (final kind in EnemyKind.values) {
        g.enemies.add(
          Enemy(Vec(45 + kind.index * 80.0, 100), kind)
            ..health = kind == EnemyKind.boss ? g.stage.bossHealth : 1,
        );
      }
      await tester.tap(find.byKey(const Key('useSkill')));
      g.bullets.add(Projectile(g.player, Vec.zero));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(g.health, 3);
      expect(g.protected, isTrue);
      final frames = <FrameTiming>[];
      void timings(List<FrameTiming> values) => frames.addAll(values);
      SchedulerBinding.instance.addTimingsCallback(timings);
      addTearDown(
        () => SchedulerBinding.instance.removeTimingsCallback(timings),
      );
      var peak = g.effects.length;
      for (var i = 0; i < 120; i++) {
        if (i % 15 == 0) {
          final e = g.enemies
              .where((e) => e.kind != EnemyKind.boss)
              .firstOrNull;
          if (e != null) {
            g.bullets.add(Projectile(e.position, Vec.zero, friendly: true));
          }
        }
        await tester.pump(const Duration(milliseconds: 16));
        if (g.effects.length > peak) peak = g.effects.length;
      }
      await tester.tap(find.byKey(const Key('pauseBattle')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('battleHud')), findsOneWidget);
      expect(g.phase, BattlePhase.paused);
      expect(peak, lessThanOrEqualTo(BattleEngine.maxEffects));
      final raster =
          frames.map((f) => f.rasterDuration.inMicroseconds / 1000).toList()
            ..sort();
      final build =
          frames.map((f) => f.buildDuration.inMicroseconds / 1000).toList()
            ..sort();
      double? percentile(List<double> values, double fraction) => values.isEmpty
          ? null
          : double.parse(
              values[((values.length - 1) * fraction).floor()].toStringAsFixed(
                2,
              ),
            );
      final metrics = <String, Object?>{
        'mode': 'Android emulator debug; synthetic encounter',
        'decoded_bytes': scene.decodedBytes,
        'effects_peak': peak,
        'frames': frames.length,
        'raster_p50_ms': percentile(raster, .5),
        'raster_p95_ms': percentile(raster, .95),
        'build_p95_ms': percentile(build, .95),
      };
      binding.reportData = {'aviation_graphics': metrics};
      debugPrint('AIRZERO_GRAPHICS_METRICS ${jsonEncode(metrics)}');
    },
  );

  testWidgets(
    'native preparation saves selected loadout, rechecks rights and launches matching sprite',
    (tester) async {
      final directory = await (await getTemporaryDirectory()).createTemp(
        'airzero_loadout_native_fixture_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final access = FixtureEntitlements(
        SubscriptionAccess(
          AccessStatus.active,
          validUntil: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      final repository = FileProgressRepository(
        directory: () async => directory,
      );
      await repository.read();
      await repository.write(
        CampaignProgress(
          tutorialDone: true,
          records: {
            1: const StageRecord(cleared: true, best: 850, attempts: 2),
          },
        ),
      );
      await tester.pumpWidget(
        RaikeopeuApp(progress: repository, entitlements: access),
      );
      await tester.pumpAndSettle();
      AppServices services() => AppServices.of(
        tester.element(find.byKey(const Key('startGame'), skipOffstage: false)),
      );
      await services().loadout.ready;
      await services().loadout.refresh();
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed(AppRoutes.hangar);
      await tester.pumpAndSettle();
      Future<void> press(Finder target) async {
        if (target.evaluate().isEmpty) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).last)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          if (target.evaluate().isEmpty) {
            await tester.scrollUntilVisible(target, 230);
          }
        }
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await press(find.byKey(const Key('select-vector')));
      await press(find.byKey(const Key('category-skill')));
      await press(find.byKey(const Key('select-pulse')));
      await press(find.byKey(const Key('category-character')));
      await press(find.byKey(const Key('select-eden')));
      await press(find.byKey(const Key('category-equipment')));
      await press(find.byKey(const Key('select-prism')));
      await services().campaign.save();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final restarted = FileProgressRepository(
        directory: () async => directory,
      );
      final saved = await restarted.read();
      expect(saved.progress.loadout.toJson(), {
        'aircraft': 'vector',
        'skill': 'pulse',
        'character': 'eden',
        'equipment': 'prism',
      });
      expect(saved.progress.records[1]!.best, 850);
      await tester.pumpWidget(
        RaikeopeuApp(
          key: const ValueKey('loadout-restart'),
          progress: restarted,
          entitlements: access,
        ),
      );
      await tester.pumpAndSettle();
      await services().loadout.ready;
      expect(
        services().loadout.effectiveSelected(CatalogCategory.aircraft),
        'aurora',
      );
      await services().loadout.refresh();
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed(AppRoutes.hangar);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('launchLoadout')),
        250,
      );
      await tester.ensureVisible(find.byKey(const Key('launchLoadout')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('launchLoadout')));
      for (
        var i = 0;
        i < 80 && find.byKey(const Key('battleField')).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate(
                      (w) => w is CustomPaint && w.painter is BattlePainter,
                    ),
                  )
                  .painter!
              as BattlePainter;
      final g = painter.game;
      expect(
        [g.aircraft, g.skill, g.character, g.equipment],
        ['vector', 'pulse', 'eden', 'prism'],
      );
      final battleServices = AppServices.of(
        tester.element(find.byKey(const Key('battleField'))),
      );
      expect(
        identical(
          painter.playerImage,
          battleServices.battleAssets.imageFor('vector'),
        ),
        isTrue,
      );
      expect(g.moveSpeed, 1.15);
      expect(g.maxHealth, 3);
      g.bullets.add(Projectile(const Vec(30, 80), Vec.zero));
      await tester.tap(find.byKey(const Key('useSkill')));
      await tester.pump(const Duration(milliseconds: 30));
      expect(g.bullets.where((b) => !b.friendly), isEmpty);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await press(find.text('홈으로 이동'));
      expect(battleServices.campaign.progress.records[1]!.best, 850);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native file records, result, sequential unlock and quick retry',
    (tester) async {
      // Isolated fictitious records; preserve the user's default app data.
      final directory = await (await getTemporaryDirectory()).createTemp(
        'airzero_native_fixture_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final repository = FileProgressRepository(
        directory: () async => directory,
      );
      await repository.read();
      await repository.write(CampaignProgress(tutorialDone: true));
      await tester.pumpWidget(RaikeopeuApp(progress: repository));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('startGame')));
      await tester.tap(find.byKey(const Key('startGame')));
      for (
        var i = 0;
        i < 80 && find.byKey(const Key('battleField')).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      BattleEngine current() =>
          (tester
                      .widget<CustomPaint>(
                        find.byWidgetPredicate(
                          (w) => w is CustomPaint && w.painter is BattlePainter,
                        ),
                      )
                      .painter!
                  as BattlePainter)
              .game;
      Future<void> finish(bool win) async {
        final g = current();
        if (win) {
          g.enemies.clear();
          g.bullets.clear();
          g.enemies.add(Enemy(const Vec(180, 80), EnemyKind.boss)..health = 10);
          g.bullets.add(
            Projectile(const Vec(180, 80), Vec.zero, friendly: true),
          );
        } else {
          g.health = 0;
        }
        // Synthetic terminal fixture exercises the real collision and native
        // result-save flow; it is not a full-duration human stage clear.
        await tester.pump(const Duration(milliseconds: 30));
        await tester.pumpAndSettle();
        for (
          var i = 0;
          i < 40 && find.text('기록 저장 중…').evaluate().isNotEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.textContaining('기기 기록 저장 완료'), findsOneWidget);
      }

      for (var stage = 1; stage <= 3; stage++) {
        expect(current().stage.number, stage);
        if (stage == 2) {
          await finish(false);
          await tester.tap(find.byKey(const Key('retryBattle')));
          await tester.pump(const Duration(milliseconds: 30));
          expect(current().health, 3);
          expect(current().elapsed, lessThan(1));
        }
        await finish(true);
        if (stage < 3) {
          await tester.tap(find.byKey(const Key('nextStage')));
          await tester.pump(const Duration(milliseconds: 30));
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final restarted = FileProgressRepository(
        directory: () async => directory,
      );
      final read = await restarted.read();
      expect(read.progress.unlocked, 4);
      expect(read.progress.records[2]!.attempts, 2);
      expect(read.progress.records[1]!.best, 1000);
      await tester.pumpWidget(
        RaikeopeuApp(key: const ValueKey('restarted'), progress: restarted),
      );
      await tester.pumpAndSettle();
      // File I/O can finish after pumpAndSettle sees no scheduled animation.
      // Wait for the real campaign read rather than assuming one frame did it.
      final campaign = AppServices.of(
        tester.element(find.byKey(const Key('startGame'))),
      ).campaign;
      for (var i = 0; i < 80 && !campaign.loaded; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(campaign.loaded, true);
      expect(find.textContaining('작전 04'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Android free combat, shield, selection and unconnected restoration',
    (tester) async {
      final directory = await (await getTemporaryDirectory()).createTemp(
        'airzero_controls_fixture_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final audio = LocalFeedbackBackend();
      await tester.pumpWidget(
        RaikeopeuApp(
          progress: FileProgressRepository(directory: () async => directory),
          feedback: audio,
        ),
      );
      await tester.pumpAndSettle();

      Future<void> press(Finder target) async {
        if (target.evaluate().isEmpty) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).last)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          if (target.evaluate().isEmpty) {
            await tester.scrollUntilVisible(target, 240);
          }
        }
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      Future<void> back() => press(find.byType(BackButton));

      await tester.ensureVisible(find.byKey(const Key('startGame')));
      await tester.tap(find.byKey(const Key('startGame')));
      for (
        var i = 0;
        i < 60 && find.byKey(const Key('battleField')).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const Key('battleField')), findsOneWidget);
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate(
                      (w) => w is CustomPaint && w.painter is BattlePainter,
                    ),
                  )
                  .painter!
              as BattlePainter;
      final game = painter.game;
      expect(game.character, 'pilot');
      expect(game.skill, 'barrier');
      final before = game.player;
      await tester.drag(
        find.byKey(const Key('battleField')),
        const Offset(60, -35),
      );
      await tester.pump(const Duration(milliseconds: 30));
      expect(game.player.dx, greaterThan(before.dx));
      if (find.byKey(const Key('tutorialFire')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('tutorialFire')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('useSkill')));
      await tester.pump(const Duration(milliseconds: 30));
      expect(game.protected, isTrue);
      final feedback = AppServices.of(
        tester.element(find.byKey(const Key('battleField'))),
      ).feedback;
      await feedback.idle;
      final audioBefore = await audio.musicPosition;
      await tester.pump(const Duration(milliseconds: 400));
      final audioAfter = await audio.musicPosition;
      expect(feedback.failed, isFalse);
      expect(audioBefore, isNotNull);
      expect(audioAfter, greaterThan(audioBefore!));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('useSkill')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('pauseBattle')));
      await tester.pumpAndSettle();
      final cooldown = game.cooldown;
      await tester.pump(const Duration(seconds: 1));
      expect(game.cooldown, cooldown);
      expect(game.phase, BattlePhase.paused);
      await back();
      expect(find.text('홈으로 이동할까요?'), findsOneWidget);
      await press(find.text('홈으로 이동'));

      await press(find.byTooltip('조작 방법'));
      expect(find.text('무료 보호막'), findsOneWidget);
      await back();
      expect(
        find.text('구독 관리'),
        findsNothing,
        reason: 'Purchasing belongs in settings',
      );
      await press(find.text('전투기·장비'));
      await press(find.byKey(const Key('category-character')));
      await press(find.byKey(const Key('catalog-rion')));
      expect(find.textContaining('유효 이용권을 확인한 뒤에만'), findsOneWidget);
      await press(find.text('환경설정에서 구독 보기'));
      await press(find.text('구독 관리'));
      await press(find.byKey(const Key('subscription-annual')));
      expect(find.textContaining('연간 총 결제액'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('subscribePurchase')))
            .onPressed,
        isNull,
      );
      await press(find.text('구독 구매 복원'));
      await press(find.text('구매 복원 연결 확인'));
      expect(find.text('연결 준비 중입니다'), findsOneWidget);
      expect(find.text('구독 이용권 확인됨'), findsNothing);
      await back();
      await back();
      await back();
      await back();
      expect(find.text('AIRZERO\nSTRIKE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native device settings survive restart and local audio assets play and pause',
    (tester) async {
      final directory = await (await getTemporaryDirectory()).createTemp(
        'airzero_settings_fixture_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final backend = LocalFeedbackBackend();
      await tester.pumpWidget(
        RaikeopeuApp(
          progress: FileProgressRepository(directory: () async => directory),
          feedback: backend,
        ),
      );
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      final services = AppServices.of(
        tester.element(find.byKey(const Key('startGame'))),
      );
      await services.campaign.ready;
      navigator.pushNamed(AppRoutes.settings);
      await tester.pumpAndSettle();
      Future<void> press(Finder target) async {
        if (target.evaluate().isEmpty) {
          await tester.scrollUntilVisible(target, 220);
        }
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await press(find.text('배경음 2초 미리 듣기'));
      await services.feedback.idle;
      expect(services.feedback.failed, isFalse);
      expect(backend.musicPlaying, isTrue);
      await press(find.byKey(const Key('musicToggle')));
      await services.feedback.idle;
      expect(backend.musicPlaying, isFalse);
      await press(find.text('효과음 확인'));
      await services.feedback.idle;
      expect(backend.lastEffect, FeedbackCue.skill);
      await press(find.byKey(const Key('vibrationToggle')));
      await press(find.text('진동 확인'));
      await press(find.byKey(const Key('sensitivity-1.25')));
      final context = tester.element(find.byKey(const Key('motionToggle')));
      final campaign = AppServices.of(context).campaign;
      await campaign.save();
      expect(AppServices.of(context).feedback.failed, isFalse);
      expect(campaign.progress.options.music, isFalse);
      expect(campaign.progress.options.vibration, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final repository = FileProgressRepository(
        directory: () async => directory,
      );
      final saved = await repository.read();
      expect(saved.progress.options.music, isFalse);
      expect(saved.progress.options.vibration, isTrue);
      expect(saved.progress.sensitivity, 1.25);
      await tester.pumpWidget(
        RaikeopeuApp(
          key: const ValueKey('settings-restart'),
          progress: repository,
        ),
      );
      await tester.pumpAndSettle();
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed(AppRoutes.support);
      await tester.pumpAndSettle();
      expect(find.textContaining('앱 버전 0.1.0 (1)'), findsOneWidget);
      expect(find.text('문의 경로 등록 대기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
