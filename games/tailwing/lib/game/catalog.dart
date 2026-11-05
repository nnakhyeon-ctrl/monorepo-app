import 'dart:async';

import 'package:flutter/material.dart';

import 'combat_model.dart';
import 'progress.dart';
import 'animal_roster.dart';
import 'advanced_skill_catalog.dart';
export 'combat_model.dart' show CatalogCategory;

class CatalogEntry {
  const CatalogEntry(
    this.id,
    this.name,
    this.detail,
    this.category, {
    this.premium = true,
    this.variant = 0,
    this.icon = Icons.flight,
  });
  final String id, name, detail;
  final CatalogCategory category;
  final bool premium;
  bool get isPremiumOnly => premium;
  final int variant;
  final IconData icon;
}

final catalogEntries = <CatalogEntry>[
  CatalogEntry(
    'aurora',
    '오로라-01',
    '기본 기체 · 장갑 3 · 자동 사격',
    CatalogCategory.aircraft,
    premium: false,
  ),
  CatalogEntry(
    'vector',
    '벡터-02',
    '기동형 · 이동·사격 속도 +15% · 최대 장갑 -1',
    CatalogCategory.aircraft,
    variant: 1,
  ),
  CatalogEntry(
    'safeguard',
    '세이프가드',
    '방어형 · 최대 장갑 +1',
    CatalogCategory.aircraft,
    variant: 2,
  ),
  CatalogEntry(
    'barrier',
    '기본 보호막',
    '2초 동안 적탄 방어 · 재사용 대기 10초',
    CatalogCategory.skill,
    premium: false,
    icon: Icons.shield_outlined,
  ),
  CatalogEntry(
    'focus',
    '오버드라이브',
    '4초 동안 사격 속도 2배 · 재사용 대기 12초',
    CatalogCategory.skill,
    icon: Icons.bolt_outlined,
  ),
  CatalogEntry(
    'mecha',
    '메카 전환',
    '5초 동안 로봇 모드 · 공격력 +50%·3방향 사격 · 재사용 대기 16초',
    CatalogCategory.skill,
    icon: Icons.transform,
  ),
  CatalogEntry(
    'pulse',
    '스페셜 펄스',
    '화면의 적탄 제거·모든 적에게 피해 40 · 재사용 대기 14초',
    CatalogCategory.skill,
    icon: Icons.auto_awesome,
  ),
  for (final spec in advancedSkillSpecs.values)
    CatalogEntry(
      spec.id,
      spec.name,
      spec.detail,
      CatalogCategory.skill,
      icon: switch (spec.id) {
        'missile_storm' => Icons.rocket_launch_outlined,
        'beam' => Icons.vertical_align_top,
        'absorb' => Icons.shield_moon_outlined,
        'blackhole' => Icons.blur_circular,
        'emp' => Icons.radar,
        _ => Icons.hub_outlined,
      },
    ),
  CatalogEntry(
    'pilot',
    '루미 · 토끼',
    '기본 사격·보호막을 사용하는 무료 캐릭터',
    CatalogCategory.character,
    premium: false,
    icon: Icons.person_outline,
  ),
  CatalogEntry(
    'rion',
    '세라 · 여우',
    '집중형 · 좁은 2연사·피해 +20% · 최대 장갑 -1',
    CatalogCategory.character,
    premium: false,
    icon: Icons.gps_fixed,
  ),
  CatalogEntry(
    'eden',
    '도미 · 거북이',
    '방어형 · 넓은 3방향 사격·탄당 피해 -25% · 장갑 +1·보호막 +0.5초',
    CatalogCategory.character,
    premium: false,
    icon: Icons.health_and_safety_outlined,
  ),
  CatalogEntry(
    'tw_bear',
    '모루 · 곰',
    '수집 반격 · 궤도 주머니',
    CatalogCategory.character,
  ),
  CatalogEntry(
    'tw_otter',
    '누비 · 수달',
    '연결 공격 · 방울 릴레이',
    CatalogCategory.character,
  ),
  CatalogEntry(
    'tw_owl',
    '루노 · 부엉이',
    '정밀 공격 · 별자리 조준',
    CatalogCategory.character,
  ),
  CatalogEntry(
    'tw_squirrel',
    '토리 · 다람쥐',
    '설치 공격 · 씨앗 비콘',
    CatalogCategory.character,
  ),
  CatalogEntry(
    'tw_hedgehog',
    '피코 · 고슴도치',
    '근접 공격 · 가시꽃 회전',
    CatalogCategory.character,
  ),
  CatalogEntry(
    'tw_penguin',
    '폴리 · 펭귄',
    '이동 제어 · 냉기 항로',
    CatalogCategory.character,
  ),
  CatalogEntry(
    'tw_chameleon',
    '미로 · 개구리',
    '조준 교란 · 잔상 비콘',
    CatalogCategory.character,
  ),
  CatalogEntry(
    'tw_eagle',
    '아로 · 독수리',
    '예고 사격 · 깃결 활주',
    CatalogCategory.character,
  ),
  CatalogEntry(
    'tw_volt',
    '비비 · 전기땃쥐',
    '발사 간격 교란 · 전위 박자',
    CatalogCategory.character,
  ),
  CatalogEntry(
    'signature',
    '캐릭터 고유 기술',
    '선택 캐릭터에 따른 고유 기술 · 월·연 구독',
    CatalogCategory.skill,
    icon: Icons.pets,
  ),
  CatalogEntry(
    'standard',
    '기본 무장',
    '기본 자동 사격 · 추가 강화 없음',
    CatalogCategory.equipment,
    premium: false,
    icon: Icons.adjust,
  ),
  CatalogEntry(
    'echo',
    '에코 윙',
    '보조 사격 2발 추가 · 각 기본 피해의 50%',
    CatalogCategory.equipment,
    icon: Icons.toys_outlined,
  ),
  CatalogEntry(
    'prism',
    '프리즘 가드',
    '12초마다 1초 자동 보호막',
    CatalogCategory.equipment,
    icon: Icons.shield_outlined,
  ),
  CatalogEntry(
    'tuner',
    '코어 튜너',
    '사격 피해 +10% · 스킬 대기시간 -10%',
    CatalogCategory.equipment,
    icon: Icons.tune,
  ),
];

