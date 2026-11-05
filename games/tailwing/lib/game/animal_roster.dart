/// Original roster and tunable balance. IDs pilot/rion/eden retain old saves.
enum TechniqueTarget {
  allEnemies,
  normalEnemies,
  ordinaryProjectiles,
  armoredAim,
}

const techniqueTargets = {
  'tw_bear': TechniqueTarget.ordinaryProjectiles,
  'eden': TechniqueTarget.ordinaryProjectiles,
  'tw_penguin': TechniqueTarget.normalEnemies,
  'tw_chameleon': TechniqueTarget.armoredAim,
  'tw_volt': TechniqueTarget.normalEnemies,
};

/// Original briefings describe existing roles without granting new abilities.
const pilotTips = <String, String>{
  'pilot': '일정한 간격으로 움직여 탄 사이의 안전한 길을 이어 보세요.',
  'rion': '좁은 연사를 적의 중앙에 맞추세요. 장갑이 적으니 예고선을 먼저 피하세요.',
  'eden': '넓은 사격으로 길을 열고, 갑판은 전방 일반탄에 맞춰 펼치세요.',
  'tw_bear': '일반탄을 가까이 모으고 반격이 나갈 전방을 확보하세요.',
  'tw_otter': '가까이 모인 적에게 명중시키면 방울 릴레이를 활용하기 좋아요.',
  'tw_owl': '표시된 우선 목표가 사라지기 전에 정밀탄의 발사 시점을 확인하세요.',
  'tw_squirrel': '적의 이동 길목에 씨앗을 놓고 안전한 쪽으로 이동하세요.',
  'tw_hedgehog': '회전 공격은 근거리용이에요. 적과 직접 부딪히지 않게 거리를 두세요.',
  'tw_penguin': '전방의 일반 적이 냉기 항로 안에 들어오도록 위치를 잡으세요.',
  'tw_chameleon': '장갑기의 조준이 잔상에 고정된 뒤 옆으로 빠져나오세요.',
  'tw_eagle': '예고 사격이 나갈 항로를 고른 뒤 적이 지나갈 위치를 읽어 보세요.',
  'tw_volt': '가까운 일반 적의 발사 간격을 흐트러뜨려 움직일 틈을 만드세요.',
};

class AnimalPilot {
  const AnimalPilot(
    this.id,
    this.species,
    this.name,
    this.role,
    this.technique,
    this.description,
    this.art,
    this.color,
    this.balance, {
    this.free = false,
  });
  final String id, species, name, role, technique, description, art;
  final int color;
  final bool free;
  final TechniqueBalance balance;
  TechniqueTarget get target =>
      techniqueTargets[id] ?? TechniqueTarget.allEnemies;
  bool get hasMountedHero => const {'rabbit', 'turtle', 'fox'}.contains(art);
  String get _artVersion => hasMountedHero ? '_v2' : '';
  String get portrait => 'assets/tailwing/${art}_portrait$_artVersion.png';
  String get aircraft => 'assets/tailwing/${art}_ship$_artVersion.png';
  String get hero =>
      hasMountedHero ? 'assets/tailwing/${art}_hero_v2.png' : aircraft;
}

class TechniqueBalance {
  const TechniqueBalance({
    required this.duration,
    required this.cooldown,
    this.damage = 0,
    this.budget = 0,
    this.radius = 0,
    this.count = 0,
    this.interval = .3,
    this.range = 0,
    this.width = 0,
    this.maxTargets = 4,
    this.damageFalloff = 2,
    this.minimumRange = 20,
    this.slowFactor = .55,
    this.armoredSlowFactor = .8,
    this.slowImmunity = 2,
  });
  final double duration,
      cooldown,
      damage,
      budget,
      radius,
      interval,
      range,
      width;
  final int count;
  final int maxTargets;
  final double damageFalloff,
      minimumRange,
      slowFactor,
      armoredSlowFactor,
      slowImmunity;
}

