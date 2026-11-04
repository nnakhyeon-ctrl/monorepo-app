import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../core/store_catalog.dart';
import '../game/catalog.dart';
import 'email_auth.dart';

enum PurchasePhase {
  setup,
  login,
  ready,
  purchasing,
  pending,
  verifying,
  canceled,
  failed,
  verified,
}

abstract interface class BillingSession implements Listenable {
  String? get key;
  Future<Map<String, dynamic>> call(
    String action, {
    Map<String, Object?>? body,
  });
}

class AccountBillingSession implements BillingSession {
  AccountBillingSession(this.auth);
  final EmailAuthController auth;
  @override
  String? get key => auth.deletionPending ? null : auth.connection?.key;
  @override
  Future<Map<String, dynamic>> call(
    String action, {
    Map<String, Object?>? body,
  }) => auth.billingRequest(action, body: body);
  @override
  void addListener(VoidCallback listener) => auth.addListener(listener);
  @override
  void removeListener(VoidCallback listener) => auth.removeListener(listener);
}

class BillingSpec {
  const BillingSpec(this.id, this.period, this.basePlan);
  final String id, basePlan;
  final BillingPeriod period;
}

class BillingOffer {
  const BillingOffer(this.product, this.native);
  final StoreProduct product;
  final Object native;
}

class BillingPurchase {
  const BillingPurchase(
    this.product,
    this.reference,
    this.phase,
    this.needsFinish,
    this.native,
  );
  final String product, reference;
  final PurchasePhase phase;
  final bool needsFinish;
  final Object native;
  @override
  String toString() => 'BillingPurchase([redacted])';
}

abstract interface class BillingStore {
  String? get store;
  Stream<List<BillingPurchase>> get updates;
  Future<bool> available();
  Future<List<BillingOffer>> products(List<BillingSpec> specs);
  Future<bool> buy(BillingOffer offer, String binding);
  Future<void> restore();
  Future<void> finish(BillingPurchase purchase);
}

/// No persisted premium flag or offline receipt cache. The server supplies a
/// short verification lease; an elapsed Timer also invalidates it if clock moves.
class BillingController extends ChangeNotifier {
  BillingController(this.session, this.store) {
    _key = session.key;
    session.addListener(_changed);
  }
  final BillingSession session;
  final BillingStore store;
  VoidCallback? onRightsChanged;
  String? _key;
  int _epoch = 0;
  int _rightsRequest = 0;
  bool _disposed = false, _ready = false, busy = false;
  bool _activating = false;
  bool get connected => _ready;
  PurchasePhase phase = PurchasePhase.setup;
  String state = 'unverified';
  String message = '스토어 상품·가격과 검증 서버 연결 준비 중입니다. 기본 플레이는 무료입니다.';
  SubscriptionAccess access = const SubscriptionAccess(AccessStatus.unverified);
  List<BillingOffer> offers = const [];
  List<BillingSpec> _specs = const [];
  Timer? _lease;
  StreamSubscription<List<BillingPurchase>>? _updates;
  Future<void> _queue = Future.value();
  final List<BillingPurchase> _retry = [];
  final Set<String> _finished = {};
  bool get canBuy =>
      connected &&
      !busy &&
      !{
        PurchasePhase.purchasing,
        PurchasePhase.pending,
        PurchasePhase.verifying,
      }.contains(phase) &&
      session.key != null &&
      !{'active', 'canceled', 'grace', 'pending'}.contains(state);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _rights() {
    if (!_disposed) onRightsChanged?.call();
  }

  bool _current(int epoch) =>
      !_disposed && epoch == _epoch && _key == session.key && _key != null;
  void _changed() {
    if (_key == session.key) return;
    _key = session.key;
    _epoch++;
    _lease?.cancel();
    _lease = null;
    access = const SubscriptionAccess(AccessStatus.unverified);
    _ready = false;
    busy = false;
    state = 'unverified';
    offers = const [];
    _specs = const [];
    _retry.clear();
    _finished.clear();
    phase = _key == null ? PurchasePhase.login : PurchasePhase.setup;
    message = _key == null
        ? '계정 연결 후 본인 이용권을 확인할 수 있습니다. 무료 플레이는 계속할 수 있습니다.'
        : '본인 계정의 스토어 연결 상태를 확인해 주세요.';
    _notify();
  }