CatalogEntry catalogEntry(String id) =>
    catalogEntries.firstWhere((e) => e.id == id);

enum AccessStatus { unverified, inactive, active }

enum SubscriptionType { none, monthly, yearly }

/// Read-only projection of verified access. A local boolean cannot grant access.
class AccountStatus {
  const AccountStatus({
    required this.isSubscribed,
    required this.subscriptionType,
    this.expirationDate,
  });
  final bool isSubscribed;
  final SubscriptionType subscriptionType;
  final DateTime? expirationDate;
}

class PermissionManager {
  const PermissionManager(this.access, this.clock);
  final SubscriptionAccess access;
  final DateTime Function() clock;
  bool get isSubscribed => access.allows(clock());
  bool canUse(CatalogEntry entry) => !entry.isPremiumOnly || isSubscribed;
  AccountStatus get accountStatus => AccountStatus(
    isSubscribed: isSubscribed,
    subscriptionType: isSubscribed
        ? access.subscriptionType
        : SubscriptionType.none,
    expirationDate: access.validUntil,
  );
}

/// The future store/server adapter must supply verified official expiry/grace.
/// Local UI never creates this state or treats a purchase callback as proof.
class SubscriptionAccess {
  const SubscriptionAccess(
    this.status, {
    this.validUntil,
    this.autoRenew,
    this.periodLabel,
    this.storeLabel,
    this.inGrace = false,
    this.subscriptionType = SubscriptionType.none,
  });
  final AccessStatus status;
  final DateTime? validUntil;
  final bool? autoRenew;
  final String? periodLabel, storeLabel;
  final bool inGrace;
  final SubscriptionType subscriptionType;
  bool allows(DateTime now) =>
      status == AccessStatus.active &&
      validUntil != null &&
      now.isBefore(validUntil!);
}

abstract interface class EntitlementRepository {
  Future<SubscriptionAccess> read();
  Future<SubscriptionAccess> restore();
}

class UnconnectedEntitlements implements EntitlementRepository {
  const UnconnectedEntitlements();
  @override
  Future<SubscriptionAccess> read() async =>
      const SubscriptionAccess(AccessStatus.unverified);
  @override
  Future<SubscriptionAccess> restore() => read();
}

class LoadoutController extends ChangeNotifier implements CombatLoadout {
  LoadoutController({
    this.repository = const UnconnectedEntitlements(),
    DateTime Function()? clock,
    this.campaign,
  }) : _clock = clock ?? DateTime.now {
    ready = _restoreSelections();
  }
  final CampaignController? campaign;
  late Future<void> ready;
  int _scopeEpoch = 0;
  Timer? _expiry;
  bool selectionsLoaded = false;
  Future<void> _restoreSelections() async {
    final epoch = _scopeEpoch;
    if (campaign != null) {
      await campaign!.ready;
      if (_disposed || epoch != _scopeEpoch) return;
      _readPreferences();
      sanitize();
    }
    selectionsLoaded = true;
    _notify();
  }

