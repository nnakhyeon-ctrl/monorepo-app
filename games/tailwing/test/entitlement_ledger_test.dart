import 'package:flutter_test/flutter_test.dart';

import '../server/entitlement_ledger.dart';

class FakeVerifier implements OfficialStoreVerifier {
  late VerifiedStoreRecord result;
  @override
  Future<VerifiedStoreRecord> verify(String opaqueReference) async => result;
}

void main() {
  final now = DateTime.utc(2026, 10, 19);
  VerifiedStoreRecord record(
    StoreState state,
    int revision, {
    String owner = 'fixture_a',
    String app = 'airzero',
  }) => VerifiedStoreRecord(
    app: app,
    environment: 'test',
    store: 'google',
    owner: owner,
    product: 'monthly_fixture',
    subscriptionId: 'fixture_subscription',
    revision: revision,
    state: state,
    validUntil: now.add(const Duration(days: 2)),
  );
  test('pending/failed do not grant; cancellation/grace retain official remaining period', () async {
    final verifier = FakeVerifier();
    final ledger = EntitlementLedger(
      verifier: verifier,
      app: 'airzero',
      environment: 'test',
      products: {'monthly_fixture', 'annual_fixture'},
    );
    Future<bool> apply(StoreState state, int revision) {
      verifier.result = record(state, revision);
      return ledger.reconcile(
        reference: 'fixture_reference',
        verifiedOwner: 'fixture_a',
        store: 'google',
        now: now,
      );
    }

    expect(await apply(StoreState.pending, 1), isFalse);
    expect(await apply(StoreState.failed, 2), isFalse);
    expect(await apply(StoreState.active, 3), isTrue);
    expect(await apply(StoreState.canceled, 4), isTrue);
    expect(await apply(StoreState.grace, 5), isTrue);
    expect(await apply(StoreState.pending, 6), isTrue);
    expect(
      await apply(StoreState.hold, 5),
      isTrue,
      reason: 'Even a pending observation advances ordering; older hold cannot replace it',
    );
    expect(
      ledger.allows(
        verifiedOwner: 'fixture_a',
        store: 'google',
        now: now.add(const Duration(days: 3)),
      ),
      isFalse,
    );
    expect(
      ledger.allows(verifiedOwner: 'fixture_a', store: 'apple', now: now),
      isFalse,
    );
    expect(await apply(StoreState.revoked, 7), isFalse);
    expect(
      await apply(StoreState.active, 3),
      isFalse,
      reason: 'Old notification cannot undo refund',
    );
    expect(
      await apply(StoreState.revoked, 7),
      isFalse,
      reason: 'Duplicate is idempotent',
    );
  });
  test('wrong app and other account cannot obtain restored rights', () async {
    final verifier = FakeVerifier()
      ..result = record(StoreState.active, 1, app: 'another_app');
    final ledger = EntitlementLedger(
      verifier: verifier,
      app: 'airzero',
      environment: 'test',
      products: {'monthly_fixture'},
    );
    Future<bool> attempt() => ledger.reconcile(
      reference: 'fixture_reference',
      verifiedOwner: 'fixture_a',
      store: 'google',
      now: now,
    );
    await expectLater(attempt(), throwsStateError);
    verifier.result = record(StoreState.active, 2, owner: 'fixture_b');
    await expectLater(attempt(), throwsStateError);
  });
}
