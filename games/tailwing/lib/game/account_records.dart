/// Account-record conflict rules, independent of login and store restoration.
/// No runtime identity adapter is connected yet. Only verified server sessions
/// may call the future transactional importer with the resulting proposal.
enum RecordChoice { keepServer, importGuest }

enum RecordDecision { emptyServerNeedsConfirmation, conflictKeepBoth, rejected }

class RecordSnapshot {
  const RecordSnapshot({
    required this.scope,
    required this.revision,
    required this.generation,
    required this.hasProgress,
  });
  final String scope;
  final int revision, generation;
  final bool hasProgress;
}

class RecordTransition {
  RecordTransition({
    required this.guest,
    required this.account,
    required this.verifiedUid,
  });
  final RecordSnapshot guest, account;
  final String verifiedUid;
  RecordDecision get decision {
    if (verifiedUid.isEmpty ||
        guest.scope != 'guest' ||
        account.scope != verifiedUid ||
        guest.generation < 0 ||
        account.generation < 0 ||
        guest.revision < 0 ||
        account.revision < 0) {
      return RecordDecision.rejected;
    }
    return account.hasProgress
        ? RecordDecision.conflictKeepBoth
        : RecordDecision.emptyServerNeedsConfirmation;
  }

  /// Existing account records are authoritative. This operation never unions
  /// wallet, upgrades, unlocks or scores, and never deletes the guest branch.
  bool canImport({
    required RecordChoice choice,
    required bool confirmed,
    required String currentUid,
    required int currentRevision,
    required int currentGeneration,
  }) =>
      decision == RecordDecision.emptyServerNeedsConfirmation &&
      choice == RecordChoice.importGuest &&
      confirmed &&
      currentUid == verifiedUid &&
      currentRevision == account.revision &&
      currentGeneration == account.generation;
}

class ScopedQueue<T> {
  final Map<String, List<T>> _queues = {};
  String _scope = 'guest';
  String get scope => _scope;
  void switchScope(String verifiedScope) {
    if (verifiedScope.isEmpty) {
      throw ArgumentError('scope');
    }
    _scope = verifiedScope;
  }

  void add(T operation) => (_queues[_scope] ??= []).add(operation);
  List<T> get pending => List.unmodifiable(_queues[_scope] ?? []);
  void revoke(String scope) {
    _queues.remove(scope);
    if (_scope == scope) {
      _scope = 'guest';
    }
  }
}
