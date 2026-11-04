import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/app.dart';
import 'package:raikeopeu2026/core/readiness.dart';
import 'package:raikeopeu2026/game/progress.dart';
import 'package:raikeopeu2026/security/backend_session.dart';
import 'package:raikeopeu2026/security/email_auth.dart';

import 'fixtures.dart';

class FakeIdentity implements EmailIdentity {
  @override
  bool get passwordAccount => true;
  @override
  Future<void> signInCustomToken(String token) async {
    uid = 'fictional_a';
    verified = true;
  }

  @override
  String? uid;
  @override
  bool verified = false;
  bool reject = false, reauthenticated = false, failSignOut = false;
  Completer<void>? waiting;
  @override
  Future<void> signIn(String email, String password) async {
    if (reject) throw const EmailFailure('credentials');
    await waiting?.future;
    uid = 'fictional_a';
  }

  @override
  Future<void> refresh() async {}
  @override
  Future<void> reauthenticate(String password) async {
    reauthenticated = true;
  }

  @override
  Future<void> signOut() async {
    if (failSignOut) throw StateError('fictional_sdk_signout_failed');
    uid = null;
    verified = false;
  }

  @override
  Future<String?> idToken({bool forceRefresh = false}) async =>
      uid == null ? null : 'synthetic-only-fixture';
  @override
  Future<String?> appCheckToken() async => null;
}

class FakeStorage implements SessionStorage {
  final data = <String, String>{};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }
}

class FakeEmailBackend implements EmailBackend {
  int imports = 0, registrations = 0, resets = 0;
  bool conflict = false, unavailable = false, expired = false;
  Map<String, Object?>? imported;
  @override
  Future<Map<String, dynamic>> call(
    String path, {
    String method = 'POST',
    Map<String, Object?>? body,
    bool authenticated = false,
    bool session = false,
  }) async {
    if (unavailable) throw const EmailFailure('unavailable');
    if (expired) throw const EmailFailure('invalid_session');
    switch (path) {
      case '/v1/session/start':
        return {
          'uid': 'fictional_a',
          'sessionHandle': 'A' * 43,
          'expiresAtMs': 200000,
          'generation': 0,
        };
      case '/v1/me/account':
        return {
          'uid': 'fictional_a',
          'generation': 0,
          'status': 'active',
          'providers': ['password'],
        };
      case '/v1/me/progress':
        return {
          'records': conflict
              ? [
                  {'stage': 1, 'cleared': true, 'best': 900, 'attempts': 2},
                ]
              : [],
        };
      case '/v1/me/import-preview':
        return {
          'decision': conflict
              ? 'conflict_keep_both'
              : 'empty_requires_confirmation',
          'revision': 0,
          'generation': 0,
        };
      case '/v1/me/import-guest':
        if (conflict) throw const EmailFailure('conflict_keep_both');
        imports++;
        imported = body;
        conflict = true;
        return {'revision': 1};
      case '/v1/auth/register':
        registrations++;
        return {'accepted': true};
      case '/v1/auth/reset-email':
        resets++;
        return {'accepted': true};
      default:
        return {'completed': true};
    }
  }
}

class EmailFixture {
  final identity = FakeIdentity(),
      backend = FakeEmailBackend(),
      storage = FakeStorage();
  int now = 1000;
  late final scope = BackendScope.cloud(
    projectId: 'airzero-strike-fixture',
    environment: 'dev',
    region: 'asia-northeast3',
  );
  late final vault = SecureSessionVault(
    scope,
    storage: storage,
    now: () => now,
  );
  late final controller = EmailAuthController(
    initialize: () async => EmailRuntime(
      identity: identity,
      backend: backend,
      vault: vault,
      apiKey: 'synthetic-api-key',
    ),
    now: () => now,
  );
  String link(String mode) =>
      'https://airzero-strike-fixture.firebaseapp.com/__/auth/action?mode=$mode&oobCode=${'x' * 32}&apiKey=synthetic-api-key';
}

