import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../game/progress.dart';
import 'backend_session.dart';
import 'social_types.dart';

class EmailFailure implements Exception {
  const EmailFailure(this.code);
  final String code;
  @override
  String toString() => 'EmailFailure($code)';
}

String emailError(Object error) {
  final code = error is EmailFailure ? error.code : 'unavailable';
  return switch (code) {
    'setup' => '계정 인증 연결 준비 중입니다. 기본 게스트 플레이와 기기 기록은 그대로 사용할 수 있습니다.',
    'email_setup_required' =>
      '이메일 인증 연결 준비 중입니다. 기본 게스트 플레이와 기기 기록은 그대로 사용할 수 있습니다.',
    'credentials' => '이메일과 비밀번호를 확인해 주세요. 로그인할 수 없다면 비밀번호 재설정을 이용해 주세요.',
    'password_policy' =>
      '새 비밀번호는 15자 이상 4096자 이내로 입력해 주세요. 문자 종류나 주기적인 변경은 강제하지 않습니다.',
    'password_blocked' => '많이 사용되거나 노출된 비밀번호입니다. 다른 긴 비밀번호를 사용해 주세요.',
    'try_later' => '요청이 많습니다. 잠시 기다린 뒤 다시 시도해 주세요. 계정이 영구 잠긴 것은 아닙니다.',
    'invalid_or_expired_link' => '링크가 잘못되었거나 만료·사용되었습니다. 새 메일을 요청해 주세요.',
    'link_account_mismatch' =>
      '현재 계정과 다른 계정의 링크입니다. 로그아웃한 뒤 해당 계정으로 다시 확인해 주세요.',
    'logout_required' =>
      '다른 계정으로 로그인하거나 가입하려면 먼저 계정 메뉴에서 로그아웃해 주세요. 현재 계정과 기록은 유지했습니다.',
    'social_setup_required' =>
      '소셜 로그인 설정 준비 중입니다. 기본 플레이와 기기 기록은 그대로 사용할 수 있습니다.',
    'social_cancelled' => '로그인을 취소했습니다. 기록은 유지했습니다. 원할 때 다시 시도해 주세요.',
    'social_unavailable' => '공급자에 연결하지 못했거나 동의가 완료되지 않았습니다. 카카오는 아래 계정 로그인으로 직접 다시 시도할 수 있습니다. 기록은 유지했습니다.',
    'invalid_provider_proof' ||
    'invalid_challenge' => '인증 요청이 만료되었거나 일치하지 않습니다. 로그인 버튼으로 새로 시도해 주세요.',
    'provider_conflict' =>
      '이미 다른 계정에 연결된 로그인입니다. 두 계정과 기록을 보존했습니다. 자동으로 합치지 않습니다.',
    'password_link_required' =>
      '이메일 계정으로 먼저 로그인한 뒤 계정 연결과 재인증을 진행해 주세요. 소셜 비밀번호는 요구하지 않습니다.',
    'invalid_session' ||
    'recent_authentication_required' => '인증이 만료되었거나 변경되었습니다. 다시 로그인해 주세요.',
    'conflict_keep_both' || 'revision_conflict' || 'generation_conflict' =>
      '계정 기록과 충돌했습니다. 기기와 계정 기록을 모두 보존했습니다. 상태를 다시 확인해 주세요.',
    'storage' => '기기의 보호 저장소를 사용할 수 없습니다. 계정 연결을 완료하지 않았습니다. 다시 시도해 주세요.',
    'account_setup_required' =>
      '회원 탈퇴 서버 연결 준비 중입니다. 삭제 요청을 접수하지 않았으며 기록을 보존했습니다.',
    'deletion_request_expired' => '탈퇴 확인 요청이 만료됐습니다. 본인 확인부터 다시 진행해 주세요.',
    'invalid_deletion_request' ||
    'confirmation_required' => '현재 계정의 탈퇴 안내와 최종 확인을 다시 확인해 주세요.',
    'account_unavailable' =>
      '사용할 수 없거나 탈퇴 처리 중인 계정입니다. 이전 기록을 다른 계정으로 가져오지 않습니다.',
    _ => '네트워크 또는 인증 서비스에 연결하지 못했습니다. 입력 내용을 확인하고 다시 시도해 주세요.',
  };
}

