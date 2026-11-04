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
import 'package:raikeopeu2026/game/animal_roster.dart';
import 'package:raikeopeu2026/game/catalog.dart';
import 'package:raikeopeu2026/game/engine.dart';
import 'package:raikeopeu2026/game/rendering.dart';

import '../test/fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'twelve original pilots: native synthetic selection combat and isolation',
    (tester) async {
      expect(const bool.fromEnvironment('AIRZERO_INTEGRATION'), true);
      expect(
        (await PackageInfo.fromPlatform()).packageName,
        'com.example.raikeopeu2026.dev.integration',
      );
      final repo = FixtureProgress(),
          rights = FixtureEntitlements(
            SubscriptionAccess(
              AccessStatus.active,
              validUntil: DateTime.now().add(const Duration(hours: 1)),
            ),
          );
      const key = Key('tailwingCapture');
      final timings = <FrameTiming>[];
      void frames(List<FrameTiming> f) {
        timings.addAll(f);
      }

      SchedulerBinding.instance.addTimingsCallback(frames);
      final watch = Stopwatch()..start();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: RaikeopeuApp(
            progress: repo,
            feedback: FixtureFeedback(),
            entitlements: rights,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final services = AppServices.of(
        tester.element(find.byKey(const Key('startGame'))),
      );
      await services.loadout.refresh();
      final directory = Directory(
        '${(await getApplicationSupportDirectory()).path}/tailwing_roster_capture_v1',
      );
      await directory.create(recursive: true);
      Future<void> capture(String name) async {
        await tester.pump();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        final picture = await boundary.toImage(
          pixelRatio: tester.view.devicePixelRatio,
        );
        try {
          expect(picture.width, 1080);
          expect(picture.height, 1920);
          final b = (await picture.toByteData(format: ui.ImageByteFormat.png))!;
          await File('${directory.path}/$name.png').writeAsBytes(
            b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes),
          );
        } finally {
          picture.dispose();
        }
      }

      await capture('00-home');
      final loading = <String, int>{};
      for (final p in animalPilots) {
        final timer = Stopwatch()..start();
        await services.battleAssets.preparePilot(p.id);
        loading[p.art] = timer.elapsedMilliseconds;
        expect(services.loadout.select(catalogEntry(p.id)), true);
        expect(services.loadout.select(catalogEntry('signature')), true);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('startGame')));
        await tester.tap(find.byKey(const Key('startGame')));
        for (var i = 0; i < 80; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (find.byKey(const Key('battleField')).evaluate().isNotEmpty) break;
        }
        expect(find.byKey(const Key('battleField')), findsOneWidget);
        BattleEngine game() => tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<BattlePainter>()
            .single
            .game;
        final g = game();
        expect(g.character, p.id);
        expect(g.skill, 'signature');
        expect(g.animal.beacons, isEmpty);
        if (p.id == 'pilot') {
          for (var i = 0; i < 100; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(g.enemies, isNotEmpty);
        }
        // Real input path, actual renderer and skill button. No enemy/score injection.
        for (var i = 0; i < 8; i++) {
          await tester.drag(
            find.byKey(const Key('battleField')),
            Offset(i.isEven ? 14 : -8, 0),
          );
          await tester.pump(const Duration(milliseconds: 130));
        }
        await tester.ensureVisible(find.byKey(const Key('useSkill')));
        await tester.tap(find.byKey(const Key('useSkill')));
        await tester.pump(const Duration(milliseconds: 100));
        expect(g.cooldown, greaterThan(0));
        expect(g.animal.active, true);
        await capture(p.art);
        // Fast deterministic model expiry is separate from real-time/device performance.
        for (var i = 0; i < (p.balance.duration / .05).ceil() + 2; i++) {
          g.step(.05);
        }
        expect(g.animalActive, false);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byType(BackButton).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('홈으로 이동'));
        await tester.pumpAndSettle();
        expect(
          repo.value.records,
          isEmpty,
          reason: 'cancelled preview combats never settle records',
        );
      }
      expect(services.battleAssets.decodedBytes, lessThan(15 * 1024 * 1024));
      rights.result = const SubscriptionAccess(AccessStatus.inactive);
      await services.loadout.refresh();
      expect(services.loadout.selected(CatalogCategory.character), 'pilot');
      expect(services.loadout.selected(CatalogCategory.skill), 'barrier');
      expect(services.loadout.select(catalogEntry('signature')), false);
      for (final p in animalPilots) {
        expect(services.loadout.canUse(catalogEntry(p.id)), p.free);
      }
      SchedulerBinding.instance.removeTimingsCallback(frames);
      watch.stop();
      double percentile(List<int> values, double p) {
        if (values.isEmpty) return 0;
        values.sort();
        return values[((values.length - 1) * p).floor()] / 1000;
      }

      await File('${directory.path}/metrics.json').writeAsString(
        jsonEncode({
          'scope': 'DEBUG_EMULATOR_SYNTHETIC_NOT_REAL_SERVER_STORE_OR_DEVICE',
          'pilots': 12,
          'decodedBytes': services.battleAssets.decodedBytes,
          'loadMilliseconds': loading,
          'elapsedMilliseconds': watch.elapsedMilliseconds,
          'frames': timings.length,
          'buildP95ms': percentile(
            timings.map((f) => f.buildDuration.inMicroseconds).toList(),
            .95,
          ),
          'rasterP95ms': percentile(
            timings.map((f) => f.rasterDuration.inMicroseconds).toList(),
            .95,
          ),
          'expiry': 'deterministic_model_steps_after_native_UI_activation',
          'recordsSettled': repo.value.records.length,
        }),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