  Future<SubscriptionAccess> check({bool force = false}) async {
    final epoch = _epoch;
    if (!_current(epoch)) {
      return const SubscriptionAccess(AccessStatus.unverified);
    }
    if (!force && _lease?.isActive == true) return access;
    final request = ++_rightsRequest;
    final elapsed = Stopwatch()..start();
    try {
      final result = await session
          .call('status')
          .timeout(const Duration(seconds: 20));
      if (!_current(epoch)) {
        return const SubscriptionAccess(AccessStatus.unverified);
      }
      if (request != _rightsRequest) return access;
      _accept(result, epoch, elapsed.elapsedMilliseconds);
    } catch (_) {
      if (_current(epoch) && request == _rightsRequest) {
        _lease?.cancel();
        access = const SubscriptionAccess(AccessStatus.unverified);
        state = 'unverified';
        _ready = false;
        message = '서버에서 이용권을 확인하지 못했습니다. 새 권한을 부여하지 않았습니다. 다시 확인해 주세요.';
      }
    }
    _notify();
    return _current(epoch)
        ? access
        : const SubscriptionAccess(AccessStatus.unverified);
  }

  void _accept(Map<String, dynamic> r, int epoch, int elapsedMs) {
    _lease?.cancel();
    access = const SubscriptionAccess(AccessStatus.unverified);
    _ready = r['ready'] == true && r['store'] == store.store;
    _specs = const [];
    if (!_ready) {
      phase = PurchasePhase.setup;
      state = 'unverified';
      message = '상품·가격과 검증 서버 연결 준비 중입니다. 무료 플레이는 유지합니다.';
      return;
    }
    final specs = r['products'];
    if (specs is! List || specs.length != 2) {
      throw const FormatException('billing catalog');
    }
    _specs = specs.map((p) {
      final id = p['productId'],
          period = p['period'],
          base = p['basePlanId'] ?? '';
      if (id is! String ||
          !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$').hasMatch(id) ||
          !{'monthly', 'annual'}.contains(period) ||
          base is! String) {
        throw const FormatException('billing catalog');
      }
      return BillingSpec(
        id,
        period == 'monthly' ? BillingPeriod.monthly : BillingPeriod.annual,
        base,
      );
    }).toList();
    if (_specs.map((s) => s.period).toSet().length != 2) {
      throw const FormatException('billing catalog');
    }
    const states = {
      'active',
      'canceled',
      'grace',
      'pending',
      'hold',
      'paused',
      'expired',
      'revoked',
      'unverified',
    };
    state = states.contains(r['status']) ? r['status'] as String : 'unverified';
    final end = r['validUntilMs'],
        until = r['leaseUntilMs'],
        now = r['serverNowMs'];
    if (r['verified'] == true &&
        {'active', 'canceled', 'grace'}.contains(state) &&
        end is int &&
        until is int &&
        now is int &&
        until > now &&
        until <= end &&
        until - now <= 120000 &&
        until - now > elapsedMs) {
      access = SubscriptionAccess(
        AccessStatus.active,
        validUntil: DateTime.fromMillisecondsSinceEpoch(end),
        autoRenew: r['autoRenew'] == true,
        inGrace: state == 'grace',
        periodLabel: r['period'] == 'annual' ? '연간' : '월간',
        storeLabel: r['store'] == 'play' ? 'Google Play' : 'App Store',
      );
      _lease = Timer(Duration(milliseconds: until - now - elapsedMs), () {
        if (!_current(epoch)) return;
        access = const SubscriptionAccess(AccessStatus.unverified);
        state = 'unverified';
        message = '이용권 확인 시간이 지났습니다. 연결 후 다시 확인해 주세요. 무료 기록은 유지됩니다.';
        _notify();
        _rights();
      });
    } else if (r['verified'] == true &&
        {'hold', 'paused', 'expired', 'revoked'}.contains(state)) {
      access = const SubscriptionAccess(AccessStatus.inactive);
    } else if ({'active', 'canceled', 'grace'}.contains(state)) {
      state = 'unverified';
    }
  }