const animalPilots = [
  AnimalPilot(
    'pilot',
    '토끼',
    '루미',
    '경로 설계',
    '구름 스티치',
    '최근 이동 경로 최대8점 연결 · 3초 · 총48피해 상한',
    'rabbit',
    0xFF85DEC9,
    TechniqueBalance(
      duration: 3,
      cooldown: 12,
      damage: 4,
      budget: 48,
      radius: 12,
      count: 8,
      range: 1.2,
    ),
    free: true,
  ),
  AnimalPilot(
    'rion',
    '여우',
    '세라',
    '각도 조절',
    '프리즘 항로',
    '4초 기본탄을 3방향 굴절 · 탄당40% · 추가 무장 제외',
    'fox',
    0xFFD3ABFA,
    TechniqueBalance(
      duration: 4,
      cooldown: 14,
      damage: .4,
      count: 3,
      range: .28,
    ),
    free: true,
  ),
  AnimalPilot(
    'tw_bear',
    '곰',
    '모루',
    '수집 반격',
    '궤도 주머니',
    '2초 근접 일반탄 최대6개 수집 후 전방 반격 · 보스탄 제외',
    'bear',
    0xFFF0C76B,
    TechniqueBalance(
      duration: 2,
      cooldown: 15,
      damage: 8,
      radius: 48,
      count: 6,
    ),
  ),
  AnimalPilot(
    'eden',
    '거북이',
    '도미',
    '방향 방어',
    '접이식 갑판',
    '3초 전방 일반탄5회 차단 · 측후방/보스탄/충돌 방어 안 함',
    'turtle',
    0xFF88BDD5,
    TechniqueBalance(duration: 3, cooldown: 13, count: 5, width: 70, range: 60),
    free: true,
  ),
  AnimalPilot(
    'tw_otter',
    '수달',
    '누비',
    '연결 공격',
    '방울 릴레이',
    '4초 명중 시 가까운 적3체 연결 · 거리80 · 총48피해 상한',
    'otter',
    0xFF79D3EF,
    TechniqueBalance(
      duration: 4,
      cooldown: 14,
      damage: 6,
      budget: 48,
      radius: 80,
      count: 3,
    ),
  ),
  AnimalPilot(
    'tw_owl',
    '부엉이',
    '루노',
    '정밀 공격',
    '별자리 조준',
    '우선 적1체 표시 · 0.6초 예고 후 정밀탄3발 · 재지정 없음',
    'owl',
    0xFFC0B7F3,
    TechniqueBalance(
      duration: 3,
      cooldown: 14,
      damage: 12,
      count: 3,
      interval: .35,
      range: .6,
    ),
  ),
  AnimalPilot(
    'tw_squirrel',
    '다람쥐',
    '토리',
    '설치 공격',
    '씨앗 비콘',
    '현재 위치 최대2개/6초 · 접근 시 반경55/최대4체 폭발',
    'squirrel',
    0xFFAFDB86,
    TechniqueBalance(
      duration: 6,
      cooldown: 5,
      damage: 20,
      radius: 55,
      count: 2,
      range: 36,
    ),
  ),
  AnimalPilot(
    'tw_hedgehog',
    '고슴도치',
    '피코',
    '근거리 공격',
    '가시꽃 회전',
    '3초 반경55 회전 공격 · 총60피해 상한 · 자동 무적 없음',
    'hedgehog',
    0xFFF4AF88,
    TechniqueBalance(
      duration: 3,
      cooldown: 12,
      damage: 5,
      budget: 60,
      radius: 55,
    ),
  ),
  AnimalPilot(
    'tw_penguin',
    '펭귄',
    '폴리',
    '이동 제어',
    '냉기 항로',
    '3초 전방 일반적45% 둔화/장갑적20% · 보스 면역·재적용 제한',
    'penguin',
    0xFF9CE2F2,
    TechniqueBalance(duration: 3, cooldown: 14, width: 100, range: 200),
  ),
  AnimalPilot(
    'tw_chameleon',
    '개구리',
    '미로',
    '조준 교란',
    '잔상 비콘',
    '3초 새 장갑적 조준을 설치 위치로 유도 · 기존 탄/보스 제외',
    'frog',
    0xFFE6A6CC,
    TechniqueBalance(duration: 3, cooldown: 15),
  ),
  AnimalPilot(
    'tw_eagle',
    '독수리',
    '아로',
    '예고 사격',
    '깃결 활주',
    '0.5초 전방 예고 후 깃탄4발 · 탄당10피해 · 자동 무적 없음',
    'eagle',
    0xFFE1BC91,
    TechniqueBalance(
      duration: 2,
      cooldown: 13,
      damage: 10,
      count: 4,
      range: .5,
      width: 80,
    ),
  ),
  AnimalPilot(
    'tw_volt',
    '전기땃쥐',
    '비비',
    '발사 간격 교란',
    '전위 박자',
    '2초 근접 일반적 최대6체 발사0.7초 지연/체당1회 · 보스 면역',
    'volt',
    0xFFB9B1FF,
    TechniqueBalance(
      duration: 2,
      cooldown: 14,
      damage: 4,
      budget: 24,
      radius: 85,
      count: 6,
      range: .7,
    ),
  ),
];

AnimalPilot? animalPilot(String id) {
  for (final pilot in animalPilots) {
    if (pilot.id == id) return pilot;
  }
  return null;
}
