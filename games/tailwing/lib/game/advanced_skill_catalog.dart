/// All advanced techniques require the same verified monthly/yearly access.
/// Values are explicit local balance data, not prices or purchase grants.
class AdvancedSkillSpec {
  const AdvancedSkillSpec(
    this.id,
    this.name,
    this.detail,
    this.charge,
    this.duration,
    this.cooldown,
  );
  final String id, name, detail;
  final double charge, duration, cooldown;
  bool get isPremiumOnly => true;
}

const advancedSkillSpecs = <String, AdvancedSkillSpec>{
  'missile_storm': AdvancedSkillSpec(
    'missile_storm',
    '유성 우편',
    '0.65초 차지 → 적·적탄 0.5초 정지 · 유도 미사일 6발×피해 20 · 대기 18초',
    .65,
    1.4,
    18,
  ),
  'beam': AdvancedSkillSpec(
    'beam',
    '새벽 실선',
    '0.55초 차지 → 전방 폭 18 지속 레이저 2.4초 · 초당 피해 30 · 대기 16초',
    .55,
    2.4,
    16,
  ),
  'absorb': AdvancedSkillSpec(
    'absorb',
    '별빛 저금통',
    '3초간 반경 50의 모든 적탄 흡수 · 최대 에너지 60 · 종료 시 6방향 반격 · 대기 17초',
    0,
    3,
    17,
  ),
  'blackhole': AdvancedSkillSpec(
    'blackhole',
    '소용돌이 정원',
    '0.4초 차지 → 전방 반경 100 중력장 3초 · 일반 적 견인·초당 피해 12 · 보스 견인 제외 · 대기 20초',
    .4,
    3,
    20,
  ),
  'emp': AdvancedSkillSpec(
    'emp',
    '고요한 연못',
    '전방 반경 120 EMP 장판 4초 · 적 이동 속도 80% 감소 · 대기 18초',
    0,
    4,
    18,
  ),
  'chain': AdvancedSkillSpec(
    'chain',
    '반딧불 연결',
    '0.35초 차지 → 거리 115 이내 최대 5기·각 피해 34 · 3초 연결 중 명중 피해 30%를 다른 연결 적에게 전달 · 대기 15초',
    .35,
    3,
    15,
  ),
};