  Future<List<StoreProduct>> catalog() async {
    final epoch = _epoch;
    await check();
    if (!_current(epoch) || !_ready || !await store.available()) {
      return const [];
    }
    if (!_current(epoch) || !_ready) return const [];
    _listen();
    final result = await store.products(_specs);
    if (!_current(epoch)) return const [];
    if (result.length != 2 ||
        result.map((p) => p.product.period).toSet().length != 2 ||
        result.any(
          (p) =>
              p.product.localizedTotal.isEmpty ||
              p.product.currencyCode.isEmpty,
        )) {
      throw const FormatException('store products');
    }
    offers = List.unmodifiable(result);
    phase = PurchasePhase.ready;
    message = '스토어의 총 청구액과 자동 갱신 조건을 확인하세요. 월간·연간 혜택은 같습니다.';
    _notify();
    return offers.map((p) => p.product).toList();
  }

  void _listen() {
    _updates ??= store.updates.listen(
      (values) {
        for (final value in values) {
          final epoch = _epoch;
          _queue = _queue
              .then((_) => _process(value, epoch))
              .catchError((_) {});
        }
      },
      onError: (_) {
        phase = PurchasePhase.failed;
        message = '스토어 연결에 실패했습니다. 이용권을 임의로 해금하지 않았습니다.';
        _notify();
      },
    );
  }

  Future<void> activate() async {
    if (_disposed ||
        _activating ||
        session.key == null ||
        (_updates != null && _ready)) {
      return;
    }
    _activating = true;
    final epoch = _epoch;
    try {
      await check(force: true);
      if (_current(epoch) && _ready) {
        final available = await store.available();
        if (!_current(epoch)) return;
        if (available) _listen();
        _rights();
      }
    } finally {
      _activating = false;
      if (!_disposed && epoch != _epoch && session.key != null) {
        Future.microtask(activate);
      }
    }
  }

