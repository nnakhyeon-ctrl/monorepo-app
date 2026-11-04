import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/app.dart';
import 'package:raikeopeu2026/core/device_options.dart';
import 'package:raikeopeu2026/core/external_services.dart';
import 'package:raikeopeu2026/core/game_feedback.dart';
import 'package:raikeopeu2026/core/readiness.dart';
import 'package:raikeopeu2026/core/store_catalog.dart';
import 'package:raikeopeu2026/features/home.dart';
import 'package:raikeopeu2026/game/catalog.dart';
import 'package:raikeopeu2026/game/engine.dart';
import 'package:raikeopeu2026/game/progress.dart';

import 'basic_screens_test.dart' show open, press;
import 'battle_flow_test.dart' show currentGame;
import 'fixtures.dart';

class RecoveringProgress extends FixtureProgress {
  bool unavailable = true;
  int writes = 0;
  @override
  Future<ProgressRead> read() {
    if (unavailable) throw StateError('fixture unavailable');
    return super.read();
  }

  @override
  Future<void> write(CampaignProgress progress) async {
    writes++;
    await super.write(progress);
  }
}

class ChangingEntitlements extends FixtureEntitlements {
  ChangingEntitlements(super.result);
  bool failed = false;
  @override
  Future<SubscriptionAccess> read() {
    if (failed) throw StateError('fixture network');
    return super.read();
  }
}

class FixtureCatalog implements StoreCatalogRepository {
  @override
  bool get connected => true;
  bool failed = true;
  @override
  Future<List<StoreProduct>> read() async {
    if (failed) throw StateError('fixture store');
    return const [
      StoreProduct(
        id: 'fixture.month',
        period: BillingPeriod.monthly,
        localizedTotal: '가상 월간 총액',
      ),
      StoreProduct(
        id: 'fixture.year',
        period: BillingPeriod.annual,
        localizedTotal: '가상 연간 총액',
      ),
    ];
  }
}

class FixtureExternal implements ExternalNavigator {
  final calls = <Uri>[];
  Completer<bool>? pending;
  bool succeeds = false;
  @override
  Future<bool> open(Uri uri) async {
    calls.add(uri);
    return pending == null ? succeeds : pending!.future;
  }
}

