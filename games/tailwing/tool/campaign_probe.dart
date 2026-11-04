import 'dart:math' as math;
import 'dart:io';

import 'package:raikeopeu2026/game/combat_model.dart';
import 'package:raikeopeu2026/game/engine.dart';
import 'package:raikeopeu2026/game/stages.dart';

/// Repeatable free-kit playability probe; not a substitute for human playtests.
Map<String, Object> probe(StageDefinition stage, {int? seed}) {
  final game = BattleEngine(const FreeLoadout(), stage: stage, seed: seed);
  var frames = 0, peakBullets = 0;
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
        var cost = (x - targetX).abs() * .1 + (x - game.player.dx).abs() * .2;
        for (final bullet in game.bullets.where((b) => !b.friendly)) {
          for (final t in [.1, .25, .5, .8]) {
            final futureX =
                game.player.dx + (x - game.player.dx).clamp(-240 * t, 240 * t);
            final distance =
                (bullet.position + bullet.velocity * t - Vec(futureX, 510))
                    .distance;
            cost += 2000 / (1 + math.pow(distance / 16, 2));
          }
        }
        for (final enemy in game.enemies) {
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
    game.step(1 / 60);
    peakBullets = math.max(peakBullets, game.bullets.length);
    frames++;
  }
  return {
    'stage': stage.number,
    'result': game.phase.name,
    'seconds': game.elapsed.round(),
    'health': game.health,
    'score': game.score,
    'peakProjectiles': peakBullets,
  };
}

void main() {
  for (final stage in stages) {
    stdout.writeln(probe(stage));
  }
}