abstract interface class EmailIdentity implements FirebaseTokenSource {
  String? get uid;
  bool get verified;
  Future<void> signIn(String email, String password);
  Future<void> signInCustomToken(String token);
  bool get passwordAccount;
  Future<void> refresh();
  Future<void> reauthenticate(String password);
  Future<void> signOut();
}

abstract interface class EmailBackend {
  Future<Map<String, dynamic>> call(
    String path, {
    String method = 'POST',
    Map<String, Object?>? body,
    bool authenticated = false,
    bool session = false,
  });
}

class EmailRuntime {
  EmailRuntime({
    required this.identity,
    required this.backend,
    required this.vault,
    required this.apiKey,
    this.social,
  });
  final EmailIdentity identity;
  final EmailBackend backend;
  final SecureSessionVault vault;
  final String apiKey;
  final SocialProviderClient? social;
}

class EmailActionLink {
  EmailActionLink._(this.mode, this.code);
  final String mode, code;
  static EmailActionLink parse(String raw, BackendScope scope, String apiKey) {
    try {
      final uri = Uri.parse(raw.trim());
      final local =
          scope.emulator &&
          uri.scheme == 'http' &&
          uri.host == '127.0.0.1' &&
          uri.port == 9299;
      final cloud =
          uri.scheme == 'https' &&
          uri.host == '${scope.projectId}.firebaseapp.com' &&
          !uri.hasPort;
      if ((!local && !cloud) ||
          uri.path != (local ? '/emulator/action' : '/__/auth/action') ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment ||
          raw.length > 8192) {
        throw const EmailFailure('invalid_or_expired_link');
      }
      const keys = {'mode', 'oobCode', 'apiKey', 'continueUrl', 'lang'};
      if (uri.queryParametersAll.entries.any(
        (e) => !keys.contains(e.key) || e.value.length != 1,
      )) {
        throw const FormatException();
      }
      final p = uri.queryParameters, mode = p['mode'], code = p['oobCode'];
      if (!{
            'verifyEmail',
            'resetPassword',
            'verifyAndChangeEmail',
          }.contains(mode) ||
          code == null ||
          !RegExp(r'^[A-Za-z0-9_-]{16,2048}$').hasMatch(code) ||
          p['apiKey'] != apiKey ||
          (p['continueUrl'] != null &&
              p['continueUrl'] !=
                  'https://${scope.projectId}.firebaseapp.com/__/auth/complete') ||
          (p['lang'] != null && !{'ko', 'en'}.contains(p['lang']))) {
        throw const FormatException();
      }
      return EmailActionLink._(mode!, code);
    } catch (_) {
      throw const EmailFailure('invalid_or_expired_link');
    }
  }

  @override
  String toString() => 'EmailActionLink([redacted])';
}

enum EmailPhase { guest, verificationPending, serverPending, connected }

class AccountConnection {
  AccountConnection(this.uid, this.generation, this.key, this.records);
  final String uid, key;
  final int generation;
  final List<dynamic> records;
  @override
  String toString() => 'AccountConnection([redacted])';
}

