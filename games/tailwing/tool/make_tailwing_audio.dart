// Original deterministic PCM composition; no samples/downloads or network.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const sampleRate = 22050, bpm = 112, bars = 16;
const beat = 60 / bpm, duration = bars * 4 * beat;
double sine(double hz, double t) => math.sin(2 * math.pi * hz * t);
double hz(int note) => (440 * math.pow(2, (note - 69) / 12)).toDouble();
double pluck(int note, double t, double length, double gain) {
  if (t < 0 || t >= length) return 0;
  final envelope =
      (1 - math.exp(-t * 100)) *
      math.exp(-t * 8) *
      math.min(1.0, (length - t) * 80);
  return gain * envelope * (sine(hz(note), t) + .18 * sine(hz(note) * 2, t));
}

double compose(double t) {
  final measure = (t / (4 * beat)).floor(), local = t % (4 * beat);
  const chords = [
    [60, 64, 67, 71],
    [57, 60, 64, 67],
    [53, 57, 60, 64],
    [55, 59, 62, 67],
  ];
  final chord = chords[(measure ~/ 2) % 4];
  double sound = 0;
  // Gentle sustained warm chords, walking bass, alternating melodic phrases.
  final breath = math
      .pow(math.sin(math.pi * local / (4 * beat)), .7)
      .toDouble();
  for (final n in chord) {
    sound += .026 * breath * sine(hz(n), t);
  }
  for (var i = 0; i < 4; i++) {
    final at = local - i * beat;
    sound += pluck(chord[i.isEven ? 0 : 2] - 24, at, beat * .85, .17);
    if (at >= 0 && at < .16) {
      sound +=
          .10 * math.exp(-at * 27) * sine(54 + 45 * math.exp(-at * 35), at);
      if (i.isOdd) {
        sound += .022 * math.exp(-at * 45) * (sine(1301, at) + sine(2143, at));
      }
    }
  }
  const phrases = [
    [0, 2, 1, 3, 2, 1, 0, 2],
    [2, 1, 3, 2, 0, 1, 2, 3],
    [0, 1, 2, 1, 3, 2, 1, 0],
    [3, 2, 1, 2, 0, 1, 3, 2],
  ];
  final phrase = phrases[(measure ~/ 4) % 4];
  for (var i = 0; i < 8; i++) {
    final at = local - i * beat * .5;
    sound += pluck(
      chord[phrase[i]] + 12,
      at,
      beat * .43,
      measure % 4 == 3 && i > 5 ? .035 : .065,
    );
    if (at >= 0 && at < .06) {
      sound += .007 * math.exp(-at * 90) * sine(6203, at);
    }
  }
  // Seam fades are only 10ms; no dramatic volume swells or harsh limiting.
  final seam = math.min(1.0, math.min(t, duration - t) / .01).clamp(0.0, 1.0);
  return sound * seam;
}

void main() {
  final count = (duration * sampleRate).round(),
      bytes = ByteData(44 + (duration * sampleRate).round() * 2);
  void text(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      bytes.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  bytes.setUint32(4, 36 + count * 2, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  text(36, 'data');
  bytes.setUint32(40, count * 2, Endian.little);
  double peak = 0, sum = 0;
  var clipped = 0;
  for (var i = 0; i < count; i++) {
    final value = compose(i / sampleRate);
    peak = math.max(peak, value.abs());
    sum += value * value;
    if (value.abs() >= 1) clipped++;
    bytes.setInt16(
      44 + i * 2,
      (value.clamp(-1, 1) * 32767).round(),
      Endian.little,
    );
  }
  if (clipped > 0 || peak > .8) throw StateError('unsafe_pcm_peak');
  File('assets/audio/tailwing_flight_v2.wav')
      .writeAsBytesSync(bytes.buffer.asUint8List());
  File('docs/tailwing/design-pass-01/AUDIO-CHECKS.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'date': '2026-10-30', 'method': 'original procedural PCM; no external samples', 'file': 'assets/audio/tailwing_flight_v2.wav', 'bpm': bpm, 'bars': bars, 'seconds': count / sampleRate, 'sampleRate': sampleRate, 'channels': 1, 'bits': 16, 'peak': peak, 'rms': math.sqrt(sum / count), 'clippedSamples': clipped, 'firstSample': bytes.getInt16(44, Endian.little), 'lastSample': bytes.getInt16(bytes.lengthInBytes - 2, Endian.little), 'listeningOnPhysicalDevice': 'NOT_VERIFIED', 'rights': 'No third-party samples; legal exclusivity not assessed'})}\n',
  );
  stdout.writeln('New original loop saved; existing audio preserved.');
}
