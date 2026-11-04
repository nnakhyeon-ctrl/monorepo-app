class DeviceOptions {
  const DeviceOptions({
    this.music = true,
    this.effects = true,
    this.vibration = false,
    this.musicVolume = .25,
    this.effectsVolume = .45,
    this.reduceMotion = false,
  });
  final bool music, effects, vibration, reduceMotion;
  final double musicVolume, effectsVolume;
  DeviceOptions copyWith({
    bool? music,
    bool? effects,
    bool? vibration,
    double? musicVolume,
    double? effectsVolume,
    bool? reduceMotion,
  }) => DeviceOptions(
    music: music ?? this.music,
    effects: effects ?? this.effects,
    vibration: vibration ?? this.vibration,
    musicVolume: musicVolume ?? this.musicVolume,
    effectsVolume: effectsVolume ?? this.effectsVolume,
    reduceMotion: reduceMotion ?? this.reduceMotion,
  );
  Map<String, Object> toJson() => {
    'music': music,
    'effects': effects,
    'vibration': vibration,
    'musicVolume': musicVolume,
    'effectsVolume': effectsVolume,
    'reduceMotion': reduceMotion,
  };
  factory DeviceOptions.fromJson(dynamic raw) {
    if (raw == null) {
      return const DeviceOptions();
    }
    if (raw is! Map<String, dynamic> ||
        [
          'music',
          'effects',
          'vibration',
          'reduceMotion',
        ].any((k) => raw[k] is! bool)) {
      throw const FormatException('device options');
    }
    double volume(String key) {
      final v = raw[key];
      if (v is! num || !v.isFinite || v < 0 || v > 1) {
        throw const FormatException('volume');
      }
      return v.toDouble();
    }

    return DeviceOptions(
      music: raw['music'],
      effects: raw['effects'],
      vibration: raw['vibration'],
      reduceMotion: raw['reduceMotion'],
      musicVolume: volume('musicVolume'),
      effectsVolume: volume('effectsVolume'),
    );
  }
}
