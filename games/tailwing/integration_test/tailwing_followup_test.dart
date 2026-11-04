import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:raikeopeu2026/app.dart';
import 'package:raikeopeu2026/core/readiness.dart';
import 'package:raikeopeu2026/game/animal_roster.dart';
import 'package:raikeopeu2026/game/combat_model.dart';
import 'package:raikeopeu2026/game/engine.dart';
import 'package:raikeopeu2026/game/rendering.dart';

import '../test/fixtures.dart';

const captureKey = Key('followupCapture');
Future<Directory> output() async {
  final dir = Directory(
    '${(await getApplicationSupportDirectory()).path}/tailwing_followup_v1',
  );
  return dir.create(recursive: true);
}

Future<void> capture(WidgetTester tester, String name) async {
  await tester.pump();
  final b = tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
  final picture = await b.toImage(pixelRatio: tester.view.devicePixelRatio);
  try {
    final data = (await picture.toByteData(format: ui.ImageByteFormat.png))!;
    await File('${(await output()).path}/$name.png').writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } finally {
    picture.dispose();
  }
}

BattleEngine? game(WidgetTester tester) {
  final painters = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<BattlePainter>();
  return painters.isEmpty ? null : painters.single.game;
}

Future<BattleEngine> waitForGame(WidgetTester tester, String id) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    final g = game(tester);
    if (g != null && g.character == id) return g;
  }
  throw StateError('native_game_not_ready');
}

Future<void> press(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    // Materialize lazy ListView children before locating a keyed button.
    final position = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .last
        .position;
    position.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
      position.jumpTo(
        math.min(position.pixels + 300, position.maxScrollExtent),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  await tester.ensureVisible(finder);
  // The battle ticker intentionally runs continuously; don't wait for idle.
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 30));
}