Future<void> mount(
  WidgetTester tester, {
  FixtureProgress? progress,
  FeedbackBackend? feedback,
  StoreCatalogRepository? store,
  ExternalNavigator? external,
  PublicContacts contacts = const PublicContacts(),
}) async {
  await tester.pumpWidget(
    RaikeopeuApp(
      progress: progress ?? FixtureProgress(),
      feedback: feedback ?? FixtureFeedback(),
      assets: ImmediateAssets(),
      appInfo: FixtureAppInfo(),
      storeCatalog: store ?? const UnconnectedStoreCatalog(),
      external: external ?? FixtureExternal(),
      contacts: contacts,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('legacy schema keeps records and persists device options and selected stage across reload', () async {
    final directory = await Directory.systemTemp.createTemp(
      'airzero_menu_fixture_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final root = await Directory('${directory.path}/airzero_progress').create();
    final legacy =
        CampaignProgress(
            records: {
              1: const StageRecord(cleared: true, best: 850, attempts: 2),
            },
          ).toJson()
          ..remove('options')
          ..remove('lastStage');
    final payload = jsonEncode(legacy);
    await File('${root.path}/progress_a.json').writeAsString(
      jsonEncode({
        'schema': 1,
        'revision': 2,
        'payload': payload,
        'checksum': FileProgressRepository.checksum('2:$payload'),
      }),
    );
    final c = CampaignController(
      FileProgressRepository(directory: () async => directory),
    );
    await c.ready;
    expect(c.progress.options.music, isTrue);
    expect(c.selectedStage, 2);
    c.selectStage(1);
    await c.setOptions(
      const DeviceOptions(
        music: false,
        effects: false,
        vibration: true,
        musicVolume: .6,
        effectsVolume: .8,
        reduceMotion: true,
      ),
    );
    await c.setSensitivity(1.25);
    c.dispose();
    final restart = CampaignController(
      FileProgressRepository(directory: () async => directory),
    );
    await restart.ready;
    expect(restart.progress.records[1]!.best, 850);
    expect(restart.progress.records[1]!.attempts, 2);
    expect(restart.selectedStage, 1);
    expect(restart.progress.sensitivity, 1.25);
    expect(
      restart.progress.options.toJson(),
      const DeviceOptions(
        music: false,
        effects: false,
        vibration: true,
        musicVolume: .6,
        effectsVolume: .8,
        reduceMotion: true,
      ).toJson(),
    );
    restart.dispose();
  });

  test(
    'failed initial read never writes over records and retry recovers them',
    () async {
      final repo = RecoveringProgress();
      repo.value.records[1] = const StageRecord(cleared: true, best: 900);
      final c = CampaignController(repo);
      await c.ready;
      await c.save();
      expect(c.writeBlocked, isTrue);
      expect(repo.writes, 0);
      repo.unavailable = false;
      await c.retryStorage();
      expect(c.writeBlocked, isFalse);
      expect(c.saveFailed, isFalse);
      expect(c.progress.records[1]!.best, 900);
      c.dispose();
    },
  );

  test('audio follows options, pause, foreground and vibration without affecting records', () async {
    final campaign = CampaignController(FixtureProgress());
    await campaign.ready;
    final backend = FixtureFeedback();
    final feedback = FeedbackController(campaign, backend);
    feedback.battle(true);
    await feedback.cue(FeedbackCue.skill);
    expect(backend.events, contains('music:true:0.25'));
    expect(backend.events, contains('effect:skill:0.45'));
    expect(backend.events, isNot(contains('vibrate')));
    final completionSound = feedback.cue(FeedbackCue.clear);
    feedback.battle(false);
    await completionSound;
    expect(backend.events, contains('effect:clear:0.45'));
    feedback.battle(true);
    await campaign.setOptions(
      const DeviceOptions(effects: false, vibration: true),
    );
    backend.events.clear();
    await feedback.cue(FeedbackCue.hit);
    expect(backend.events, contains('vibrate'));
    expect(backend.events.where((e) => e.startsWith('effect')), isEmpty);
    feedback.pause(true);
    await feedback.cue(FeedbackCue.skill);
    await Future<void>.delayed(Duration.zero);
    expect(backend.events.last, 'music:false:0.25');
    feedback.foreground(false);
    backend.events.clear();
    await feedback.cue(FeedbackCue.skill, preview: true);
    await Future<void>.delayed(Duration.zero);
    expect(backend.events.where((e) => e == 'vibrate'), isEmpty);
    feedback.dispose();
    campaign.dispose();
  });

  test('subscription refresh failure preserves only already verified unexpired access', () async {
    var now = DateTime.utc(2026, 10, 19);
    final repo = ChangingEntitlements(
      SubscriptionAccess(
        AccessStatus.active,
        validUntil: now.add(const Duration(hours: 1)),
        autoRenew: false,
      ),
    );
    final c = LoadoutController(repository: repo, clock: () => now);
    await c.refresh();
    expect(c.select(catalogEntry('tw_owl')), isTrue);
    repo.failed = true;
    await c.refresh();
    expect(c.lastCheckFailed, isTrue);
    expect(c.premiumActive, isTrue);
    expect(c.isSelected(catalogEntry('tw_owl')), isTrue);
    now = now.add(const Duration(hours: 2));
    await c.refresh();
    expect(c.premiumActive, isFalse);
    expect(c.isSelected(catalogEntry('pilot')), isTrue);
    expect(c.select(catalogEntry('tw_owl')), isFalse);
    c.dispose();
  });

  test('external destinations reject unconfirmed or unsafe addresses', () {
    const contacts = PublicContacts(
      email: 'qa@example.invalid',
      supportUrl: 'https://support.example.invalid/help',
    );
    expect(contacts.permits(contacts.support!), isTrue);
    expect(contacts.permits(contacts.mail!), isTrue);
    for (final value in [
      'http://support.example.invalid',
      'https://name:secret@example.invalid',
      'javascript:alert(1)',
      'https://support.example.invalid:444',
      'https://support.example.invalid/help#untrusted',
    ]) {
      expect(contacts.https(value), isNull);
    }
    expect(
      contacts.permits(Uri.parse('https://unconfirmed.example.invalid')),
      isFalse,
    );
    expect(
      const PublicContacts(email: 'qa@example.invalid\r\nBcc:bad').mail,
      isNull,
    );
    expect(const PublicContacts().mail, isNull);
    expect(
      contacts.permits(storeManagementUrl(TargetPlatform.android)!),
      isTrue,
    );
    expect(contacts.permits(storeManagementUrl(TargetPlatform.iOS)!), isTrue);
  });

  testWidgets(
    'settings widgets persist sound, vibration, volume and sensitivity after app recreation',
    (tester) async {
      final repo = FixtureProgress();
      await mount(tester, progress: repo);
      await open(tester, AppRoutes.settings);
      await press(tester, find.byKey(const Key('musicToggle')));
      await press(tester, find.byKey(const Key('effectsToggle')));
      await press(tester, find.byKey(const Key('vibrationToggle')));
      await press(tester, find.byKey(const Key('sensitivity-1.25')));
      await press(tester, find.byKey(const Key('motionToggle')));
      expect(repo.value.options.music, isFalse);
      expect(repo.value.options.effects, isFalse);
      expect(repo.value.options.vibration, isTrue);
      expect(repo.value.options.reduceMotion, isTrue);
      expect(repo.value.sensitivity, 1.25);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await mount(tester, progress: repo);
      await open(tester, AppRoutes.settings);
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('musicToggle')))
            .value,
        isFalse,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('vibrationToggle')),
        200,
      );
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('vibrationToggle')))
            .value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'paused retry and back require confirmation and keep completed records',
    (tester) async {
      final repo = FixtureProgress();
      repo.value.records[1] = const StageRecord(
        cleared: true,
        best: 1000,
        attempts: 1,
      );
      await mount(tester, progress: repo);
      await tester.ensureVisible(find.byKey(const Key('startGame')));
      await tester.tap(find.byKey(const Key('startGame')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 30));
      final first = currentGame(tester)..score = 75;
      await tester.tap(find.byKey(const Key('pauseBattle')));
      await tester.pumpAndSettle();
      await press(tester, find.byKey(const Key('retryPausedBattle')));
      expect(find.text('처음부터 다시 도전할까요?'), findsOneWidget);
      await press(tester, find.text('취소'));
      expect(currentGame(tester).score, 75);
      await press(tester, find.byKey(const Key('retryPausedBattle')));
      await tester.tap(find.text('다시 도전'));
      await tester.pump(const Duration(milliseconds: 30));
      expect(identical(currentGame(tester), first), isFalse);
      expect(currentGame(tester).score, 0);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('홈으로 이동할까요?'), findsOneWidget);
      expect(currentGame(tester).phase, BattlePhase.paused);
      await press(tester, find.text('홈으로 이동'));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(repo.value.records[1]!.best, 1000);
      expect(repo.value.records[1]!.attempts, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'volume drag saves on release and failed save can be retried without resetting records',
    (tester) async {
      final repo = FixtureProgress();
      repo.value.records[1] = const StageRecord(best: 600, attempts: 3);
      await mount(tester, progress: repo);
      await open(tester, AppRoutes.settings);
      final slider = find.byKey(const Key('musicVolume'));
      await tester.ensureVisible(slider);
      await tester.drag(slider, const Offset(150, 0));
      await tester.pumpAndSettle();
      expect(repo.value.options.musicVolume, greaterThan(.25));
      repo.failWrites = true;
      await press(tester, find.byKey(const Key('effectsToggle')));
      await tester.scrollUntilVisible(
        find.byKey(const Key('localSaveStatus')),
        240,
      );
      expect(find.text('기기 저장 실패 · 다시 시도해 주세요'), findsOneWidget);
      expect(find.text('기기 저장 다시 시도'), findsOneWidget);
      repo.failWrites = false;
      await press(tester, find.text('기기 저장 다시 시도'));
      await tester.scrollUntilVisible(
        find.byKey(const Key('localSaveStatus')),
        -160,
      );
      expect(find.text('기기 설정·기록 저장 가능'), findsOneWidget);
      expect(repo.value.options.effects, isFalse);
      expect(repo.value.records[1]!.best, 600);
      expect(repo.value.records[1]!.attempts, 3);
    },
  );

  testWidgets(
    'store prices retry with supplied localized totals and no runtime purchase bypass',
    (tester) async {
      final store = FixtureCatalog();
      await mount(tester, store: store);
      await open(tester, AppRoutes.entitlement);
      await tester.scrollUntilVisible(find.text('스토어 가격 다시 확인'), 200);
      expect(find.textContaining('스토어 가격을 읽지 못했습니다.'), findsOneWidget);
      store.failed = false;
      await press(tester, find.text('스토어 가격 다시 확인'));
      expect(find.textContaining('가상 월간 총액'), findsOneWidget);
      expect(find.textContaining('가상 연간 총액'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('subscribePurchase')),
        180,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('subscribePurchase')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'support keeps missing contacts truthful and report copies only user-approved draft',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'];
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await mount(tester);
      await open(tester, AppRoutes.support);
      expect(find.text('문의 경로 등록 대기'), findsOneWidget);
      expect(find.textContaining('앱 버전 0.1.0 (1)'), findsOneWidget);
      expect(find.text('문의 페이지 열기'), findsNothing);
      await press(tester, find.text('오류 신고 초안 작성'));
      await tester.enterText(
        find.byKey(const Key('reportSteps')),
        '가상 테스트: 일시정지 후 뒤로 이동',
      );
      await tester.enterText(
        find.byKey(const Key('reportProblem')),
        '가상 테스트: 예상 화면과 다름',
      );
      await press(tester, find.byKey(const Key('copyReport')));
      expect(copied, contains('가상 테스트: 일시정지'));
      expect(copied, contains('앱 버전: 0.1.0 (1)'));
      expect(find.text('초안을 복사했습니다. 문의가 전송된 것은 아닙니다.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'external opening prevents duplicates and allows retry after failure',
    (tester) async {
      final external = FixtureExternal()..pending = Completer<bool>();
      await mount(
        tester,
        external: external,
        contacts: const PublicContacts(
          supportUrl: 'https://support.example.invalid/help',
        ),
      );
      await open(tester, AppRoutes.support);
      await tester.tap(find.text('문의 페이지 열기'));
      await tester.pump();
      expect(external.calls.length, 1);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '여는 중…'),
            )
            .onPressed,
        isNull,
      );
      external.pending!.complete(false);
      await tester.pumpAndSettle();
      expect(find.textContaining('열지 못했습니다.'), findsOneWidget);
      external.pending = null;
      external.succeeds = true;
      await press(tester, find.text('문의 페이지 열기'));
      expect(external.calls.length, 2);
      expect(find.textContaining('열지 못했습니다.'), findsNothing);
    },
  );

  testWidgets(
    'unverified cooperative entry is hidden and direct route is unavailable',
    (tester) async {
      await mount(tester);
      await open(tester, AppRoutes.stages);
      expect(find.textContaining('협동'), findsNothing);
      expect(AppRoutes.all, isNot(contains(AppRoutes.coop)));
      await open(tester, AppRoutes.coop);
      expect(find.text('화면을 열 수 없습니다'), findsOneWidget);
    },
  );
}
