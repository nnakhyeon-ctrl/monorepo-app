import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/app.dart';
import 'package:raikeopeu2026/core/readiness.dart';
import 'package:raikeopeu2026/game/catalog.dart';
import 'package:raikeopeu2026/game/progress.dart';
import 'package:raikeopeu2026/security/account_game.dart';
import 'package:raikeopeu2026/security/backend_session.dart';
import 'package:raikeopeu2026/security/email_auth.dart';

import 'email_auth_test.dart' show FakeIdentity, FakeStorage;
import 'fixtures.dart';

CampaignProgress copy(CampaignProgress p) =>
    CampaignProgress.fromJson(jsonDecode(jsonEncode(p.toJson())));

class AccountIdentity extends FakeIdentity {
  bool rejectReauth = false;
  String? refreshFailure;
  @override
  Future<void> signIn(String email, String password) async {
    uid = email.startsWith('b@') ? 'fictional_b' : 'fictional_a';
    verified = true;
  }

  @override
  Future<void> refresh() async {
    if (refreshFailure != null) throw EmailFailure(refreshFailure!);
  }

  @override
  Future<void> reauthenticate(String password) async {
    if (rejectReauth) throw const EmailFailure('credentials');
    reauthenticated = true;
  }
}

class AccountBackend implements EmailBackend {
  AccountBackend(this.identity);
  final AccountIdentity identity;
  final states = <String, String>{}, owners = <String, String>{};
  final deleted = <String>{};
  bool ready = true,
      loseResponse = false,
      pending = false,
      invalidSession = false;
  int preparations = 0, commits = 0, resumptions = 0;
  int imports = 0;
  final remoteRecords = <String, List<dynamic>>{};
  @override
  Future<Map<String, dynamic>> call(
    String path, {
    String method = 'POST',
    Map<String, Object?>? body,
    bool authenticated = false,
    bool session = false,
  }) async {
    if (path == '/v1/public/account-policy') return {'ready': ready};
    if (path == '/v1/account/deletion/resume') {
      resumptions++;
      final receipt = body!['receipt'] as String;
      final status = states[receipt];
      if (status == 'pending' && !pending) {
        states[receipt] = 'complete';
        deleted.add(owners[receipt]!);
      }
      return {'status': states[receipt] ?? 'prepared'};
    }
    if (invalidSession || deleted.contains(identity.uid)) {
      throw const EmailFailure('invalid_session');
    }
    switch (path) {
      case '/v1/session/start':
        return {
          'uid': identity.uid,
          'generation': 0,
          'sessionHandle': 'S' * 43,
          'expiresAtMs': 2000000,
        };
      case '/v1/me/account':
        return {
          'uid': identity.uid,
          'generation': 0,
          'status': 'active',
          'providers': ['password'],
        };
      case '/v1/me/progress':
        return {'records': remoteRecords[identity.uid] ?? []};
      case '/v1/me/import-preview':
        return {
          'decision': (remoteRecords[identity.uid]?.isNotEmpty ?? false)
              ? 'conflict_keep_both'
              : 'empty_requires_confirmation',
          'revision': 0,
          'generation': 0,
        };
      case '/v1/me/import-guest':
        imports++;
        remoteRecords[identity.uid!] = List.of(
          (body!['guest'] as Map)['records'] as List,
        );
        return {'revision': 1};
      case '/v1/account/deletion/prepare':
        preparations++;
        final receipt = body!['receipt'] as String;
        states[receipt] = 'prepared';
        owners[receipt] = identity.uid!;
        return {
          'status': 'prepared',
          'noticeVersion': 'airzero-account-delete-v1',
        };
      case '/v1/account/deletion/commit':
        commits++;
        final receipt = body!['receipt'] as String;
        if (owners[receipt] != identity.uid) {
          throw const EmailFailure('invalid_session');
        }
        states[receipt] = pending ? 'pending' : 'complete';
        if (!pending) deleted.add(identity.uid!);
        if (loseResponse) throw const EmailFailure('unavailable');
        return {'status': states[receipt]};
      default:
        return {'completed': true};
    }
  }
}

class AccountMemory implements ProgressRepository {
  CampaignProgress? value;
  Completer<void>? writeGate;
  @override
  Future<ProgressRead> read() async => ProgressRead(
    value == null ? CampaignProgress() : copy(value!),
    fresh: value == null,
  );
  @override
  Future<void> write(CampaignProgress progress) async {
    await writeGate?.future;
    value = copy(progress);
  }
}

