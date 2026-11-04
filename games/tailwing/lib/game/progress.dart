import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'stages.dart';
import '../core/device_options.dart';
import 'saved_loadout.dart';
import 'combat_model.dart';

class StageRecord {
  const StageRecord({this.cleared = false, this.best = 0, this.attempts = 0});
  final bool cleared;
  final int best, attempts;
  Map<String, Object> toJson() => {
    'cleared': cleared,
    'best': best,
    'attempts': attempts,
  };
  factory StageRecord.fromJson(Map<String, dynamic> json) {
    final best = json['best'], attempts = json['attempts'];
    if (json['cleared'] is! bool ||
        best is! int ||
        best < 0 ||
        best > 10000000 ||
        attempts is! int ||
        attempts < 0 ||
        attempts > 10000000) {
      throw const FormatException('record');
    }
    return StageRecord(
      cleared: json['cleared'],
      best: best,
      attempts: attempts,
    );
  }
}

class CampaignProgress {
  CampaignProgress({
    Map<int, StageRecord>? records,
    List<String>? settled,
    this.tutorialDone = false,
    this.sensitivity = 1,
    this.analyticsConsent = false,
    Map<String, int>? counters,
    this.options = const DeviceOptions(),
    this.lastStage,
    this.loadout = const SavedLoadout(),
  }) : records = Map.of(records ?? {}),
       settled = List.of(settled ?? []),
       counters = Map.of(counters ?? {});
  final Map<int, StageRecord> records;
  final List<String> settled;
  bool tutorialDone, analyticsConsent;
  double sensitivity;
  DeviceOptions options;
  int? lastStage;
  SavedLoadout loadout;
  final Map<String, int> counters;
  int get unlocked {
    var next = 1;
    while (next < stages.length && (records[next]?.cleared ?? false)) {
      next++;
    }
    return next;
  }

  Map<String, Object> toJson() => {
    'records': {for (final e in records.entries) '${e.key}': e.value.toJson()},
    'settled': settled,
    'tutorial': tutorialDone,
    'sensitivity': sensitivity,
    'analyticsConsent': analyticsConsent,
    'counters': counters,
    'options': options.toJson(),
    'lastStage': ?lastStage,
    'loadout': loadout.toJson(),
  };
  factory CampaignProgress.fromJson(Map<String, dynamic> json) {
    final records = <int, StageRecord>{};
    for (final e in (json['records'] as Map<String, dynamic>).entries) {
      final stage = int.parse(e.key);
      if (stage < 1 || stage > 15) {
        throw const FormatException('stage');
      }
      records[stage] = StageRecord.fromJson(e.value as Map<String, dynamic>);
    }
    final settled = (json['settled'] as List).cast<String>();
    if (settled.length > 256 ||
        settled.any((s) => !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(s))) {
      throw const FormatException('settlement');
    }
    final sensitivity = (json['sensitivity'] as num).toDouble();
    if (![.75, 1.0, 1.25].contains(sensitivity)) {
      throw const FormatException('sensitivity');
    }
    final counters = <String, int>{};
    for (final e in (json['counters'] as Map<String, dynamic>).entries) {
      if (!allowedMetrics.contains(e.key) ||
          e.value is! int ||
          e.value < 0 ||
          e.value > 10000000) {
        throw const FormatException('metric');
      }
      counters[e.key] = e.value as int;
    }
    if (json['tutorial'] is! bool || json['analyticsConsent'] is! bool) {
      throw const FormatException('settings');
    }
    return CampaignProgress(
      records: records,
      settled: settled,
      tutorialDone: json['tutorial'],
      sensitivity: sensitivity,
      analyticsConsent: json['analyticsConsent'],
      counters: counters,
      options: DeviceOptions.fromJson(json['options']),
      loadout: SavedLoadout.fromJson(json['loadout']),
      lastStage:
          json['lastStage'] is int &&
              json['lastStage'] >= 1 &&
              json['lastStage'] <= 15
          ? json['lastStage']
          : null,
    );
  }
}

