import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/security/backend_session.dart';
import 'package:raikeopeu2026/security/email_auth.dart';
import 'package:raikeopeu2026/security/firebase_email.dart';

import 'backend_session_test.dart' show MemoryStorage;

class UnusedAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TransportIdentity extends FirebaseEmailIdentity {
  TransportIdentity() : super(UnusedAuth(), null);
  String? proof = 'FICTIONAL_APP_CHECK';
  int tokenCalls = 0;
  @override
  String get uid => 'fictional_a';
  @override
  Future<String?> appCheckToken() async => proof;
  @override
  Future<String?> idToken({bool forceRefresh = false}) async {
    tokenCalls++;
    return 'FICTIONAL_ONLY_A_TOKEN';
  }
}

class CaptureHeaders implements HttpHeaders {
  @override
  ContentType? contentType;
  final values = <String, Object>{};
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class LocalResponse extends Stream<List<int>> implements HttpClientResponse {
  LocalResponse(this.statusCode, this.body);
  @override
  final int statusCode;
  final List<int> body;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(body).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class LocalRequest implements HttpClientRequest {
  LocalRequest(this.response);
  final LocalResponse response;
  @override
  final CaptureHeaders headers = CaptureHeaders();
  @override
  bool followRedirects = true;
  final sent = <int>[];
  @override
  void add(List<int> data) => sent.addAll(data);
  @override
  Future<HttpClientResponse> close() async => response;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class LocalClient implements HttpClient {
  LocalClient(this.request);
  final LocalRequest request;
  final destinations = <Uri>[];
  bool forceClosed = false;
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    destinations.add(url);
    return request;
  }

  @override
  void close({bool force = false}) => forceClosed = force;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> inspect(
    int status,
    List<int> response,
    Future<void> Function(FirebaseEmailBackend, LocalClient, TransportIdentity)
    work,
  ) async {
    final scope = BackendScope.cloud(
      projectId: 'airzero-strike-fixture',
      environment: 'dev',
      region: 'asia-northeast3',
    );
    final vault = SecureSessionVault(scope, storage: MemoryStorage());
    await vault.save(
      ServerSession(
        uid: 'fictional_a',
        handle: 'A' * 43,
        expiresAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
        generation: 0,
      ),
    );
    final identity = TransportIdentity();
    final client = LocalClient(LocalRequest(LocalResponse(status, response)));
    await HttpOverrides.runZoned(
      () =>
          work(FirebaseEmailBackend(scope, identity, vault), client, identity),
      createHttpClient: (_) => client,
    );
  }

  test('private calls use one scoped HTTPS destination, verified headers and never redirect', () async {
    await inspect(200, utf8.encode('{"ready":false}'), (
      backend,
      client,
      _,
    ) async {
      await backend.call(
        '/v1/billing/status',
        method: 'GET',
        authenticated: true,
        session: true,
      );
      expect(
        client.destinations.single.toString(),
        'https://asia-northeast3-airzero-strike-fixture.cloudfunctions.net/api/v1/billing/status',
      );
      expect(client.request.followRedirects, false);
      expect(
        client.request.headers.values.keys,
        containsAll([
          'Authorization',
          'X-Firebase-AppCheck',
          'X-Airzero-Session',
        ]),
      );
      expect(client.request.sent, isEmpty);
      expect(client.forceClosed, true);
    });
  });
  test(
    'redirect/error text cannot escape or trigger a second destination',
    () async {
      await inspect(302, utf8.encode('{"error":"FICTIONAL_DO_NOT_ECHO"}'), (
        backend,
        client,
        _,
      ) async {
        await expectLater(
          backend.call(
            '/v1/billing/status',
            method: 'GET',
            authenticated: true,
            session: true,
          ),
          throwsA(
            isA<EmailFailure>().having((e) => e.code, 'code', 'unavailable'),
          ),
        );
        expect(client.destinations.length, 1);
        expect(client.request.followRedirects, false);
        expect(client.forceClosed, true);
      });
    },
  );
  test(
    'missing App Check aborts before reading or sending the ID token',
    () async {
      await inspect(200, utf8.encode('{}'), (backend, client, identity) async {
        identity.proof = null;
        await expectLater(
          backend.call(
            '/v1/billing/status',
            method: 'GET',
            authenticated: true,
            session: true,
          ),
          throwsA(
            isA<EmailFailure>().having(
              (e) => e.code,
              'code',
              'invalid_session',
            ),
          ),
        );
        expect(identity.tokenCalls, 0);
        expect(
          client.request.headers.values.containsKey('Authorization'),
          false,
        );
        expect(client.forceClosed, true);
      });
    },
  );
  test('oversized requests/responses and malformed JSON fail closed without leaking payloads', () async {
    for (final bytes in [utf8.encode('not-json'), List.filled(65537, 65)]) {
      await inspect(200, bytes, (backend, client, _) async {
        await expectLater(
          backend.call(
            '/v1/billing/status',
            method: 'GET',
            authenticated: true,
            session: true,
          ),
          throwsA(isA<EmailFailure>()),
        );
        expect(client.forceClosed, true);
      });
    }
    await inspect(200, utf8.encode('{}'), (backend, client, _) async {
      await expectLater(
        backend.call('/v1/auth/register', body: {'password': 'x' * 32769}),
        throwsA(isA<EmailFailure>()),
      );
      expect(client.request.sent, isEmpty);
      expect(client.forceClosed, true);
    });
  });
  test('only authenticated billing status/intent/verify use their exact methods; webhook/admin paths stay blocked', () async {
    await inspect(200, utf8.encode('{}'), (backend, client, _) async {
      for (final action in ['intent', 'verify']) {
        await backend.call(
          '/v1/billing/$action',
          authenticated: true,
          session: true,
          body: {},
        );
      }
      expect(client.destinations.length, 2);
      for (final action in ['maintenance', 'notifications/play']) {
        await expectLater(
          backend.call(
            '/v1/billing/$action',
            authenticated: true,
            session: true,
          ),
          throwsA(isA<EmailFailure>()),
        );
      }
      await expectLater(
        backend.call(
          '/v1/billing/verify',
          method: 'GET',
          authenticated: true,
          session: true,
        ),
        throwsA(isA<EmailFailure>()),
      );
      await expectLater(
        backend.call('/v1/billing/status', method: 'GET'),
        throwsA(isA<EmailFailure>()),
      );
      expect(client.destinations.length, 2);
    });
  });
}
