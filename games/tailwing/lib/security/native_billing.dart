import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

import '../core/store_catalog.dart';
import 'billing.dart';

/// Official Flutter plugin -> Play Billing / StoreKit 2. No purchase is started
/// at construction, and there is no mock mode or local entitlement switch.
class NativeBillingStore implements BillingStore {
  InAppPurchase get _sdk => InAppPurchase.instance;
  @override
  String? get store => kIsWeb
      ? null
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => 'play',
          TargetPlatform.iOS => 'app-store',
          _ => null,
        };
  @override
  Stream<List<BillingPurchase>> get updates => _sdk.purchaseStream.map(
    (values) => values
        .map(
          (p) => BillingPurchase(
            p.productID,
            store == 'play'
                ? p.verificationData.serverVerificationData
                : p.purchaseID ?? '',
            switch (p.status) {
              PurchaseStatus.pending => PurchasePhase.pending,
              PurchaseStatus.canceled => PurchasePhase.canceled,
              PurchaseStatus.error => PurchasePhase.failed,
              _ => PurchasePhase.verifying,
            },
            p.pendingCompletePurchase,
            p,
          ),
        )
        .toList(),
  );
  @override
  Future<bool> available() async {
    if (store == null) return false;
    try {
      return await _sdk.isAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<BillingOffer>> products(List<BillingSpec> specs) async {
    final result = await _sdk.queryProductDetails(
      specs.map((s) => s.id).toSet(),
    );
    if (result.error != null || result.notFoundIDs.isNotEmpty) {
      throw StateError('store_catalog_unavailable');
    }
    final offers = <BillingOffer>[];
    for (final spec in specs) {
      for (final p in result.productDetails.where((p) => p.id == spec.id)) {
        if (p.currencyCode.isEmpty || p.rawPrice <= 0 || p.price.isEmpty) {
          continue;
        }
        if (p is GooglePlayProductDetails) {
          final index = p.subscriptionIndex,
              details = p.productDetails.subscriptionOfferDetails;
          if (index == null || details == null || index >= details.length) {
            continue;
          }
          final offer = details[index];
          if (offer.basePlanId != spec.basePlan ||
              offer.offerId != null ||
              offer.installmentPlanDetails != null ||
              offer.pricingPhases.length != 1) {
            continue;
          }
          final phase = offer.pricingPhases.single;
          if (phase.recurrenceMode != RecurrenceMode.infiniteRecurring ||
              phase.billingPeriod !=
                  (spec.period == BillingPeriod.monthly ? 'P1M' : 'P1Y')) {
            continue;
          }
        } else if (p is AppStoreProduct2Details) {
          final sub = p.sk2Product.subscription;
          if (p.sk2Product.type != SK2ProductType.autoRenewable ||
              sub == null ||
              sub.promotionalOffers.isNotEmpty ||
              sub.subscriptionPeriod.value != 1 ||
              sub.subscriptionPeriod.unit !=
                  (spec.period == BillingPeriod.monthly
                      ? SK2SubscriptionPeriodUnit.month
                      : SK2SubscriptionPeriodUnit.year)) {
            continue;
          }
        } else {
          continue;
        } // No consumables, legacy SK1 receipts, introductory or prepaid plans.
        offers.add(
          BillingOffer(
            StoreProduct(
              id: p.id,
              period: spec.period,
              localizedTotal: p.price,
              currencyCode: p.currencyCode,
            ),
            p,
          ),
        );
      }
    }
    return offers;
  }

  @override
  Future<bool> buy(BillingOffer offer, String binding) => _sdk.buyNonConsumable(
    purchaseParam: PurchaseParam(
      productDetails: offer.native as ProductDetails,
      applicationUserName: binding,
    ),
  );
  @override
  Future<void> restore() => _sdk.restorePurchases();
  @override
  Future<void> finish(BillingPurchase purchase) =>
      _sdk.completePurchase(purchase.native as PurchaseDetails);
}
