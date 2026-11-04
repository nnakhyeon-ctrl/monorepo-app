import 'package:flutter/foundation.dart';

enum BillingPeriod { monthly, annual }

class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.period,
    required this.localizedTotal,
    this.currencyCode = '',
  });
  final String id, localizedTotal, currencyCode;
  final BillingPeriod period;
}

abstract interface class StoreCatalogRepository {
  bool get connected;

  /// A future official SDK adapter supplies store-localized total price only.
  Future<List<StoreProduct>> read();
}

class UnconnectedStoreCatalog implements StoreCatalogRepository {
  const UnconnectedStoreCatalog();
  @override
  bool get connected => false;
  @override
  Future<List<StoreProduct>> read() async => [];
}

class StoreCatalogController extends ChangeNotifier {
  StoreCatalogController(this.repository);
  final StoreCatalogRepository repository;
  bool busy = false, failed = false, checked = false, _disposed = false;
  List<StoreProduct> products = const [];
  StoreProduct? product(BillingPeriod period) =>
      products.where((p) => p.period == period).firstOrNull;
  Future<void> refresh() async {
    if (busy || _disposed) {
      return;
    }
    busy = true;
    failed = false;
    notifyListeners();
    try {
      final result = await repository.read().timeout(
        const Duration(seconds: 8),
      );
      if (result.length > 2 ||
          result.map((p) => p.period).toSet().length != result.length ||
          result.any(
            (p) =>
                p.id.isEmpty ||
                p.id.length > 200 ||
                p.localizedTotal.isEmpty ||
                p.localizedTotal.length > 100,
          )) {
        throw const FormatException('store catalog');
      }
      products = List.unmodifiable(result);
    } catch (_) {
      failed = true;
      products = const [];
    } finally {
      busy = false;
      checked = true;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