// Automated steering through the same model input/clamp, not human dexterity.
// No health/score/enemy injection or shortened stage is used in the full run.
void steerFreeKit(BattleEngine g) {
  var bestX = g.player.dx, bestCost = double.infinity;
  final targets =
      g.enemies.where((e) => e.health > 0 && e.position.dy < 350).toList()
        ..sort((a, b) => b.position.dy.compareTo(a.position.dy));
  final targetX = targets.isEmpty ? 180.0 : targets.first.position.dx;
  for (var x = 25.0; x <= 335; x += 10) {
    var cost = (x - targetX).abs() * .1 + (x - g.player.dx).abs() * .2;
    for (final b in g.bullets.where((b) => !b.friendly)) {
      for (final t in [.1, .25, .5, .8]) {
        final futureX =
            g.player.dx + (x - g.player.dx).clamp(-240 * t, 240 * t);
        final d = (b.position + b.velocity * t - Vec(futureX, 510)).distance;
        cost += 2000 / (1 + math.pow(d / 16, 2));
      }
    }
    for (final e in g.enemies.where((e) => e.position.dy > 410)) {
      cost += 5000 / (1 + math.pow((x - e.position.dx) / 50, 2));
    }
    if (cost < bestCost) {
      bestCost = cost;
      bestX = x;
    }
  }
  g.moveBy(Vec((bestX - g.player.dx).clamp(-12, 12).toDouble(), 0));
  if (g.bullets.any(
    (b) => !b.friendly && (b.position - g.player).distance < 75,
  )) {
    g.activateSkill();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final dir = await output();
    for (final name in [
      'lab-turtle.png',
      'lab-squirrel.png',
      'lab-frog.png',
      'lab.json',
      if (!const bool.fromEnvironment('TAILWING_LAB_ONLY')) ...[
        'boss.png',
        'result.png',
        'retry.png',
        'flow.json',
      ],
    ]) {
      final file = File('${dir.path}/$name');
      if (await file.exists()) await file.delete();
    }
  });
  setUp(() async {
    expect(const bool.fromEnvironment('AIRZERO_INTEGRATION'), true);
    expect(
      (await PackageInfo.fromPlatform()).packageName,
      'com.example.raikeopeu2026.dev.integration',
    );
  });
  testWidgets(
    'debug research lab exposes all twelve without subscription grants',
    (tester) async {
      final repo = FixtureProgress();
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: RaikeopeuApp(progress: repo, feedback: FixtureFeedback()),
        ),
      );
      await tester.pumpAndSettle();
      final services = AppServices.of(
        tester.element(find.byKey(const Key('startGame'))),
      );
      expect(services.loadout.premiumActive, false);
      await press(tester, find.byKey(const Key('animalLab')));
      await waitForGame(tester, 'pilot');
      final checked = <String>[];
      for (final p in animalPilots) {
        await press(tester, find.byKey(Key('trial-${p.id}')));
        final g = await waitForGame(tester, p.id);
        expect(services.battleAssets.pilotImageFor(p.id), isNotNull);
        expect(g.animal.beacons, isEmpty);
        await press(tester, find.byKey(const Key('trialSkill')));
        expect(g.animalActive, true);
        if (['eden', 'tw_squirrel', 'tw_chameleon'].contains(p.id)) {
          await tester.ensureVisible(find.byKey(const Key('trialField')));
          await tester.pump(const Duration(milliseconds: 30));
          await capture(tester, 'lab-${p.art}');
        }
        for (var i = 0; i < (p.balance.duration / .05).ceil() + 2; i++) {
          g.step(.05);
        }
        expect(g.animalActive, false);
        expect(g.animal.durability, 0);
        expect(g.animal.anchor, isNull);
        expect(g.animal.beacons, isEmpty);
        await press(tester, find.byKey(const Key('trialRestart')));
        final retry = await waitForGame(tester, p.id);
        expect(identical(g, retry), false);
        expect(retry.cooldown, 0);
        expect(retry.animal.beacons, isEmpty);
        expect(retry.animal.captured, isEmpty);
        expect(retry.health, retry.maxHealth);
        expect(services.loadout.premiumActive, false);
        expect(repo.value.records, isEmpty);
        checked.add(p.id);
      }
      await File('${(await output()).path}/lab.json').writeAsString(
        jsonEncode({
          'scope': 'native_debug_lab_synthetic_no_real_entitlements',
          'pilots': checked,
          'records': repo.value.records.length,
          'normalPremiumGranted': services.loadout.premiumActive,
          'expiry': 'model_steps_after_native_button_activation',
        }),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'native stage one spawn to boss result and retry with normal free kit',
    (tester) async {
      final repo = FixtureProgress();
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: RaikeopeuApp(progress: repo, feedback: FixtureFeedback()),
        ),
      );
      await tester.pumpAndSettle();
      await press(tester, find.byKey(const Key('startGame')));
      final g = await waitForGame(tester, 'pilot');
      expect(g.skill, 'barrier');
      var bossSeen = false, frames = 0;
      final watch = Stopwatch()..start();
      while (g.phase == BattlePhase.playing && frames < 6500) {
        steerFreeKit(g);
        await tester.pump(const Duration(milliseconds: 50));
        if (!bossSeen && g.enemies.any((e) => e.kind == EnemyKind.boss)) {
          bossSeen = true;
          await capture(tester, 'boss');
        }
        if (frames % 600 == 0) {
          debugPrint(
            'TAILWING FLOW: simulation ${g.elapsed.floor()}s, health ${g.health}, boss $bossSeen',
          );
        }
        frames++;
      }
      await tester.pumpAndSettle();
      watch.stop();
      await capture(tester, 'result');
      await File('${(await output()).path}/flow.json').writeAsString(
        jsonEncode({
          'scope': 'actual_native_flutter_UI_automated_steering_not_human_or_physical_device',
          'stage': g.stage.number,
          'phase': g.phase.name,
          'seconds': g.elapsed,
          'bossSeen': bossSeen,
          'framesPumped': frames,
          'wallMilliseconds': watch.elapsedMilliseconds,
          'health': g.health,
          'score': g.score,
          'recordCleared': repo.value.records[1]?.cleared,
          'stageDurationShortened': false,
          'enemiesHealthScoreInjected': false,
        }),
      );
      expect(bossSeen, true);
      expect(g.phase, BattlePhase.won);
      expect(g.elapsed, greaterThan(180));
      expect(repo.value.records[1]?.cleared, true);
      expect(repo.value.unlocked, 2);
      expect(g.animal.active, false);
      await press(tester, find.byKey(const Key('retryBattle')));
      final retry = await waitForGame(tester, 'pilot');
      expect(identical(g, retry), false);
      expect(retry.elapsed, lessThan(1));
      expect(retry.health, retry.maxHealth);
      expect(retry.cooldown, 0);
      expect(retry.animal.beacons, isEmpty);
      await capture(tester, 'retry');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
