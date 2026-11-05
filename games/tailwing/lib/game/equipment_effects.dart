part of 'engine.dart';

class EquipmentState {
  int hits = 0;
  bool volleyReady = false;
  double emergencyCooldown = 0, flash = 0;
  void clear() {
    hits = 0;
    volleyReady = false;
    emergencyCooldown = flash = 0;
  }

  void tick(double dt) {
    emergencyCooldown = math.max(0, emergencyCooldown - dt);
    flash = math.max(0, flash - dt);
  }

  double consumeVolley(String equipment) {
    if (equipment != 'capacitor' || !volleyReady) return 1;
    hits = 0;
    volleyReady = false;
    flash = .6;
    return 1.35;
  }

  void recordHit(String equipment) {
    if (equipment != 'capacitor' || volleyReady) return;
    hits++;
    if (hits >= 8) {
      hits = 8;
      volleyReady = true;
    }
  }
}

extension EquipmentReadout on BattleEngine {
  double get basicShieldRechargeDuration =>
      10 * (equipment == 'tuner' ? 0.9 : 1);
  String get equipmentStatus => switch (equipment) {
    'capacitor' =>
      itemState.volleyReady ? '축전 완료 · 다음 기본탄 +35%' : '축전 ${itemState.hits}/8',
    'safety_cell' =>
      itemState.emergencyCooldown > 0
          ? '비상셀 ${itemState.emergencyCooldown.ceil()}초 후'
          : '비상셀 준비',
    'prism' => '자동 보호막 ${(12 - _prismClock).ceil()}초 후',
    'gyro' => '분산 -35% · 유도 선회 +30%',
    'tuner' => '피해 +10% · 대기 -10%',
    'echo' => '보조 사격 2발',
    _ => '기본 자동 사격',
  };
}
