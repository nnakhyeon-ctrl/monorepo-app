import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/app.dart';
import 'package:raikeopeu2026/core/readiness.dart';
import 'package:raikeopeu2026/game/assets.dart';
import 'package:raikeopeu2026/game/catalog.dart';
import 'package:raikeopeu2026/game/engine.dart';
import 'package:raikeopeu2026/game/progress.dart';
import 'package:raikeopeu2026/game/saved_loadout.dart';

import 'basic_screens_test.dart' show open, press;
import 'battle_flow_test.dart' show currentGame;
import 'fixtures.dart';

class MeasuredProgress extends FixtureProgress {
  int active = 0, maxActive = 0, writes = 0;
  @override
  Future<void> write(CampaignProgress progress) async {
    active++;
    writes++;
    if (active > maxActive) maxActive = active;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await super.write(progress);
    } finally {
      active--;
    }
  }
}

class BrokenRead extends MeasuredProgress {
  @override
  Future<ProgressRead> read() async =>
      throw StateError('fictitious read failure');
}

class InterruptedAssets extends CachingAssetBundle {
  bool broken = true;
  @override
  Future<ByteData> load(String key) async {
    if (broken && key.endsWith('vector_mk2.png')) {
      throw StateError('fictitious asset failure');
    }
    return rootBundle.load(key);
  }
}

SubscriptionAccess activeAccess() => SubscriptionAccess(
  AccessStatus.active,
  validUntil: DateTime.now().add(const Duration(hours: 1)),
);

