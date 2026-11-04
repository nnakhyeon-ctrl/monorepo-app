import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/security/billing.dart';
import 'package:raikeopeu2026/core/store_catalog.dart';
import 'package:raikeopeu2026/game/catalog.dart';
import 'package:raikeopeu2026/app.dart';
import 'package:raikeopeu2026/core/readiness.dart';
import 'package:raikeopeu2026/game/progress.dart';

import 'fixtures.dart';

class FixtureBillingSession extends ChangeNotifier implements BillingSession {
  @override
  String? key = 'fictional-a';
  bool ready = true, fail = false;
  String state = 'expired';
  int ttl = 120000, verifications = 0;
  Completer<void>? gate;
  final statusReplies = <Completer<Map<String, dynamic>>>[];
  Map<String, dynamic> status() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'ready': ready,
      'verified': true,
      'store': 'play',
      'status': state,
      'products': [
        {'productId': 'fixture_month', 'period': 'monthly'},
        {'productId': 'fixture_year', 'period': 'annual'},
      ],
      'serverNowMs': now,
      'leaseUntilMs': now + ttl,
      'validUntilMs': now + 86400000,
      'autoRenew': state != 'canceled',
      'period': 'monthly',
    };
  }

  void switchOwner(String? value) {
    key = value;
    state = 'expired';
    notifyListeners();
  }

  @override
  Future<Map<String, dynamic>> call(
    String action, {
    Map<String, Object?>? body,
  }) async {
    if (fail) throw StateError('fictional_offline');
    if (action == 'intent') {
      return {
        'binding': '11111111-1111-4111-a111-111111111111',
        'store': 'play',
        'product': {
          'productId': body!['period'] == 'monthly'
              ? 'fixture_month'
              : 'fixture_year',
          'period': body['period'],
        },
      };
    }
    if (action == 'verify') {
      verifications++;
      if (gate != null) await gate!.future;
      state = 'active';
      return {'verified': true, 'finish': true, 'entitlement': status()};
    }
    if (statusReplies.isNotEmpty) return statusReplies.removeAt(0).future;
    return status();
  }
}

class FixtureBillingStore implements BillingStore {
  @override
  String? get store => 'play';
  final events = StreamController<List<BillingPurchase>>.broadcast(sync: true);
  int purchases = 0, finishes = 0, restores = 0, queries = 0;
  Completer<bool>? availabilityGate;
  Completer<void>? availabilityEntered, finishGate, finishEntered;
  @override
  Stream<List<BillingPurchase>> get updates => events.stream;
  @override
  Future<bool> available() async {
    availabilityEntered?.complete();
    return availabilityGate == null ? true : await availabilityGate!.future;
  }

  @override
  Future<List<BillingOffer>> products(List<BillingSpec> specs) async {
    queries++;
    return specs
        .map(
          (s) => BillingOffer(
            StoreProduct(
              id: s.id,
              period: s.period,
              localizedTotal: 'TEST STORE PRICE',
              currencyCode: 'TEST',
            ),
            Object(),
          ),
        )
        .toList();
  }

  @override
  Future<bool> buy(BillingOffer offer, String binding) async {
    purchases++;
    return true;
  }

  @override
  Future<void> restore() async {
    restores++;
  }

  @override
  Future<void> finish(BillingPurchase purchase) async {
    finishes++;
    finishEntered?.complete();
    if (finishGate != null) await finishGate!.future;
  }
}

