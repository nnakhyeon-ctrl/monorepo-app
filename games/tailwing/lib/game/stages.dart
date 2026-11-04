/// Authored campaign configuration, not a random difficulty multiplier.
class StageDefinition {
  const StageDefinition(
    this.number,
    this.name,
    this.biome,
    this.formation,
    this.bossPattern,
    this.spawnInterval,
    this.bulletSpeed,
    this.bossHealth,
  );
  final int number, biome, formation, bossPattern;
  final String name;
  final double spawnInterval, bulletSpeed, bossHealth;
  double get bossAt => 160 + (number % 3) * 5;
  double get timeLimit => 300;
  int get seed => 2026 + number * 7919;
  String get bossName => switch (bossPattern) {
    0 => '철갑 편대장',
    1 => '폭풍 지휘기',
    _ => '이동 요새',
  };
  String get briefing => switch (formation) {
    0 => '교차 정찰 편대 · 조준탄을 옆으로 피하세요',
    1 => '좌우 확산 편대 · 탄 사이의 틈을 찾으세요',
    _ => '중앙 장갑 편대 · 예고선을 확인하세요',
  };
}

// First three are the validation baseline; later rows are introduced only
// after the same deterministic simulation and progression tests pass.
const stages = [
  StageDefinition(1, '새벽 해안', 0, 0, 0, 2.8, 85, 420),
  StageDefinition(2, '안개 수로', 0, 1, 1, 2.7, 90, 460),
  StageDefinition(3, '강철 항구', 0, 2, 2, 3.2, 85, 500),
  StageDefinition(4, '녹음 전선', 1, 0, 1, 3.2, 85, 470),
  StageDefinition(5, '협곡 진입', 1, 1, 2, 2.9, 92, 510),
  StageDefinition(6, '숲의 요새', 1, 2, 0, 3.8, 85, 540),
  StageDefinition(7, '은빛 설원', 2, 0, 2, 3.0, 92, 500),
  StageDefinition(8, '빙하 철교', 2, 1, 0, 3.0, 95, 540),
  StageDefinition(9, '북부 기지', 2, 0, 1, 3.2, 90, 560),
  StageDefinition(10, '청색 폭풍', 3, 0, 0, 3.0, 95, 540),
  StageDefinition(11, '구름 장벽', 3, 1, 1, 3.1, 98, 570),
  StageDefinition(12, '번개 회랑', 3, 2, 2, 3.8, 90, 600),
  StageDefinition(13, '황혼 방어선', 4, 0, 1, 3.1, 98, 570),
  StageDefinition(14, '최후의 항로', 4, 1, 2, 3.1, 100, 600),
  StageDefinition(15, '에어제로', 4, 2, 0, 3.5, 98, 640),
];

StageDefinition stageByNumber(int number) {
  if (number < 1 || number > stages.length) {
    throw RangeError.range(number, 1, stages.length, 'stage');
  }
  return stages[number - 1];
}
