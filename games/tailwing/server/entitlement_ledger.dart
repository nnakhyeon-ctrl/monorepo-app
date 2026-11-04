/// Server-side policy component. No Apple/Google verifier or durable database
/// adapter is connected, so this component cannot grant production app access.
enum StoreState {
  active,
  canceled,
  grace,
  pending,
  failed,
  hold,
  expired,
  revoked,
}

class VerifiedStoreRecord {
  const VerifiedStoreRecord({
    required this.app,
    required this.environment,
    required this.store,
    required this.owner,
    required this.product,
    required this.subscriptionId,
    required this.revision,
    required this.state,
    this.validUntil,
  });
  final String app, environment, store, owner, product, subscriptionId;
  final int revision;
  final StoreState state;
  final DateTime? validUntil;
  bool allows(DateTime now) =>
      {
        StoreState.active,
        StoreState.canceled,
        StoreState.grace,
      }.contains(state) &&
      validUntil != null &&
      now.isBefore(validUntil!);
}

abstract interface class OfficialStoreVerifier {
  /// Must query official API / verify signed data and current canonical status.
  /// Never construct a verified record from client success flags or price.
  Future<VerifiedStoreRecord> verify(String opaqueReference);
}

class EntitlementLedger {
  EntitlementLedger({
    required this.verifier,
    required this.app,
    required this.environment,
    required this.products,
  });
  final OfficialStoreVerifier verifier;
  final String app, environment;
  final Set<String> products;
  final Map<String, VerifiedStoreRecord> _records = {};
  final Map<String, int> _versions = {};
  Future<bool> reconcile({
    required String reference,
    required String verifiedOwner,
    required String store,
    required DateTime now,
  }) async {
    final result = await verifier.verify(reference);
    if (result.app != app ||
        result.environment != environment ||
        result.store != store ||
        result.owner != verifiedOwner ||
        !products.contains(result.product) ||
        result.subscriptionId.isEmpty ||
        result.revision < 0) {
      throw StateError('Store scope mismatch');
    }
    final key = '$store/${result.subscriptionId}';
    final old = _records[key];
    if (old != null && old.owner != verifiedOwner) {
      throw StateError('Ownership mismatch');
    }
    if (result.revision > (_versions[key] ?? -1)) {
      _versions[key] = result.revision;
      // Pending/failed attempts never replace an already verified paid period.
      // An official hold, expiry or revocation does replace it immediately.
      if (old == null ||
          !{StoreState.pending, StoreState.failed}.contains(result.state)) {
        _records[key] = result;
      }
    }
    return allows(verifiedOwner: verifiedOwner, store: store, now: now);
  }

  bool allows({
    required String verifiedOwner,
    required String store,
    required DateTime now,
  }) => _records.values.any(
    (r) => r.owner == verifiedOwner && r.store == store && r.allows(now),
  );
}