void main() {
  test('old and invalid optional selections preserve stage records and accept only category IDs', () {
    final data = CampaignProgress(
      records: {1: const StageRecord(cleared: true, best: 950, attempts: 3)},
    ).toJson()..remove('loadout');
    final old = CampaignProgress.fromJson(data);
    expect(old.loadout.selected(CatalogCategory.aircraft), 'aurora');
    data['loadout'] = {
      'aircraft': '../../private',
      'skill': 'vector',
      'character': 'eden',
      'equipment': 4,
      'entitlement': 'active',
    };
    final parsed = CampaignProgress.fromJson(data);
    expect(parsed.records[1]!.best, 950);
    expect(parsed.records[1]!.attempts, 3);
    expect(parsed.loadout.toJson(), {
      'aircraft': 'aurora',
      'skill': 'barrier',
      'character': 'eden',
      'equipment': 'standard',
    });
    expect(
      () => parsed.loadout.select(CatalogCategory.skill, 'vector'),
      throwsArgumentError,
    );
    expect(
      catalogEntries.map((e) => e.id).toSet(),
      SavedLoadout.allowed.values.expand((ids) => ids).toSet(),
    );
  });

  test('saved paid preferences survive disk reload but require fresh verified access before combat', () async {
    final dir = await Directory.systemTemp.createTemp(
      'airzero_loadout_fixture_',
    );
    addTearDown(() => dir.delete(recursive: true));
    final campaign = CampaignController(
      FileProgressRepository(directory: () async => dir),
    );
    final loadout = LoadoutController(
      campaign: campaign,
      repository: FixtureEntitlements(activeAccess()),
    );
    await loadout.ready;
    await loadout.refresh();
    for (final id in ['vector', 'pulse', 'eden', 'prism']) {
      expect(loadout.select(catalogEntry(id)), isTrue);
    }
    await campaign.finish(
      runId: 'prepare_fixture',
      stage: 1,
      won: true,
      score: 700,
    );
    await campaign.save();
    loadout.dispose();
    campaign.dispose();
    final restarted = CampaignController(
      FileProgressRepository(directory: () async => dir),
    );
    final rights = FixtureEntitlements(
      const SubscriptionAccess(AccessStatus.unverified),
    );
    final restored = LoadoutController(campaign: restarted, repository: rights);
    await restored.ready;
    expect(
      restarted.progress.loadout.selected(CatalogCategory.aircraft),
      'vector',
    );
    expect(restarted.progress.records[1]!.best, 700);
    expect(BattleEngine(restored).aircraft, 'aurora');
    expect(restored.select(catalogEntry('vector')), isFalse);
    rights.result = activeAccess();
    await restored.refresh();
    final game = BattleEngine(restored);
    expect(
      [game.aircraft, game.skill, game.character, game.equipment],
      ['vector', 'pulse', 'eden', 'prism'],
    );
    expect(game.moveSpeed, 1.15);
    expect(game.maxHealth, 3);
    expect(game.shotDamage, 7.5);
    rights.result = const SubscriptionAccess(AccessStatus.inactive);
    await restored.refresh();
    game.step(.02);
    expect(game.aircraft, 'aurora');
    expect(game.skill, 'barrier');
    expect(restarted.progress.records[1]!.best, 700);
    restored.dispose();
    restarted.dispose();
  });

  test('rapid selections, duplicate requests and failed writes share one save queue', () async {
    final repo = MeasuredProgress()..failWrites = true;
    final campaign = CampaignController(repo);
    final loadout = LoadoutController(
      campaign: campaign,
      repository: FixtureEntitlements(activeAccess()),
    );
    await loadout.ready;
    await loadout.refresh();
    loadout.select(catalogEntry('vector'));
    loadout.select(catalogEntry('vector'));
    loadout.select(catalogEntry('focus'));
    await campaign.setSensitivity(1.25);
    // The sensitivity write can finish before the two asynchronous selections.
    // Append a barrier write to wait for the whole existing queue.
    await campaign.save();
    expect(repo.writes, 4);
    expect(repo.maxActive, 1);
    expect(campaign.saveFailed, isTrue);
    repo.failWrites = false;
    await campaign.retryStorage();
    expect(repo.value.loadout.selected(CatalogCategory.aircraft), 'vector');
    expect(repo.value.loadout.selected(CatalogCategory.skill), 'focus');
    expect(repo.value.sensitivity, 1.25);
    expect(campaign.saveFailed, isFalse);
    loadout.dispose();
    campaign.dispose();
  });

  test(
    'unreadable storage blocks preference changes without creating writes',
    () async {
      final repo = BrokenRead();
      final campaign = CampaignController(repo);
      final loadout = LoadoutController(
        campaign: campaign,
        repository: FixtureEntitlements(activeAccess()),
      );
      await loadout.ready;
      await loadout.refresh();
      expect(loadout.select(catalogEntry('vector')), isFalse);
      expect(repo.writes, 0);
      expect(campaign.writeBlocked, isTrue);
      loadout.dispose();
      campaign.dispose();
    },
  );

  testWidgets(
    'new sprites decode distinctly, failed loading rolls back and retry coalesces',
    (tester) async {
      final bundle = InterruptedAssets();
      final actual = BattleAssets(bundle: bundle);
      await tester.runAsync(() async {
        await expectLater(actual.prepare(), throwsStateError);
      });
      expect(actual.player, isNull);
      bundle.broken = false;
      await tester.runAsync(() async {
        final first = actual.prepare();
        expect(identical(first, actual.prepare()), isTrue);
        await first;
        for (final id in ['aurora', 'vector', 'safeguard']) {
          final image = actual.imageFor(id)!;
          expect(image.width, 256);
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          expect(data.getUint8(3), 0);
          expect(data.getUint8((128 * 256 + 128) * 4 + 3), greaterThan(0));
        }
        expect(
          identical(actual.imageFor('aurora'), actual.imageFor('vector')),
          isFalse,
        );
      });
      actual.dispose();
    },
  );

  testWidgets(
    'large-text preparation keeps real skill details reachable and premium blocked',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        RaikeopeuApp(
          progress: FixtureProgress(),
          feedback: FixtureFeedback(),
          appInfo: FixtureAppInfo(),
          assets: ImmediateAssets(),
        ),
      );
      await tester.pumpAndSettle();
      await open(tester, AppRoutes.hangar);
      await press(tester, find.byKey(const Key('category-skill')));
      await press(tester, find.byKey(const Key('catalog-focus')));
      expect(find.textContaining('사격 속도 2배'), findsWidgets);
      expect(find.text('환경설정에서 구독 보기'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await press(tester, find.text('닫기'));
      await tester.scrollUntilVisible(
        find.byKey(const Key('select-focus')),
        240,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('select-focus')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preparation launches the selected verified loadout with duplicate taps blocked',
    (tester) async {
      final repository = FixtureProgress();
      await tester.pumpWidget(
        RaikeopeuApp(
          progress: repository,
          feedback: FixtureFeedback(),
          appInfo: FixtureAppInfo(),
          assets: ImmediateAssets(),
          entitlements: FixtureEntitlements(activeAccess()),
        ),
      );
      await tester.pumpAndSettle();
      await open(tester, AppRoutes.hangar);
      final s = AppServices.of(
        tester.element(find.byKey(const Key('category-aircraft'))),
      );
      await s.loadout.refresh();
      await tester.pumpAndSettle();
      await press(tester, find.byKey(const Key('category-aircraft')));
      await press(tester, find.byKey(const Key('select-vector')));
      await tester.scrollUntilVisible(
        find.byKey(const Key('launchLoadout')),
        300,
      );
      await tester.ensureVisible(find.byKey(const Key('launchLoadout')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('launchLoadout')));
      await tester.tap(
        find.byKey(const Key('launchLoadout')),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 30));
      expect(currentGame(tester).aircraft, 'vector');
      expect(currentGame(tester).moveSpeed, 1.15);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      expect(
        repository.value.loadout.selected(CatalogCategory.aircraft),
        'vector',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
