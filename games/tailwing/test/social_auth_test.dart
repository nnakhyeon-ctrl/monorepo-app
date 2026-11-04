import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/app.dart';
import 'package:raikeopeu2026/core/readiness.dart';
import 'package:raikeopeu2026/security/backend_session.dart';
import 'package:raikeopeu2026/security/email_auth.dart';
import 'package:raikeopeu2026/security/social_types.dart';

import 'email_auth_test.dart' show FakeIdentity, FakeEmailBackend, FakeStorage;
import 'fixtures.dart';

class SocialClientFixture implements SocialProviderClient {
  bool available = true, browser = false;
  String? error;
  int calls = 0, clears = 0;
  Completer<void>? pending;
  @override
  bool configured(SocialProvider provider) => available;
  @override
  Future<SocialProof> authorize(
    SocialProvider provider,
    SocialChallengeData challenge, {
    bool kakaoAccountOnly = false,
  }) async {
    calls++;
    browser = kakaoAccountOnly;
    await pending?.future;
    if (error != null) throw EmailFailure(error!);
    return SocialProof(
      provider,
      'synthetic-provider-proof',
      accessToken: provider == SocialProvider.kakao
          ? 'synthetic-opaque-access'
          : null,
    );
  }

  @override
  Future<void> clear() async {
    clears++;
  }
}

class SocialBackendFixture extends FakeEmailBackend {
  final calls = <String>[];
  Map<String, Object?>? completeBody, beginBody;
  bool denied = false, authenticatedLink = false;
  Completer<void>? waitingBegin;
  @override
  Future<Map<String, dynamic>> call(
    String path, {
    String method = 'POST',
    Map<String, Object?>? body,
    bool authenticated = false,
    bool session = false,
  }) async {
    calls.add(path);
    if (path == '/v1/social/begin') {
      beginBody = body;
      authenticatedLink = authenticated && session;
      await waitingBegin?.future;
      return {'challengeId': 'a' * 43, 'state': 'b' * 43, 'nonce': 'c' * 43};
    }
    if (path == '/v1/social/complete') {
      completeBody = body;
      if (denied) throw const EmailFailure('provider_conflict');
      return {'uid': 'fictional_a', 'customToken': 'synthetic-custom-token'};
    }
    return super.call(
      path,
      method: method,
      body: body,
      authenticated: authenticated,
      session: session,
    );
  }
}

class SocialFixture {
  final identity = FakeIdentity(),
      backend = SocialBackendFixture(),
      client = SocialClientFixture(),
      storage = FakeStorage();
  late final vault = SecureSessionVault(
    BackendScope.cloud(
      projectId: 'airzero-strike-fixture',
      environment: 'dev',
      region: 'asia-northeast3',
    ),
    storage: storage,
    now: () => 1000,
  );
  late final controller = EmailAuthController(
    initialize: () async => EmailRuntime(
      identity: identity,
      backend: backend,
      vault: vault,
      apiKey: 'synthetic-api-key',
      social: client,
    ),
    now: () => 1000,
  );
}

