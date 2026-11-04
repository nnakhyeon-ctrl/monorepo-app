import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/game/account_records.dart';

void main() {
  const guest = RecordSnapshot(
    scope: 'guest',
    revision: 4,
    generation: 0,
    hasProgress: true,
  );
  test('existing account preserves both branches without automatic union or overwrite', () {
    final t = RecordTransition(
      guest: guest,
      verifiedUid: 'fixture_a',
      account: const RecordSnapshot(
        scope: 'fixture_a',
        revision: 3,
        generation: 1,
        hasProgress: true,
      ),
    );
    expect(t.decision, RecordDecision.conflictKeepBoth);
    expect(
      t.canImport(
        choice: RecordChoice.importGuest,
        confirmed: true,
        currentUid: 'fixture_a',
        currentRevision: 3,
        currentGeneration: 1,
      ),
      isFalse,
    );
  });
  test('empty-account import requires explicit consent and current identity/revision/generation', () {
    final t = RecordTransition(
      guest: guest,
      verifiedUid: 'fixture_a',
      account: const RecordSnapshot(
        scope: 'fixture_a',
        revision: 0,
        generation: 2,
        hasProgress: false,
      ),
    );
    bool check({
      bool confirmed = true,
      String uid = 'fixture_a',
      int revision = 0,
      int generation = 2,
    }) => t.canImport(
      choice: RecordChoice.importGuest,
      confirmed: confirmed,
      currentUid: uid,
      currentRevision: revision,
      currentGeneration: generation,
    );
    expect(check(), isTrue);
    expect(check(confirmed: false), isFalse);
    expect(check(uid: 'fixture_b'), isFalse);
    expect(check(revision: 1), isFalse);
    expect(check(generation: 1), isFalse);
  });
  test('logout and account switches isolate pending operations', () {
    final q = ScopedQueue<String>();
    q.add('guest_run');
    q.switchScope('fixture_a');
    expect(q.pending, isEmpty);
    q.add('a_run');
    q.switchScope('fixture_b');
    expect(q.pending, isEmpty);
    q.switchScope('guest');
    expect(q.pending, ['guest_run']);
    q.switchScope('fixture_a');
    q.revoke('fixture_a');
    expect(q.scope, 'guest');
    q.switchScope('fixture_a');
    expect(q.pending, isEmpty);
  });
}
