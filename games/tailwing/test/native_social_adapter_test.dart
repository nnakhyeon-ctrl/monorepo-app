import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart'
    as google;
import 'package:raikeopeu2026/security/native_social.dart';
import 'package:raikeopeu2026/security/social_types.dart';
import 'package:raikeopeu2026/security/email_auth.dart';

class GoogleFixture extends google.GoogleSignInPlatform {
  final nonces = <String?>[];
  int prompts = 0, signouts = 0;
  bool cancel = false;
  @override
  Future<void> init(google.InitParameters p) async {
    nonces.add(p.nonce);
  }

  @override
  bool supportsAuthenticate() => true;
  @override
  Future<google.AuthenticationResults> authenticate(
    google.AuthenticateParameters params,
  ) async {
    prompts++;
    if (cancel) {
      throw const google.GoogleSignInException(
        code: google.GoogleSignInExceptionCode.canceled,
      );
    }
    return const google.AuthenticationResults(
      user: google.GoogleSignInUserData(email: '', id: 'synthetic-id'),
      authenticationTokens: google.AuthenticationTokenData(
        idToken: 'synthetic-id-token',
      ),
    );
  }

  @override
  Future<void> signOut(google.SignOutParams p) async {
    signouts++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected Google API');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SocialChallengeData challenge(String nonce) => SocialChallengeData.fromJson({
    'challengeId': 'a' * 43,
    'state': 'b' * 43,
    'nonce': nonce * 43,
  });
  test('Google native adapter sends a fresh challenge nonce per attempt and cancellation never retries', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final original = google.GoogleSignInPlatform.instance,
        sdk = GoogleFixture();
    google.GoogleSignInPlatform.instance = sdk;
    addTearDown(() {
      google.GoogleSignInPlatform.instance = original;
      debugDefaultTargetPlatformOverride = null;
    });
    final client = NativeSocialClient(
      googleClient: 'synthetic-web.apps.googleusercontent.com',
    );
    expect(
      (await client.authorize(SocialProvider.google, challenge('c'))).idToken,
      'synthetic-id-token',
    );
    await client.clear();
    await client.authorize(SocialProvider.google, challenge('d'));
    expect(sdk.nonces, ['c' * 43, 'd' * 43]);
    sdk.cancel = true;
    await expectLater(
      client.authorize(SocialProvider.google, challenge('e')),
      throwsA(
        isA<EmailFailure>().having((e) => e.code, 'code', 'social_cancelled'),
      ),
    );
    expect(sdk.prompts, 3);
    expect(sdk.signouts, 1);
  });
  test('Kakao missing Talk uses account once; cancellation never forces fallback and explicit account bypasses Talk', () async {
    int talks = 0, accounts = 0, checks = 0;
    bool installed = false;
    Future<String> choose(bool accountOnly) => chooseKakaoAuthorization(
      accountOnly: accountOnly,
      installed: () async {
        checks++;
        return installed;
      },
      talk: () async {
        talks++;
        throw const EmailFailure('social_cancelled');
      },
      account: () async {
        accounts++;
        return 'synthetic';
      },
    );
    expect(await choose(false), 'synthetic');
    installed = true;
    await expectLater(choose(false), throwsA(isA<EmailFailure>()));
    expect(accounts, 1);
    expect(talks, 1);
    expect(await choose(true), 'synthetic');
    expect(checks, 2);
    expect(accounts, 2);
  });
}