  Future<void> buy(BillingPeriod period, {required bool confirmed}) async {
    if (!confirmed || !canBuy) return;
    final offer = offers.where((p) => p.product.period == period).firstOrNull;
    if (offer == null) return;
    final epoch = _epoch;
    busy = true;
    phase = PurchasePhase.purchasing;
    _notify();
    try {
      // Always recheck current server rights before opening a store purchase UI.
      final intent = await session.call(
        'intent',
        body: {'period': period.name},
      );
      if (!_current(epoch)) return;
      final binding = intent['binding'], product = intent['product'];
      if (intent['store'] != store.store ||
          binding is! String ||
          !RegExp(r'^[a-f0-9-]{36}$', caseSensitive: false).hasMatch(binding) ||
          product is! Map ||
          product['productId'] != offer.product.id ||
          product['period'] != period.name) {
        throw const FormatException('billing intent');
      }
      _listen();
      if (!await store.buy(offer, binding) && _current(epoch)) {
        phase = PurchasePhase.canceled;
        message = '구매를 시작하지 않았습니다. 무료 기록을 유지했습니다.';
      }
    } catch (_) {
      if (_current(epoch)) {
        phase = PurchasePhase.failed;
        message = '구매를 시작하지 못했습니다. 기존 구독·로그인·연결 상태를 확인하고 복원 또는 재시도하세요.';
      }
    } finally {
      if (_current(epoch)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> restore() async {
    final epoch = _epoch;
    if (!_current(epoch) || busy) return;
    await check(force: true);
    if (!_current(epoch) || !_ready || !await store.available()) return;
    if (!_current(epoch) || !_ready) return;
    _listen();
    busy = true;
    phase = PurchasePhase.verifying;
    _notify();
    try {
      await store.restore();
      if (_current(epoch)) {
        message = '복원 요청을 보냈습니다. 스토어 응답과 서버 검증을 기다립니다. 새 결제는 시작하지 않습니다.';
      }
    } catch (_) {
      if (_current(epoch)) {
        phase = PurchasePhase.failed;
        message = '구매 복원을 확인하지 못했습니다. 같은 앱 계정과 스토어 계정으로 다시 시도해 주세요.';
      }
    } finally {
      if (_current(epoch)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> _process(BillingPurchase event, int epoch) async {
    if (!_current(epoch)) return;
    if (event.phase == PurchasePhase.pending ||
        event.phase == PurchasePhase.canceled ||
        event.phase == PurchasePhase.failed) {
      phase = event.phase;
      message = switch (phase) {
        PurchasePhase.pending => '결제 승인 대기 중입니다. 새 이용권은 아직 제공하지 않습니다.',
        PurchasePhase.canceled => '결제를 취소했습니다. 기존 기록과 유효한 이용권은 유지합니다.',
        _ => '결제에 실패했습니다. 무료 기록을 유지했으며 새 이용권은 부여하지 않았습니다.',
      };
      if (phase == PurchasePhase.pending) state = 'pending';
      _notify();
      return;
    }
    phase = PurchasePhase.verifying;
    _notify();
    final request = ++_rightsRequest;
    final elapsed = Stopwatch()..start();
    try {
      final r = await session.call(
        'verify',
        body: {'productId': event.product, 'reference': event.reference},
      );
      if (!_current(epoch)) return;
      if (r['verified'] != true || r['entitlement'] is! Map) {
        throw const FormatException('unverified purchase');
      }
      if (request == _rightsRequest) {
        _accept(
          Map<String, dynamic>.from(r['entitlement'] as Map),
          epoch,
          elapsed.elapsedMilliseconds,
        );
      }
      final fingerprint = sha256
          .convert(utf8.encode('${_key!}:${event.product}:${event.reference}'))
          .toString();
      if (r['finish'] == true &&
          event.needsFinish &&
          !_finished.contains(fingerprint)) {
        await store.finish(event);
        if (!_current(epoch)) return;
        _finished.add(fingerprint);
      }
      _retry.remove(event);
      phase = PurchasePhase.verified;
      message = access.status == AccessStatus.active
          ? '서버에서 본인 구독 이용권을 확인했습니다.'
          : '거래를 확인했습니다. 현재 공식 상태에 맞는 이용권을 적용했습니다.';
      _rights();
    } catch (error) {
      if (!_current(epoch)) return;
      if (!_retry.contains(event)) _retry.add(event);
      phase = PurchasePhase.failed;
      message = error is EmailFailure && error.code == 'purchase_owner_conflict'
          ? '다른 앱 계정에 귀속된 구매일 수 있습니다. 원래 계정으로 로그인해 복원하세요. 이메일만으로 구매를 이전하지 않습니다.'
          : '구매 검증 또는 거래 완료를 확인하지 못했습니다. 미완료 거래를 보존했으며 다시 확인할 수 있습니다.';
    }
    _notify();
  }

  Future<void> retry() {
    final epoch = _epoch;
    // Native callbacks and manual retries must use the same queue, including
    // completePurchase. An account change invalidates the queued retry too.
    final operation = _queue.then((_) async {
      if (!_current(epoch)) return;
      for (final event in List.of(_retry)) {
        if (!_current(epoch)) return;
        await _process(event, epoch);
      }
      if (!_current(epoch)) return;
      await check(force: true);
      _rights();
    });
    _queue = operation.catchError((_) {});
    return operation;
  }

  Future<void> get settled => _queue;
  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _lease?.cancel();
    _updates?.cancel();
    session.removeListener(_changed);
    _retry.clear();
    offers = const [];
    super.dispose();
  }
}

class BillingEntitlements implements EntitlementRepository {
  BillingEntitlements(this.billing);
  final BillingController billing;
  @override
  Future<SubscriptionAccess> read() => billing.check();
  @override
  Future<SubscriptionAccess> restore() async {
    await billing.restore();
    return billing.check(force: true);
  }
}

class BillingCatalog implements StoreCatalogRepository {
  BillingCatalog(this.billing);
  final BillingController billing;
  @override
  bool get connected => billing.connected;
  @override
  Future<List<StoreProduct>> read() => billing.catalog();
}