final allowedMetrics = {
  'first_battle_complete',
  'return',
  'retry',
  'purchase_success',
  'purchase_failure',
  for (var i = 1; i <= 15; i++) 'failure_$i',
};

class ProgressRead {
  const ProgressRead(
    this.progress, {
    this.recovered = false,
    this.writeBlocked = false,
    this.fresh = false,
  });
  final CampaignProgress progress;
  final bool recovered, writeBlocked, fresh;
}

abstract interface class ProgressRepository {
  Future<ProgressRead> read();
  Future<void> write(CampaignProgress progress);
}

/// Two independent flushed slots. An interrupted replacement of one slot
/// leaves the other intact. Checksum detects accidents, not player tampering.
class FileProgressRepository implements ProgressRepository {
  FileProgressRepository({
    Future<Directory> Function()? directory,
    this.folder = 'airzero_progress',
  }) : _directory = directory ?? getApplicationSupportDirectory {
    if (folder != 'airzero_progress' &&
        !RegExp(r'^airzero_account_[a-f0-9]{64}_g[0-9]{1,10}$')
            .hasMatch(folder)) {
      throw ArgumentError('Invalid app cache folder');
    }
  }
  final String folder;
  final Future<Directory> Function() _directory;
  int _revision = 0;
  bool _blocked = true;
  static String checksum(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16);
  }

  Future<Directory> _root() async {
    final dir = Directory(
      '${(await _directory()).path}${Platform.pathSeparator}$folder',
    );
    if (await FileSystemEntity.type(dir.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw StateError('Linked cache is not supported');
    }
    await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<ProgressRead> read() async {
    _blocked = true; // A failed read must never authorize replacing old data.
    final root = await _root();
    final candidates = <(int, CampaignProgress)>[];
    var present = 0, invalid = 0;
    var incompatible = false;
    for (final slot in ['a', 'b']) {
      final file = File('${root.path}/progress_$slot.json');
      if (!await file.exists()) {
        continue;
      }
      present++;
      try {
        if (await file.length() > 262144) {
          throw const FormatException('size');
        }
        final wrapper =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        if (wrapper['schema'] != 1) {
          incompatible = true;
          continue;
        }
        final payload = wrapper['payload'] as String;
        final revision = wrapper['revision'];
        if (wrapper['checksum'] != checksum('$revision:$payload') ||
            revision is! int ||
            revision < 0) {
          throw const FormatException('checksum');
        }
        candidates.add((
          revision,
          CampaignProgress.fromJson(jsonDecode(payload)),
        ));
      } catch (_) {
        invalid++;
      }
    }
    candidates.sort((a, b) => b.$1.compareTo(a.$1));
    if (candidates.isEmpty) {
      _blocked = incompatible || present > 0;
      return ProgressRead(
        CampaignProgress(),
        writeBlocked: _blocked,
        fresh: present == 0,
      );
    }
    _revision = candidates.first.$1;
    _blocked = incompatible;
    return ProgressRead(
      candidates.first.$2,
      recovered: invalid > 0,
      writeBlocked: _blocked,
    );
  }

  @override
  Future<void> write(CampaignProgress progress) async {
    if (_blocked) {
      throw StateError('Preserve incompatible or damaged records');
    }
    final root = await _root();
    final next = _revision + 1;
    final payload = jsonEncode(progress.toJson());
    final content = jsonEncode({
      'schema': 1,
      'revision': next,
      'payload': payload,
      'checksum': checksum('$next:$payload'),
    });
    final target = File(
      '${root.path}/progress_${next.isEven ? 'a' : 'b'}.json',
    );
    final temp = File('${root.path}/progress.pending');
    await temp.writeAsString(content, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
    _revision = next;
  }

  /// Only this app's known account cache files. Never deletes guest files or
  /// traverses a directory/link supplied by a caller.
  Future<void> eraseAccountCache() async {
    if (!folder.startsWith('airzero_account_')) {
      throw StateError('Guest cache is preserved');
    }
    final root = await _root();
    for (final name in [
      'progress_a.json',
      'progress_b.json',
      'progress.pending',
    ]) {
      final file = File('${root.path}/$name');
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file) {
        throw StateError('Unexpected cache entry');
      }
      await file.delete();
    }
    await root.delete(); // Non-recursive: unexpected contents are preserved.
    _blocked = true;
    _revision = 0;
  }

  Future<void> eraseAccountFamily() async {
    if (!folder.startsWith('airzero_account_')) {
      throw StateError('Guest cache is preserved');
    }
    final parent = await _directory();
    final prefix = folder.substring(0, folder.lastIndexOf('_g') + 2);
    if (!await parent.exists()) return;
    await for (final entry in parent.list(followLinks: false)) {
      final name = entry.path.split(Platform.pathSeparator).last;
      if (RegExp('^$prefix[0-9]{1,10}\$').hasMatch(name)) {
        if (entry is! Directory) throw StateError('Unexpected cache entry');
        await FileProgressRepository(
          directory: _directory,
          folder: name,
        ).eraseAccountCache();
      }
    }
  }
}

class CampaignController extends ChangeNotifier {
  CampaignController(this.repository) {
    ready = _load();
  }
  ProgressRepository repository;
  late Future<void> ready;
  int scopeEpoch = 0;
  CampaignProgress progress = CampaignProgress();
  bool loaded = false,
      saveFailed = false,
      recovered = false,
      writeBlocked = false;
  bool _disposed = false;
  int selectedStage = 1;
  Future<void> _queue = Future.value();
  int _pendingWrites = 0;
  bool get saving => _pendingWrites > 0;
  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> _load({CampaignProgress? seed}) async {
    final epoch = scopeEpoch, source = repository;
    try {
      final result = await source.read();
      if (_disposed || epoch != scopeEpoch) return;
      progress = result.fresh && !result.writeBlocked && seed != null
          ? seed
          : result.progress;
      saveFailed = false;
      recovered = result.recovered;
      writeBlocked = result.writeBlocked;
      selectedStage = (progress.lastStage ?? progress.unlocked).clamp(
        1,
        progress.unlocked,
      );
      if (result.fresh && seed != null && !writeBlocked) {
        await source.write(progress);
      }
      if (_disposed || epoch != scopeEpoch) return;
      if (progress.analyticsConsent) {
        metric('return');
      }
    } catch (_) {
      if (_disposed || epoch != scopeEpoch) return;
      saveFailed = true;
      writeBlocked = true;
    }
    loaded = true;
    _notify();
  }

  Future<void> activateRepository(
    ProgressRepository next, {
    CampaignProgress? seed,
  }) {
    scopeEpoch++;
    repository = next;
    progress = CampaignProgress();
    loaded = false;
    writeBlocked = true;
    saveFailed = false;
    recovered = false;
    selectedStage = 1;
    final epoch = scopeEpoch;
    final previousWrites = _queue;
    final previousLoad = ready;
    // Old writes retain their original repository and immutable snapshot.
    ready = () async {
      await Future.wait([previousWrites, previousLoad]);
      if (!_disposed && epoch == scopeEpoch) await _load(seed: seed);
    }();
    _notify();
    return ready;
  }

  String newRunId() {
    final random = math.Random.secure();
    return List.generate(
      4,
      (_) => random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
    ).join();
  }

  Future<void> acceptInitialServerRecords(
    List<dynamic> records, {
    required int expectedScopeEpoch,
  }) async {
    await ready;
    if (scopeEpoch != expectedScopeEpoch ||
        !loaded ||
        writeBlocked ||
        progress.records.isNotEmpty) {
      return;
    }
    final parsed = <int, StageRecord>{};
    for (final raw in records) {
      parsed[raw['stage'] as int] = StageRecord.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
    }
    progress.records.addAll(parsed);
    selectedStage = progress.unlocked;
    progress.lastStage = selectedStage;
    _notify();
    await save();
  }

  bool selectStage(int number) {
    if (!loaded || number < 1 || number > progress.unlocked) {
      return false;
    }
    selectedStage = number;
    progress.lastStage = number;
    _notify();
    save();
    return true;
  }

  void metric(String name) {
    if (!progress.analyticsConsent || !allowedMetrics.contains(name)) {
      return;
    }
    progress.counters[name] = math.min(
      10000000,
      (progress.counters[name] ?? 0) + 1,
    );
  }

  Future<void> save() {
    if (!loaded || writeBlocked) {
      saveFailed = true;
      _notify();
      return Future.value();
    }
    _pendingWrites++;
    final source = repository, epoch = scopeEpoch;
    final snapshot = CampaignProgress.fromJson(
      jsonDecode(jsonEncode(progress.toJson())),
    );
    _notify();
    _queue = _queue.then((_) async {
      try {
        await source.write(snapshot);
        if (epoch == scopeEpoch) saveFailed = false;
      } catch (_) {
        if (epoch == scopeEpoch) saveFailed = true;
      }
      _pendingWrites--;
      _notify();
    });
    return _queue;
  }

  Future<void> retryStorage() async {
    if (writeBlocked && progress.records.isEmpty) {
      loaded = false;
      _notify();
      await _load();
    } else {
      await save();
    }
  }

  Future<void> finish({
    required String runId,
    required int stage,
    required bool won,
    required int score,
    int? expectedScopeEpoch,
  }) async {
    final epoch = expectedScopeEpoch ?? scopeEpoch;
    await ready;
    if (epoch != scopeEpoch ||
        !loaded ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(runId) ||
        stage < 1 ||
        stage > progress.unlocked ||
        score < 0 ||
        score > 10000000 ||
        progress.settled.contains(runId)) {
      return;
    }
    final firstBattle = progress.records.isEmpty;
    final old = progress.records[stage] ?? const StageRecord();
    progress.records[stage] = StageRecord(
      cleared: old.cleared || won,
      best: math.max(old.best, score),
      attempts: math.min(10000000, old.attempts + 1),
    );
    progress.settled.add(runId);
    if (won && selectedStage == stage) {
      selectedStage = math.min(stage + 1, progress.unlocked);
      progress.lastStage = selectedStage;
    }
    if (progress.settled.length > 256) {
      progress.settled.removeAt(0);
    }
    if (firstBattle) {
      metric('first_battle_complete');
    }
    if (!won) {
      metric('failure_$stage');
    }
    _notify();
    await save();
  }

  Future<void> completeTutorial() async {
    if (!loaded) return;
    progress.tutorialDone = true;
    await save();
  }

  Future<void> setSensitivity(double value) async {
    if (!loaded || ![.75, 1.0, 1.25].contains(value)) {
      return;
    }
    progress.sensitivity = value;
    _notify();
    await save();
  }

  Future<void> setAnalytics(bool value) async {
    if (!loaded) return;
    progress.analyticsConsent = value;
    if (!value) {
      progress.counters.clear();
    }
    _notify();
    await save();
  }

  Future<void> setOptions(DeviceOptions value) async {
    final epoch = scopeEpoch;
    await ready;
    if (epoch != scopeEpoch || !loaded) return;
    // Validate before changing persisted data, including programmatic callers.
    progress.options = DeviceOptions.fromJson(value.toJson());
    _notify();
    await save();
  }

  Future<void> setSelection(CatalogCategory category, String id) async {
    final epoch = scopeEpoch;
    await ready;
    if (epoch != scopeEpoch || !loaded || writeBlocked) return;
    progress.loadout = progress.loadout.select(category, id);
    _notify();
    await save();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