  void accountChanged() {
    _expiry?.cancel();
    _scopeEpoch++;
    _access = const SubscriptionAccess(AccessStatus.unverified);
    _busy = false;
    lastCheckFailed = false;
    selectionsLoaded = false;
    _selected
      ..clear()
      ..addAll(defaults);
    ready = _restoreSelections();
    _notify();
  }

  void _readPreferences() {
    final saved = campaign?.progress.loadout;
    if (saved != null) {
      for (final category in CatalogCategory.values) {
        _selected[category] = saved.selected(category);
      }
    }
  }

  final EntitlementRepository repository;
  final DateTime Function() _clock;
  SubscriptionAccess _access = const SubscriptionAccess(
    AccessStatus.unverified,
  );
  bool _busy = false;
  bool lastCheckFailed = false, _disposed = false;
  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  bool get busy => _busy;
  SubscriptionAccess get access => _access;
  PermissionManager get permissions => PermissionManager(_access, _clock);
  AccountStatus get accountStatus => permissions.accountStatus;
  bool get premiumActive => permissions.isSubscribed;
  static const defaults = {
    CatalogCategory.aircraft: 'aurora',
    CatalogCategory.skill: 'barrier',
    CatalogCategory.character: 'pilot',
    CatalogCategory.equipment: 'standard',
  };
  final Map<CatalogCategory, String> _selected = Map.of(defaults);
  @override
  String selected(CatalogCategory category) => _selected[category]!;
  bool canUse(CatalogEntry entry) => permissions.canUse(entry);
  AnimalPilot get pilot =>
      animalPilot(effectiveSelected(CatalogCategory.character)) ??
      animalPilots.first;
  String effectiveSelected(CatalogCategory category) =>
      canUse(catalogEntry(selected(category)))
      ? selected(category)
      : defaults[category]!;
  bool isSelected(CatalogEntry entry) =>
      effectiveSelected(entry.category) == entry.id;
  String accessLabel(CatalogEntry entry) {
    if (!entry.premium) return '무료 · 사용 가능';
    if (premiumActive) return '유료 · 구독 이용권 보유';
    return _access.status == AccessStatus.unverified
        ? '유료 · 이용권 미확인'
        : '유료 · 유효 이용권 없음';
  }

  bool select(CatalogEntry entry) {
    if (!selectionsLoaded ||
        campaign?.writeBlocked == true ||
        !catalogEntries.any((candidate) => identical(candidate, entry)) ||
        !canUse(entry)) {
      return false;
    }
    if (_selected[entry.category] == entry.id) return true;
    _selected[entry.category] = entry.id;
    campaign?.setSelection(entry.category, entry.id);
    _notify();
    return true;
  }

  @override
  bool sanitize() {
    var changed = false;
    for (final category in CatalogCategory.values) {
      if (!canUse(catalogEntry(selected(category)))) {
        _selected[category] = defaults[category]!;
        changed = true;
      }
    }
    if (changed) _notify();
    return changed;
  }

  Future<bool> refresh({bool restore = false}) async {
    final epoch = _scopeEpoch;
    await ready;
    if (_disposed || epoch != _scopeEpoch || _busy) return false;
    _busy = true;
    lastCheckFailed = false;
    _notify();
    try {
      final result = await (restore ? repository.restore() : repository.read())
          .timeout(const Duration(seconds: 8));
      if (_disposed || epoch != _scopeEpoch) return false;
      _access = result;
      _expiry?.cancel();
      if (premiumActive) {
        final delay = _access.validUntil!.difference(_clock());
        _expiry = Timer(delay, () {
          if (!_disposed) {
            sanitize();
            _notify();
          }
        });
      }
    } catch (_) {
      if (_disposed || epoch != _scopeEpoch) return false;
      lastCheckFailed = true;
      if (!premiumActive) {
        _access = const SubscriptionAccess(AccessStatus.unverified);
      }
    } finally {
      if (!_disposed && epoch == _scopeEpoch) {
        _busy = false;
        if (premiumActive) _readPreferences();
        sanitize();
        _notify();
      }
    }
    return premiumActive;
  }

  @override
  void dispose() {
    _expiry?.cancel();
    _disposed = true;
    super.dispose();
  }
}
