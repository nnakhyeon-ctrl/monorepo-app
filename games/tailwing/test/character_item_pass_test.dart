import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/features/battle_skill_dock.dart';
import 'package:raikeopeu2026/game/catalog.dart';
import 'package:raikeopeu2026/game/engine.dart';

import 'fixtures.dart';
import 'expanded_combat_test.dart' show subscribed;

void main() {
  testWidgets(
    'revoked charged skill can render while paused before simulation resumes',
    (t) async {
      final c = await subscribed('beam'),
          g = BattleEngine(c)
            ..activateSkill()
            ..pause();
      (c.repository as FixtureEntitlements).result = const SubscriptionAccess(
        AccessStatus.inactive,
      );
      await c.refresh();
      expect(g.skill, 'barrier');
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BattleSkillDock(g, onSkill: () {}, onShield: () {}),
          ),
        ),
      );
      expect(t.takeException(), isNull);
      c.dispose();
    },
  );
}
