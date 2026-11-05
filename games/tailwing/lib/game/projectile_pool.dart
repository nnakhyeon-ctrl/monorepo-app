part of 'engine.dart';

/// Released rounds have one owner even when transferred to a co-op world.
/// Capacity bounds retained memory, never drops a live shot or changes damage.
class ProjectilePool {
  ProjectilePool({this.capacity = 256});
  final int capacity;
  final _available = <Projectile>[];
  int allocations = 0, reuses = 0;
  int get retained => _available.length;
  Projectile acquire(
    Vec position,
    Vec velocity, {
    double damage = 10,
    bool friendly = false,
    bool collectible = true,
    bool precision = false,
    bool homing = false,
    bool baseShot = false,
  }) {
    final Projectile bullet;
    if (_available.isEmpty) {
      allocations++;
      bullet = Projectile(position, velocity);
    } else {
      reuses++;
      bullet = _available.removeLast();
    }
    bullet
      ..position = position
      ..velocity = velocity
      ..damage = damage
      ..friendly = friendly
      ..collectible = collectible
      ..precision = precision
      ..homing = homing
      ..baseShot = baseShot
      ..steeringRemaining = friendly ? 3 : 1.2
      .._owner = this
      .._leased = true;
    return bullet;
  }

  void release(Projectile bullet) {
    if (!identical(bullet._owner, this) || !bullet._leased) return;
    bullet._leased = false;
    if (_available.length < capacity) _available.add(bullet);
  }
}

extension GuidedProjectiles on BattleEngine {
  void _steerProjectile(Projectile b, double dt) {
    Vec target = player;
    if (b.friendly) {
      Enemy? nearest;
      var distance = double.infinity;
      for (final e in enemies) {
        final d = (e.position - b.position).distance;
        if (e.health > 0 && e.position.dy >= 0 && d < distance) {
          distance = d;
          nearest = e;
        }
      }
      if (nearest == null) return;
      target = nearest.position;
    } else {
      final second = partner;
      if (second != null &&
          second.health > 0 &&
          (health <= 0 ||
              (second.player - b.position).distance <
                  (player - b.position).distance)) {
        target = second.player;
      } else if (health <= 0) {
        return; // No live target: keep the last velocity until cleanup.
      }
    }
    final speed = b.velocity.distance;
    final direction = target - b.position;
    final current = math.atan2(b.velocity.dy, b.velocity.dx);
    final desired = math.atan2(direction.dy, direction.dx);
    final difference = math.atan2(
      math.sin(desired - current),
      math.cos(desired - current),
    );
    final rate = b.friendly ? 3.0 * (equipment == 'gyro' ? 1.3 : 1) : .65;
    final angle = current + difference.clamp(-rate * dt, rate * dt);
    b.velocity = Vec(math.cos(angle) * speed, math.sin(angle) * speed);
  }
}
