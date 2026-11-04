// Original procedural cues and an eight-second minor arpeggio loop. No samples,
// recordings, commercial game music, downloaded assets or network access.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const rate = 22050;
void wave(String name, double seconds, double Function(double) sample) {
  final count = (rate * seconds).round();
  final bytes = ByteData(44 + count * 2);
  void text(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  bytes.setUint32(4, 36 + count * 2, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, rate, Endian.little);
  bytes.setUint32(28, rate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  text(36, 'data');
  bytes.setUint32(40, count * 2, Endian.little);
  for (var i = 0; i < count; i++) {
    bytes.setInt16(
      44 + i * 2,
      (sample(i / rate).clamp(-1, 1) * 18000).round(),
      Endian.little,
    );
  }
  final target = File('assets/audio/$name.wav');
  target.parent.createSync(recursive: true);
  target.writeAsBytesSync(bytes.buffer.asUint8List());
  stdout.writeln('Wrote ${target.path} (${count / rate}s)');
}

double tone(double hz, double t) => math.sin(2 * math.pi * hz * t);
void main() {
  wave('flight_loop', 8, (t) {
    const notes = [
      146.83,
      220.0,
      293.66,
      349.23,
      130.81,
      196.0,
      261.63,
      329.63,
      116.54,
      174.61,
      233.08,
      293.66,
      130.81,
      196.0,
      261.63,
      329.63,
    ];
    final step = (t * 2).floor() % notes.length, local = t % .5;
    final envelope = math.sin(math.pi * local / .5);
    return envelope *
        (.26 * tone(notes[step], local) + .12 * tone(notes[step] * 2, local));
  });
  wave(
    'shot',
    .09,
    (t) => .32 * tone(900 - 550 * t / .09, t) * math.pow(1 - t / .09, 2),
  );
  wave(
    'hit',
    .16,
    (t) => .45 * (tone(78, t) + .3 * tone(193, t)) * math.pow(1 - t / .16, 2),
  );
  wave(
    'skill',
    .3,
    (t) => .4 * tone(330 + 660 * t / .3, t) * math.sin(math.pi * t / .3),
  );
  wave(
    'clear',
    .6,
    (t) =>
        .38 *
        tone(
          [293.66, 369.99, 440.0, 587.33][(t / .15).floor().clamp(0, 3)],
          t,
        ) *
        math.sin(math.pi * (t % .15) / .15),
  );
}