void main() {
  test('social proof and challenge diagnostics redact credentials', () {
    final c = SocialChallengeData.fromJson({
      'challengeId': 'a' * 43,
      'state': 'b' * 43,
      'nonce': 'c' * 43,
    });
    expect(c.toString(), isNot(contains('a' * 43)));
    expect(
      SocialProof(SocialProvider.google, 'synthetic-secret').toString(),
      isNot(contains('synthetic-secret')),
    );
    expect(
      () => SocialChallengeData.fromJson({'challengeId': 'bad'}),
      throwsFormatException,
    );
  });
  test('social signup requires no email and never uploads guest data or unlocks purchases', () async {
    final f = SocialFixture();
    addTearDown(f.controller.dispose);
    expect(await f.controller.socialSignIn(SocialProvider.google), true);
    expect(f.controller.phase, EmailPhase.connected);
    expect(f.backend.completeBody?['state'], 'b' * 43);
    expect(
      (f.backend.completeBody?['proof'] as Map)['kind'],
      'google-id-token',
    );
    expect(f.backend.imports, 0);
    expect(f.backend.registrations, 0);
    expect(f.backend.calls.any((p) => p.contains('entitlement')), false);
    expect(f.client.clears, 1);
  });
  test('cancel, network error and missing setup preserve guest identity and avoid completion', () async {
    for (final error in [
      'social_cancelled',
      'social_unavailable',
      'social_setup_required',
    ]) {
      final f = SocialFixture();
      addTearDown(f.controller.dispose);
      f.client.error = error;
      expect(await f.controller.socialSignIn(SocialProvider.kakao), false);
      expect(f.identity.uid, isNull);
      expect(f.controller.phase, EmailPhase.guest);
      expect(f.backend.completeBody, isNull);
      expect(f.client.calls, 1);
      expect(f.backend.imports, 0);
    }
    final f = SocialFixture();
    addTearDown(f.controller.dispose);
    f.client.available = false;
    expect(await f.controller.socialSignIn(SocialProvider.google), false);
    expect(f.client.calls, 0);
    expect(f.backend.calls, isEmpty);
  });
  test('browser fallback is explicitly requested and duplicate taps cannot open another prompt', () async {
    final f = SocialFixture();
    addTearDown(f.controller.dispose);
    f.client.pending = Completer<void>();
    final first = f.controller.socialSignIn(
      SocialProvider.kakao,
      kakaoAccountOnly: true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(await f.controller.socialSignIn(SocialProvider.kakao), false);
    expect(f.client.calls, 1);
    expect(f.client.browser, true);
    f.client.pending!.complete();
    expect(await first, true);
  });
  test('email link requires explicit intent and reauthentication and keeps conflict records', () async {
    final f = SocialFixture();
    addTearDown(f.controller.dispose);
    f.identity.verified = true;
    await f.controller.login('fictional@example.test', 'synthetic-password');
    expect(await f.controller.socialSignIn(SocialProvider.google), false);
    expect(
      await f.controller.socialSignIn(SocialProvider.google, link: true),
      false,
    );
    f.backend.denied = true;
    expect(
      await f.controller.socialSignIn(
        SocialProvider.google,
        link: true,
        currentPassword: 'synthetic-password',
      ),
      false,
    );
    expect(f.identity.reauthenticated, true);
    expect(f.backend.authenticatedLink, true);
    expect(f.backend.beginBody?['intent'], 'link');
    expect(f.identity.uid, 'fictional_a');
    expect(f.controller.phase, EmailPhase.connected);
    expect(f.backend.imports, 0);
    f.backend.denied = false;
    expect(
      await f.controller.socialSignIn(
        SocialProvider.google,
        link: true,
        currentPassword: 'synthetic-password',
      ),
      true,
    );
    expect(f.identity.uid, 'fictional_a');
  });
  test(
    'logout while provider prompt is pending prevents late sign-in revival',
    () async {
      final f = SocialFixture();
      addTearDown(f.controller.dispose);
      f.client.pending = Completer<void>();
      final login = f.controller.socialSignIn(SocialProvider.google);
      await Future<void>.delayed(Duration.zero);
      final logout = f.controller.logout();
      f.client.pending!.complete();
      expect(await login, false);
      await logout;
      expect(f.identity.uid, isNull);
      expect(f.backend.completeBody, isNull);
      expect(f.controller.phase, EmailPhase.guest);
      expect(await f.vault.load(), isNull);
      expect(await f.vault.hasSignOutIntent(), true);
      expect(f.storage.data.values, ['1']);
    },
  );
  test(
    'logout during challenge request cannot open a delayed native prompt',
    () async {
      final f = SocialFixture();
      addTearDown(f.controller.dispose);
      f.backend.waitingBegin = Completer<void>();
      final login = f.controller.socialSignIn(SocialProvider.google);
      await Future<void>.delayed(Duration.zero);
      final logout = f.controller.logout();
      f.backend.waitingBegin!.complete();
      expect(await login, false);
      await logout;
      expect(f.client.calls, 0);
      expect(f.identity.uid, isNull);
    },
  );
  testWidgets(
    'successful social login returns to original settings and preserves guest progress',
    (tester) async {
      final f = SocialFixture();
      addTearDown(f.controller.dispose);
      final progress = FixtureProgress();
      await tester.pumpWidget(
        RaikeopeuApp(
          progress: progress,
          emailAuth: f.controller,
          feedback: FixtureFeedback(),
          appInfo: FixtureAppInfo(),
        ),
      );
      await tester.pumpAndSettle();
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.pushNamed(AppRoutes.settings);
      await tester.pumpAndSettle();
      nav.pushNamed(AppRoutes.account);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('googleLogin')));
      await tester.tap(find.byKey(const Key('googleLogin')));
      await tester.pumpAndSettle();
      expect(find.text('환경설정'), findsWidgets);
      expect(find.byKey(const Key('googleLogin')), findsNothing);
      expect(f.controller.phase, EmailPhase.connected);
      expect(f.backend.imports, 0);
    },
  );
}