class EmailAuthController extends ChangeNotifier {
  EmailAuthController({required this._initialize, int Function()? now})
    : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);
  final Future<EmailRuntime> Function() _initialize;
  final int Function() _now;
  EmailRuntime? _runtime;
  bool _explicitlySignedOut = false;
  Future<EmailRuntime>? _initializing;
  Completer<void>? _active;
  Future<void>? _loggingOut;
  EmailPhase phase = EmailPhase.guest;
  String? message;
  bool busy = false, setupMissing = false;
  int _epoch = 0, _nextAttempt = 0;
  final _nextMail = <String, int>{};
  bool _disposed = false;
  int serverRecordCount = 0;
  Map<String, dynamic>? _preview;
  Map<String, Object?>? _proposal;
  EmailActionLink? pendingAction;
  AccountConnection? connection;
  Set<String> linkedProviders = {};
  PendingDeletion? _deletion;
  bool deletionPrepared = false, deletionPending = false;
  Future<void> Function(String scopeKey)? onAccountDeleted;
  Future<void> Function()? beforeGuestImport;
  Future<void> Function(AccountConnection connection)? onGuestImported;
  String _scopeKey(EmailRuntime r, String uid, int generation) =>
      '${r.vault.scope.projectId}:${r.vault.scope.environment}:$uid:$generation';
  void _detach() {
    connection = null;
    linkedProviders = {};
    serverRecordCount = 0;
    _preview = null;
    _proposal = null;
    deletionPrepared = false;
  }

  bool get canImport =>
      phase == EmailPhase.connected &&
      _preview?['decision'] == 'empty_requires_confirmation';
  bool get hasRuntime => _runtime != null;
  Future<Map<String, dynamic>> billingRequest(
    String action, {
    Map<String, Object?>? body,
  }) async {
    if (!{'status', 'intent', 'verify'}.contains(action) ||
        _runtime == null ||
        connection == null ||
        deletionPending ||
        busy) {
      throw const EmailFailure('invalid_session');
    }
    final key = connection!.key, epoch = _epoch;
    final result = await _runtime!.backend.call(
      '/v1/billing/$action',
      method: action == 'status' ? 'GET' : 'POST',
      body: body,
      authenticated: true,
      session: true,
    );
    if (_disposed ||
        epoch != _epoch ||
        connection?.key != key ||
        deletionPending) {
      throw const EmailFailure('invalid_session');
    }
    return result;
  }

  bool get hasIdentity => _runtime?.identity.uid != null;
  bool get canLinkSocial =>
      phase == EmailPhase.connected &&
      (_runtime?.identity.passwordAccount ?? false);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<EmailRuntime> _ready() async {
    if (_runtime != null) return _runtime!;
    try {
      return _runtime = await (_initializing ??= _initialize());
    } finally {
      _initializing = null;
    }
  }

  Future<bool> _run(
    Future<void> Function(EmailRuntime runtime, int epoch) action, {
    String? mail,
  }) async {
    if (busy || _disposed) return false;
    final now = _now();
    if (now < _nextAttempt || (mail != null && now < (_nextMail[mail] ?? 0))) {
      message = emailError(const EmailFailure('try_later'));
      _notify();
      return false;
    }
    final epoch = _epoch;
    final active = Completer<void>();
    _active = active;
    busy = true;
    message = null;
    _notify();
    try {
      final runtime = await _ready();
      if (epoch != _epoch) return false;
      setupMissing = false;
      await action(runtime, epoch);
      return epoch == _epoch;
    } catch (error) {
      if (epoch == _epoch) {
        setupMissing =
            error is EmailFailure &&
            {'setup', 'email_setup_required'}.contains(error.code);
        message = error is SessionStorageFailure
            ? emailError(const EmailFailure('storage'))
            : emailError(error);
        if (deletionPending) {
          message = '탈퇴 접수·완료 여부를 확인하지 못했습니다. 완료로 표시하지 않았습니다. 탈퇴 화면에서 처리 확인을 다시 시도해 주세요.';
          _detach();
        }
        if (phase == EmailPhase.serverPending) _detach();
        if (error is EmailFailure && error.code == 'credentials') {
          _nextAttempt = _now() + 3000;
        }
        if (error is EmailFailure &&
            {'invalid_session', 'account_unavailable'}.contains(error.code)) {
          phase = EmailPhase.guest;
          _detach();
          _preview = null;
          _proposal = null;
          serverRecordCount = 0;
          try {
            await _runtime?.identity.signOut();
            await _runtime?.vault.clear();
          } catch (_) {
            /* Fail closed; no data fallback. */
          }
        }
      }
      return false;
    } finally {
      if (identical(_active, active)) _active = null;
      active.complete();
      if (epoch == _epoch) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> restore() async {
    await _run((r, epoch) async {
      _detach();
      phase = EmailPhase.serverPending;
      _notify();
      _deletion = await r.vault.loadDeletion();
      if (_deletion?.accepted == true) {
        deletionPending = true;
        await _resumeDeletion(r, epoch);
        if (epoch != _epoch || deletionPending) return;
      }
      if (_explicitlySignedOut || await r.vault.hasSignOutIntent()) {
        phase = EmailPhase.guest;
        _detach();
        return;
      }
      await r.identity.refresh();
      if (epoch != _epoch) return;
      if (r.identity.uid == null) {
        phase = EmailPhase.guest;
        _detach();
        return;
      }
      if (!r.identity.verified) {
        _detach();
        phase = EmailPhase.verificationPending;
        return;
      }
      await _connect(r, epoch);
    });
  }

  Future<void> _connect(EmailRuntime r, int epoch) async {
    if (_explicitlySignedOut || await r.vault.hasSignOutIntent()) {
      throw const EmailFailure('invalid_session');
    }
    phase = EmailPhase.serverPending;
    _preview = null;
    serverRecordCount = 0;
    Map<String, dynamic> started;
    try {
      started = await r.backend.call(
        '/v1/session/start',
        authenticated: true,
        body: {},
      );
    } on EmailFailure catch (error) {
      if (error.code != 'fresh_token_required') rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      if (epoch != _epoch) return;
      await r.identity.idToken(forceRefresh: true);
      started = await r.backend.call(
        '/v1/session/start',
        authenticated: true,
        body: {},
      );
    }
    if (epoch != _epoch) return;
    if (started['uid'] != r.identity.uid) {
      throw const EmailFailure('invalid_session');
    }
    final session = ServerSession(
      uid: started['uid'],
      handle: started['sessionHandle'],
      expiresAtMs: started['expiresAtMs'],
      generation: started['generation'],
    );
    if (!await r.vault.save(session) || epoch != _epoch) return;
    final records = await r.backend.call(
      '/v1/me/progress',
      method: 'GET',
      authenticated: true,
      session: true,
    );
    final preview = await r.backend.call(
      '/v1/me/import-preview',
      body: {},
      authenticated: true,
      session: true,
    );
    final profile = await r.backend.call(
      '/v1/me/account',
      method: 'GET',
      authenticated: true,
      session: true,
    );
    if (epoch != _epoch) return;
    if (profile['uid'] != session.uid ||
        profile['generation'] != session.generation ||
        profile['status'] != 'active' ||
        profile['providers'] is! List) {
      throw const EmailFailure('invalid_session');
    }
    linkedProviders = (profile['providers'] as List)
        .whereType<String>()
        .where({'password', 'google.com', 'kakao', 'apple.com'}.contains)
        .toSet();
    final rawRecords = records['records'];
    if (rawRecords is! List || rawRecords.length > 15) {
      throw const EmailFailure('invalid_session');
    }
    final seen = <int>{};
    for (final raw in rawRecords) {
      if (raw is! Map ||
          raw['stage'] is! int ||
          raw['stage'] < 1 ||
          raw['stage'] > 15 ||
          !seen.add(raw['stage'])) {
        throw const EmailFailure('invalid_session');
      }
      StageRecord.fromJson(Map<String, dynamic>.from(raw));
    }
    connection = AccountConnection(
      session.uid,
      session.generation,
      _scopeKey(r, session.uid, session.generation),
      List.of(rawRecords),
    );
    serverRecordCount = (records['records'] as List).length;
    _preview = preview;
    phase = EmailPhase.connected;
    message = '계정과 기록 서버를 확인했습니다. 이 계정의 기록·선택 구성을 사용하며 게스트 원본은 유지합니다. 전투 기록의 전체 자동 동기화는 준비 중입니다.';
  }

  Future<bool> register(String email, String password) =>
      _run((r, epoch) async {
        if (r.identity.uid != null) throw const EmailFailure('logout_required');
        await r.backend.call(
          '/v1/auth/register',
          body: {'email': email.trim(), 'password': password, 'consent': true},
        );
        if (epoch != _epoch) return;
        _nextMail['register'] = _now() + 60000;
        phase = EmailPhase.verificationPending;
        message = '처리 가능한 경우 확인 메일을 보냈습니다. 메일을 확인한 뒤 로그인해 주세요. 이미 가입했다면 로그인 또는 비밀번호 재설정을 이용해 주세요.';
      }, mail: 'register');
  Future<bool> socialSignIn(
    SocialProvider provider, {
    bool link = false,
    String? currentPassword,
    bool kakaoAccountOnly = false,
  }) => _run((r, epoch) async {
    if (deletionPending) throw const EmailFailure('invalid_deletion_request');
    final client = r.social;
    if (client == null || !client.configured(provider)) {
      throw const EmailFailure('social_setup_required');
    }
    if (link) {
      if (!canLinkSocial ||
          currentPassword == null ||
          currentPassword.isEmpty) {
        throw const EmailFailure('password_link_required');
      }
      await r.identity.reauthenticate(currentPassword);
      if (epoch != _epoch) return;
      await _connect(r, epoch);
    } else if (r.identity.uid != null) {
      throw const EmailFailure('logout_required');
    }
    if (epoch != _epoch) return;
    pendingAction = null;
    final originalUid = r.identity.uid;
    try {
      final challenge = SocialChallengeData.fromJson(
        await r.backend.call(
          '/v1/social/begin',
          body: {'provider': provider.name, 'intent': link ? 'link' : 'signin'},
          authenticated: link,
          session: link,
        ),
      );
      if (epoch != _epoch) return;
      final proof = await client.authorize(
        provider,
        challenge,
        kakaoAccountOnly: kakaoAccountOnly,
      );
      if (epoch != _epoch) return;
      final result = await r.backend.call(
        '/v1/social/complete',
        body: {
          'challengeId': challenge.id,
          'state': challenge.state,
          'proof': proof.toJson(),
        },
        authenticated: link,
        session: link,
      );
      if (epoch != _epoch) return;
      if (result['uid'] is! String ||
          result['customToken'] is! String ||
          (link && result['uid'] != originalUid)) {
        throw const EmailFailure('invalid_session');
      }
      await r.identity.signInCustomToken(result['customToken'] as String);
      if (epoch != _epoch) {
        await r.identity.signOut();
        return;
      }
      if (r.identity.uid != result['uid']) {
        throw const EmailFailure('invalid_session');
      }
      if (!link) {
        await r.vault.clearSignOutIntent();
        if (epoch != _epoch) return;
        _explicitlySignedOut = false;
      }
      await _connect(r, epoch);
      if (epoch != _epoch) return;
      message = link
          ? '명시적으로 요청한 로그인 연결을 완료했습니다. 기록·설정·이용권은 합치거나 변경하지 않았습니다.'
          : '소셜 계정과 기록 서버를 확인했습니다. 기기 기록·설정은 유지합니다.';
    } finally {
      try {
        await client.clear();
      } catch (_) {
        /* Firebase session is independent. */
      }
    }
  });
  Future<bool> login(String email, String password) => _run((r, epoch) async {
    if (deletionPending) throw const EmailFailure('invalid_deletion_request');
    _detach();
    _notify();
    pendingAction = null;
    if (r.identity.uid != null) {
      try {
        if (await r.vault.load() != null) {
          await r.backend.call(
            '/v1/session/end',
            body: {},
            authenticated: true,
            session: true,
          );
        }
      } catch (_) {
        /* Local identity must still be cleared. */
      }
      await r.identity.signOut();
      await r.vault.clear();
    }
    phase = EmailPhase.guest;
    _preview = null;
    _proposal = null;
    serverRecordCount = 0;
    await r.identity.signIn(email.trim(), password);
    if (epoch != _epoch) {
      await r.identity.signOut();
      return;
    }
    await r.vault.clearSignOutIntent();
    if (epoch != _epoch) return;
    _explicitlySignedOut = false;
    if (!r.identity.verified) {
      phase = EmailPhase.verificationPending;
      message = '아직 이메일 소유 확인 전입니다. 메일의 링크를 확인한 뒤 상태를 다시 확인해 주세요.';
    } else {
      await _connect(r, epoch);
    }
  });
  Future<bool> resend() => _run((r, epoch) async {
    if (r.identity.uid == null) throw const EmailFailure('invalid_session');
    await r.backend.call(
      '/v1/auth/verification-email',
      body: {},
      authenticated: true,
    );
    if (epoch != _epoch) return;
    _nextMail['verify'] = _now() + 60000;
    message = '처리 가능한 경우 확인 메일을 보냈습니다. 60초 뒤 다시 요청할 수 있습니다.';
  }, mail: 'verify');
  Future<bool> refreshVerification() => _run((r, epoch) async {
    await r.identity.refresh();
    if (epoch != _epoch) return;
    if (r.identity.uid == null) throw const EmailFailure('invalid_session');
    if (r.identity.verified) {
      await _connect(r, epoch);
    } else {
      phase = EmailPhase.verificationPending;
      message = '아직 확인되지 않았습니다. 메일의 링크를 열거나 새 확인 메일을 요청해 주세요.';
    }
  });
  Future<bool> requestReset(String email) => _run((r, epoch) async {
    await r.backend.call('/v1/auth/reset-email', body: {'email': email.trim()});
    if (epoch != _epoch) return;
    _nextMail['reset'] = _now() + 60000;
    message = '처리 가능한 경우 재설정 메일을 보냈습니다. 가입 여부와 관계없이 동일한 안내입니다. 스팸함도 확인해 주세요.';
  }, mail: 'reset');
  Future<bool> changeEmail(String email, String currentPassword) =>
      _run((r, epoch) async {
        await r.identity.reauthenticate(currentPassword);
        await r.backend.call(
          '/v1/auth/change-email',
          body: {'email': email.trim()},
          authenticated: true,
        );
        if (epoch != _epoch) return;
        _nextMail['change'] = _now() + 60000;
        message = '처리 가능한 경우 새 주소로 확인 메일을 보냈습니다. 확인 전에는 기존 이메일을 사용합니다.';
      }, mail: 'change');
  Future<bool> inspectLink(String raw) => _run((r, epoch) async {
    pendingAction = null;
    final action = EmailActionLink.parse(raw, r.vault.scope, r.apiKey);
    await r.backend.call(
      '/v1/auth/check-action',
      body: {'mode': action.mode, 'code': action.code},
      authenticated: action.mode != 'resetPassword' || hasIdentity,
    );
    if (epoch != _epoch) return;
    pendingAction = action;
    message = action.mode == 'resetPassword'
        ? '링크를 확인했습니다. 새 비밀번호를 입력해 주세요.'
        : '현재 계정의 링크를 확인했습니다. 아래에서 확인을 완료해 주세요.';
  });
  Future<bool> confirmLink([String? password]) => _run((r, epoch) async {
    final action = pendingAction;
    if (action == null) throw const EmailFailure('invalid_or_expired_link');
    await r.backend.call(
      '/v1/auth/confirm-action',
      body: {
        'mode': action.mode,
        'code': action.code,
        if (action.mode == 'resetPassword') 'password': password,
      },
      authenticated: action.mode != 'resetPassword' || hasIdentity,
    );
    if (epoch != _epoch) return;
    pendingAction = null;
    if (action.mode == 'verifyEmail') {
      await r.identity.refresh();
      await _connect(r, epoch);
    } else {
      await r.identity.signOut();
      await r.vault.clear();
      phase = EmailPhase.guest;
      _detach();
      _preview = null;
      _proposal = null;
      serverRecordCount = 0;
      message = '변경을 완료했습니다. 이전 세션을 폐기했습니다. 자동 로그인하지 않으므로 새 인증 정보로 로그인해 주세요. 기기 기록은 보존했습니다.';
    }
  });
  void discardLink() {
    pendingAction = null;
  }

  Future<bool> importGuest(
    CampaignProgress progress, {
    String? expectedScopeKey,
  }) => _run((r, epoch) async {
    if (!canImport ||
        _preview == null ||
        (expectedScopeKey != null && connection?.key != expectedScopeKey)) {
      throw const EmailFailure('conflict_keep_both');
    }
    await beforeGuestImport?.call();
    if (epoch != _epoch) return;
    final random = Random.secure();
    _proposal ??= {
      'guest': {
        'schema': 1,
        'records': [
          for (final e in progress.records.entries)
            {'stage': e.key, ...e.value.toJson()},
        ],
      },
      'confirmed': true,
      'expectedRevision': _preview!['revision'],
      'generation': _preview!['generation'],
      'operationId': base64UrlEncode(
        List.generate(24, (_) => random.nextInt(256)),
      ),
    };
    await r.backend.call(
      '/v1/me/import-guest',
      body: _proposal,
      authenticated: true,
      session: true,
    );
    if (epoch != _epoch) return;
    _proposal = null;
    await _connect(r, epoch);
    if (epoch != _epoch || connection == null) return;
    await onGuestImported?.call(connection!);
    message = '계정에 최초 기록을 보관했습니다. 기기의 원본 기록·설정은 삭제하거나 합치지 않았습니다.';
  });
  Future<void> logout() => _loggingOut ??= _logout().whenComplete(() {
    _loggingOut = null;
  });

  Future<void> _logout() async {
    _epoch++;
    _explicitlySignedOut = true;
    busy = true;
    pendingAction = null;
    _preview = null;
    _proposal = null;
    serverRecordCount = 0;
    phase = EmailPhase.guest;
    _detach();
    _notify();
    // Firebase initialization/sign-in cannot be cancelled. Keep the next login
    // blocked until the old operation settles, then clear its restored identity.
    await _active?.future;
    final r = _runtime;
    var remoteClosed = true;
    var intentStored = true;
    if (r != null) {
      try {
        await r.vault.markSignedOut();
      } catch (_) {
        intentStored = false;
      }
      try {
        if (r.identity.uid != null && await r.vault.load() != null) {
          await r.backend.call(
            '/v1/session/end',
            body: {},
            authenticated: true,
            session: true,
          );
        }
      } catch (_) {
        remoteClosed = false;
      }
      var identityCleared = true;
      try {
        await r.identity.signOut();
      } catch (_) {
        identityCleared = false;
      }
      try {
        await r.social?.clear();
      } catch (_) {
        /* No upstream token persisted. */
      }
      try {
        await r.vault.clear();
        if (_deletion?.accepted != true) {
          await r.vault.clearDeletion();
          _deletion = null;
        }
      } catch (_) {
        message = emailError(const EmailFailure('storage'));
        busy = false;
        _notify();
        return;
      }
      if (!identityCleared) {
        message =
            '계정 접근을 중단하고 기기 세션을 지웠습니다. 인증 서비스 로그아웃은 확인하지 못했습니다. 다시 시도해 주세요.';
        busy = false;
        _notify();
        return;
      }
    }
    message = !intentStored
        ? emailError(const EmailFailure('storage'))
        : remoteClosed
        ? '이 기기에서 로그아웃했습니다. 기기 게임 기록과 설정은 보존했습니다.'
        : '기기 인증을 정리했습니다. 서버 세션 종료는 확인하지 못했으며 토큰 만료·서버 검증이 적용됩니다.';
    busy = false;
    _notify();
  }

  Future<bool> prepareDeletion({
    String? password,
    SocialProvider? provider,
  }) => _run((r, epoch) async {
    if (deletionPending) throw const EmailFailure('invalid_deletion_request');
    if (connection == null) throw const EmailFailure('invalid_session');
    final originalUid = connection!.uid;
    final policy = await r.backend.call(
      '/v1/public/account-policy',
      method: 'GET',
    );
    if (policy['ready'] != true) {
      throw const EmailFailure('account_setup_required');
    }
    if (provider == null) {
      if (!linkedProviders.contains('password') ||
          password?.isNotEmpty != true) {
        throw const EmailFailure('credentials');
      }
      await r.identity.reauthenticate(password!);
    } else {
      final serverProvider = switch (provider) {
        SocialProvider.google => 'google.com',
        SocialProvider.kakao => 'kakao',
        SocialProvider.apple => 'apple.com',
      };
      if (!linkedProviders.contains(serverProvider) ||
          r.social == null ||
          !r.social!.configured(provider)) {
        throw const EmailFailure('social_setup_required');
      }
      try {
        final challenge = SocialChallengeData.fromJson(
          await r.backend.call(
            '/v1/social/begin',
            body: {'provider': provider.name, 'intent': 'reauth'},
            authenticated: true,
            session: true,
          ),
        );
        if (epoch != _epoch) return;
        final proof = await r.social!.authorize(provider, challenge);
        if (epoch != _epoch) return;
        final result = await r.backend.call(
          '/v1/social/complete',
          body: {
            'challengeId': challenge.id,
            'state': challenge.state,
            'proof': proof.toJson(),
          },
          authenticated: true,
          session: true,
        );
        if (epoch != _epoch) return;
        if (result['uid'] != originalUid || result['customToken'] is! String) {
          throw const EmailFailure('invalid_session');
        }
        await r.identity.signInCustomToken(result['customToken']);
      } finally {
        try {
          await r.social?.clear();
        } catch (_) {
          /* No provider proof is persisted. */
        }
      }
    }
    if (epoch != _epoch) return;
    await _connect(r, epoch);
    if (epoch != _epoch) return;
    if (connection?.uid != originalUid) {
      throw const EmailFailure('invalid_session');
    }
    final random = Random.secure();
    _deletion = PendingDeletion(
      uid: originalUid,
      generation: connection!.generation,
      receipt: base64UrlEncode(List.generate(32, (_) => random.nextInt(256)))
          .replaceAll('=', ''),
    );
    await r.vault.saveDeletion(_deletion!);
    final prepared = await r.backend.call(
      '/v1/account/deletion/prepare',
      body: {'receipt': _deletion!.receipt},
      authenticated: true,
      session: true,
    );
    if (epoch != _epoch) return;
    if (prepared['status'] != 'prepared' ||
        prepared['noticeVersion'] != 'airzero-account-delete-v1') {
      throw const EmailFailure('invalid_deletion_request');
    }
    deletionPrepared = true;
    message = '본인 확인을 마쳤습니다. 삭제 범위를 확인하고 최종 탈퇴를 선택해 주세요. 아직 삭제하지 않았습니다.';
  });

  Future<void> cancelDeletion() async {
    if (busy || deletionPending) return;
    deletionPrepared = false;
    _deletion = null;
    try {
      await _runtime?.vault.clearDeletion();
      message = '탈퇴를 취소했습니다. 계정과 기록은 유지했습니다.';
    } catch (_) {
      message = '탈퇴는 실행하지 않았습니다. 기기 확인 요청 정리를 다시 시도해 주세요.';
    }
    _notify();
  }

  Future<bool> commitDeletion() => _run((r, epoch) async {
    final pending = _deletion;
    if (!deletionPrepared ||
        pending == null ||
        connection?.uid != pending.uid) {
      throw const EmailFailure('invalid_deletion_request');
    }
    _deletion = PendingDeletion(
      uid: pending.uid,
      generation: pending.generation,
      receipt: pending.receipt,
      accepted: true,
    );
    await r.vault.saveDeletion(_deletion!);
    deletionPrepared = false;
    deletionPending = true;
    _detach();
    phase = EmailPhase.guest;
    _notify();
    final result = await r.backend.call(
      '/v1/account/deletion/commit',
      body: {
        'receipt': pending.receipt,
        'confirmed': true,
        'noticeVersion': 'airzero-account-delete-v1',
      },
      authenticated: true,
      session: true,
    );
    if (epoch != _epoch) return;
    _detach();
    phase = EmailPhase.guest;
    await _deletionResult(r, epoch, result);
  });
  Future<bool> resumeDeletion() => _run(_resumeDeletion);
  Future<void> _resumeDeletion(EmailRuntime r, int epoch) async {
    _deletion ??= await r.vault.loadDeletion();
    if (_deletion == null) throw const EmailFailure('invalid_deletion_request');
    final result = await r.backend.call(
      '/v1/account/deletion/resume',
      body: {'receipt': _deletion!.receipt},
    );
    if (epoch != _epoch) return;
    await _deletionResult(r, epoch, result);
  }

  Future<void> _deletionResult(
    EmailRuntime r,
    int epoch,
    Map<String, dynamic> result,
  ) async {
    final pending = _deletion!;
    if (result['status'] == 'prepared') {
      deletionPending = false;
      deletionPrepared = false;
      _deletion = null;
      await r.vault.clearDeletion();
      message = '삭제는 접수되지 않았습니다. 본인 확인과 최종 확인부터 다시 진행해 주세요.';
      return;
    }
    if (result['status'] != 'complete') {
      deletionPending = true;
      message = '탈퇴 처리 중입니다. 완료 확인을 다시 시도해 주세요. 완료로 표시하지 않았습니다.';
      return;
    }
    if (r.identity.uid == pending.uid) {
      await r.identity.signOut();
      await r.vault.clear();
      if (epoch != _epoch) return;
      _detach();
      phase = EmailPhase.guest;
    }
    deletionPending = true;
    await onAccountDeleted?.call(_scopeKey(r, pending.uid, pending.generation));
    await r.vault.clearDeletion();
    if (epoch != _epoch) return;
    _deletion = null;
    deletionPending = false;
    deletionPrepared = false;
    message = '테일윙 계정과 서버 기록 삭제를 완료했습니다. 게스트 원본은 유지했습니다. 구독 해지·환불과 공급자 자체 계정 삭제는 별개입니다.';
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    pendingAction = null;
    super.dispose();
  }
}
