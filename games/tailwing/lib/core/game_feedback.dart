import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../game/progress.dart';

enum FeedbackCue { shot, hit, skill, clear }

abstract interface class FeedbackBackend {
  Future<void> music(bool playing, double volume);
  Future<void> effect(FeedbackCue cue, double volume);
  Future<void> vibrate();
  Future<void> dispose();
}

class LocalFeedbackBackend implements FeedbackBackend {
  AudioPlayer? _music, _effects;
  bool _musicLoaded = false;
  bool get musicPlaying => _music?.state == PlayerState.playing;
  Future<Duration?> get musicPosition async => _music?.getCurrentPosition();
  FeedbackCue? lastEffect;
  Future<AudioPlayer> _player({required bool loop}) async {
    // No audio progress UI: avoid polling native playback on every frame.
    final player = AudioPlayer()..positionUpdater = null;
    await player.setAudioContext(
      AudioContext(
        // Retain the native media defaults; do not change global audio routing.
        android: const AudioContextAndroid(),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          // Ambient already mixes; the explicit mix option is invalid here.
        ),
      ),
    );
    await player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    return player;
  }

  @override
  Future<void> music(bool playing, double volume) async {
    if (!playing || volume == 0) {
      await _music?.pause();
      return;
    }
    _music ??= await _player(loop: true);
    await _music!.setVolume(volume);
    if (!_musicLoaded) {
      await _music!.setSource(AssetSource('audio/tailwing_flight_v2.wav'));
      _musicLoaded = true;
    }
    await _music!.resume();
  }

  @override
  Future<void> effect(FeedbackCue cue, double volume) async {
    if (volume == 0) {
      return;
    }
    _effects ??= await _player(loop: false);
    await _effects!.play(AssetSource('audio/${cue.name}.wav'), volume: volume);
    lastEffect = cue;
  }

  @override
  Future<void> vibrate() => HapticFeedback.lightImpact();
  @override
  Future<void> dispose() async {
    await _music?.dispose();
    await _effects?.dispose();
  }
}

class FeedbackController extends ChangeNotifier {
  FeedbackController(this.campaign, this.backend) {
    campaign.addListener(_sync);
  }
  final CampaignController campaign;
  final FeedbackBackend backend;
  bool _battle = false,
      _paused = false,
      _foreground = true,
      _disposed = false,
      _preview = false;
  bool failed = false;
  Timer? _previewTimer;
  Future<void> _operations = Future.value();
  Future<void> get idle => _operations;
  final Stopwatch _shotClock = Stopwatch()..start();
  Future<void> _run(Future<void> Function() operation) {
    _operations = _operations.then((_) async {
      if (_disposed) {
        return;
      }
      try {
        await operation().timeout(const Duration(seconds: 5));
      } catch (_) {
        failed = true;
        if (!_disposed) {
          notifyListeners();
        }
      }
    });
    return _operations;
  }

  Future<void> _sync() {
    final options = campaign.progress.options;
    return _run(
      () => backend.music(
        campaign.loaded &&
            options.music &&
            _foreground &&
            ((_battle && !_paused) || _preview),
        options.musicVolume,
      ),
    );
  }

  void battle(bool value) {
    _battle = value;
    _paused = false;
    _preview = false;
    _previewTimer?.cancel();
    _sync();
  }

  void pause(bool value) {
    _paused = value;
    _sync();
  }

  void foreground(bool value) {
    _foreground = value;
    _preview = false;
    _previewTimer?.cancel();
    _sync();
  }

  Future<void> cue(FeedbackCue cue, {bool preview = false}) async {
    final options = campaign.progress.options;
    if (!_foreground || (!preview && (!_battle || _paused))) {
      return;
    }
    final completingBattle = cue == FeedbackCue.clear && _battle;
    if (preview) {
      failed = false;
      notifyListeners();
    }
    if (cue == FeedbackCue.shot) {
      if (_shotClock.elapsedMilliseconds < 180) {
        return;
      }
      _shotClock.reset();
    }
    await _run(() async {
      if (!_foreground ||
          (!preview && !completingBattle && (!_battle || _paused))) {
        return;
      }
      if (options.effects) {
        await backend.effect(cue, options.effectsVolume);
      }
      if (options.vibration &&
          (preview || cue == FeedbackCue.hit || cue == FeedbackCue.skill)) {
        await backend.vibrate();
      }
    });
  }

  Future<void> previewMusic() async {
    failed = false;
    notifyListeners();
    _preview = true;
    _previewTimer?.cancel();
    await _sync();
    if (_disposed || !_preview || failed) {
      return;
    }
    // Count audible preview time after the native asset has loaded.
    _previewTimer = Timer(const Duration(seconds: 2), () {
      _preview = false;
      _sync();
    });
  }

  Future<void> previewVibration() {
    failed = false;
    notifyListeners();
    return _run(() async {
      if (_foreground && campaign.progress.options.vibration) {
        await backend.vibrate();
      }
    });
  }

  void stopPreview() {
    _preview = false;
    _previewTimer?.cancel();
    _sync();
  }

  @override
  void dispose() {
    _disposed = true;
    campaign.removeListener(_sync);
    _previewTimer?.cancel();
    _operations.then((_) => backend.dispose()).catchError((Object _) {});
    super.dispose();
  }
}
