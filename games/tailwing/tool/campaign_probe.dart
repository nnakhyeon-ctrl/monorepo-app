import 'dart:math' as math;
import 'dart:io';
import 'dart:convert';

import 'package:raikeopeu2026/game/combat_model.dart';
import 'package:raikeopeu2026/game/engine.dart';
import 'package:raikeopeu2026/game/stages.dart';

/// Repeatable free-kit playability probe; not a substitute for human playtests.
Map<String, Object> probe(StageDefinition stage, {int? seed}) {
  final game = BattleEngine(const FreeLoadout(), stage: stage, seed: seed);
  var frames = 0, peakBullets = 0, peakEffects = 0;
  final damageEvents = <Map<String, Object>>[];
  while (game.phase == BattlePhase.playing && frames < 18001) {
    if (frames % 3 == 0) {
      var bestX = game.player.dx, bestCost = double.infinity;
      final target =
          game.enemies
              .where((e) => e.health > 0 && e.position.dy < 350)
              .toList()
            ..sort((a, b) => b.position.dy.compareTo(a.position.dy));
      final targetX = target.isEmpty ? 180.0 : target.first.position.dx;
      for (var x = 25.0; x <= 335; x += 10) {
        var cost = (x - targetX).abs() * .6 + (x - game.player.dx).abs() * .2;
        for (final bullet in game.bullets.where((b) => !b.friendly)) {
          for (final t in [.1, .25, .5, .8]) {
            final futureX =
                game.player.dx + (x - game.player.dx).clamp(-240 * t, 240 * t);
            var predicted = bullet.position + bullet.velocity * t;
            if (bullet.homing && bullet.steeringRemaining > 0) {
              final theta = math.atan2(bullet.velocity.dy, bullet.velocity.dx);
              final desired = math.atan2(
                510 - bullet.position.dy,
                futureX - bullet.position.dx,
              );
              final diff = math.atan2(
                math.sin(desired - theta),
                math.cos(desired - theta),
              );
              final turnTime = math.min(t, bullet.steeringRemaining);
              final omega = (diff / turnTime).clamp(-.65, .65);
              if (omega.abs() > .001) {
                final angle = theta + omega * turnTime,
                    speed = bullet.velocity.distance;
                predicted =
                    bullet.position +
                    Vec(
                          math.sin(angle) - math.sin(theta),
                          math.cos(theta) - math.cos(angle),
                        ) *
                        (speed / omega) +
                    Vec(math.cos(angle), math.sin(angle)) *
                        (speed * (t - turnTime));
              }
            }
            final distance = (predicted - Vec(futureX, 510)).distance;
            cost += 2000 / (1 + math.pow(distance / 16, 2));
          }
        }
        for (final enemy in game.enemies) {
          if (enemy.kind == EnemyKind.charger && enemy.fireClock >= 1.2) {
            for (final t in [.15, .35, .65, 1.0]) {
              final travel =
                  math.max(0.0, enemy.fireClock + t - 2.1) -
                  math.max(0.0, enemy.fireClock - 2.1);
              final at =
                  enemy.position +
                  Vec(math.sin(enemy.aim), math.cos(enemy.aim)) *
                      (190 * travel);
              final futureX =
                  game.player.dx +
                  (x - game.player.dx).clamp(-240 * t, 240 * t);
              cost +=
                  8000 /
                  (1 + math.pow((at - Vec(futureX, 510)).distance / 24, 2));
            }
          }
          if (enemy.kind == EnemyKind.sentinel &&
              (enemy.laserWarning || enemy.laserActive)) {
            for (final t in [.15, .4, .8]) {
              final angle = (enemy.age + t) * .55;
              final delta = Vec(x, 510) - enemy.position;
              final direction = Vec(math.sin(angle), math.cos(angle));
              final dot = delta.dx * direction.dx + delta.dy * direction.dy;
              if (dot > 0) {
                final distance = (delta - direction * dot).distance;
                cost += 9000 / (1 + math.pow(distance / 24, 2));
              }
            }
          }
          if (enemy.position.dy > 410) {
            cost += 5000 / (1 + math.pow((x - enemy.position.dx) / 50, 2));
          }
        }
        if (cost < bestCost) {
          bestCost = cost;
          bestX = x;
        }
      }
      game.moveBy(Vec((bestX - game.player.dx).clamp(-12, 12).toDouble(), 0));
      if (game.bullets.any(
        (b) => !b.friendly && (b.position - game.player).distance < 75,
      )) {
        game.activateSkill();
      }
    }
    final hp = game.health;
    game.step(1 / 60);
    if (game.health < hp) {
      damageEvents.add({
        'time': game.elapsed.round(),
        'x': game.player.dx.round(),
        'near': game.enemies
            .where((e) => (e.position - game.player).distance < 100)
            .map((e) => e.kind.name)
            .join(','),
      });
    }
    peakBullets = math.max(peakBullets, game.bullets.length);
    peakEffects = math.max(peakEffects, game.effects.length);
    frames++;
  }
  return {
    'stage': stage.number,
    'result': game.phase.name,
    'seconds': game.elapsed.round(),
    'health': game.health,
    'score': game.score,
    'peakProjectiles': peakBullets,
    'damageEvents': damageEvents,
    'peakEffects': peakEffects,
    'projectileAllocations': game.projectilePool.allocations,
    'projectileReuses': game.projectilePool.reuses,
    'retainedProjectiles': game.projectilePool.retained,
  };
}

void main() {
  for (final stage in stages) {
    stdout.writeln(jsonEncode(probe(stage)));
  }
}
