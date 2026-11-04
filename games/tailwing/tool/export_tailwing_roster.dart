import 'dart:convert';
import 'dart:io';

import 'package:raikeopeu2026/game/animal_roster.dart';

// Read the runtime catalog rather than inventing a second unlock catalog.
void main() {
  final rows = [
    for (final p in animalPilots)
      {
        'id': p.id,
        'species': p.species,
        'name': p.name,
        'role': p.role,
        'technique': p.technique,
        'description': p.description,
        'art': p.art,
        'portrait': p.portrait,
        'aircraft': p.aircraft,
        'hero': p.hero,
        'freeCharacter': p.free,
        'signatureAccess': 'verified_monthly_or_annual_subscription',
        'pirateConcept': ['tw_bear', 'tw_otter'].contains(p.id)
            ? 'base_character_design_not_separate_skin_or_product'
            : 'not_pirate',
        'duration': p.balance.duration,
        'cooldown': p.balance.cooldown,
      },
  ];
  if (rows.length != 12 || rows.map((p) => p['id']).toSet().length != 12) {
    throw StateError('unexpected_roster');
  }
  for (final row in rows) {
    for (final key in ['portrait', 'aircraft', 'hero']) {
      if (!File(row[key]! as String).existsSync()) {
        throw StateError('missing_runtime_asset');
      }
    }
  }
  File('docs/tailwing/ROSTER-CATALOG.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'scope': 'runtime_catalog_export_no_entitlement_grant', 'pilots': rows})}\n',
  );
  stdout.writeln('12 runtime pilots exported; portrait/aircraft/hero references exist.');
}
