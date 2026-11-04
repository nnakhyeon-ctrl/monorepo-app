import 'engine.dart';

enum DeckPhase { ready, deploying, active, depleted, ended }

/// Presentation derived from the real simulation; grants no protection.
class DeckStatus {
  const DeckStatus(this.phase, this.seconds, this.remaining, this.capacity);
  final DeckPhase phase;
  final double seconds;
  final int remaining, capacity;
  static DeckStatus? read(BattleEngine g) {
    if (g.character != 'eden' || g.skill != 'signature') return null;
    final capacity = g.pilot.balance.count;
    if (g.animalActive) {
      final phase = g.animal.durability <= 0
          ? DeckPhase.depleted
          : g.pilot.balance.duration - g.skillRemaining < .35
          ? DeckPhase.deploying
          : DeckPhase.active;
      return DeckStatus(
        phase,
        g.skillRemaining.clamp(0, g.pilot.balance.duration),
        g.animal.durability,
        capacity,
      );
    }
    return DeckStatus(
      g.cooldown > 0 ? DeckPhase.ended : DeckPhase.ready,
      0,
      0,
      capacity,
    );
  }

  bool get blocking =>
      phase == DeckPhase.deploying || phase == DeckPhase.active;
  String get label => switch (phase) {
    DeckPhase.ready => '갑판 준비',
    DeckPhase.deploying => '갑판 전개',
    DeckPhase.active => '갑판 작동',
    DeckPhase.depleted => '갑판 소진 · 방어 종료',
    DeckPhase.ended => '갑판 종료',
  };
}
