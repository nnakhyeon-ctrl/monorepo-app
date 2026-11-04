import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/security/backend_session.dart';

class MemoryStorage implements SessionStorage {
  final values = <String, String>{};
  bool failRead = false, failDelete = false;
  Completer<void>? started, release;
  @override
  Future<String?> read(String key) async {
    if (failRead) throw StateError('synthetic secret must not escape');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    started?.complete();
    await release?.future;
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failDelete) throw StateError('synthetic secret must not escape');
    values.remove(key);
  }
}

BackendScope scope([String environment = 'dev']) => BackendScope.cloud(
  projectId: 'airzero-strike-fixture',
  environment: environment,
  region: 'asia-northeast3',
);
ServerSession descriptor({int expires = 2000}) => ServerSession(
  uid: 'fictional_a',
  handle: 'A' * 43,
  expiresAtMs: expires,
  generation: 0,
);

void main() {
  test('cloud endpoint is HTTPS, configuration is bounded and emulator needs an explicit debug flag', () {
    expect(scope().endpoint.scheme, 'https');
    expect(scope().storageKey, isNot(scope('prod').storageKey));
    expect(
      () => BackendScope.cloud(
        projectId: 'other-app',
        environment: 'dev',
        region: 'asia-northeast3',
      ),
      throwsArgumentError,
    );
    expect(
      () => BackendScope.cloud(
        projectId: 'airzero-strike-fixture',
        environment: 'anything',
        region: 'asia-northeast3',
      ),
      throwsArgumentError,
    );
    expect(() => BackendScope.emulator(), throwsStateError);
    expect(descriptor().toString(), isNot(contains('fictional_a')));
    expect(descriptor().toString(), isNot(contains('A' * 43)));
  });

  test('vault reloads its own session, isolates environments and deletes only its own key', () async {
    final storage = MemoryStorage();
    final dev = SecureSessionVault(scope(), storage: storage, now: () => 1000);
    final prod = SecureSessionVault(
      scope('prod'),
      storage: storage,
      now: () => 1000,
    );
    expect(await dev.save(descriptor()), isTrue);
    expect(await prod.load(), isNull);
    expect(
      (await SecureSessionVault(
        scope(),
        storage: storage,
        now: () => 1000,
      ).load())!.uid,
      'fictional_a',
    );
    await prod.save(descriptor());
    await dev.clear();
    expect(await dev.load(), isNull);
    expect((await prod.load())!.uid, 'fictional_a');
    expect(storage.values.length, 1);
  });

  test('logout invalidates an in-flight write and queued read without resurrecting a session', () async {
    final storage = MemoryStorage()
      ..started = Completer<void>()
      ..release = Completer<void>();
    final vault = SecureSessionVault(
      scope(),
      storage: storage,
      now: () => 1000,
    );
    final saving = vault.save(descriptor());
    await storage.started!.future;
    final reading = vault.load();
    final clearing = vault.clear();
    storage.release!.complete();
    expect(await saving, isFalse);
    expect(await reading, isNull);
    await clearing;
    expect(await vault.load(), isNull);
    expect(storage.values, isEmpty);
  });

  test('expired sessions fail closed and leave another scope intact', () async {
    final storage = MemoryStorage();
    await SecureSessionVault(
      scope(),
      storage: storage,
      now: () => 1000,
    ).save(descriptor());
    storage.values[scope('prod').storageKey] = 'unrelated synthetic record';
    final expired = SecureSessionVault(
      scope(),
      storage: storage,
      now: () => 2001,
    );
    expect(await expired.load(), isNull);
    expect(storage.values.keys, [scope('prod').storageKey]);
    await expectLater(
      expired.save(descriptor()),
      throwsA(isA<SessionStorageFailure>()),
    );
  });

  test(
    'corrupt storage is preserved and native errors do not disclose input',
    () async {
      final storage = MemoryStorage()
        ..values[scope().storageKey] = '{invalid synthetic data';
      final vault = SecureSessionVault(
        scope(),
        storage: storage,
        now: () => 1000,
      );
      await expectLater(vault.load(), throwsA(isA<SessionStorageFailure>()));
      expect(storage.values[scope().storageKey], '{invalid synthetic data');
      storage.failRead = true;
      try {
        await vault.load();
        fail('read should fail');
      } catch (error) {
        expect(error.toString(), 'SessionStorageFailure');
      }
    },
  );

  test(
    'failed native delete locks out reads until an explicit successful clear',
    () async {
      final storage = MemoryStorage();
      final vault = SecureSessionVault(
        scope(),
        storage: storage,
        now: () => 1000,
      );
      await vault.save(descriptor());
      storage.failDelete = true;
      await expectLater(vault.clear(), throwsA(isA<SessionStorageFailure>()));
      expect(await vault.load(), isNull);
      expect(storage.values.length, 1);
      storage.failDelete = false;
      await vault.clear();
      expect(storage.values, isEmpty);
    },
  );
}
