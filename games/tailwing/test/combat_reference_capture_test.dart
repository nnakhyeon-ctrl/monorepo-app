// Explicit, synthetic local review only. Never captures a desktop or account.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/app.dart';
import 'package:raikeopeu2026/core/readiness.dart';
import 'package:raikeopeu2026/game/assets.dart';
import 'package:raikeopeu2026/game/combat_model.dart';
import 'package:raikeopeu2026/game/engine.dart';
import 'package:raikeopeu2026/game/catalog.dart';
import 'package:raikeopeu2026/game/advanced_skill_catalog.dart';

import 'battle_flow_test.dart' show currentGame;
import 'fixtures.dart';

void main() {
  const label = String.fromEnvironment('TAILWING_REVIEW');
  testWidgets('export actual app with synthetic combat for local review', (
    t,
  ) async {
    if (!['before', 'after'].contains(label)) return;
    t.view.physicalSize = const Size(396, 860);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final assets = BattleAssets();
    await t.runAsync(() async {
      // Local OS font only for review, never copied into the app/repository.
      final korean = FontLoader('Roboto')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              await File('C:/Windows/Fonts/malgun.ttf').readAsBytes(),
            ),
          ),
        );
      await korean.load();
      final defaultTestFont = FontLoader('Ahem')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              await File('C:/Windows/Fonts/malgun.ttf').readAsBytes(),
            ),
          ),
        );
      await defaultTestFont.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              await File(
                Platform.environment['TAILWING_REVIEW_ICONS'] ?? '../../flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
              ).readAsBytes(),
            ),
          ),
        );
      await icons.load();
      await assets.prepare();
      await assets.preparePilot('pilot');
    });
    final frame = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: frame,
        child: RaikeopeuApp(
          assets: assets,
          progress: FixtureProgress(),
          feedback: FixtureFeedback(),
          appInfo: FixtureAppInfo(),
          entitlements: FixtureEntitlements(
            SubscriptionAccess(
              AccessStatus.active,
              validUntil: DateTime.now().add(const Duration(hours: 1)),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('startGame')));
    await t.tap(find.byKey(const Key('startGame')));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await t.pump(const Duration(milliseconds: 300));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await t.pump(const Duration(milliseconds: 100));
    final g = currentGame(t);
    Future<void> saveFrame(String name) async {
      await t.runAsync(() async {
        final boundary =
            frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        image.dispose();
        final output = File('docs/combat-pass-2026-11-05/$name.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(
          png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
        );
      });
    }

    g.elapsed = 45;
    g.score = 2400;
    g.enemies.clear();
    for (var i = 0; i < 3; i++) {
      g.enemies.add(
        Enemy(Vec(78 + i * 100.0, 130 + i % 2 * 35.0), EnemyKind.values[i]),
      );
    }
    g.bullets.clear();
    for (var i = 0; i < 13; i++) {
      final angle = -.9 + i * .15;
      g.bullets.add(
        Projectile(
          Vec(180 + math.sin(angle) * 170, 150 + math.cos(angle) * 210),
          Vec(math.sin(angle) * 120, math.cos(angle) * 120),
        ),
      );
    }
    g.moveBy(const Vec(25, 0));
    g.activateSkill();
    await t.pump(const Duration(milliseconds: 100));
    await saveFrame(label);
    if (label == 'after') {
      final s = AppServices.of(t.element(find.byKey(const Key('useSkill'))));
      await s.loadout.refresh();
      for (final id in advancedSkillSpecs.keys) {
        expect(s.loadout.select(catalogEntry(id)), true);
        g.step(.01);
        g.cooldown = 0;
        g.health = g.maxHealth;
        g.enemies.clear();
        g.bullets.clear();
        g.enemies.addAll([
          Enemy(const Vec(140, 270), EnemyKind.interceptor),
          Enemy(const Vec(220, 300), EnemyKind.sentinel)..shield = 20,
          Enemy(const Vec(280, 240), EnemyKind.charger)..fireClock = 1.3,
        ]);
        g.activateSkill();
        await t.pump(const Duration(milliseconds: 100));
        if (id == 'beam') await saveFrame('charge-beam');
        for (var i = 0; i < 18; i++) {
          g.step(.05);
        }
        if (id == 'absorb') {
          g.bullets.add(Projectile(g.player, Vec.zero, collectible: false));
          g.step(.01);
        }
        await t.pump(const Duration(milliseconds: 100));
        await saveFrame('skill-$id');
      }
    }
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
