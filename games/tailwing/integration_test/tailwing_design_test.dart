import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:raikeopeu2026/app.dart';
import 'package:raikeopeu2026/core/readiness.dart';
import 'package:raikeopeu2026/core/game_feedback.dart';
import 'package:raikeopeu2026/game/catalog.dart';
import 'package:raikeopeu2026/game/engine.dart';
import 'package:raikeopeu2026/game/rendering.dart';

import '../test/fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('design pass native screens and unchanged purchase boundary', (
    t,
  ) async {
    expect(const bool.fromEnvironment('AIRZERO_INTEGRATION'), true);
    expect(
      (await PackageInfo.fromPlatform()).packageName,
      'com.example.raikeopeu2026.dev.integration',
    );
    const before = bool.fromEnvironment('TAILWING_DESIGN_BEFORE');
    final dir = await Directory(
      '${(await getApplicationSupportDirectory()).path}/tailwing_design_${before ? 'before' : 'after'}',
    ).create(recursive: true);
    const key = Key('designCapture');
    final repo = FixtureProgress();
    final timings = <FrameTiming>[];
    void collectFrames(List<FrameTiming> values) => timings.addAll(values);
    SchedulerBinding.instance.addTimingsCallback(collectFrames);
    addTearDown(
      () => SchedulerBinding.instance.removeTimingsCallback(collectFrames),
    );
    final rights = FixtureEntitlements(
      const SubscriptionAccess(AccessStatus.inactive),
    );
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: RaikeopeuApp(
          progress: repo,
          entitlements: rights,
          feedback: FixtureFeedback(),
        ),
      ),
    );
    await t.pumpAndSettle();
    final s = AppServices.of(t.element(find.byKey(const Key('startGame'))));
    await s.loadout.ready;
    Future<void> capture(String name) async {
      await t.pump(const Duration(milliseconds: 100));
      final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final frame = await boundary.toImage(pixelRatio: t.view.devicePixelRatio);
      try {
        final data = (await frame.toByteData(format: ui.ImageByteFormat.png))!;
        await File('${dir.path}/$name.png').writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      } finally {
        frame.dispose();
      }
    }

    await capture('home-rabbit');
    expect(s.loadout.select(catalogEntry('eden')), true);
    await t.pumpAndSettle();
    await capture('home-turtle');
    Navigator.of(t.element(find.byKey(const Key('startGame'))))
        .pushNamed(AppRoutes.hangar);
    await t.pumpAndSettle();
    await capture('hangar-top');
    await t.scrollUntilVisible(find.byKey(const Key('catalog-pilot')), 240);
    await t.ensureVisible(find.byKey(const Key('catalog-pilot')));
    if (!before) {
      await t.ensureVisible(find.byKey(const Key('character-card-pilot')));
    }
    await t.pumpAndSettle();
    await capture('hangar-cards');
    expect(s.loadout.select(catalogEntry('tw_bear')), false);
    expect(s.loadout.select(catalogEntry('signature')), false);
    await t.tap(find.byType(BackButton).first);
    await t.pumpAndSettle();
    // Synthetic rights live only inside this native test, never the runtime app.
    rights.result = SubscriptionAccess(
      AccessStatus.active,
      validUntil: DateTime.now().add(const Duration(hours: 1)),
    );
    await s.loadout.refresh();
    expect(s.loadout.select(catalogEntry('signature')), true);
    await t.ensureVisible(find.byKey(const Key('startGame')));
    await t.tap(find.byKey(const Key('startGame')));
    BattleEngine? game;
    for (var i = 0; i < 100 && game == null; i++) {
      await t.pump(const Duration(milliseconds: 100));
      game = t
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<BattlePainter>()
          .firstOrNull
          ?.game;
    }
    final g = game!;
    expect(g.character, 'eden');
    await t.tap(find.byKey(const Key('useSkill')));
    await t.pump(const Duration(milliseconds: 100));
    expect(g.animalActive, true);
    expect(g.animal.durability, 5);
    await capture('shield-active');
    for (var i = 0; i < 64; i++) {
      g.step(.05);
    }
    await t.pump(const Duration(milliseconds: 100));
    expect(g.animalActive, false);
    expect(g.animal.durability, 0);
    await capture('shield-ended');
    if (!before) {
      await t.tap(find.byType(BackButton).first);
      await t.pumpAndSettle();
      await t.tap(find.text('홈으로 이동'));
      await t.pumpAndSettle();
      expect(s.loadout.select(catalogEntry('pilot')), true);
      await t.tap(find.byKey(const Key('startGame')));
      BattleEngine? rabbit;
      for (var i = 0; i < 100 && rabbit == null; i++) {
        await t.pump(const Duration(milliseconds: 100));
        rabbit = t
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((p) => p.painter)
            .whereType<BattlePainter>()
            .firstOrNull
            ?.game;
      }
      expect(rabbit!.character, 'pilot');
      for (var i = 0; i < 100; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      for (var i = 0; i < 8; i++) {
        await t.drag(
          find.byKey(const Key('battleField')),
          Offset(i.isEven ? 12 : -8, 0),
        );
        await t.pump(const Duration(milliseconds: 80));
      }
      await t.tap(find.byKey(const Key('useSkill')));
      await t.pump(const Duration(milliseconds: 50));
      expect(rabbit.animalActive, true);
      expect(rabbit.animal.stitch, isNotEmpty);
      await capture('rabbit-combat');
    }
    expect(repo.value.records, isEmpty);
    rights.result = const SubscriptionAccess(AccessStatus.inactive);
    await s.loadout.refresh();
    expect(s.loadout.canUse(catalogEntry('signature')), false);
    expect(s.loadout.selected(CatalogCategory.skill), 'barrier');
    var nativeAudioTransport = false;
    if (!before) {
      final audio = LocalFeedbackBackend();
      try {
        await audio.music(true, .22);
        for (var i = 0; i < 12 && !nativeAudioTransport; i++) {
          await t.pump(const Duration(milliseconds: 250));
          final position = await audio.musicPosition;
          nativeAudioTransport =
              audio.musicPlaying &&
              position != null &&
              position.inMilliseconds > 0;
        }
        expect(nativeAudioTransport, true);
        await audio.music(false, .22);
        expect(audio.musicPlaying, false);
      } finally {
        await audio.dispose();
      }
    }
    await File('${dir.path}/checks.json').writeAsString(
      jsonEncode({
        'scope': 'NATIVE_ANDROID_EMULATOR_SYNTHETIC_NOT_PHYSICAL_OR_LIVE',
        'before': before,
        'screens': before ? 6 : 7,
        'freeSelection': true,
        'lockedSignature': true,
        'shieldCount': 5,
        'shieldExpiry': true,
        'recordsUnchanged': true,
        'decodedBytes': s.battleAssets.decodedBytes,
        'imageCacheBytes': PaintingBinding.instance.imageCache.currentSizeBytes,
        'frames': timings.length,
        'buildOver16ms': timings
            .where((f) => f.buildDuration.inMicroseconds > 16667)
            .length,
        'rasterOver16ms': timings
            .where((f) => f.rasterDuration.inMicroseconds > 16667)
            .length,
        'performanceScope':
            'SHORT_DEBUG_EMULATOR_SAMPLE_NOT_DEVICE_PERFORMANCE_PASS',
        'nativeAudioTransport': before
            ? 'NOT_RUN_BEFORE'
            : nativeAudioTransport,
        'physicalSpeakerListening': 'NOT_VERIFIED',
      }),
    );
    await t.pumpWidget(const SizedBox());
  });
}
