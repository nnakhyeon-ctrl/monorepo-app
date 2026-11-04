part of 'engine.dart';

class TrailPoint {
  const TrailPoint(this.position, this.time);
  final Vec position;
  final double time;
}

class SeedBeacon {
  SeedBeacon(this.position, this.expires);
  final Vec position;
  final double expires;
}

class AnimalCombatState {
  final history = <TrailPoint>[];
  final stitch = <Vec>[];
  final beacons = <SeedBeacon>[];
  final links = <(Vec, Vec)>[];
  final captured = <Projectile>[];
  final disrupted = <Enemy>{};
  Vec? anchor;
  Enemy? target;
  double expires = 0, tick = 0, spent = 0, linkExpiry = 0, nextPrecision = 0;
  int durability = 0, precisionShots = 0;
  bool active = false;
  void clear() {
    history.clear();
    stitch.clear();
    beacons.clear();
    links.clear();
    captured.clear();
    disrupted.clear();
    anchor = null;
    target = null;
    expires = tick = spent = linkExpiry = nextPrecision = 0;
    durability = precisionShots = 0;
    active = false;
  }
}

double _segmentDistance(Vec p, Vec a, Vec b) {
  final d = b - a, length = d.dx * d.dx + d.dy * d.dy;
  if (length < .001) return (p - a).distance;
  final t = (((p - a).dx * d.dx + (p - a).dy * d.dy) / length).clamp(0.0, 1.0);
  return (p - (a + d * t)).distance;
}

extension AnimalTechniques on BattleEngine {
  bool _animalTargetAllowed(Enemy e) => switch (pilot.target) {
    TechniqueTarget.normalEnemies => e.kind != EnemyKind.boss,
    TechniqueTarget.armoredAim => e.kind == EnemyKind.armored,
    _ => true,
  };
  bool get animalActive => skill == 'signature' && animal.active && health > 0;
  void _activateAnimal() {
    final b = pilot.balance;
    animal.active = true;
    animal.expires = elapsed + b.duration;
    animal.tick = 0;
    animal.spent = 0;
    animal.anchor = player;
    animal.captured.clear();
    animal.links.clear();
    animal.disrupted.clear();
    animal.precisionShots = 0;
    animal.nextPrecision = elapsed + b.range;
    animal.durability = b.count;
    skillRemaining = b.duration;
    animal.stitch
      ..clear()
      ..addAll(
        animal.history
            .where((p) => elapsed - p.time <= b.range)
            .map((p) => p.position),
      );
    if (character == 'tw_squirrel') {
      if (animal.beacons.length >= b.count) animal.beacons.removeAt(0);
      animal.beacons.add(SeedBeacon(player, elapsed + b.duration));
    }
    if (character == 'tw_owl') {
      final candidates = enemies
          .where(
            (e) =>
                e.health > 0 &&
                _animalTargetAllowed(e) &&
                e.position.dy >= 0 &&
                e.position.dy < BattleEngine.height,
          )
          .toList();
      int priority(Enemy e) => switch (e.kind) {
        EnemyKind.boss => 3,
        EnemyKind.armored => 2,
        _ => 1,
      };
      candidates.sort((a, b) {
        final rank = priority(b).compareTo(priority(a));
        return rank != 0
            ? rank
            : (a.position - player).distance.compareTo(
                (b.position - player).distance,
              );
      });
      animal.target = candidates.isEmpty ? null : candidates.first;
      animal.precisionShots = 0;
      animal.nextPrecision = elapsed + b.range;
    }
  }

