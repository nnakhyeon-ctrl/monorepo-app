/// Explicit equipment effects, shared by catalog and simulation.
class EquipmentSpec {
  const EquipmentSpec(this.id, this.name, this.detail, {this.premium = true});
  final String id, name, detail;
  final bool premium;
}

const equipmentSpecs = <String, EquipmentSpec>{
  'standard': EquipmentSpec(
    'standard',
    '기본 무장',
    '기본 자동 사격 · 추가 강화 없음',
    premium: false,
  ),
  'echo': EquipmentSpec('echo', '에코 윙', '보조 사격 2발 추가 · 각 기본 피해의 50%'),
  'prism': EquipmentSpec('prism', '프리즘 가드', '12초마다 1초 자동 보호막'),
  'tuner': EquipmentSpec('tuner', '코어 튜너', '사격 피해 +10% · 스킬·기본 보호막 대기시간 -10%'),
  'gyro': EquipmentSpec('gyro', '항로 자이로', '기본탄 분산 폭 -35% · 아군 유도탄 선회 속도 +30%'),
  'capacitor': EquipmentSpec(
    'capacitor',
    '잔광 축전기',
    '피해를 준 기본탄 8회 명중 → 다음 기본 일제 사격 피해 +35%',
  ),
  'safety_cell': EquipmentSpec(
    'safety_cell',
    '새싹 비상셀',
    '장갑1에서 피격 시 1.2초 긴급 보호 · 대기24초 · 장갑/피격 범위는 그대로',
  ),
};
