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

import '../test/fixtures.dart' show FixtureFeedback, FixtureProgress;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture real free gameplay in an isolated fictional app', (
    tester,
  ) async {
    expect(const bool.fromEnvironment('AIRZERO_INTEGRATION'), true);
    expect(
      (await PackageInfo.fromPlatform()).packageName,
      'com.example.raikeopeu2026.dev.integration',
    );
    const captureKey = Key('stage12CaptureRoot');
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: RaikeopeuApp(
          progress: FixtureProgress(),
          feedback: FixtureFeedback(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> capture(String name) async {
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(captureKey),
      );
      await tester.runAsync(() async {
        final picture = await boundary.toImage(
          pixelRatio: tester.view.devicePixelRatio,
        );
        try {
          expect(picture.width, 1080);
          expect(picture.height, 1920);
          final png = await picture.toByteData(format: ui.ImageByteFormat.png);
          expect(png, isNotNull);
          final root = await getApplicationSupportDirectory();
          final directory = Directory(
            '${root.path}/airzero_stage12_capture_v1',
          );
          await directory.create(recursive: true);
          await File('${directory.path}/$name.png').writeAsBytes(
            png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
            flush: true,
          );
        } finally {
          picture.dispose();
        }
      });
    }

    await capture('01-home');
    final services = AppServices.of(
      tester.element(find.byKey(const Key('startGame'))),
    );
    await services.battleAssets.prepare();
    await tester.tap(find.byKey(const Key('startGame')));
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(const Key('battleField')).evaluate().isNotEmpty) break;
    }
    expect(find.byKey(const Key('battleField')), findsOneWidget);
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.drag(
      find.byKey(const Key('battleField')),
      const Offset(-35, 0),
    );
    await capture('02-stage1');
    await tester.tap(find.byKey(const Key('useSkill')));
    await tester.pump(const Duration(milliseconds: 100));
    await capture('03-free-shield');
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.drag(
      find.byKey(const Key('battleField')),
      const Offset(65, 0),
    );
    await capture('04-stage1-flight');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