  void _tickAnimal(double dt) {
    // Bounded path independent of render frame rate, no persistence/upload.
    if (animal.history.isEmpty || elapsed - animal.history.last.time >= .12) {
      animal.history.add(TrailPoint(player, elapsed));
      if (animal.history.length > 8) animal.history.removeAt(0);
    }
    if (health <= 0) {
      animal.clear();
      skillRemaining = 0;
      return;
    }
    if (elapsed >= animal.linkExpiry) animal.links.clear();
    if (animal.active && elapsed >= animal.expires) {
      if (character == 'tw_bear' && skill == 'signature') {
        final count = animal.captured.length;
        for (var i = 0; i < count; i++) {
          bullets.add(
            Projectile(
              player + Vec((i - (count - 1) / 2) * 8, -24),
              const Vec(0, -390),
              damage: pilot.balance.damage,
              friendly: true,
              precision: true,
            ),
          );
        }
      }
      animal.active = false;
      animal.captured.clear();
      animal.target = null;
      animal.stitch.clear();
      animal.anchor = null;
      animal.durability = 0;
      animal.disrupted.clear();
    }
    final b = pilot.balance;
    if (character == 'tw_squirrel' && skill == 'signature') {
      for (final beacon in List<SeedBeacon>.of(animal.beacons)) {
        if (elapsed >= beacon.expires) {
          animal.beacons.remove(beacon);
          continue;
        }
        if (enemies.any(
          (e) =>
              e.health > 0 &&
              (e.position - beacon.position).distance <= b.range,
        )) {
          var hits = 0;
          for (final enemy in enemies) {
            if (enemy.health > 0 &&
                _animalTargetAllowed(enemy) &&
                (enemy.position - beacon.position).distance <= b.radius &&
                hits < b.maxTargets) {
              enemy.health -= b.damage;
              hits++;
            }
          }
          _effect(beacon.position, EffectKind.explosion, size: b.radius * 2);
          animal.beacons.remove(beacon);
        }
      }
    }
    if (!animalActive) return;
    if (character == 'tw_eagle' &&
        animal.precisionShots == 0 &&
        elapsed >= animal.nextPrecision) {
      final origin = animal.anchor ?? player;
      for (var i = 0; i < b.count; i++) {
        bullets.add(
          Projectile(
            origin + Vec((i - (b.count - 1) / 2) * b.width / b.count, -28),
            const Vec(0, -460),
            damage: b.damage,
            friendly: true,
            precision: true,
          ),
        );
      }
      animal.precisionShots = b.count;
    }
    if (character == 'tw_owl') {
      final target = animal.target;
      if (target != null &&
          enemies.contains(target) &&
          target.health > 0 &&
          animal.precisionShots < b.count &&
          elapsed >= animal.nextPrecision) {
        final d = target.position - player, length = math.max(1, d.distance);
        bullets.add(
          Projectile(
            player + const Vec(0, -24),
            d * (480 / length),
            damage: b.damage,
            friendly: true,
            precision: true,
          ),
        );
        animal.precisionShots++;
        animal.nextPrecision = elapsed + b.interval;
      }
    }
    animal.tick -= dt;
    if (animal.tick > 0) return;
    animal.tick += b.interval;
    for (final enemy in enemies) {
      if (enemy.health <= 0 || !_animalTargetAllowed(enemy)) continue;
      if (character == 'tw_volt' &&
          animal.disrupted.length < b.count &&
          !animal.disrupted.contains(enemy) &&
          (enemy.position - player).distance <= b.radius) {
        animal.disrupted.add(enemy);
        enemy.fireClock = math.max(0, enemy.fireClock - b.range);
        enemy.health -= b.damage;
        animal.spent += b.damage;
        if (animal.links.length >= 12) animal.links.removeAt(0);
        animal.links.add((player, enemy.position));
        animal.linkExpiry = elapsed + .18;
      }
      final inRange = character == 'tw_hedgehog'
          ? (enemy.position - player).distance <= b.radius
          : character == 'pilot' &&
                animal.stitch.length > 1 &&
                [
                  for (var i = 1; i < animal.stitch.length; i++)
                    _segmentDistance(
                      enemy.position,
                      animal.stitch[i - 1],
                      animal.stitch[i],
                    ),
                ].any((d) => d <= b.radius + enemy.radius);
      if (inRange && animal.spent < b.budget) {
        final damage = math.min(b.damage, b.budget - animal.spent);
        enemy.health -= damage;
        animal.spent += damage;
        _effect(enemy.position, EffectKind.hit);
      }
    }
  }

  void _interceptAnimal(Set<Projectile> consumed) {
    if (!animalActive || pilot.target != TechniqueTarget.ordinaryProjectiles) {
      return;
    }
    final b = pilot.balance;
    for (final bullet in bullets) {
      if (bullet.friendly || !bullet.collectible) continue;
      final relative = bullet.position - player;
      final pocket =
          character == 'tw_bear' &&
          relative.distance <= b.radius &&
          animal.captured.length < b.count;
      final deck =
          character == 'eden' &&
          animal.durability > 0 &&
          relative.dy <= -b.minimumRange &&
          relative.dy >= -b.range &&
          relative.dx.abs() <= b.width / 2 &&
          bullet.velocity.dy >= 0;
      if (pocket || deck) {
        consumed.add(bullet);
        if (pocket) {
          animal.captured.add(bullet);
        } else {
          animal.durability--;
        }
        _effect(bullet.position, EffectKind.shieldHit, size: 12);
      }
    }
  }

  void _relayAnimal(Enemy hit, Projectile bullet) {
    if (!animalActive || character != 'tw_otter' || bullet.precision) return;
    final b = pilot.balance;
    final visited = <Enemy>{hit};
    var previous = hit;
    for (var i = 0; i < b.count; i++) {
      final choices =
          enemies
              .where(
                (e) =>
                    e.health > 0 &&
                    _animalTargetAllowed(e) &&
                    !visited.contains(e) &&
                    (e.position - previous.position).distance <= b.radius,
              )
              .toList()
            ..sort(
              (a, c) => (a.position - previous.position).distance.compareTo(
                (c.position - previous.position).distance,
              ),
            );
      if (choices.isEmpty || animal.spent >= b.budget) break;
      final next = choices.first,
          damage = math.min(
            math.max(0, b.damage - i * b.damageFalloff),
            b.budget - animal.spent,
          );
      next.health -= damage;
      animal.spent += damage;
      visited.add(next);
      if (animal.links.length >= 12) animal.links.removeAt(0);
      animal.links.add((previous.position, next.position));
      animal.linkExpiry = elapsed + .18;
      previous = next;
    }
  }
}
