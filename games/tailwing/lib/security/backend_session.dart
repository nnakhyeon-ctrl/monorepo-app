import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Configuration is not identity. The backend always verifies the SDK token.
class BackendScope {
  BackendScope.cloud({
    required this.projectId,
    required this.environment,
    required String region,
  }) : emulator = false,
       endpoint = Uri.https('$region-$projectId.cloudfunctions.net', '/api') {
    if (!RegExp(r'^airzero-strike-[a-z0-9-]+$').hasMatch(projectId) ||
        !{'dev', 'prod'}.contains(environment) ||
        !RegExp(r'^[a-z]+-[a-z]+\d$').hasMatch(region)) {
      throw ArgumentError('backend scope');
    }
  }
  BackendScope.emulator({bool androidEmulator = false})
    : projectId = 'demo-airzero-strike',
      environment = 'dev',
      emulator = true,
      endpoint = Uri.parse(
        'http://${androidEmulator ? '10.0.2.2' : '127.0.0.1'}:5101/demo-airzero-strike/asia-northeast3/api',
      ) {
    if (!kDebugMode || !const bool.fromEnvironment('AIRZERO_AUTH_EMULATOR')) {
      throw StateError('local auth requires explicit debug configuration');
    }
  }
  final String projectId, environment;
  final bool emulator;
  final Uri endpoint;
  String get storageKey => 'airzero:$projectId:$environment:session:v1';
}

/// Only Firebase SDK ID tokens may be sent to the account API. Google/Apple/
/// Kakao upstream tokens and Firebase custom tokens need separate SDK exchange.
abstract interface class FirebaseTokenSource {
  Future<String?> idToken({bool forceRefresh = false});
  Future<String?> appCheckToken();
}

class ServerSession {
  ServerSession({
    required this.uid,
    required this.handle,
    required this.expiresAtMs,
    required this.generation,
  }) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(uid) ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(handle) ||
        expiresAtMs <= 0 ||
        generation < 0) {
      throw const FormatException('session descriptor');
    }
  }
  final String uid, handle;
  final int expiresAtMs, generation;
  @override
  String toString() => 'ServerSession([redacted])';
}

abstract interface class SessionStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformSessionStorage implements SessionStorage {
  PlatformSessionStorage()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(
          storageNamespace: 'airzero_auth_v1',
          resetOnError: false,
          migrateWithBackup: false,
        ),
        iOptions: IOSOptions(
          accountName: 'airzero_auth_v1',
          accessibility: KeychainAccessibility.unlocked_this_device,
          synchronizable: false,
        ),
      ) {
    if (kIsWeb) throw UnsupportedError('Native protected storage required');
  }
  final FlutterSecureStorage _storage;
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class SessionStorageFailure implements Exception {
  const SessionStorageFailure();
  @override
  String toString() => 'SessionStorageFailure';
}

class PendingDeletion {
  const PendingDeletion({
    required this.uid,
    required this.receipt,
    required this.generation,
    this.accepted = false,
  });
  final String uid, receipt;
  final int generation;
  final bool accepted;
  @override
  String toString() => 'PendingDeletion([redacted])';
}

/// Stores scoped session descriptors, logout intent and deletion retry metadata
/// in the OS vault.
/// No Firebase refresh token, password, purchase right or game progress here.
/// Storage alone never authenticates; every API call needs live server checks.
class SecureSessionVault {
  SecureSessionVault(this.scope, {SessionStorage? storage, int Function()? now})
    : _storage = storage ?? PlatformSessionStorage(),
      _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);
  final BackendScope scope;
  final SessionStorage _storage;
  final int Function() _now;
  Future<void> _tail = Future.value();
  int _epoch = 0;
  bool _lockedOut = false;
  String get _deletionKey => '${scope.storageKey}:deletion';
  String get _signOutKey => '${scope.storageKey}:signed-out:v1';
  Future<void> markSignedOut() =>
      _serial(() => _storage.write(_signOutKey, '1'));
  Future<void> clearSignOutIntent() =>
      _serial(() => _storage.delete(_signOutKey));
  Future<bool> hasSignOutIntent() => _serial(() async {
    final value = await _storage.read(_signOutKey);
    if (value != null && value != '1') throw const SessionStorageFailure();
    return value == '1';
  });
  Future<void> saveDeletion(PendingDeletion value) => _serial(() async {
    await _storage.write(
      _deletionKey,
      jsonEncode({
        'uid': value.uid,
        'receipt': value.receipt,
        'generation': value.generation,
        'accepted': value.accepted,
      }),
    );
  });
  Future<PendingDeletion?> loadDeletion() => _serial(() async {
    final raw = await _storage.read(_deletionKey);
    if (raw == null) return null;
    final p = jsonDecode(raw);
    if (p is! Map ||
        p['uid'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(p['uid']) ||
        p['receipt'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(p['receipt']) ||
        p['generation'] is! int ||
        p['generation'] < 0 ||
        p['accepted'] is! bool) {
      throw const SessionStorageFailure();
    }
    return PendingDeletion(
      uid: p['uid'],
      receipt: p['receipt'],
      generation: p['generation'],
      accepted: p['accepted'],
    );
  });
  Future<void> clearDeletion() => _serial(() => _storage.delete(_deletionKey));

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) async {
      try {
        return await action();
      } catch (_) {
        throw const SessionStorageFailure();
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> save(ServerSession session) {
    final epoch = _epoch;
    return _serial(() async {
      if (epoch != _epoch) return false;
      if (session.expiresAtMs <= _now()) {
        throw const FormatException('expired session');
      }
      await _storage.write(
        scope.storageKey,
        jsonEncode({
          'schema': 1,
          'project': scope.projectId,
          'environment': scope.environment,
          'uid': session.uid,
          'handle': session.handle,
          'expiresAtMs': session.expiresAtMs,
          'generation': session.generation,
        }),
      );
      if (epoch != _epoch) {
        await _storage.delete(scope.storageKey);
        return false;
      }
      _lockedOut = false;
      return true;
    });
  }

  Future<ServerSession?> load() {
    final epoch = _epoch;
    return _serial(() async {
      if (_lockedOut || epoch != _epoch) return null;
      final raw = await _storage.read(scope.storageKey);
      if (raw == null || epoch != _epoch) return null;
      final p = jsonDecode(raw);
      if (p is! Map<String, dynamic> ||
          p['schema'] != 1 ||
          p['project'] != scope.projectId ||
          p['environment'] != scope.environment ||
          p['uid'] is! String ||
          p['handle'] is! String ||
          p['expiresAtMs'] is! int ||
          p['generation'] is! int) {
        throw const FormatException('session descriptor');
      }
      final session = ServerSession(
        uid: p['uid'],
        handle: p['handle'],
        expiresAtMs: p['expiresAtMs'],
        generation: p['generation'],
      );
      if (session.expiresAtMs <= _now()) {
        await _storage.delete(scope.storageKey);
        return null;
      }
      return session;
    });
  }

  Future<void> clear() {
    _epoch++;
    _lockedOut = true;
    return _serial(() async {
      await _storage.delete(scope.storageKey);
      _lockedOut = false;
    });
  }
}
