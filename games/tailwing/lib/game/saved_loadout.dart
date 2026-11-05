import 'combat_model.dart';

/// Preferences only. These IDs never represent ownership or an entitlement.
class SavedLoadout {
  const SavedLoadout([this._values = const {}]);
  final Map<CatalogCategory, String> _values;
  static const allowed = {
    CatalogCategory.aircraft: ['aurora', 'vector', 'safeguard'],
    CatalogCategory.skill: [
      'barrier',
      'focus',
      'mecha',
      'pulse',
      'signature',
      'missile_storm',
      'beam',
      'absorb',
      'blackhole',
      'emp',
      'chain',
    ],
    CatalogCategory.character: [
      'pilot',
      'rion',
      'eden',
      'tw_bear',
      'tw_otter',
      'tw_owl',
      'tw_squirrel',
      'tw_hedgehog',
      'tw_penguin',
      'tw_chameleon',
      'tw_eagle',
      'tw_volt',
    ],
    CatalogCategory.equipment: ['standard', 'echo', 'prism', 'tuner'],
  };
  String selected(CatalogCategory category) =>
      _values[category] ?? allowed[category]!.first;
  SavedLoadout select(CatalogCategory category, String id) {
    if (!allowed[category]!.contains(id)) {
      throw ArgumentError('Invalid loadout selection');
    }
    return SavedLoadout(Map.unmodifiable({..._values, category: id}));
  }

  Map<String, String> toJson() => {
    for (final category in CatalogCategory.values)
      category.name: selected(category),
  };
  factory SavedLoadout.fromJson(dynamic raw) {
    // Missing, unknown or removed optional choices must not discard records.
    if (raw is! Map) return const SavedLoadout();
    return SavedLoadout(
      Map.unmodifiable({
        for (final category in CatalogCategory.values)
          if (allowed[category]!.contains(raw[category.name]))
            category: raw[category.name] as String,
      }),
    );
  }
}
