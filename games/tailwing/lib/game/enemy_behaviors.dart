part of 'engine.dart';

/// Strategies own movement/attack; common engine owns collisions and rewards.
abstract class EnemyBehavior {
  const EnemyBehavior();
  void tick(
    BattleEngine game,
    Enemy enemy,
    double dt, {
    double movementFactor = 1,
  });
}

class InterceptorBehavior extends EnemyBehavior {
  const InterceptorBehavior();
  @override
  void tick(BattleEngine g, Enemy e, double dt, {double movementFactor = 1}) {
    e.position += Vec(math.sin(e.age * 2) * 30 * dt, 38 * dt) * movementFactor;
    e.fireClock += dt;
    e.telegraph = e.fireClock >= 2.2;
    if (e.position.dy <= 0 || e.position.dy > 340 || e.fireClock < 2.8) return;
    e.fireClock = 0;
    e.telegraph = false;
    g.bullets.add(
      g.projectilePool.acquire(
        e.position,
        Vec(0, g.stage.bulletSpeed),
        homing: true,
      ),
    );
  }
}

class ChargerBehavior extends EnemyBehavior {
  const ChargerBehavior();
  @override
  void tick(BattleEngine g, Enemy e, double dt, {double movementFactor = 1}) {
    e.fireClock += dt;
    if (e.fireClock < 1.2) {
      e.position += Vec(0, 55 * dt * movementFactor);
    } else if (e.fireClock < 2.1) {
      e.telegraph = true;
      final survivor = g.partner;
      e.lockedTarget ??=
          g.health <= 0 && survivor != null && survivor.health > 0
          ? survivor.player
          : g.player;
      final d = e.lockedTarget! - e.position;
      e.aim = math.atan2(d.dx, d.dy);
    } else {
      e.telegraph = false;
      e.position +=
          Vec(math.sin(e.aim) * 190 * dt, math.cos(e.aim) * 190 * dt) *
          movementFactor;
    }
  }
}

class SentinelBehavior extends EnemyBehavior {
  const SentinelBehavior();
  @override
  void tick(BattleEngine g, Enemy e, double dt, {double movementFactor = 1}) {
    if (dt == 0) return;
    if (e.position.dy < 125) e.position += Vec(0, 38 * dt * movementFactor);
    final cycle = e.age % 6;
    if (cycle < dt && e.age > 1) e.shield = 30;
    e.laserAngle = e.age * .55;
    if (e.laserActive && e.position.dy > 0) {
      final d = Vec(math.sin(e.laserAngle), math.cos(e.laserAngle));
      final end = e.position + d * 700;
      if (_segmentDistance(g.player, e.position, end) < 10) g._damagePlayer();
      final partner = g.partner;
      if (partner != null &&
          _segmentDistance(partner.player, e.position, end) < 10) {
        partner._damagePlayer();
      }
    }
  }
}

const enemyBehaviors = <EnemyKind, EnemyBehavior>{
  EnemyKind.interceptor: InterceptorBehavior(),
  EnemyKind.charger: ChargerBehavior(),
  EnemyKind.sentinel: SentinelBehavior(),
};
