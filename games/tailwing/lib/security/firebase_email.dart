import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'backend_session.dart';
import 'email_auth.dart';
import 'native_social.dart';

/// Public Firebase client configuration only. No service account/admin secret.
Future<EmailRuntime> createFirebaseEmailRuntime() async {
  if (kIsWeb ||
      !{
        TargetPlatform.android,
        TargetPlatform.iOS,
      }.contains(defaultTargetPlatform)) {
    throw const EmailFailure('setup');
  }
  final local =
      kDebugMode && const bool.fromEnvironment('AIRZERO_AUTH_EMULATOR');
  const project = String.fromEnvironment('AIRZERO_FIREBASE_PROJECT');
  const apiKey = String.fromEnvironment('AIRZERO_FIREBASE_API_KEY');
  const appId = String.fromEnvironment('AIRZERO_FIREBASE_APP_ID');
  const sender = String.fromEnvironment('AIRZERO_FIREBASE_SENDER_ID');
  const environment = String.fromEnvironment('AIRZERO_ENVIRONMENT');
  const region = String.fromEnvironment('AIRZERO_REGION');
  if (!local &&
      (project.isEmpty ||
          apiKey.isEmpty ||
          appId.isEmpty ||
          sender.isEmpty ||
          environment.isEmpty ||
          region.isEmpty)) {
    throw const EmailFailure('setup');
  }
  final scope = local
      ? BackendScope.emulator(
          androidEmulator: defaultTargetPlatform == TargetPlatform.android,
        )
      : BackendScope.cloud(
          projectId: project,
          environment: environment,
          region: region,
        );
  final options = FirebaseOptions(
    apiKey: local ? 'fake-api-key' : apiKey,
    appId: local ? '1:123456789:android:abcdef1234567890' : appId,
    messagingSenderId: local ? '123456789' : sender,
    projectId: scope.projectId,
  );
  final app = await Firebase.initializeApp(
    name: 'airzero-email-${scope.environment}',
    options: options,
  );
  final auth = FirebaseAuth.instanceFor(app: app);
  FirebaseAppCheck? check;
  if (local) {
    await auth.useAuthEmulator(
      defaultTargetPlatform == TargetPlatform.android
          ? '10.0.2.2'
          : '127.0.0.1',
      9299,
      automaticHostMapping: false,
    );
  } else {
    check = FirebaseAppCheck.instanceFor(app: app);
    await check.activate(
      providerAndroid: const AndroidPlayIntegrityProvider(),
      providerApple: const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  }
  await auth.setLanguageCode('ko');
  final identity = FirebaseEmailIdentity(auth, check);
  final vault = SecureSessionVault(scope);
  final backend = FirebaseEmailBackend(scope, identity, vault);
  // Per-operation server readiness is checked at the email/social endpoints.
  return EmailRuntime(
    identity: identity,
    backend: backend,
    vault: vault,
    apiKey: options.apiKey,
    social: NativeSocialClient(),
  );
}

class FirebaseEmailIdentity implements EmailIdentity {
  FirebaseEmailIdentity(this.auth, this.check);
  final FirebaseAuth auth;
  final FirebaseAppCheck? check;
  String? _socialUid;
  @override
  String? get uid => auth.currentUser?.uid;
  @override
  bool get verified =>
      (auth.currentUser?.emailVerified ?? false) ||
      (uid != null && _socialUid == uid);
  @override
  bool get passwordAccount =>
      auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
      false;
  Future<T> _safe<T>(
    Future<T> Function() work, {
    bool signingIn = false,
  }) async {
    try {
      // A Dart timeout does not cancel a native Firebase mutation. Let the SDK
      // settle so logout's barrier also covers a delayed sign-in/reload.
      return await work();
    } on FirebaseAuthException catch (error) {
      throw EmailFailure(switch (error.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'invalid-email' => 'credentials',
        'user-not-found' ||
        'user-disabled' => signingIn ? 'credentials' : 'invalid_session',
        'too-many-requests' => 'try_later',
        'requires-recent-login' ||
        'user-token-expired' ||
        'invalid-user-token' => 'invalid_session',
        _ => 'unavailable',
      });
    } on EmailFailure {
      rethrow;
    } catch (_) {
      throw const EmailFailure('unavailable');
    }
  }

  @override
  Future<void> signIn(String email, String password) async {
    _socialUid = null;
    await _safe(
      () => auth.signInWithEmailAndPassword(email: email, password: password),
      signingIn: true,
    );
  }

  @override
  Future<void> signInCustomToken(String token) => _safe(() async {
    final credential = await auth.signInWithCustomToken(token);
    _socialUid = credential.user?.uid;
  });

  @override
  Future<void> refresh() => _safe(() async {
    await auth.currentUser?.reload();
    _socialUid = null;
    if (auth.currentUser != null) {
      final token = await auth.currentUser!.getIdTokenResult(true);
      if (token.claims?['azSocialGrant'] is String &&
          token.signInProvider == 'custom') {
        _socialUid = uid;
      }
    }
  });
  @override
  Future<void> reauthenticate(String password) => _safe(() async {
    final user = auth.currentUser;
    if (user == null ||
        user.email == null ||
        !user.providerData.any((p) => p.providerId == 'password')) {
      throw const EmailFailure('invalid_session');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: password),
    );
    await user.getIdToken(true);
  });
  @override
  Future<void> signOut() => _safe(() async {
    _socialUid = null;
    await auth.signOut();
  });
  @override
  Future<String?> idToken({bool forceRefresh = false}) =>
      _safe(() async => auth.currentUser?.getIdToken(forceRefresh));
  @override
  Future<String?> appCheckToken() async => check?.getToken();
}