class DelayedAccess implements EntitlementRepository {
  final result = Completer<SubscriptionAccess>();
  @override
  Future<SubscriptionAccess> read() => result.future;
  @override
  Future<SubscriptionAccess> restore() => read();
}

class AccountFixture {
  AccountFixture({bool bind = true, EntitlementRepository? entitlements}) {
    loadout = LoadoutController(
      campaign: campaign,
      repository: entitlements ?? const UnconnectedEntitlements(),
    );
    if (bind) {
      coordinator = AccountGameCoordinator(
        auth,
        campaign,
        loadout,
        cacheFactory: cache,
        eraseCache: erase,
      );
    }
  }
  final identity = AccountIdentity(), storage = FakeStorage();
  late final backend = AccountBackend(identity);
  int now = 1000;
  late final vault = SecureSessionVault(
    BackendScope.cloud(
      projectId: 'airzero-strike-fixture',
      environment: 'dev',
      region: 'asia-northeast3',
    ),
    storage: storage,
    now: () => now,
  );
  late final auth = EmailAuthController(
    initialize: () async => EmailRuntime(
      identity: identity,
      backend: backend,
      vault: vault,
      apiKey: 'synthetic-api-key',
    ),
    now: () => now,
  );
  final guest = FixtureProgress();
  late final campaign = CampaignController(guest);
  late final LoadoutController loadout;
  AccountGameCoordinator? coordinator;
  final caches = <String, AccountMemory>{}, erased = <String>[];
  bool failErase = false;
  AccountMemory cache(String key) => caches.putIfAbsent(key, AccountMemory.new);
  Future<void> erase(String key) async {
    if (failErase) throw StateError('synthetic cache cleanup failure');
    erased.add(key);
    caches.remove(key);
  }

  Future<void> login([String user = 'a']) async {
    expect(await auth.login('$user@example.test', 'synthetic password'), true);
    await coordinator?.settled;
    await loadout.ready;
  }

  void dispose() {
    coordinator?.dispose();
    loadout.dispose();
    campaign.dispose();
    auth.dispose();
  }
}

