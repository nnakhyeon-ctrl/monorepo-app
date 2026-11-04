import 'package:flutter/material.dart';

import '../core/design.dart';
import '../core/readiness.dart';
import '../core/store_catalog.dart';

enum SubscriptionPeriod { monthly, annual }

class SubscriptionPlans extends StatefulWidget {
  const SubscriptionPlans({super.key});
  @override
  State<SubscriptionPlans> createState() => _SubscriptionPlansState();
}

class _SubscriptionPlansState extends State<SubscriptionPlans> {
  SubscriptionPeriod? _period;
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final catalog = AppServices.of(context).storeCatalog;
    if (!_started) {
      _started = true;
      if (catalog.repository.connected && !catalog.checked) {
        Future.microtask(catalog.refresh);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '월간·연간 구독은 같은 프리미엄 혜택을 제공합니다. 스토어의 총 청구액과 자동 갱신 조건을 확인해 선택합니다. 상품·가격 미설정 시 구매를 시작하지 않습니다.',
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          for (final period in SubscriptionPeriod.values)
            ChoiceChip(
              key: Key('subscription-${period.name}'),
              label: Text(
                period == SubscriptionPeriod.monthly ? '월간 구독' : '연간 구독',
              ),
              selected: _period == period,
              onSelected: (_) => setState(() => _period = period),
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
        ],
      ),
      const SizedBox(height: 12),
      Text(switch (_period) {
        SubscriptionPeriod.monthly => '월간: 1개월마다 갱신 · 월간 총 결제액 · 관리자 설정 대기',
        SubscriptionPeriod.annual => '연간: 1년마다 갱신 · 연간 총 결제액 · 관리자 설정 대기',
        null => '기간을 선택해 갱신 주기를 확인하세요. 선택만으로 구독이 시작되지 않습니다.',
      }, style: const TextStyle(color: Palette.muted)),
      const SizedBox(height: 12),
      ListenableBuilder(
        listenable: AppServices.of(context).storeCatalog,
        builder: (context, _) {
          final c = AppServices.of(context).storeCatalog;
          if (!c.repository.connected) {
            return const Text(
              '스토어 상품·가격 미연결 · 관리자가 최종 가격을 입력하고 공식 스토어를 연결해야 표시됩니다.',
            );
          }
          if (c.busy) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (c.failed)
                const Text('스토어 가격을 읽지 못했습니다. 임의 가격으로 대체하지 않습니다.')
              else if (c.products.isEmpty)
                const Text('조회 가능한 월간·연간 상품이 없습니다. 상품 등록 상태를 확인해야 합니다.')
              else
                for (final p in c.products)
                  Text(
                    '${p.period == BillingPeriod.monthly ? '월간 · 1개월' : '연간 · 1년'} 총 청구액: ${p.localizedTotal}\n두 기간의 프리미엄 혜택은 같습니다.',
                  ),
              OutlinedButton(
                onPressed: c.refresh,
                child: const Text('스토어 가격 다시 확인'),
              ),
            ],
          );
        },
      ),
      PurchaseActions(
        period: _period == null
            ? null
            : _period == SubscriptionPeriod.monthly
            ? BillingPeriod.monthly
            : BillingPeriod.annual,
      ),
    ],
  );
}

class PurchaseActions extends StatefulWidget {
  const PurchaseActions({this.period, this.restoreOnly = false, super.key});
  final BillingPeriod? period;
  final bool restoreOnly;
  @override
  State<PurchaseActions> createState() => _PurchaseActionsState();
}

class _PurchaseActionsState extends State<PurchaseActions> {
  bool _agreed = false;
  String? _owner;
  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context), billing = services.billing;
    return ListenableBuilder(
      listenable: billing,
      builder: (context, _) {
        if (_owner != billing.session.key) {
          _owner = billing.session.key;
          _agreed = false;
        }
        final legalReady =
            services.contacts.terms != null &&
            services.contacts.privacy != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Text(billing.message, key: const Key('billingStatus')),
            Text(switch (billing.state) {
              'active' => '이용권 활성',
              'canceled' => '자동 갱신 중단 · 공식 남은 기간 유지',
              'grace' => '스토어 결제 유예기간 · 공식 기한까지 유지',
              'pending' => '결제 승인 대기 · 새 이용권 없음',
              'hold' => '결제 보류 · 유료 혜택 제한',
              'paused' => '구독 일시중지 · 유료 혜택 제한',
              'expired' => '구독 만료 · 무료 플레이/기록 유지',
              'revoked' => '공식 철회 확인 · 무료 플레이/기록 유지',
              _ => '이용권 미확인',
            }),
            if (billing.access.validUntil case final end?)
              Text(
                '공식 이용 기한: ${MaterialLocalizations.of(context).formatMediumDate(end.toLocal())} '
                '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(end.toLocal()))}',
              ),
            OutlinedButton(
              key: const Key('billingRefresh'),
              onPressed: billing.busy
                  ? null
                  : () async {
                      await billing.check(force: true);
                      await services.storeCatalog.refresh();
                      await services.loadout.refresh();
                    },
              child: const Text('스토어·이용권 다시 확인'),
            ),
            if (!widget.restoreOnly) ...[
              const Text(
                '선택한 기간마다 자동 갱신됩니다. 스토어에서 갱신을 중단할 수 있으며 계정 탈퇴와는 별개입니다.',
              ),
              CheckboxListTile(
                key: const Key('billingConsent'),
                contentPadding: EdgeInsets.zero,
                value: _agreed,
                onChanged: billing.busy
                    ? null
                    : (v) => setState(() => _agreed = v ?? false),
                title: const Text(
                  '총 결제액·갱신 주기·자동 갱신·약관·개인정보·해지/환불 안내를 확인했습니다.',
                ),
              ),
              if (!legalReady)
                const Text('공개 약관·개인정보 주소와 상품 설정을 준비한 뒤 구매할 수 있습니다.'),
              FilledButton(
                key: const Key('subscribePurchase'),
                onPressed:
                    billing.canBuy &&
                        _agreed &&
                        legalReady &&
                        widget.period != null &&
                        billing.offers.any(
                          (o) => o.product.period == widget.period,
                        )
                    ? () => billing.buy(widget.period!, confirmed: true)
                    : null,
                child: const Text('선택한 구독으로 구매 진행'),
              ),
            ],
            TextButton(
              key: const Key('billingRetry'),
              onPressed: billing.busy ? null : billing.retry,
              child: const Text('미완료 거래 다시 확인'),
            ),
          ],
        );
      },
    );
  }
}
