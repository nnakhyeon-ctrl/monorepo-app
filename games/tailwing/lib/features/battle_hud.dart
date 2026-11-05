import 'package:flutter/material.dart';

import '../core/design.dart';
import '../game/catalog.dart';
import '../game/engine.dart';
import '../game/deck_status.dart';
import '../game/battle_pacing.dart';

class BattleHud extends StatelessWidget {
  const BattleHud(this.game, {super.key});
  final BattleEngine game;

  @override
  Widget build(BuildContext context) {
    final g = game;
    final deck = DeckStatus.read(g);
    final pacing = BattlePacing.read(g);
    final boss = g.enemies.where((e) => e.kind == EnemyKind.boss).firstOrNull;
    return Container(
      key: const Key('battleHud'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF142B3B), Color(0xFF101827)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.teal.withValues(alpha: .3)),
        boxShadow: [
          BoxShadow(color: Palette.teal.withValues(alpha: .06), blurRadius: 14),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          color: Color(0xFFF1F6F9),
          fontSize: 15,
          height: 1.35,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 3,
              children: [
                Text(
                  pacing.label,
                  key: const Key('battleChapter'),
                  style: const TextStyle(
                    color: Palette.teal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  pacing.hint,
                  style: const TextStyle(fontSize: 12, color: Palette.muted),
                ),
              ],
            ),
            const SizedBox(height: 5),
            LinearProgressIndicator(
              value: pacing.progress,
              minHeight: 2,
              color: const Color(0xFFB9B1FF),
              backgroundColor: const Color(0xFF293D4B),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        '장갑 ${g.health}/${g.maxHealth}',
                        key: const Key('battleHealth'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                Text(
                  '점수 ${g.score}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '격추 ${g.defeated}',
                  style: const TextStyle(color: Palette.muted),
                ),
                Text(
                  '${g.elapsed ~/ 60}:${(g.elapsed.toInt() % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Palette.muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Semantics(
              label: '남은 장갑 ${g.health}, 최대 ${g.maxHealth}',
              child: Wrap(
                key: const Key('healthIcons'),
                spacing: 4,
                children: [
                  for (var i = 0; i < g.maxHealth; i++)
                    Icon(
                      i < g.health ? Icons.favorite : Icons.favorite_border,
                      size: 14,
                      color: i < g.health ? Palette.teal : Palette.muted,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (g.health / g.maxHealth).clamp(0, 1),
                minHeight: 4,
                color: g.health <= 1 ? const Color(0xFFFFA380) : Palette.teal,
                backgroundColor: const Color(0xFF293D4B),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                Text(
                  '보호막 ${g.shieldRemaining.toStringAsFixed(1)}초',
                  key: const Key('shieldTime'),
                  style: TextStyle(
                    color: g.protected ? Palette.teal : Palette.muted,
                  ),
                ),
                if (deck == null)
                  Text(
                    g.advanced.phase == SkillStage.charging
                        ? '${catalogEntry(g.skill).name} 차지 ${g.advanced.chargeRemaining.toStringAsFixed(1)}초'
                        : g.skillRemaining > 0
                        ? '${g.skill == 'signature' ? g.pilot.technique : catalogEntry(g.skill).name} ${g.skillRemaining.toStringAsFixed(1)}초'
                        : g.cooldown > 0
                        ? '스킬 ${g.cooldown.ceil()}초 후 준비'
                        : '스킬 준비 완료',
                    style: TextStyle(
                      color: g.cooldown > 0 ? Palette.muted : Palette.teal,
                    ),
                  ),
                if (g.skill == 'absorb' &&
                    g.advanced.phase == SkillStage.active)
                  Text(
                    '흡수 에너지 ${g.advanced.energy.toInt()}/60',
                    key: const Key('absorbEnergy'),
                  ),
                if (g.repairNotice > 0)
                  const Text(
                    '구간 정비 · 장갑 +1',
                    style: TextStyle(color: Palette.teal),
                  ),
              ],
            ),
            if (deck != null) ...[
              const SizedBox(height: 6),
              Wrap(
                key: const Key('deckStatus'),
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(
                    deck.blocking ? Icons.shield : Icons.shield_outlined,
                    size: 18,
                    color: deck.blocking ? Palette.teal : Palette.muted,
                  ),
                  Text(
                    deck.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: deck.blocking ? Palette.teal : Palette.muted,
                    ),
                  ),
                  if (deck.blocking)
                    Text(
                      '${deck.seconds.toStringAsFixed(1)}초 · 차단 ${deck.remaining}/${deck.capacity}',
                    ),
                  if (!deck.blocking && g.cooldown > 0)
                    Text('${g.cooldown.ceil()}초 후 준비'),
                ],
              ),
              if (deck.blocking) ...[
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: deck.seconds / g.pilot.balance.duration,
                  minHeight: 3,
                  color: Palette.teal,
                  backgroundColor: const Color(0xFF293D4B),
                ),
              ],
            ],
            if (boss != null) ...[
              const SizedBox(height: 8),
              Text(
                '${g.stage.bossName} · ${(boss.health / g.stage.bossHealth * 100).ceil().clamp(0, 100)}%',
                style: const TextStyle(
                  color: Color(0xFFFFB88D),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'PHASE ${boss.bossPhase(g.stage.bossHealth)} · 날개 모듈 ${boss.parts.where((hp) => hp > 0).length}/2',
                style: const TextStyle(fontSize: 12, color: Palette.muted),
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: (boss.health / g.stage.bossHealth).clamp(0, 1),
                minHeight: 3,
                color: const Color(0xFFFFA380),
                backgroundColor: const Color(0xFF352A30),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
