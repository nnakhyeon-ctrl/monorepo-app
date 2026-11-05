import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raikeopeu2026/game/progress.dart';
import 'package:raikeopeu2026/game/stages.dart';

import '../tool/campaign_probe.dart';
import 'fixtures.dart';

void main() {
  test('all 15 stages clear with unmodified free kit after scheduled boss and within time limit', () {
    expect(stages.length, 15);
    for (final stage in stages) {
      final result = probe(stage);
      expect(result['result'], 'won', reason: '$result');
      expect(
        result['seconds'],
        inInclusiveRange(stage.bossAt, stage.timeLimit),
      );
      expect(result['peakProjectiles'], lessThan(100));
    }
  });
  test('result settlement unlocks sequentially and is idempotent', () async {
    final repo = FixtureProgress();
    final c = CampaignController(repo);
    await c.ready;
    expect(c.selectStage(2), isFalse);
    await c.finish(runId: 'run_1', stage: 1, won: true, score: 500);
    await c.finish(runId: 'run_1', stage: 1, won: true, score: 500);
    expect(c.progress.records[1]?.attempts, 1);
    expect(c.progress.unlocked, 2);
    await c.finish(runId: 'run_2', stage: 1, won: false, score: 100);
    expect(c.progress.records[1]?.cleared, isTrue);
    expect(c.progress.records[1]?.best, 500);
    final restart = CampaignController(repo);
    await restart.ready;
    expect(restart.progress.unlocked, 2);
    expect(restart.progress.records[1]?.best, 500);
    await c.finish(runId: 'forged_locked', stage: 3, won: true, score: 1000);
    expect(c.progress.records[3], isNull);
    c.dispose();
    restart.dispose();
  });
  test('failed save remains visible and retry persists without duplicate settlement', () async {
    final repo = FixtureProgress()..failWrites = true;
    final c = CampaignController(repo);
    await c.ready;
    await c.finish(runId: 'run_1', stage: 1, won: true, score: 500);
    expect(c.saveFailed, isTrue);
    repo.failWrites = false;
    await c.save();
    expect(c.saveFailed, isFalse);
    expect(repo.value.records[1]?.attempts, 1);
    c.dispose();
  });
  test('two disk slots recover interrupted/corrupt latest write; preserve future schema', () async {
    final dir = await Directory.systemTemp.createTemp('airzero_fixture_');
    addTearDown(() => dir.delete(recursive: true));
    final repo = FileProgressRepository(directory: () async => dir);
    await repo.read();
    final value = CampaignProgress(
      records: {1: const StageRecord(cleared: true, best: 700, attempts: 1)},
    );
    await repo.write(value);
    await repo.write(value);
    await File('${dir.path}/airzero_progress/progress_a.json')
        .writeAsString('{interrupted');
    final loaded = await FileProgressRepository(directory: () async => dir)
        .read();
    expect(loaded.recovered, isTrue);
    expect(loaded.progress.records[1]?.best, 700);
    await File('${dir.path}/airzero_progress/progress_a.json')
        .writeAsString(jsonEncode({'schema': 99}));
    final future = FileProgressRepository(directory: () async => dir);
    expect((await future.read()).writeBlocked, isTrue);
    await expectLater(future.write(value), throwsStateError);
    expect(
      await File('${dir.path}/airzero_progress/progress_a.json').readAsString(),
      contains('99'),
    );
  });
  test(
    'analytics require opt-in and contain only bounded allowlisted counters',
    () async {
      final c = CampaignController(FixtureProgress());
      await c.ready;
      c.metric('retry');
      expect(c.progress.counters, isEmpty);
      await c.setAnalytics(true);
      c.metric('retry');
      c.metric('pilot@example.invalid');
      expect(c.progress.counters, {'retry': 1});
      await c.setAnalytics(false);
      expect(c.progress.counters, isEmpty);
      c.dispose();
    },
  );
}
