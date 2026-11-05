// Explicit opt-in, fictional profile and combat. Never captures a desktop.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/app.dart';
import 'package:raikeopeu2026/core/readiness.dart';
import 'package:raikeopeu2026/game/assets.dart';
import 'package:raikeopeu2026/game/catalog.dart';
import 'package:raikeopeu2026/game/combat_model.dart';
import 'package:raikeopeu2026/game/engine.dart';
import 'package:raikeopeu2026/game/rendering.dart';

import 'fixtures.dart';
import 'battle_flow_test.dart' show currentGame;

void main() {
  const enabled = bool.fromEnvironment('TAILWING_CHARACTER_REVIEW');
  testWidgets(
    'export Sera home, equipment and new skill renders with fictional data',
    (t) async {
      if (!enabled) return;
      t.view.physicalSize = const Size(396, 860);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final assets = BattleAssets();
      await t.runAsync(() async {
        final fontBytes = ByteData.sublistView(
          await File('C:/Windows/Fonts/malgun.ttf').readAsBytes(),
        );
        await (FontLoader('Roboto')..addFont(Future.value(fontBytes))).load();
        final icons = ByteData.sublistView(
          await File(
            '../../flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes(),
        );
        await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(icons))).load();
        await assets.prepare();
        await assets.preparePilot('rion');
        await assets.preparePilot('pilot');
      });
      final boundary = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: boundary,
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
      final services = AppServices.of(
        t.element(find.byKey(const Key('startGame'))),
      );
      await services.loadout.refresh();
      services.loadout.select(catalogEntry('rion'));
      await t.pumpAndSettle();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await t.pumpAndSettle();
      Future<void> save(String name) async {
        await t.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final frame = await render.toImage(pixelRatio: 2);
          final data = (await frame.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          frame.dispose();
          final file = File('docs/character-item-pass-2026-11-05/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
        });
      }

      await save('sera-home');
      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      nav.pushNamed(AppRoutes.hangar);
      await t.pumpAndSettle();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await t.pumpAndSettle();
      await save('sera-selection');
      await t.tap(find.byKey(const Key('category-equipment')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('catalog-capacitor')));
      await t.pumpAndSettle();
      await t.drag(find.byType(Scrollable).last, const Offset(0, 180));
      await t.pumpAndSettle();
      await save('equipment-capacitor');
      nav.pop();
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('startGame')));
      await t.tap(find.byKey(const Key('startGame')));
      await t.pump(const Duration(milliseconds: 300));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await t.pump(const Duration(milliseconds: 100));
      for (
        var attempt = 0;
        attempt < 10 &&
            find
                .byWidgetPredicate(
                  (w) => w is CustomPaint && w.painter is BattlePainter,
                )
                .evaluate()
                .isEmpty;
        attempt++
      ) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await t.pump(const Duration(milliseconds: 50));
      }
      final g = currentGame(t);
      // Let the actual route fade finish before exporting the first skill.
      await t.pump(const Duration(milliseconds: 250));
      for (final (id, gear) in [
        ('petal_orbit', 'gyro'),
        ('aurora_sweep', 'capacitor'),
        ('landing_beacon', 'safety_cell'),
      ]) {
        services.loadout.select(catalogEntry(id));
        services.loadout.select(catalogEntry(gear));
        g.synchronizeLoadout();
        g.cooldown = 0;
        g.health = g.maxHealth;
        g.enemies.clear();
        g.bullets.clear();
        g.enemies.addAll([
          Enemy(const Vec(140, 300), EnemyKind.interceptor),
          Enemy(const Vec(250, 240), EnemyKind.sentinel)..shield = 30,
        ]);
        g.activateSkill();
        for (var i = 0; i < 20; i++) {
          g.step(.03);
        }
        await t.pump(const Duration(milliseconds: 100));
        await save(id);
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
