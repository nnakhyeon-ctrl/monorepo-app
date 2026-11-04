import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:raikeopeu2026/app.dart';
import 'package:raikeopeu2026/core/readiness.dart';

import '../test/fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native skill card shows real bounds and keeps subscription locked',
    (tester) async {
      expect(const bool.fromEnvironment('AIRZERO_INTEGRATION'), true);
      expect(
        (await PackageInfo.fromPlatform()).packageName,
        'com.example.raikeopeu2026.dev.integration',
      );
      const key = Key('tailwingCardCapture');
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: RaikeopeuApp(
            progress: FixtureProgress(),
            feedback: FixtureFeedback(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.pushNamed(AppRoutes.hangar);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('category-skill')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('category-skill')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('catalog-signature')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-signature')));
      await tester.pumpAndSettle();
      expect(find.text('지속 3초'), findsWidgets);
      expect(find.text('대기 12초'), findsWidgets);
      expect(find.text('추가 피해 상한 48'), findsWidgets);
      expect(find.text('환경설정에서 구독 보기'), findsOneWidget);
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
        final dir = Directory(
          '${(await getApplicationSupportDirectory()).path}/tailwing_roster_capture_v1',
        );
        await dir.create(recursive: true);
        await File(
          '${dir.path}/skill-cards.png',
        ).writeAsBytes(b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes));
      } finally {
        picture.dispose();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