class FirebaseEmailBackend implements EmailBackend {
  FirebaseEmailBackend(this.scope, this.identity, this.vault);
  final BackendScope scope;
  final EmailIdentity identity;
  final SecureSessionVault vault;
  @override
  Future<Map<String, dynamic>> call(
    String path, {
    String method = 'POST',
    Map<String, Object?>? body,
    bool authenticated = false,
    bool session = false,
  }) async {
    const paths = {
      '/v1/public/email-policy',
      '/v1/public/social-policy',
      '/v1/public/account-policy',
      '/v1/me/account',
      '/v1/account/deletion/prepare',
      '/v1/account/deletion/commit',
      '/v1/account/deletion/resume',
      '/v1/social/begin',
      '/v1/social/complete',
      '/v1/auth/register',
      '/v1/auth/reset-email',
      '/v1/auth/verification-email',
      '/v1/auth/change-email',
      '/v1/auth/check-action',
      '/v1/auth/confirm-action',
      '/v1/session/start',
      '/v1/session/end',
      '/v1/me/progress',
      '/v1/me/import-preview',
      '/v1/me/import-guest',
      '/v1/billing/status',
      '/v1/billing/intent',
      '/v1/billing/verify',
    };
    if (!paths.contains(path) || !{'POST', 'GET'}.contains(method)) {
      throw const EmailFailure('unavailable');
    }
    if (path.startsWith('/v1/billing/') &&
        (!authenticated ||
            !session ||
            method != (path.endsWith('/status') ? 'GET' : 'POST'))) {
      throw const EmailFailure('invalid_session');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      return await (() async {
        final request = await client.openUrl(
          method,
          scope.endpoint.replace(path: '${scope.endpoint.path}$path'),
        );
        request.followRedirects = false;
        request.headers.contentType = ContentType.json;
        final proof = await identity.appCheckToken();
        if (!scope.emulator && (proof == null || proof.isEmpty)) {
          throw const EmailFailure('invalid_session');
        }
        if (proof != null) request.headers.set('X-Firebase-AppCheck', proof);
        if (authenticated) {
          final token = await identity.idToken();
          if (token == null) throw const EmailFailure('invalid_session');
          request.headers.set('Authorization', 'Bearer $token');
        }
        if (session) {
          final stored = await vault.load();
          if (stored == null || stored.uid != identity.uid) {
            throw const EmailFailure('invalid_session');
          }
          request.headers.set('X-Airzero-Session', stored.handle);
        }
        if (body != null) {
          final bytes = utf8.encode(jsonEncode(body));
          if (bytes.length > 32768) throw const EmailFailure('unavailable');
          request.add(bytes);
        }
        final response = await request.close();
        final bytes = <int>[];
        await for (final part in response) {
          bytes.addAll(part);
          if (bytes.length > 65536) throw const EmailFailure('unavailable');
        }
        final data = jsonDecode(utf8.decode(bytes));
        if (data is! Map<String, dynamic>) {
          throw const EmailFailure('unavailable');
        }
        if (response.statusCode != 200) {
          const allowed = {
            'social_setup_required',
            'invalid_provider_proof',
            'invalid_challenge',
            'provider_conflict',
            'password_link_required',
            'email_setup_required',
            'password_policy',
            'password_blocked',
            'try_later',
            'invalid_or_expired_link',
            'link_account_mismatch',
            'invalid_session',
            'fresh_token_required',
            'recent_authentication_required',
            'conflict_keep_both',
            'revision_conflict',
            'generation_conflict',
            'account_setup_required',
            'account_unavailable',
            'deletion_request_expired',
            'invalid_deletion_request',
            'confirmation_required',
            'billing_setup_required',
            'billing_verification_failed',
            'billing_busy',
            'billing_try_later',
            'invalid_purchase',
            'purchase_scope_denied',
            'purchase_owner_conflict',
            'subscription_already_exists',
          };
          throw EmailFailure(
            allowed.contains(data['error'])
                ? data['error'] as String
                : 'unavailable',
          );
        }
        return data;
      })().timeout(const Duration(seconds: 25));
    } on EmailFailure {
      rethrow;
    } on SessionStorageFailure {
      throw const EmailFailure('storage');
    } catch (_) {
      throw const EmailFailure('unavailable');
    } finally {
      client.close(force: true);
    }
  }
}
