import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart'
    as google;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'email_auth.dart';
import 'social_types.dart';

/// Upstream tokens exist only while exchanging a server challenge. Firebase
/// owns the app session; no social refresh token is saved by this application.
class MemoryKakaoTokens implements kakao.TokenManager {
  kakao.OAuthToken? _token;
  @override
  Future<void> setToken(kakao.OAuthToken token) async {
    _token = token;
  }

  @override
  Future<kakao.OAuthToken?> getToken() async => _token;
  @override
  Future<void> clear() async {
    _token = null;
  }
}

class NativeSocialClient implements SocialProviderClient {
  NativeSocialClient({
    this.googleClient = googleServer,
    this.iosClient = googleIos,
    this.kakaoNativeKey = kakaoKey,
    this.appleLoginEnabled = appleEnabled,
  });
  final String googleClient, iosClient, kakaoNativeKey;
  final bool appleLoginEnabled;
  static const googleServer = String.fromEnvironment(
    'AIRZERO_GOOGLE_WEB_CLIENT_ID',
  );
  static const googleIos = String.fromEnvironment(
    'AIRZERO_GOOGLE_IOS_CLIENT_ID',
  );
  static const kakaoKey = String.fromEnvironment('AIRZERO_KAKAO_NATIVE_KEY');
  static const appleEnabled = bool.fromEnvironment('AIRZERO_APPLE_LOGIN');
  final _kakaoTokens = MemoryKakaoTokens();
  bool _kakaoInitialized = false, _googleInitialized = false;
  bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;
  @override
  bool configured(SocialProvider provider) {
    if (kIsWeb ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(defaultTargetPlatform)) {
      return false;
    }
    final googleId = RegExp(r'^[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$');
    return switch (provider) {
      SocialProvider.google =>
        googleId.hasMatch(googleClient) &&
            (!_ios || googleId.hasMatch(iosClient)),
      SocialProvider.kakao => RegExp(
        r'^[a-f0-9]{32}$',
      ).hasMatch(kakaoNativeKey),
      SocialProvider.apple => _ios && appleLoginEnabled,
    };
  }

  @override
  Future<SocialProof> authorize(
    SocialProvider provider,
    SocialChallengeData challenge, {
    bool kakaoAccountOnly = false,
  }) async {
    if (!configured(provider)) {
      throw const EmailFailure('social_setup_required');
    }
    try {
      switch (provider) {
        case SocialProvider.google:
          // The app-facing singleton supports initialize exactly once. Use its
          // public typed native platform adapter to configure a fresh nonce on
          // each serialized attempt, without adding event-stream subscriptions.
          final sdk = google.GoogleSignInPlatform.instance;
          await sdk.init(
            google.InitParameters(
              clientId: _ios ? iosClient : null,
              serverClientId: googleClient,
              nonce: challenge.nonce,
            ),
          );
          _googleInitialized = true;
          if (!sdk.supportsAuthenticate()) {
            throw const EmailFailure('social_unavailable');
          }
          final result = await sdk.authenticate(
            const google.AuthenticateParameters(),
          );
          final token = result.authenticationTokens.idToken;
          if (token == null) throw const EmailFailure('invalid_provider_proof');
          return SocialProof(provider, token);
        case SocialProvider.kakao:
          if (!_kakaoInitialized) {
            await kakao.KakaoSdk.init(
              nativeAppKey: kakaoNativeKey,
              loggingEnabled: false,
            );
            kakao.TokenManagerProvider.instance.manager = _kakaoTokens;
            _kakaoInitialized = true;
          }
          // No catch-and-auto-fallback after cancellation or failure. The user
          // can explicitly select the account/browser button for another try.
          final token = await chooseKakaoAuthorization(
            accountOnly: kakaoAccountOnly,
            installed: kakao.isKakaoTalkInstalled,
            talk: () => kakao.UserApi.instance.loginWithKakaoTalk(
              nonce: challenge.nonce,
            ),
            account: () => kakao.UserApi.instance.loginWithKakaoAccount(
              nonce: challenge.nonce,
            ),
          );
          if (token.idToken == null) {
            throw const EmailFailure('social_setup_required');
          }
          return SocialProof(
            provider,
            token.idToken!,
            accessToken: token.accessToken,
          );
        case SocialProvider.apple:
          if (!await SignInWithApple.isAvailable()) {
            throw const EmailFailure('social_unavailable');
          }
          final value = await SignInWithApple.getAppleIDCredential(
            scopes: const [],
            nonce: sha256.convert(utf8.encode(challenge.nonce)).toString(),
            state: challenge.state,
          );
          if (value.state != challenge.state || value.identityToken == null) {
            throw const EmailFailure('invalid_provider_proof');
          }
          return SocialProof(provider, value.identityToken!);
      }
    } on google.GoogleSignInException catch (error) {
      throw EmailFailure(switch (error.code) {
        google.GoogleSignInExceptionCode.canceled => 'social_cancelled',
        google.GoogleSignInExceptionCode.clientConfigurationError ||
        google.GoogleSignInExceptionCode.providerConfigurationError =>
          'social_setup_required',
        _ => 'social_unavailable',
      });
    } on kakao.KakaoClientException catch (error) {
      throw EmailFailure(
        error.reason == kakao.ClientErrorCause.cancelled
            ? 'social_cancelled'
            : 'social_unavailable',
      );
    } on PlatformException catch (error) {
      throw EmailFailure(
        {'CANCELED', 'CANCELLED', 'cancelled', 'canceled'}.contains(error.code)
            ? 'social_cancelled'
            : 'social_unavailable',
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      throw EmailFailure(
        error.code == AuthorizationErrorCode.canceled
            ? 'social_cancelled'
            : 'social_unavailable',
      );
    } on EmailFailure {
      rethrow;
    } catch (_) {
      throw const EmailFailure('social_unavailable');
    } finally {
      await _kakaoTokens.clear();
    }
  }

  @override
  Future<void> clear() async {
    await _kakaoTokens.clear();
    if (_googleInitialized) {
      await google.GoogleSignInPlatform.instance.signOut(
        const google.SignOutParams(),
      );
    }
  }
}

/// Choose once. A cancelled/denied Talk request must never open another prompt.
Future<T> chooseKakaoAuthorization<T>({
  required bool accountOnly,
  required Future<bool> Function() installed,
  required Future<T> Function() talk,
  required Future<T> Function() account,
}) async {
  return !accountOnly && await installed() ? talk() : account();
}
