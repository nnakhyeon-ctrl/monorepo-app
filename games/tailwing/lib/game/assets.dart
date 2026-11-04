import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'animal_roster.dart';

class BattleAssets {
  BattleAssets({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
  final AssetBundle _bundle;
  static const playerPath = 'assets/images/aurora_aviation_hd.png';
  static const coastPath = 'assets/tailwing/world_background.png';
  static const enemiesPath = 'assets/tailwing/world_enemies.png';
  static const explosionPath = 'assets/images/explosion_hd_atlas.png';
  static const cloudPath = 'assets/images/cloud_bank_hd.png';
  static const aircraftPaths = {
    'aurora': playerPath,
    'vector': 'assets/images/vector_mk2.png',
    'safeguard': 'assets/images/safeguard_mk2.png',
  };
  final Map<String, ui.Image> _aircraft = {};
  final Map<String, ui.Image> _pilots = {};
  final Map<String, Future<void>> _pilotLoading = {};
  ui.Image? pilotImageFor(String id) => _pilots[id];
  Future<void> preparePilot(String id) {
    if (_disposed) return Future.error(StateError('assets disposed'));
    final pilot = animalPilot(id);
    if (pilot == null) return Future.error(ArgumentError('unknown pilot'));
    if (_pilots.containsKey(id)) return Future.value();
    return _pilotLoading.putIfAbsent(id, () async {
      try {
        final data = await _bundle.load(pilot.aircraft);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          targetWidth: 256,
        );
        try {
          final image = (await codec.getNextFrame()).image;
          if (_disposed) {
            image.dispose();
          } else {
            _pilots[id] = image;
          }
        } finally {
          codec.dispose();
        }
      } catch (_) {
        _pilotLoading.remove(id);
        rethrow;
      }
    });
  }

  static const _sceneWidths = {
    coastPath: 720,
    enemiesPath: 512,
    explosionPath: 256, // Small legacy compatibility image; new FX are vector.
    cloudPath: 384,
  };
  final Map<String, ui.Image> _scene = {};
  ui.Image? get player => _aircraft['aurora'];
  ui.Image? imageFor(String id) => _aircraft[id] ?? player;
  ui.Image? get coast => _scene[coastPath];
  ui.Image? get enemies => _scene[enemiesPath];
  ui.Image? get explosion => _scene[explosionPath];
  ui.Image? get cloud => _scene[cloudPath];
  int get decodedBytes => [
    ..._aircraft.values,
    ..._pilots.values,
    ..._scene.values,
  ].fold(0, (sum, image) => sum + image.width * image.height * 4);
  Future<void>? _loading;
  bool _disposed = false;
  Future<void> prepare() {
    if (_disposed) return Future.error(StateError('assets disposed'));
    return _loading ??= _decode();
  }

  Future<void> _decode() async {
    try {
      final decoded = <String, ui.Image>{};
      try {
        final paths = {
          for (final entry in aircraftPaths.entries)
            entry.key: (entry.value, 256),
          for (final entry in _sceneWidths.entries)
            entry.key: (entry.key, entry.value),
        };
        for (final entry in paths.entries) {
          final data = await _bundle.load(entry.value.$1);
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            targetWidth: entry.value.$2,
          );
          try {
            decoded[entry.key] = (await codec.getNextFrame()).image;
          } finally {
            codec.dispose();
          }
        }
        if (!_disposed) {
          for (final entry in decoded.entries) {
            (aircraftPaths.containsKey(entry.key)
                    ? _aircraft
                    : _scene)[entry.key] =
                entry.value;
          }
        } else {
          for (final image in decoded.values) {
            image.dispose();
          }
        }
      } catch (_) {
        for (final image in decoded.values) {
          image.dispose();
        }
        rethrow;
      }
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  void dispose() {
    _disposed = true;
    for (final image in [
      ..._aircraft.values,
      ..._scene.values,
      ..._pilots.values,
    ]) {
      image.dispose();
    }
    _aircraft.clear();
    _scene.clear();
    _pilots.clear();
  }
}
