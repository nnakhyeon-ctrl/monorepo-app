import 'dart:math' as math;

import 'combat_model.dart';

/// Simulation properties shared by touch/keyboard, renderer and tests.
/// Tilt is cosmetic; the original circular collision radius remains 10.
class AircraftHitbox {
  const AircraftHitbox({this.radius = 10});
  final double radius;
  bool contains(Vec center, Vec point) => (point - center).distance < radius;
  double get width => radius * 2;
  double get height => radius * 2;
}

class PlayerAircraft {
  Vec position = const Vec(180, 510);
  Vec velocity = Vec.zero;
  double speed = 1;
  int hp = 3;
  final hitbox = const AircraftHitbox();
  double tilt = 0;
  Vec _movement = Vec.zero;
  double get x => position.dx;
  double get y => position.dy;

  void moveBy(Vec delta, {required double multiplier}) {
    final previous = position;
    speed = multiplier;
    position = Vec(
      (x + delta.dx * speed).clamp(22, 338),
      (y + delta.dy * speed).clamp(30, 576),
    );
    _movement += position - previous;
  }

  void stepPresentation(double dt) {
    velocity = _movement * (1 / dt);
    final desired = (_movement.dx / 18).clamp(-1.0, 1.0) * .16;
    tilt += (desired - tilt) * (1 - math.exp(-12 * dt));
    _movement = Vec.zero;
  }
}