void main() {
  test('failed SDK sign-out cannot reconnect on resume or restart without explicit login', () async {
    final f = EmailFixture();
    addTearDown(f.controller.dispose);
    f.identity.uid = 'fictional_a';
    f.identity.verified = true;
    await f.controller.restore();
    expect(f.controller.connection, isNotNull);
    f.identity.failSignOut = true;
    await f.controller.logout();
    expect(f.controller.connection, isNull);
    await f.controller.restore();
    expect(f.controller.phase, EmailPhase.guest);
    expect(f.controller.connection, isNull);
    final restarted = EmailAuthController(
      initialize: () async => EmailRuntime(
        identity: f.identity,
        backend: f.backend,
        vault: SecureSessionVault(
          f.scope,
          storage: f.storage,
          now: () => f.now,
        ),
        apiKey: 'synthetic-api-key',
      ),
      now: () => f.now,
    );
    addTearDown(restarted.dispose);
    await restarted.restore();
    expect(restarted.connection, isNull);
    f.identity.failSignOut = false;
    expect(
      await restarted.login('fictional@example.test', 'fictional password'),
      true,
    );
    expect(restarted.phase, EmailPhase.verificationPending);
    f.identity.verified = true;
    expect(await restarted.refreshVerification(), true);
    expect(restarted.connection, isNotNull);
    expect(await f.vault.hasSignOutIntent(), false);
  });
  test('action links allow only the configured HTTPS project/mode/key/return and redact tokens', () {
    final f = EmailFixture(), valid = EmailFixture().link('resetPassword');
    expect(
      EmailActionLink.parse(valid, f.scope, 'synthetic-api-key').mode,
      'resetPassword',
    );
    expect(
      EmailActionLink.parse(valid, f.scope, 'synthetic-api-key').toString(),
      'EmailActionLink([redacted])',
    );
    for (final bad in [
      valid.replaceFirst('https:', 'http:'),
      valid.replaceFirst('airzero-strike-fixture.', 'other.'),
      '$valid&mode=verifyEmail',
      '$valid#fragment',
      '$valid&continueUrl=https%3A%2F%2Fother.invalid',
      valid.replaceFirst('synthetic-api-key', 'other-key'),
      valid.replaceFirst('resetPassword', 'signIn'),
      valid.replaceFirst('/__/auth/action', '/emulator/action'),
    ]) {
      expect(
        () => EmailActionLink.parse(bad, f.scope, 'synthetic-api-key'),
        throwsA(isA<EmailFailure>()),
      );
    }
  });
  test(
    'a rejected replacement link cannot leave the previous action active',
    () async {
      final f = EmailFixture();
      addTearDown(f.controller.dispose);
      expect(await f.controller.inspectLink(f.link('resetPassword')), true);
      expect(
        await f.controller.inspectLink('https://unapproved.invalid'),
        false,
      );
      expect(f.controller.pendingAction, isNull);
      expect(
        await f.controller.confirmLink('a fictional replacement password'),
        false,
      );
    },
  );
  test(
    'unverified SDK identity cannot open the private server session',
    () async {
      final f = EmailFixture();
      addTearDown(f.controller.dispose);
      expect(
        await f.controller.login(
          'fictional@example.test',
          'synthetic password',
        ),
        true,
      );
      expect(f.controller.phase, EmailPhase.verificationPending);
      expect(await f.vault.load(), isNull);
      f.identity.verified = true;
      expect(await f.controller.refreshVerification(), true);
      expect(f.controller.phase, EmailPhase.connected);
      expect((await f.vault.load())!.uid, 'fictional_a');
    },
  );
  test('explicit guest import preserves original records/settings and existing account refuses overwrite', () async {
    final f = EmailFixture();
    addTearDown(f.controller.dispose);
    f.identity.verified = true;
    await f.controller.login('fictional@example.test', 'synthetic password');
    final progress = CampaignProgress(
      records: {1: const StageRecord(cleared: true, best: 900, attempts: 2)},
      sensitivity: 1.25,
    );
    final before = progress.toJson().toString();
    expect(f.backend.imports, 0);
    expect(await f.controller.importGuest(progress), true);
    expect(f.backend.imports, 1);
    expect(progress.toJson().toString(), before);
    expect((f.backend.imported!['guest'] as Map).keys, ['schema', 'records']);
    expect(await f.controller.importGuest(progress), false);
    expect(f.backend.imports, 1);
  });
  test('register/reset use a bounded cooldown with a generic response and no automatic sign-in', () async {
    final f = EmailFixture();
    addTearDown(f.controller.dispose);
    await f.controller.register(
      'fictional@example.test',
      'a synthetic registration passphrase',
    );
    expect(f.identity.uid, isNull);
    expect(await f.controller.requestReset('unknown@example.test'), true);
    expect(await f.controller.requestReset('unknown@example.test'), false);
    f.now += 60001;
    expect(await f.controller.requestReset('unknown@example.test'), true);
    expect(f.backend.resets, 2);
    expect(f.identity.uid, isNull);
  });
  test('connected registration preserves its account and a new login discards old action proof', () async {
    final f = EmailFixture();
    addTearDown(f.controller.dispose);
    f.identity.verified = true;
    await f.controller.login('fictional@example.test', 'synthetic password');
    await f.controller.inspectLink(f.link('resetPassword'));
    expect(
      await f.controller.register(
        'other@example.test',
        'a new synthetic passphrase',
      ),
      false,
    );
    expect(f.controller.phase, EmailPhase.connected);
    expect(f.backend.registrations, 0);
    expect(f.identity.uid, 'fictional_a');
    await f.controller.login('fictional@example.test', 'synthetic password');
    expect(f.controller.pendingAction, isNull);
  });
  test('reset confirmation discards action/session and requires a new explicit login', () async {
    final f = EmailFixture();
    addTearDown(f.controller.dispose);
    f.identity.verified = true;
    await f.controller.login('fictional@example.test', 'synthetic password');
    expect(await f.controller.inspectLink(f.link('resetPassword')), true);
    expect(await f.controller.confirmLink('a new synthetic passphrase'), true);
    expect(f.controller.phase, EmailPhase.guest);
    expect(f.identity.uid, isNull);
    expect(await f.vault.load(), isNull);
    expect(f.controller.pendingAction, isNull);
  });
  test(
    'late login completion after logout cannot revive an identity or vault',
    () async {
      final f = EmailFixture();
      addTearDown(f.controller.dispose);
      f.identity.waiting = Completer<void>();
      final logging = f.controller.login(
        'fictional@example.test',
        'synthetic password',
      );
      await Future<void>.delayed(Duration.zero);
      final logout = f.controller.logout();
      expect(f.controller.busy, true);
      expect(
        await f.controller.login(
          'other@example.test',
          'another synthetic password',
        ),
        false,
      );
      f.identity.waiting!.complete();
      await logging;
      await logout;
      expect(f.identity.uid, isNull);
      expect(f.controller.phase, EmailPhase.guest);
      expect(await f.vault.load(), isNull);
    },
  );
  test(
    'logout waits for initialization and clears a restored SDK identity',
    () async {
      final f = EmailFixture(), initializing = Completer<EmailRuntime>();
      final controller = EmailAuthController(
        initialize: () => initializing.future,
      );
      addTearDown(controller.dispose);
      final restoring = controller.restore();
      final logout = controller.logout();
      f.identity.uid = 'fictional_restored';
      initializing.complete(
        EmailRuntime(
          identity: f.identity,
          backend: f.backend,
          vault: f.vault,
          apiKey: 'synthetic-api-key',
        ),
      );
      await restoring;
      await logout;
      expect(f.identity.uid, isNull);
      expect(controller.phase, EmailPhase.guest);
      expect(controller.busy, false);
    },
  );
  test('a rejected session clears the previous connected state and protected handle', () async {
    final f = EmailFixture();
    addTearDown(f.controller.dispose);
    f.identity.verified = true;
    await f.controller.login('fictional@example.test', 'synthetic password');
    expect(f.controller.phase, EmailPhase.connected);
    f.backend.expired = true;
    expect(await f.controller.refreshVerification(), false);
    expect(f.controller.phase, EmailPhase.guest);
    expect(f.controller.serverRecordCount, 0);
    expect(f.identity.uid, isNull);
    expect(await f.vault.load(), isNull);
  });
  test('backend failure never becomes a connected account and can retry without deleting guest data', () async {
    final f = EmailFixture();
    addTearDown(f.controller.dispose);
    f.identity.verified = true;
    f.backend.unavailable = true;
    expect(
      await f.controller.login('fictional@example.test', 'synthetic password'),
      false,
    );
    expect(f.controller.phase, EmailPhase.serverPending);
    expect(await f.vault.load(), isNull);
    f.backend.unavailable = false;
    expect(await f.controller.refreshVerification(), true);
    expect(f.controller.phase, EmailPhase.connected);
  });
  testWidgets(
    'configured login enters verification, keeps password manager/paste support and clears password',
    (tester) async {
      final f = EmailFixture();
      addTearDown(f.controller.dispose);
      await tester.pumpWidget(
        RaikeopeuApp(
          emailAuth: f.controller,
          progress: FixtureProgress(),
          feedback: FixtureFeedback(),
          appInfo: FixtureAppInfo(),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed(AppRoutes.login);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('emailInput')),
        'fictional@example.test',
      );
      await tester.enterText(
        find.byKey(const Key('passwordInput')),
        'a synthetic login passphrase',
      );
      final field = tester.widget<TextFormField>(
        find.byKey(const Key('passwordInput')),
      );
      expect(field.enabled, isNot(false));
      await tester.ensureVisible(find.byKey(const Key('emailSubmit')));
      await tester.tap(find.byKey(const Key('emailSubmit')));
      await tester.pumpAndSettle();
      expect(find.text('이메일 확인'), findsOneWidget);
      expect(f.controller.phase, EmailPhase.verificationPending);
    },
  );
}
