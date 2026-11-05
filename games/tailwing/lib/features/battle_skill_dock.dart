import 'package:flutter/material.dart';

import '../core/design.dart';
import '../game/catalog.dart';
import '../game/engine.dart';
import '../game/advanced_skill_catalog.dart';

class BattleSkillDock extends StatelessWidget {
  const BattleSkillDock(
    this.game, {
    required this.onSkill,
    required this.onShield,
    super.key,
  });
  final BattleEngine game;
  final VoidCallback onSkill, onShield;
  @override
  Widget build(BuildContext context) {
    final g = game;
    final selected = g.skill != 'barrier';
    final spec = advancedSkillSpecs[g.skill];
    final charging =
        selected &&
        spec != null &&
        spec.charge > 0 &&
        g.advanced.phase == SkillStage.charging;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, size) {
              final cards = [
                _SkillCard(
                  actionKey: selected
                      ? const Key('basicShield')
                      : const Key('useSkill'),
                  name: '기본 보호막',
                  icon: Icons.shield_outlined,
                  hint: g.protected
                      ? '${g.shieldRemaining.toStringAsFixed(1)}초 방어 중'
                      : g.basicShieldCooldown > 0
                      ? '${g.basicShieldCooldown.ceil()}초 후'
                      : '방어 준비 · Z',
                  progress:
                      g.basicShieldCooldown / g.basicShieldRechargeDuration,
                  enabled:
                      g.basicShieldCooldown <= 0 &&
                      g.phase == BattlePhase.playing,
                  onTap: onShield,
                ),
                _SkillCard(
                  actionKey: selected
                      ? const Key('useSkill')
                      : const Key('automaticFire'),
                  name: selected
                      ? (g.skill == 'signature'
                            ? g.pilot.technique
                            : catalogEntry(g.skill).name)
                      : '기본 사격',
                  icon: selected
                      ? catalogEntry(g.skill).icon
                      : Icons.double_arrow,
                  hint: !selected
                      ? '자동 발사'
                      : charging
                      ? '차지 ${g.advanced.chargeRemaining.toStringAsFixed(1)}초'
                      : g.skillRemaining > 0
                      ? '${g.skillRemaining.toStringAsFixed(1)}초 작동'
                      : g.cooldown > 0
                      ? '${g.cooldown.ceil()}초 후'
                      : '발사 준비 · SPACE',
                  progress: !selected
                      ? 0
                      : charging
                      ? g.advanced.chargeRemaining / spec.charge
                      : g.cooldown / g.skillRechargeDuration,
                  enabled:
                      selected &&
                      g.cooldown <= 0 &&
                      g.phase == BattlePhase.playing,
                  onTap: onSkill,
                  automatic: !selected,
                ),
              ];
              final vertical =
                  size.maxWidth < 260 ||
                  MediaQuery.textScalerOf(context).scale(14) > 23;
              return vertical
                  ? Column(
                      children: [cards[0], const SizedBox(height: 6), cards[1]],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 8),
                        Expanded(child: cards[1]),
                      ],
                    );
            },
          ),
          const SizedBox(height: 5),
          const Text(
            '드래그 이동 · 자동 사격 · 흰 점이 피격 위치',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Palette.muted),
          ),
        ],
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.actionKey,
    required this.name,
    required this.icon,
    required this.hint,
    required this.progress,
    required this.enabled,
    required this.onTap,
    this.automatic = false,
  });
  final Key actionKey;
  final String name, hint;
  final IconData icon;
  final double progress;
  final bool enabled, automatic;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: !automatic,
    enabled: enabled || automatic,
    label: '$name, $hint',
    child: Material(
      color: const Color(0xFF122332),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: actionKey,
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (enabled || automatic ? Palette.teal : Palette.muted)
                  .withValues(alpha: .55),
            ),
            boxShadow: [
              if (enabled)
                BoxShadow(
                  color: Palette.teal.withValues(alpha: .08),
                  blurRadius: 10,
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          icon,
                          size: 20,
                          color: enabled || automatic
                              ? Palette.teal
                              : Palette.muted,
                        ),
                        if (progress > 0)
                          Positioned.fill(
                            child: CircularProgressIndicator(
                              value: progress.clamp(0, 1),
                              strokeWidth: 2,
                              color: const Color(0xFFB9B1FF),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                hint,
                style: TextStyle(
                  fontSize: 12,
                  color: enabled || automatic ? Palette.teal : Palette.muted,
                ),
              ),
              const SizedBox(height: 5),
              LinearProgressIndicator(
                value: (1 - progress).clamp(0, 1),
                minHeight: 2,
                color: Palette.teal,
                backgroundColor: const Color(0xFF293D4B),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
