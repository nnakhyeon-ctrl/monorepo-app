import 'package:flutter/material.dart';

import '../core/design.dart';
import '../core/readiness.dart';
import '../game/catalog.dart';
import 'loadout_art.dart';
import 'settings.dart' show LocalSaveStatus;
import '../game/animal_roster.dart';

class HangarScreen extends StatefulWidget {
  const HangarScreen({super.key});
  @override
  State<HangarScreen> createState() => _HangarScreenState();
}

class _HangarScreenState extends State<HangarScreen> {
  CatalogCategory _category = CatalogCategory.character;
  bool _starting = false;

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final s = AppServices.of(context);
      await Future.wait([
        s.campaign.ready,
        s.loadout.ready,
        s.battleAssets.prepare(),
      ]);
      if (mounted) await Navigator.pushNamed(context, AppRoutes.battle);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('전투를 준비하지 못했습니다. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _details(CatalogEntry entry) async {
    final s = AppServices.of(context), c = s.loadout;
    final destination = await showDialog<String>(
      context: context,
      builder: (dialogContext) => ListenableBuilder(
        listenable: Listenable.merge([c, s.campaign]),
        builder: (context, _) => AlertDialog(
          scrollable: true,
          title: Text(entry.name),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CatalogArt(entry, height: 180),
              const SizedBox(height: 16),
              Text(
                catalogRole(entry.id),
                style: TextStyle(
                  color: catalogAccent(entry.id),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(entry.detail),
              if (entry.id == 'signature') SignatureInfo(c.pilot),
              if (animalPilot(entry.id) case final pilot?) ...[
                Image.asset(
                  pilot.aircraft,
                  height: 150,
                  cacheWidth: 512,
                  fit: BoxFit.contain,
                  semanticLabel: '${pilot.name} 탑승 기체',
                ),
                const SizedBox(height: 12),
                Text(
                  '${pilot.technique} · 구독 고유 기술',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(pilot.description),
                const Text(
                  '무료 3종은 기본 사격·보호막으로 사용할 수 있습니다. 고유 기술은 스킬에서 별도 선택합니다.',
                ),
              ],
              const SizedBox(height: 14),
              Text(c.accessLabel(entry)),
              if (!c.canUse(entry)) ...[
                const SizedBox(height: 10),
                const Text(
                  '월/년 구독 시 모든 기체와 스킬이 해금됩니다',
                  key: Key('subscriptionUnlockMessage'),
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const Text('월간·연간 혜택은 같으며 전투 쿨타임은 적용됩니다.'),
              ],
              const SizedBox(height: 12),
              Text(
                entry.premium
                    ? '월간·연간 구독에 포함됩니다. 가격은 관리자 설정 대기입니다. 유효 이용권을 확인한 뒤에만 선택·사용할 수 있습니다.'
                    : '기본 무료 구성입니다. 선택한 능력은 다음 전투에 적용됩니다.',
              ),
              const SizedBox(height: 12),
              const Text('표시한 능력 수치는 현재 전투에 적용되는 초기 균형 값입니다.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('닫기'),
            ),
            if (c.canUse(entry))
              FilledButton(
                key: Key('select-detail-${entry.id}'),
                onPressed:
                    c.isSelected(entry) ||
                        !c.selectionsLoaded ||
                        s.campaign.writeBlocked
                    ? null
                    : () {
                        if (c.select(entry)) {
                          Navigator.pop(dialogContext);
                        }
                      },
                child: Text(c.isSelected(entry) ? '선택됨' : '이 구성 선택'),
              )
            else
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, AppRoutes.settings),
                child: const Text('환경설정에서 구독 보기'),
              ),
            if (!c.canUse(entry))
              TextButton(
                key: const Key('openSubscriptionUnlock'),
                onPressed: () =>
                    Navigator.pop(dialogContext, AppRoutes.entitlement),
                child: const Text('월/년 구독 페이지로'),
              ),
          ],
        ),
      ),
    );
    if (destination != null && mounted) {
      await Navigator.pushNamed(context, destination);
    }
  }

  Widget _card(CatalogEntry entry) {
    final s = AppServices.of(context), c = s.loadout;
    final selected = c.isSelected(entry), usable = c.canUse(entry);
    final accent = catalogAccent(entry.id);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: selected ? .16 : .06),
            Palette.panel,
          ],
        ),
        border: Border.all(
          color: selected ? accent : accent.withValues(alpha: .24),
          width: selected ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _details(entry),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      children: [
                        CatalogArt(
                          entry,
                          height: entry.category == CatalogCategory.aircraft
                              ? 170
                              : 115,
                        ),
                        if (!usable)
                          const Positioned(
                            top: 6,
                            right: 6,
                            child: Icon(Icons.lock, color: Palette.muted),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      entry.name,
                      key: Key('catalog-${entry.id}'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      catalogRole(entry.id),
                      style: TextStyle(
                        fontSize: 14,
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.detail,
                      style: const TextStyle(
                        color: Palette.muted,
                        fontSize: 15,
                      ),
                    ),
                    if (entry.id == 'signature') SignatureInfo(c.pilot),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Badge(
                          entry.premium ? '구독 콘텐츠' : '무료',
                          entry.premium
                              ? const Color(0xFFFFCA85)
                              : Palette.teal,
                        ),
                        _Badge(
                          selected
                              ? '현재 선택'
                              : usable
                              ? '사용 가능'
                              : '이용권 확인 필요',
                          selected ? accent : Palette.muted,
                        ),
                      ],
                    ),
                    if (entry.premium) ...[
                      const SizedBox(height: 8),
                      const Text(
                        '월·연 구독 포함 · 가격 설정 대기',
                        style: TextStyle(color: Palette.muted, fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton.icon(
                  key: Key('details-${entry.id}'),
                  onPressed: () => _details(entry),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('능력 보기'),
                ),
                OutlinedButton(
                  key: Key('select-${entry.id}'),
                  onPressed:
                      usable &&
                          !selected &&
                          c.selectionsLoaded &&
                          !s.campaign.writeBlocked
                      ? () => c.select(entry)
                      : null,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: selected ? accent : accent.withValues(alpha: .4),
                    ),
                  ),
                  child: Text(
                    selected
                        ? '선택됨'
                        : usable
                        ? '선택하기'
                        : '선택 잠김',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _characterCard(CatalogEntry entry) {
    final s = AppServices.of(context), c = s.loadout;
    final selected = c.isSelected(entry), usable = c.canUse(entry);
    final p = animalPilot(entry.id)!;
    return Container(
      key: Key('character-card-${entry.id}'),
      decoration: BoxDecoration(
        color: selected ? Color(p.color).withValues(alpha: .12) : Palette.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? Color(p.color) : const Color(0xFF344957),
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _details(entry),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        p.portrait,
                        height: 80,
                        cacheWidth: 256,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
                      if (!usable)
                        const Positioned(
                          top: 0,
                          right: 0,
                          child: Icon(
                            Icons.lock,
                            size: 19,
                            color: Palette.muted,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    entry.name,
                    key: Key('catalog-${entry.id}'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.role,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(p.color),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 3,
                    children: [
                      Icon(
                        selected
                            ? Icons.check_circle
                            : usable
                            ? Icons.circle_outlined
                            : Icons.lock_outline,
                        size: 14,
                        color: selected ? Color(p.color) : Palette.muted,
                      ),
                      Text(
                        selected
                            ? '선택됨'
                            : usable
                            ? entry.isPremiumOnly
                                  ? '구독 · 해금'
                                  : '무료'
                            : '구독 · 잠김',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            child: OutlinedButton(
              key: Key('select-${entry.id}'),
              onPressed:
                  usable &&
                      !selected &&
                      c.selectionsLoaded &&
                      !s.campaign.writeBlocked
                  ? () => c.select(entry)
                  : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                minimumSize: const Size(48, 48),
              ),
              child: Text(
                selected
                    ? '선택됨'
                    : usable
                    ? '선택'
                    : '잠김',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedPilot() {
    final c = AppServices.of(context).loadout,
        p = AppServices.of(context).loadout.pilot;
    return Container(
      key: const Key('selectedPilotOverview'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(p.color).withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '선택한 파일럿 · ${p.name}',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          LayoutBuilder(
            builder: (context, bounds) => SizedBox(
              height: bounds.maxWidth < 250 ? 130 : 170,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Image.asset(
                      p.portrait,
                      cacheWidth: 512,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Image.asset(
                      p.hero,
                      cacheWidth: 768,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Badge(p.free ? '무료 캐릭터' : '월·연 구독 캐릭터', Color(p.color)),
              _Badge(
                catalogEntry(c.effectiveSelected(CatalogCategory.aircraft))
                    .name,
                Palette.muted,
              ),
            ],
          ),
          SignatureInfo(p),
          const SizedBox(height: 8),
          Text(
            '조종 팁 · ${pilotTips[p.id]}',
            style: const TextStyle(fontSize: 13, color: Palette.muted),
          ),
          const Text(
            '고유 기술은 구독 스킬에서 선택합니다. 무료 플레이는 기본 사격·보호막을 사용합니다.',
            style: TextStyle(fontSize: 13, color: Palette.muted),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppServices.of(context), c = s.loadout;
    return ListenableBuilder(
      listenable: Listenable.merge([c, s.campaign]),
      builder: (context, _) => AppPage(
        title: '전투기·장비',
        footer: FilledButton.icon(
          key: const Key('launchLoadout'),
          onPressed: _starting || !c.selectionsLoaded ? null : _start,
          icon: _starting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow_rounded),
          label: Text(_starting ? '전투 준비 중' : '선택한 구성으로 시작'),
        ),
        children: [
          const Text(
            '출격 준비',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text('기체와 능력을 고르고 바로 출격하세요. 기본 기체·캐릭터·사격·보호막은 무료입니다.'),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in CatalogCategory.values)
                ChoiceChip(
                  key: Key('category-${category.name}'),
                  label: Text(switch (category) {
                    CatalogCategory.aircraft => '기체',
                    CatalogCategory.skill => '스킬',
                    CatalogCategory.character => '캐릭터',
                    CatalogCategory.equipment => '아이템',
                  }),
                  selected: category == _category,
                  onSelected: (_) => setState(() => _category = category),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_category == CatalogCategory.character)
            _selectedPilot()
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Palette.panel,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Palette.teal.withValues(alpha: .3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '다음 전투에 적용할 선택',
                    style: TextStyle(
                      color: Palette.teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in CatalogCategory.values)
                        _Badge(
                          catalogEntry(c.effectiveSelected(category)).name,
                          catalogAccent(c.effectiveSelected(category)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const LocalSaveStatus(),
                  if (!c.selectionsLoaded) const LinearProgressIndicator(),
                ],
              ),
            ),
          const SizedBox(height: 18),
          const SizedBox(height: 12),
          Text(
            _category == CatalogCategory.skill
                ? '스킬은 전투 중 버튼을 눌러 사용합니다. 사용 후 대기시간이 끝나면 다시 사용할 수 있습니다.'
                : '카드를 누르면 능력과 이용 조건을 자세히 볼 수 있습니다.',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, bounds) {
              final entries = catalogEntries
                  .where((e) => e.category == _category)
                  .toList();
              final textSize = MediaQuery.textScalerOf(context).scale(16);
              final columns = _category == CatalogCategory.character
                  ? bounds.maxWidth >= 300 && textSize <= 20
                        ? 3
                        : bounds.maxWidth >= 230 && textSize <= 27
                        ? 2
                        : 1
                  : 1;
              final two =
                  _category == CatalogCategory.skill &&
                  bounds.maxWidth >= 330 &&
                  MediaQuery.textScalerOf(context).scale(16) < 22;
              return Wrap(
                spacing: 12,
                runSpacing: 14,
                children: [
                  for (final entry in entries)
                    SizedBox(
                      width: _category == CatalogCategory.character
                          ? ((bounds.maxWidth - 12 * (columns - 1)) / columns)
                                .floorToDouble()
                          : two
                          ? (bounds.maxWidth - 12) / 2
                          : bounds.maxWidth,
                      child: _category == CatalogCategory.character
                          ? _characterCard(entry)
                          : _card(entry),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const InfoPanel(
            title: '선택과 이용권',
            body: '선택한 구성은 이 기기에 저장됩니다. 구독 콘텐츠는 검증된 이용 기간에만 적용하며 미확인·만료 시 무료 구성으로 출격합니다. 저장된 선택은 구매 증명이 아닙니다. 현재 스토어·계정 서버는 연결 준비 중입니다.',
          ),
          const RouteTile(title: '조작 방법', route: AppRoutes.controls),
          const RouteTile(title: '환경설정', route: AppRoutes.settings),
        ],
      ),
    );
  }
}

class SignatureInfo extends StatelessWidget {
  const SignatureInfo(this.pilot, {super.key});
  final AnimalPilot pilot;
  @override
  Widget build(BuildContext context) {
    final b = pilot.balance;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${pilot.name} · ${pilot.technique}',
            style: TextStyle(
              color: Color(pilot.color),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Badge(
                '지속 ${b.duration.toStringAsFixed(0)}초',
                Color(pilot.color),
              ),
              _Badge(
                '대기 ${b.cooldown.toStringAsFixed(0)}초',
                Color(pilot.color),
              ),
              _Badge(
                b.budget > 0
                    ? '추가 피해 상한 ${b.budget.toInt()}'
                    : b.count > 0
                    ? '개수 상한 ${b.count}'
                    : '대상 제한 있음',
                Color(pilot.color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pilot.description,
            style: const TextStyle(fontSize: 14, color: Palette.muted),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: .3)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          height: 1.35,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
