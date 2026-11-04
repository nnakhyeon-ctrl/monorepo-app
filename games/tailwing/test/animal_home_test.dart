import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/app.dart';
import 'package:raikeopeu2026/game/assets.dart';
import 'package:raikeopeu2026/game/rendering.dart';
import 'package:raikeopeu2026/game/combat_model.dart';

import 'fixtures.dart';
import 'basic_screens_test.dart' show open, press;

import 'package:raikeopeu2026/core/readiness.dart';

class PrimedAssets extends BattleAssets {
  Future<void> prime() async {
    await super.prepare();
    await super.preparePilot('pilot');
  }

  @override
  Future<void> prepare() async {}
  @override
  Future<void> preparePilot(String id) async {}
}

void main() {
  testWidgets(
    'signature cards display actual bounds while unverified purchase remains locked',
    (tester) async {
      await tester.pumpWidget(
        RaikeopeuApp(
          assets: ImmediateAssets(),
          progress: FixtureProgress(),
          feedback: FixtureFeedback(),
          appInfo: FixtureAppInfo(),
        ),
      );
      await tester.pumpAndSettle();
      await open(tester, AppRoutes.hangar);
      final services = AppServices.of(
        tester.element(find.byKey(const Key('category-skill'))),
      );
      await press(tester, find.byKey(const Key('category-skill')));
      await press(tester, find.byKey(const Key('catalog-signature')));
      expect(find.text('루미 · 구름 스티치'), findsWidgets);
      expect(find.text('지속 3초'), findsWidgets);
      expect(find.text('대기 12초'), findsWidgets);
      expect(find.text('추가 피해 상한 48'), findsWidgets);
      expect(find.text('환경설정에서 구독 보기'), findsOneWidget);
      expect(services.loadout.selected(CatalogCategory.skill), 'barrier');
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'rabbit home and actual normal battle share decoded mounted craft',
    (tester) async {
      final assets = PrimedAssets();
      await tester.runAsync(assets.prime);
      await tester.pumpWidget(
        RaikeopeuApp(
          assets: assets,
          progress: FixtureProgress(),
          feedback: FixtureFeedback(),
          appInfo: FixtureAppInfo(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TAILWING'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('startGame')));
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('startGame')));
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        find.byKey(const Key('battleField')),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '),
      );
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<BattlePainter>()
          .single;
      expect(painter.game.character, 'pilot');
      expect(assets.pilotImageFor('pilot'), isNotNull);
      expect(
        BattlePainter.playerBounds(painter.game.player).center.dx,
        painter.game.player.dx,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      assets.dispose();
    },
  );
}
