part of 'engine.dart';

enum SkillStage { idle, charging, active }

class AdvancedSkillState {
  SkillStage phase = SkillStage.idle;
  double chargeRemaining = 0, remaining = 0, energy = 0, freeze = 0, clock = 0;
  int emitted = 0;
  Vec anchor = Vec.zero;
  final links = <(Vec, Vec)>[];
  final tethered = <Enemy>[];
  void clear() {
    phase = SkillStage.idle;
    chargeRemaining = remaining = energy = freeze = clock = 0;
    emitted = 0;
    links.clear();
    tethered.clear();
    anchor = Vec.zero;
  }
}

/// A new skill supplies a spec and strategy; engine/input/HUD need no new cases.
abstract class AdvancedSkillStrategy {
  const AdvancedSkillStrategy(this.id);
  final String id;
  AdvancedSkillSpec get spec => advancedSkillSpecs[id]!;
  void activate(BattleEngine g) {
    g.advanced.clear();
    final a = g.advanced;
    a.anchor = Vec(g.player.dx, math.max(75, g.player.dy - 140));
    a.chargeRemaining = spec.charge;
    a.phase = spec.charge > 0 ? SkillStage.charging : SkillStage.active;
    if (spec.charge == 0) _fire(g);
  }

  void _fire(BattleEngine g) {
    g.advanced.phase = SkillStage.active;
    g.advanced.remaining = spec.duration;
    g.skillRemaining = spec.duration;
    g._effect(g.player, EffectKind.skill, size: 45);
    onFire(g);
  }

  void tick(BattleEngine g, double dt) {
    final a = g.advanced;
    a.freeze = math.max(0, a.freeze - dt);
    if (g.health <= 0) {
      a.clear();
      return;
    }
    if (a.phase == SkillStage.charging) {
      a.chargeRemaining = math.max(0, a.chargeRemaining - dt);
      if (a.chargeRemaining == 0) _fire(g);
      return;
    }
    if (a.phase != SkillStage.active) return;
    final activeDt = math.min(dt, a.remaining);
    onTick(g, activeDt);
    a.remaining = math.max(0, a.remaining - dt);
    g.skillRemaining = a.remaining;
    if (a.remaining == 0) {
      onEnd(g);
      a.phase = SkillStage.idle;
      a.links.clear();
      a.tethered.clear();
    }
  }

  void onFire(BattleEngine g) {}
  void onTick(BattleEngine g, double dt) {}
  void onEnd(BattleEngine g) {}
  double movementFactor(BattleEngine g, Enemy enemy) => 1;
}

class MissileStormStrategy extends AdvancedSkillStrategy {
  const MissileStormStrategy() : super('missile_storm');
  @override
  void onFire(BattleEngine g) => g.advanced.freeze = .5;
  @override
  void onTick(BattleEngine g, double dt) {
    final a = g.advanced;
    a.clock -= dt;
    if (a.emitted >= 6 || a.clock > 0) return;
    a.clock += .16;
    final side = a.emitted.isEven ? -1 : 1;
    g.bullets.add(
      g.projectilePool.acquire(
        g.player + Vec(side * 20.0, -20),
        Vec(side * 90.0, -300),
        friendly: true,
        damage: 20,
        homing: true,
        precision: true,
      ),
    );
    a.emitted++;
  }
}

class BeamStrategy extends AdvancedSkillStrategy {
  const BeamStrategy() : super('beam');
  @override
  void onTick(BattleEngine g, double dt) {
    for (final e in g.enemies) {
      if (e.health > 0 &&
          e.position.dy >= 0 &&
          e.position.dy < g.player.dy - 24 &&
          (e.position.dx - g.player.dx).abs() <= 9 + e.radius) {
        g.damageEnemy(e, 30 * dt);
      }
    }
  }
}

class AbsorbStrategy extends AdvancedSkillStrategy {
  const AbsorbStrategy() : super('absorb');
  @override
  void onEnd(BattleEngine g) {
    for (var i = 0; i < 6; i++) {
      final angle = (i - 2.5) * .22;
      g.bullets.add(
        g.projectilePool.acquire(
          g.player + const Vec(0, -24),
          Vec(math.sin(angle) * 420, -math.cos(angle) * 420),
          friendly: true,
          precision: true,
          damage: 5 + g.advanced.energy / 6,
        ),
      );
    }
    g._effect(g.player, EffectKind.pulse, size: 110);
  }
}

class BlackholeStrategy extends AdvancedSkillStrategy {
  const BlackholeStrategy() : super('blackhole');
  @override
  void onTick(BattleEngine g, double dt) {
    for (final e in g.enemies) {
      final delta = g.advanced.anchor - e.position, length = delta.distance;
      if (e.health <= 0 || length > 100 || e.position.dy < 0) continue;
      if (e.kind != EnemyKind.boss && length > 1) {
        e.position += delta * (math.min(length, 80 * dt) / length);
      }
      g.damageEnemy(e, 12 * dt);
    }
  }
}

class EmpStrategy extends AdvancedSkillStrategy {
  const EmpStrategy() : super('emp');
  @override
  double movementFactor(BattleEngine g, Enemy enemy) =>
      g.advanced.phase == SkillStage.active &&
          (enemy.position - g.advanced.anchor).distance <= 120
      ? .2
      : 1;
}

class ChainStrategy extends AdvancedSkillStrategy {
  const ChainStrategy() : super('chain');
  @override
  void onFire(BattleEngine g) {
    final hit = <Enemy>{};
    var previous = g.player;
    for (var i = 0; i < 5; i++) {
      Enemy? next;
      var closest = i == 0 ? 320.0 : 115.0;
      for (final e in g.enemies) {
        final d = (e.position - previous).distance;
        if (e.health > 0 &&
            e.position.dy >= 0 &&
            !hit.contains(e) &&
            (i > 0 || e.position.dy < g.player.dy) &&
            d <= closest) {
          next = e;
          closest = d;
        }
      }
      if (next == null) break;
      g.advanced.links.add((previous, next.position));
      g.damageEnemy(next, 34, allowSharing: false);
      hit.add(next);
      previous = next.position;
    }
    g.advanced.tethered.addAll(hit);
  }

  @override
  void onTick(BattleEngine g, double dt) {
    final a = g.advanced;
    a.tethered.removeWhere((e) => e.health <= 0 || !g.enemies.contains(e));
    a.links.clear();
    var previous = g.player;
    for (final e in a.tethered) {
      a.links.add((previous, e.position));
      previous = e.position;
    }
  }
}

const advancedSkillStrategies = <String, AdvancedSkillStrategy>{
  'missile_storm': MissileStormStrategy(),
  'beam': BeamStrategy(),
  'absorb': AbsorbStrategy(),
  'blackhole': BlackholeStrategy(),
  'emp': EmpStrategy(),
  'chain': ChainStrategy(),
};

extension Absorption on BattleEngine {
  bool _absorbProjectile(Projectile b) {
    if (b.friendly ||
        skill != 'absorb' ||
        advanced.phase != SkillStage.active ||
        (b.position - player).distance > 50) {
      return false;
    }
    advanced.energy = math.min(60, advanced.energy + b.damage);
    _effect(b.position, EffectKind.shieldHit, size: 16);
    return true;
  }
}
