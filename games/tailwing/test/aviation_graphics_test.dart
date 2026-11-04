import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/core/design.dart';
import 'package:raikeopeu2026/features/battle_hud.dart';
import 'package:raikeopeu2026/game/assets.dart';
import 'package:raikeopeu2026/game/combat_model.dart';
import 'package:raikeopeu2026/game/engine.dart';
import 'package:raikeopeu2026/game/rendering.dart';
import 'package:raikeopeu2026/coop/protocol.dart';

class InterruptedScene extends CachingAssetBundle {
  bool broken = true;
  @override
  Future<ByteData> load(String key) async {
    if (broken && key == BattleAssets.cloudPath) {
      throw StateError('synthetic scene interruption');
    }
    return rootBundle.load(key);
  }
}

void main() {
  test('visual events preserve simulation, expire, pause and stay bounded', () {
    final a = BattleEngine(
      const FreeLoadout(),
      partnerLoadout: const FreeLoadout(),
    );
    final b = BattleEngine(
      const FreeLoadout(),
      partnerLoadout: const FreeLoadout(),
    );
    for (var frame = 0; frame < 1200; frame++) {
      a.step(.01);
      b.step(.01);
      b.effects.clear();
      expect(a.effects.length, lessThanOrEqualTo(BattleEngine.maxEffects));
    }
    expect(battleSnapshot(a, 1200), battleSnapshot(b, 1200));
    a.enemies.clear();
    a.bullets.clear();
    final before = a.score;
    a.enemies.addAll(
      List.generate(
        70,
        (i) => Enemy(Vec(30 + i.toDouble(), 80), EnemyKind.scout)..health = 0,
      ),
    );
    a.step(.01);
    expect(a.score, before + 7000);
    expect(a.effects.length, BattleEngine.maxEffects);
    final effect = a.effects.last;
    a.pause();
    final age = effect.age;
    a.step(.05);
    expect(effect.age, age);
    a.resume();
    for (var i = 0; i < 80; i++) {
      a.step(.01);
    }
    expect(a.effects.any((e) => e.kind == EffectKind.explosion), isFalse);

    final shield = BattleEngine(const FreeLoadout());
    shield.activateSkill();
    shield.bullets.add(Projectile(shield.player, Vec.zero));
    shield.step(.01);
    expect(shield.health, 3);
    expect(shield.effects.any((e) => e.kind == EffectKind.shieldHit), isTrue);
  });

  testWidgets(
    'complete scene decodes within budget and a late failure can retry atomically',
    (tester) async {
      final bundle = InterruptedScene();
      final assets = BattleAssets(bundle: bundle);
      addTearDown(assets.dispose);
      await tester.runAsync(() async {
        await expectLater(assets.prepare(), throwsStateError);
        expect(assets.player, isNull);
        expect(assets.enemies, isNull);
        expect(assets.decodedBytes, 0);
        bundle.broken = false;
        final loading = assets.prepare();
        expect(identical(loading, assets.prepare()), isTrue);
        await loading;
        expect(assets.decodedBytes, lessThan(9 * 1024 * 1024));
        expect(assets.coast!.width, 720);
        expect(assets.enemies!.width, 512);
        expect(assets.explosion!.width / assets.explosion!.height, 2);
        for (final image in [
          assets.player!,
          assets.enemies!,
          assets.cloud!,
          assets.explosion!,
        ]) {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          expect(bytes.getUint8(3), 0);
        }
        final atlas = assets.enemies!;
        final bytes = (await atlas.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        for (var i = 0; i < 4; i++) {
          final x = i % 2 * 256 + 128, y = i ~/ 2 * 256 + 128;
          expect(bytes.getUint8((y * 512 + x) * 4 + 3), greaterThan(100));
        }
      });
    },
  );

  testWidgets(
    'real textures render below projectiles and exact simulation centers',
    (tester) async {
      final assets = BattleAssets();
      addTearDown(assets.dispose);
      await tester.runAsync(() async {
        await assets.prepare();
        final g = BattleEngine(const FreeLoadout());
        g.effects.add(
          CombatEffect(const Vec(180, 240), EffectKind.explosion, size: 126)
            ..age = .3,
        );
        g.bullets.add(Projectile(const Vec(180, 240), Vec.zero));
        g.bullets.add(
          Projectile(const Vec(260, 240), Vec.zero, friendly: true),
        );
        for (final kind in EnemyKind.values) {
          final e = Enemy(Vec(40 + kind.index * 80.0, 100), kind);
          g.enemies.add(e);
          expect(
            BattlePainter.enemyBounds(e).center,
            Offset(e.position.dx, e.position.dy),
          );
        }
        expect(
          BattlePainter.playerBounds(g.player).center,
          const Offset(180, 510),
        );
        final recorder = ui.PictureRecorder();
        BattlePainter(
          g,
          assets.player,
          assets: assets,
        ).paint(Canvas(recorder), const Size(360, 600));
        final picture = recorder.endRecording();
        final image = await picture.toImage(360, 600);
        picture.dispose();
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        image.dispose();
        int channel(int x, int y, int c) =>
            data.getUint8((y * 360 + x) * 4 + c);
        expect(channel(180, 240, 0), greaterThan(240));
        expect(channel(180, 240, 1), greaterThan(200));
        expect(
          channel(180, 240, 2),
          lessThan(200),
          reason: 'enemy core remains visible above explosion',
        );
        expect(
          channel(260, 240, 2),
          greaterThan(220),
          reason: 'friendly streak has a separate shape and cool core',
        );
        expect(channel(180, 510, 0), greaterThan(245));
        expect(channel(180, 510, 1), greaterThan(245));
        g.moveBy(const Vec(9999, -9999));
        expect(
          BattlePainter.playerBounds(g.player).center,
          Offset(g.player.dx, g.player.dy),
        );
      });
    },
  );

  testWidgets(
    'digital HUD wraps at 320 with 200 percent text and reports actual boss health',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final game = BattleEngine(const FreeLoadout());
      game.enemies.add(
        Enemy(const Vec(180, 85), EnemyKind.boss)
          ..health = game.stage.bossHealth / 2,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: BattleHud(game),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('장갑 3/3'), findsOneWidget);
      expect(find.text('철갑 편대장 · 50%'), findsOneWidget);
      expect(find.byKey(const Key('shieldTime')), findsOneWidget);
    },
  );
}
