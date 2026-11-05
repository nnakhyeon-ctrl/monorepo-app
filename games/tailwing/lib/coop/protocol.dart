import '../game/combat_model.dart';
import '../game/engine.dart';
import '../game/stages.dart';

const protocolVersion = 2;
const maxFrameBytes = 65536;

Map<String, Object> battleSnapshot(BattleEngine g, int tick) => {
  'v': protocolVersion,
  'tick': tick,
  'stage': g.stage.number,
  'phase': g.phase.index,
  'time': g.elapsed,
  'score': g.score,
  'players': [
    for (final p in [g, ?g.partner])
      [
        p.player.dx,
        p.player.dy,
        p.health,
        p.shieldRemaining,
        p.cooldown,
        p.playerAircraft.tilt,
      ],
  ],
  'enemies': [
    for (final e in g.enemies)
      [
        e.position.dx,
        e.position.dy,
        e.kind.index,
        e.health,
        e.telegraph,
        e.aim,
        e.age,
        e.shield,
        e.laserAngle,
        e.parts[0],
        e.parts[1],
      ],
  ],
  'bullets': [
    for (final b in g.bullets)
      [
        b.position.dx,
        b.position.dy,
        b.velocity.dx,
        b.velocity.dy,
        b.friendly,
        b.homing,
      ],
  ],
};

double _number(dynamic value, double min, double max) {
  if (value is! num || !value.isFinite || value < min || value > max) {
    throw const FormatException('frame');
  }
  return value.toDouble();
}

int _integer(dynamic value, int min, int max) {
  if (value is! int || value < min || value > max) {
    throw const FormatException('frame');
  }
  return value;
}

BattleEngine readSnapshot(Map<String, dynamic> data) {
  if (data['v'] != protocolVersion) {
    throw const FormatException('version');
  }
  final g = BattleEngine(
    const FreeLoadout(),
    partnerLoadout: const FreeLoadout(),
    stage: stageByNumber(_integer(data['stage'], 1, stages.length)),
  );
  g.elapsed = _number(data['time'], 0, 301);
  g.score = _integer(data['score'], 0, 10000000);
  g.phase = BattlePhase
      .values[_integer(data['phase'], 0, BattlePhase.values.length - 1)];
  final players = data['players'] as List;
  if (players.length != 2) {
    throw const FormatException('players');
  }
  for (var i = 0; i < 2; i++) {
    final values = players[i] as List;
    if (values.length != 6) {
      throw const FormatException('player');
    }
    final p = i == 0 ? g : g.partner!;
    p.player = Vec(_number(values[0], 20, 340), _number(values[1], 25, 580));
    p.health = _integer(values[2], 0, 3);
    p.shieldRemaining = _number(values[3], 0, 2);
    p.cooldown = _number(values[4], 0, 10);
    p.playerAircraft.tilt = _number(values[5], -.16, .16);
  }
  final enemies = data['enemies'] as List, bullets = data['bullets'] as List;
  if (enemies.length > 100 || bullets.length > 512) {
    throw const FormatException('size');
  }
  for (final raw in enemies) {
    final e = raw as List;
    if (e.length != 11 || e[4] is! bool) {
      throw const FormatException('enemy');
    }
    g.enemies.add(
      Enemy(
          Vec(_number(e[0], -100, 460), _number(e[1], -100, 700)),
          EnemyKind.values[_integer(e[2], 0, EnemyKind.values.length - 1)],
        )
        ..health = _number(e[3], 0, 2000)
        ..telegraph = e[4]
        ..aim = _number(e[5], -4, 4)
        ..age = _number(e[6], 0, 301)
        ..shield = _number(e[7], 0, 30)
        ..laserAngle = _number(e[8], 0, 200)
        ..parts[0] = _number(e[9], 0, 55)
        ..parts[1] = _number(e[10], 0, 55),
    );
  }
  for (final raw in bullets) {
    final b = raw as List;
    if (b.length != 6 || b[4] is! bool || b[5] is! bool) {
      throw const FormatException('bullet');
    }
    g.bullets.add(
      Projectile(
        Vec(_number(b[0], -100, 460), _number(b[1], -100, 700)),
        Vec(_number(b[2], -600, 600), _number(b[3], -600, 600)),
        friendly: b[4],
      )..homing = b[5],
    );
  }
  return g;
}
