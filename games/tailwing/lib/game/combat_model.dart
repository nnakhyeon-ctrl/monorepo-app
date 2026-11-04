import 'dart:math' as math;

enum CatalogCategory { aircraft, skill, character, equipment }

/// Shared by the renderer, single player simulation and authoritative server.
/// It deliberately has no Flutter or platform imports.
abstract interface class CombatLoadout {
  String selected(CatalogCategory category);
  bool sanitize();
}

class Vec {
  const Vec(this.dx, this.dy);
  final double dx, dy;
  static const zero = Vec(0, 0);
  Vec operator +(Vec other) => Vec(dx + other.dx, dy + other.dy);
  Vec operator -(Vec other) => Vec(dx - other.dx, dy - other.dy);
  Vec operator *(double factor) => Vec(dx * factor, dy * factor);
  double get distance => math.sqrt(dx * dx + dy * dy);
  List<double> toJson() => [dx, dy];
}

class FreeLoadout implements CombatLoadout {
  const FreeLoadout();
  @override
  String selected(CatalogCategory category) => switch (category) {
    CatalogCategory.aircraft => 'aurora',
    CatalogCategory.skill => 'barrier',
    CatalogCategory.character => 'pilot',
    CatalogCategory.equipment => 'standard',
  };
  @override
  bool sanitize() => false;
}