void main() {
  late FixtureBillingSession session;
  late FixtureBillingStore store;
  late BillingController controller;
  setUp(() {
    session = FixtureBillingSession();
    store = FixtureBillingStore();
    controller = BillingController(session, store);
  });
  tearDown(() async {
    controller.dispose();
    session.dispose();
    await store.events.close();
  });
  Future<void> prepare() async {
    await controller.catalog();
  }

  BillingPurchase event([PurchasePhase phase = PurchasePhase.verifying]) =>
      BillingPurchase(
        'fixture_month',
        'fictional_reference_never_print',
        phase,
        true,
        Object(),
      );
  Future<void> emit(BillingPurchase e) async {
    store.events.add([e]);
    await controller.settled;
  }

  test('guest/unconfigured product/server never opens checkout or grants a local right', () async {
    session.ready = false;
    await prepare();
    await controller.buy(BillingPeriod.monthly, confirmed: true);
    expect(store.purchases, 0);
    expect(controller.access.status, AccessStatus.unverified);
    session.switchOwner(null);
    await controller.restore();
    expect(store.restores, 0);
  });
  test('explicit confirmation is required; native checkout carries only server binding', () async {
    await prepare();
    await controller.buy(BillingPeriod.monthly, confirmed: false);
    expect(store.purchases, 0);
    await controller.buy(BillingPeriod.monthly, confirmed: true);
    expect(store.purchases, 1);
    expect(controller.access.status, isNot(AccessStatus.active));
  });
  test('purchase callback is not entitlement; delivery waits for server verification, duplicate finish is idempotent', () async {
    await prepare();
    session.gate = Completer<void>();
    final e = event();
    store.events.add([e]);
    await Future<void>.delayed(Duration.zero);
    expect(controller.access.status, isNot(AccessStatus.active));
    expect(store.finishes, 0);
    session.gate!.complete();
    await controller.settled;
    expect(controller.access.status, AccessStatus.active);
    expect(store.finishes, 1);
    await emit(e);
    expect(store.finishes, 1);
    expect(session.verifications, 2);
    expect(e.toString(), isNot(contains(e.reference)));
  });
  test(
    'pending, cancellation and failure never create a new entitlement',
    () async {
      await prepare();
      for (final phase in [
        PurchasePhase.pending,
        PurchasePhase.canceled,
        PurchasePhase.failed,
      ]) {
        await emit(event(phase));
        expect(controller.phase, phase);
        expect(controller.access.status, isNot(AccessStatus.active));
        expect(store.finishes, 0);
      }
      expect(session.verifications, 0);
    },
  );
  test('failed validation keeps transaction unfinished and retries without new checkout', () async {
    await prepare();
    session.fail = true;
    await emit(event());
    expect(store.finishes, 0);
    expect(controller.access.status, isNot(AccessStatus.active));
    session.fail = false;
    await controller.retry();
    expect(store.finishes, 1);
    expect(store.purchases, 0);
  });
  test('switching owner during native availability prevents the previous restore and product query', () async {
    for (final restore in [false, true]) {
      store.availabilityGate = Completer<bool>();
      store.availabilityEntered = Completer<void>();
      final operation = restore ? controller.restore() : controller.catalog();
      await store.availabilityEntered!.future;
      session.switchOwner(restore ? null : 'fictional-b');
      store.availabilityGate!.complete(true);
      await operation;
      expect(store.restores, 0);
      expect(store.queries, 0);
      expect(
        controller.phase,
        restore ? PurchasePhase.login : PurchasePhase.setup,
      );
      expect(controller.access.status, AccessStatus.unverified);
    }
  });
  test('manual retries and a duplicate native event serialize one transaction completion', () async {
    await prepare();
    final e = event();
    session.fail = true;
    await emit(e);
    session.fail = false;
    store.finishGate = Completer<void>();
    store.finishEntered = Completer<void>();
    final first = controller.retry();
    await store.finishEntered!.future;
    final second = controller.retry();
    store.events.add([event()]);
    await Future<void>.delayed(Duration.zero);
    expect(store.finishes, 1);
    store.finishGate!.complete();
    await Future.wait([first, second]);
    await controller.settled;
    expect(store.finishes, 1);
    expect(store.purchases, 0);
  });
  test('late A verification cannot grant B or guest or finish a transaction under the new owner', () async {
    await prepare();
    session.gate = Completer<void>();
    store.events.add([event()]);
    await Future<void>.delayed(Duration.zero);
    session.switchOwner('fictional-b');
    session.gate!.complete();
    await controller.settled;
    expect(controller.access.status, AccessStatus.unverified);
    expect(store.finishes, 0);
    session.switchOwner(null);
    expect(controller.access.status, AccessStatus.unverified);
  });
  test('official cancellation/grace preserve time, hold/refund/expiry restrict only premium; no offline lease extension', () async {
    for (final state in ['active', 'canceled', 'grace']) {
      session.state = state;
      await controller.check(force: true);
      expect(controller.access.status, AccessStatus.active);
    }
    for (final state in ['hold', 'paused', 'expired', 'revoked']) {
      session.state = state;
      await controller.check(force: true);
      expect(controller.access.status, AccessStatus.inactive);
    }
    session.state = 'active';
    session.ttl = 10;
    await controller.check(force: true);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(controller.access.status, AccessStatus.unverified);
    session.fail = true;
    await controller.check(force: true);
    expect(controller.access.status, AccessStatus.unverified);
  });
  test('restore requests no new purchase and remains pending until native/server results', () async {
    await prepare();
    await controller.restore();
    expect(store.restores, 1);
    expect(store.purchases, 0);
    expect(controller.access.status, isNot(AccessStatus.active));
    await emit(event());
    expect(controller.access.status, AccessStatus.active);
  });
  test('account activation listens for unfinished purchases without opening a purchase or restore dialog', () async {
    await controller.activate();
    expect(store.purchases, 0);
    expect(store.restores, 0);
    await emit(event());
    expect(controller.access.status, AccessStatus.active);
    expect(store.finishes, 1);
  });
  test('an older active status cannot overwrite a newer revocation or a failed newer check', () async {
    for (final failure in [false, true]) {
      final old = Completer<Map<String, dynamic>>();
      final latest = Completer<Map<String, dynamic>>();
      session.statusReplies.addAll([old, latest]);
      session.state = 'active';
      final oldResult = session.status();
      final first = controller.check(force: true);
      final second = controller.check(force: true);
      if (failure) {
        latest.completeError(StateError('fictional_offline'));
      } else {
        session.state = 'revoked';
        latest.complete(session.status());
      }
      await second;
      old.complete(oldResult);
      await first;
      expect(
        controller.access.status,
        failure ? AccessStatus.unverified : AccessStatus.inactive,
      );
    }
  });
  test('a delayed purchase verification cannot undo a newer canonical status check', () async {
    await prepare();
    session.gate = Completer<void>();
    store.events.add([event()]);
    await Future<void>.delayed(Duration.zero);
    session.state = 'revoked';
    await controller.check(force: true);
    session.gate!.complete();
    await controller.settled;
    expect(controller.access.status, AccessStatus.inactive);
    expect(store.finishes, 1);
  });
  test('time spent waiting for a response never extends the server verification lease', () async {
    final reply = Completer<Map<String, dynamic>>();
    session.statusReplies.add(reply);
    session.state = 'active';
    session.ttl = 20;
    final stale = session.status();
    final pending = controller.check(force: true);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    reply.complete(stale);
    await pending;
    expect(controller.access.status, AccessStatus.unverified);
  });
  testWidgets(
    'small phone consent cannot start checkout without account, verified products and public policies',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final progress = FixtureProgress()
        ..value.records[1] = const StageRecord(
          cleared: true,
          best: 501,
          attempts: 1,
        );
      await tester.pumpWidget(
        RaikeopeuApp(
          progress: progress,
          feedback: FixtureFeedback(),
          billingStore: store,
        ),
      );
      await tester.pumpAndSettle();
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed(AppRoutes.entitlement);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('billingConsent')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('billingConsent')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('billingConsent')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const Key('billingConsent')))
            .value,
        true,
      );
      await tester.ensureVisible(find.byKey(const Key('subscribePurchase')));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('subscribePurchase')))
            .onPressed,
        isNull,
      );
      expect(store.purchases, 0);
      expect(progress.value.records[1]!.best, 501);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
