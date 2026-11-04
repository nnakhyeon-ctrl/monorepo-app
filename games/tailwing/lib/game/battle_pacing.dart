import 'engine.dart';

/// UI-only chapter cues driven by actual stage timing and boss presence.
class BattlePacing {
  const BattlePacing(this.label, this.hint, this.progress);
  final String label, hint;
  final double progress;
  static BattlePacing read(BattleEngine g) {
    if (g.phase == BattlePhase.won) {
      return const BattlePacing('항로 확보', '다음 항로가 기다립니다', 1);
    }
    if (g.phase == BattlePhase.lost) {
      return const BattlePacing('재정비', '선택한 구성으로 다시 도전', 0);
    }
    final boss = g.enemies
        .where((e) => e.kind == EnemyKind.boss && e.health > 0)
        .firstOrNull;
    if (boss != null) {
      return BattlePacing(
        '보스 교전',
        g.stage.bossName,
        (1 - boss.health / g.stage.bossHealth).clamp(0, 1),
      );
    }
    final remaining = (g.stage.bossAt - g.elapsed).ceil();
    return BattlePacing(
      g.elapsed < 4
          ? '항로 진입'
          : remaining <= 12
          ? '보스 접근'
          : '편대 교전',
      g.elapsed < 4
          ? g.stage.briefing
          : remaining <= 12
          ? '보스 도착 ${remaining.clamp(0, 12)}초 · 스킬을 준비하세요'
          : '작전 진행 · 조준 예고와 탄 사이의 틈을 확인하세요',
      (g.elapsed / g.stage.bossAt).clamp(0, 1),
    );
  }
}