void main() {
  test('switch and deletion drain an in-flight initial cache seed before erasing it', () async {
    final f = AccountFixture();
    addTearDown(f.dispose);
    await f.campaign.ready;
    const key = 'airzero-strike-fixture:dev:fictional_a:0';
    final gate = Completer<void>();
    f.cache(key).writeGate = gate;
    expect(await f.auth.login('a@example.test', 'synthetic password'), true);
    await Future<void>.delayed(Duration.zero);
    expect(f.campaign.loaded, false);
    expect(await f.auth.prepareDeletion(password: 'synthetic correct'), true);
    final deleting = f.auth.commitDeletion();
    await Future<void>.delayed(Duration.zero);
    var completed = false;
    deleting.then((_) {
      completed = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(completed, false);
    expect(f.erased, isEmpty);
    gate.complete();
    expect(await deleting, true);
    await f.coordinator!.settled;
    expect(f.erased, [key]);
    expect(f.caches.containsKey(key), false);
    expect(f.campaign.loaded, true);
    expect(f.campaign.progress.records, isEmpty);
  });
  test('explicit guest import seeds only an empty owning cache and rejects changed owner/local conflicts', () async {
    final f = AccountFixture();
    addTearDown(f.dispose);
    await f.campaign.ready;
    await f.campaign.finish(
      runId: 'guest_import_result',
      stage: 1,
      won: true,
      score: 750,
    );
    await f.login();
    final owner = f.auth.connection!.key;
    final snapshot = await f.coordinator!.guestSnapshot();
    expect(f.backend.imports, 0);
    expect(await f.auth.importGuest(snapshot, expectedScopeKey: owner), true);
    expect(f.campaign.progress.records[1]!.best, 750);
    expect(f.guest.value.records[1]!.best, 750);
    await f.auth.logout();
    await f.login('b');
    expect(await f.auth.importGuest(snapshot, expectedScopeKey: owner), false);
    await f.campaign.finish(
      runId: 'b_local_before_import',
      stage: 1,
      won: false,
      score: 130,
    );
    expect(
      await f.auth.importGuest(
        snapshot,
        expectedScopeKey: f.auth.connection!.key,
      ),
      false,
    );
    expect(f.backend.imports, 1);
    expect(f.campaign.progress.records[1]!.best, 130);
  });
  test('new animal choices stay scoped to A; cached signature never grants a subscription', () async {
    final f = AccountFixture();
    addTearDown(f.dispose);
    await f.campaign.ready;
    await f.login();
    await f.campaign.setSelection(CatalogCategory.character, 'tw_volt');
    await f.campaign.setSelection(CatalogCategory.skill, 'signature');
    await f.auth.logout();
    await f.coordinator!.settled;
    expect(
      f.campaign.progress.loadout.selected(CatalogCategory.character),
      'pilot',
    );
    await f.login('b');
    expect(
      f.campaign.progress.loadout.selected(CatalogCategory.character),
      'pilot',
    );
    expect(f.loadout.premiumActive, false);
    await f.auth.logout();
    await f.login();
    expect(
      f.campaign.progress.loadout.selected(CatalogCategory.character),
      'tw_volt',
    );
    expect(f.loadout.effectiveSelected(CatalogCategory.character), 'pilot');
    expect(f.loadout.effectiveSelected(CatalogCategory.skill), 'barrier');
  });
  test('A/B/guest records, options and loadout preferences are separated and survive switching back', () async {
    final f = AccountFixture();
    addTearDown(f.dispose);
    await f.campaign.ready;
    await f.campaign.finish(
      runId: 'guest_result',
      stage: 1,
      won: true,
      score: 700,
    );
    await f.campaign.setSensitivity(1.25);
    await f.login();
    expect(f.campaign.progress.records, isEmpty);
    expect(f.campaign.progress.sensitivity, 1);
    await f.campaign.finish(runId: 'a_result', stage: 1, won: true, score: 900);
    await f.campaign.setSelection(CatalogCategory.aircraft, 'vector');
    await f.campaign.setSelection(CatalogCategory.skill, 'mecha');
    await f.campaign.setSelection(CatalogCategory.character, 'rion');
    await f.campaign.setSelection(CatalogCategory.equipment, 'echo');
    await f.auth.logout();
    await f.coordinator!.settled;
    expect(f.campaign.progress.records[1]!.best, 700);
    expect(f.campaign.progress.sensitivity, 1.25);
    await f.login('b');
    expect(f.campaign.progress.records, isEmpty);
    expect(
      f.campaign.progress.loadout.selected(CatalogCategory.aircraft),
      'aurora',
    );
    expect(
      f.campaign.progress.loadout.selected(CatalogCategory.skill),
      'barrier',
    );
    expect(
      f.campaign.progress.loadout.selected(CatalogCategory.character),
      'pilot',
    );
    expect(
      f.campaign.progress.loadout.selected(CatalogCategory.equipment),
      'standard',
    );
    await f.campaign.finish(
      runId: 'b_result',
      stage: 1,
      won: false,
      score: 100,
    );
    await f.auth.logout();
    await f.login();
    expect(f.campaign.progress.records[1]!.best, 900);
    expect(
      f.campaign.progress.loadout.selected(CatalogCategory.aircraft),
      'vector',
    );
    expect(
      f.campaign.progress.loadout.selected(CatalogCategory.skill),
      'mecha',
    );
    expect(
      f.campaign.progress.loadout.selected(CatalogCategory.character),
      'rion',
    );
    expect(
      f.campaign.progress.loadout.selected(CatalogCategory.equipment),
      'echo',
    );
    expect(
      f.loadout.effectiveSelected(CatalogCategory.aircraft),
      'aurora',
      reason: 'saved selection is not a purchase right',
    );
    expect(f.loadout.effectiveSelected(CatalogCategory.skill), 'barrier');
    expect(f.loadout.effectiveSelected(CatalogCategory.character), 'rion');
    expect(f.loadout.effectiveSelected(CatalogCategory.equipment), 'standard');
    expect((await f.coordinator!.guestSnapshot()).records[1]!.best, 700);
  });

  test('queued A writes keep A snapshots and old battle results cannot settle into B', () async {
    final f = AccountFixture();
    addTearDown(f.dispose);
    await f.campaign.ready;
    await f.login();
    final key = f.auth.connection!.key, epoch = f.campaign.scopeEpoch;
    final gate = Completer<void>();
    f.cache(key).writeGate = gate;
    final writing = f.campaign.finish(
      runId: 'queued_a',
      stage: 1,
      won: true,
      score: 950,
    );
    await Future<void>.delayed(Duration.zero);
    await f.auth.logout();
    expect(await f.auth.login('b@example.test', 'synthetic password'), true);
    gate.complete();
    await writing;
    await f.coordinator!.settled;
    expect(f.cache(key).value!.records[1]!.best, 950);
    expect(f.campaign.progress.records, isEmpty);
    await f.campaign.finish(
      runId: 'old_a_result',
      stage: 1,
      won: true,
      score: 9999,
      expectedScopeEpoch: epoch,
    );
    expect(f.campaign.progress.records, isEmpty);
  });

  test('late A entitlement cannot unlock B or the guest', () async {
    final delayed = DelayedAccess(), f = AccountFixture(entitlements: delayed);
    addTearDown(f.dispose);
    await f.campaign.ready;
    await f.login();
    final checking = f.loadout.refresh();
    await Future<void>.delayed(Duration.zero);
    await f.auth.logout();
    await f.login('b');
    delayed.result.complete(
      SubscriptionAccess(
        AccessStatus.active,
        validUntil: DateTime.now().add(const Duration(days: 1)),
      ),
    );
    expect(await checking, false);
    expect(f.loadout.premiumActive, false);
    expect(f.loadout.select(catalogEntry('vector')), false);
  });

  test('expiry and refresh failure detach private progress; re-login restores only its own cache', () async {
    final f = AccountFixture();
    addTearDown(f.dispose);
    await f.campaign.ready;
    await f.login();
    await f.campaign.finish(runId: 'a_saved', stage: 1, won: true, score: 800);
    f.identity.refreshFailure = 'invalid_session';
    await f.auth.restore();
    await f.coordinator!.settled;
    expect(f.auth.connection, isNull);
    expect(f.identity.uid, isNull);
    expect(f.campaign.progress.records, isEmpty);
    f.identity.refreshFailure = null;
    await f.login();
    expect(f.campaign.progress.records[1]!.best, 800);
    f.identity.refreshFailure = 'unavailable';
    await f.auth.restore();
    await f.coordinator!.settled;
    expect(f.auth.connection, isNull);
    expect(f.loadout.premiumActive, false);
  });

  test('reauth failure, unconfigured server and cancel never send a final deletion request', () async {
    final f = AccountFixture();
    addTearDown(f.dispose);
    await f.campaign.ready;
    await f.login();
    f.identity.rejectReauth = true;
    expect(
      await f.auth.prepareDeletion(password: 'synthetic incorrect'),
      false,
    );
    expect(f.backend.preparations, 0);
    expect(f.backend.commits, 0);
    f.now += 4000;
    f.identity.rejectReauth = false;
    f.backend.ready = false;
    expect(await f.auth.prepareDeletion(password: 'synthetic correct'), false);
    f.backend.ready = true;
    expect(await f.auth.prepareDeletion(password: 'synthetic correct'), true);
    await f.auth.cancelDeletion();
    expect(await f.auth.commitDeletion(), false);
    expect(f.backend.commits, 0);
    expect(f.auth.connection, isNotNull);
    expect(await f.vault.loadDeletion(), isNull);
  });

  test('completed deletion clears only A cache, keeps guest and denies deleted account access', () async {
    final f = AccountFixture();
    addTearDown(f.dispose);
    await f.campaign.ready;
    await f.campaign.finish(
      runId: 'guest_keep',
      stage: 1,
      won: true,
      score: 500,
    );
    await f.login();
    final aKey = f.auth.connection!.key;
    expect(await f.auth.prepareDeletion(password: 'synthetic correct'), true);
    expect(await f.auth.commitDeletion(), true);
    await f.coordinator!.settled;
    expect(f.erased, [aKey]);
    expect(f.identity.uid, isNull);
    expect(await f.vault.loadDeletion(), isNull);
    expect(f.campaign.progress.records[1]!.best, 500);
    expect(f.auth.deletionPending, false);
    expect(
      await f.auth.login('a@example.test', 'synthetic old account'),
      false,
    );
    expect(f.auth.connection, isNull);
  });

  test('lost response persists receipt, blocks new login and restart safely finishes once', () async {
    final f = AccountFixture();
    addTearDown(f.dispose);
    await f.campaign.ready;
    await f.login();
    expect(await f.auth.prepareDeletion(password: 'synthetic correct'), true);
    f.backend.loseResponse = true;
    expect(await f.auth.commitDeletion(), false);
    expect(f.auth.connection, isNull);
    expect(f.auth.deletionPending, true);
    expect((await f.vault.loadDeletion())!.accepted, true);
    expect(await f.auth.login('b@example.test', 'synthetic'), false);
    final restored = EmailAuthController(
      initialize: () async => EmailRuntime(
        identity: f.identity,
        backend: f.backend,
        vault: f.vault,
        apiKey: 'synthetic-api-key',
      ),
    );
    addTearDown(restored.dispose);
    restored.onAccountDeleted = f.erase;
    await restored.restore();
    expect(restored.deletionPending, false);
    expect(f.backend.commits, 1);
    expect(f.backend.resumptions, 1);
    expect(await f.vault.loadDeletion(), isNull);
  });

  test('pending server job and local cleanup failure stay retryable; a different restored SDK user is preserved', () async {
    final f = AccountFixture();
    addTearDown(f.dispose);
    await f.campaign.ready;
    await f.login();
    expect(await f.auth.prepareDeletion(password: 'synthetic correct'), true);
    f.backend.pending = true;
    expect(await f.auth.commitDeletion(), true);
    expect(f.auth.deletionPending, true);
    expect(f.auth.message, isNot(contains('삭제를 완료')));
    f.backend.pending = false;
    f.failErase = true;
    expect(await f.auth.resumeDeletion(), false);
    expect(await f.vault.loadDeletion(), isNotNull);
    f.failErase = false;
    f.identity.uid = 'fictional_b';
    f.identity.verified = true;
    await f.auth.restore();
    await f.coordinator!.settled;
    expect(f.auth.connection!.uid, 'fictional_b');
    expect(f.identity.uid, 'fictional_b');
    expect(f.auth.deletionPending, false);
    expect(f.campaign.progress.records, isEmpty);
  });

  test('file cleanup is limited to exact account cache family and preserves guest/B files', () async {
    final directory = await Directory.systemTemp.createTemp(
      'airzero_account_fixture_',
    );
    addTearDown(() => directory.delete(recursive: true));
    const a = 'airzero-strike-fixture:dev:fictional_a:0',
        aOld = 'airzero-strike-fixture:dev:fictional_a:1',
        b = 'airzero-strike-fixture:dev:fictional_b:0';
    FileProgressRepository repo([String? key]) => FileProgressRepository(
      directory: () async => directory,
      folder: key == null ? 'airzero_progress' : accountCacheFolder(key),
    );
    for (final key in [null, a, aOld, b]) {
      final r = repo(key);
      await r.read();
      await r.write(CampaignProgress());
    }
    await repo(a).eraseAccountFamily();
    expect(
      await Directory('${directory.path}/${accountCacheFolder(a)}').exists(),
      false,
    );
    expect(
      await Directory('${directory.path}/${accountCacheFolder(aOld)}').exists(),
      false,
    );
    expect(
      await Directory('${directory.path}/${accountCacheFolder(b)}').exists(),
      true,
    );
    expect(
      await Directory('${directory.path}/airzero_progress').exists(),
      true,
    );
    expect(repo().eraseAccountCache(), throwsStateError);
    expect(
      () => FileProgressRepository(folder: '../other-app'),
      throwsArgumentError,
    );
  });

  testWidgets(
    'small phone deletion UI requires final confirmation and cancellation keeps records',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = AccountFixture(bind: false);
      addTearDown(f.dispose);
      await tester.pumpWidget(
        RaikeopeuApp(
          emailAuth: f.auth,
          progress: f.guest,
          accountCacheFactory: f.cache,
          eraseAccountCache: f.erase,
          feedback: FixtureFeedback(),
          appInfo: FixtureAppInfo(),
        ),
      );
      await tester.pumpAndSettle();
      await f.auth.login('a@example.test', 'synthetic password');
      await tester.pumpAndSettle();
      expect(f.auth.connection, isNotNull);
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed(AppRoutes.deleteAccount);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('deleteAccountPassword')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const Key('deleteAccountPassword')),
        'synthetic correct',
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('prepareAccountDeletion')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('prepareAccountDeletion')));
      await tester.pumpAndSettle();
      expect(f.backend.commits, 0);
      await tester.ensureVisible(find.byKey(const Key('deleteAccountNow')));
      await tester.tap(find.byKey(const Key('deleteAccountNow')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('confirmAccountDeletion')), findsOneWidget);
      await tester.tap(find.text('취소').last);
      await tester.pumpAndSettle();
      expect(f.backend.commits, 0);
      expect(f.auth.connection, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
