/// Persisted music options managed through the overlay settings.
class MusicSettings {
  static const minQueueLength = 1;
  static const maxQueueLength = 50;
  static const minTrackDurationSeconds = 60;
  static const maxTrackDurationSeconds = 1200;
  static const minCacheMb = 128;
  static const maxCacheMb = 2048;

  final bool enabled;
  final int volumePercent;
  final int ttsVolumePercent;
  final int maxQueue;
  final int maxDurationSeconds;
  final int cacheMaxMb;
  final bool controlServerEnabled;
  final int controlServerPort;

  const MusicSettings({
    this.enabled = true,
    this.volumePercent = 70,
    this.ttsVolumePercent = 25,
    this.maxQueue = 10,
    this.maxDurationSeconds = 600,
    this.cacheMaxMb = maxCacheMb,
    this.controlServerEnabled = true,
    this.controlServerPort = 47821,
  });

  factory MusicSettings.fromJson(Map<String, dynamic> json) {
    int integer(String key, int fallback) =>
        json[key] is int ? json[key] as int : fallback;
    bool boolean(String key, bool fallback) =>
        json[key] is bool ? json[key] as bool : fallback;
    return MusicSettings(
      enabled: boolean('enabled', true),
      volumePercent: integer('volume_percent', 70),
      ttsVolumePercent: integer('tts_volume_percent', 25),
      maxQueue: integer('max_queue', 10),
      maxDurationSeconds: integer('max_duration_seconds', 600),
      cacheMaxMb: integer('cache_max_mb', maxCacheMb),
      controlServerEnabled: boolean('control_server_enabled', true),
      controlServerPort: integer('control_server_port', 47821),
    ).normalized();
  }

  MusicSettings normalized() => copyWith(
    volumePercent: volumePercent.clamp(0, 100),
    ttsVolumePercent: ttsVolumePercent.clamp(0, 100),
    maxQueue:
        maxQueue > 0 ? maxQueue.clamp(minQueueLength, maxQueueLength) : 10,
    maxDurationSeconds:
        maxDurationSeconds > 0
            ? maxDurationSeconds.clamp(
              minTrackDurationSeconds,
              maxTrackDurationSeconds,
            )
            : 600,
    cacheMaxMb:
        cacheMaxMb <= 0 ? maxCacheMb : cacheMaxMb.clamp(minCacheMb, maxCacheMb),
    controlServerPort:
        controlServerPort > 0 && controlServerPort <= 65535
            ? controlServerPort
            : 47821,
  );

  MusicSettings copyWith({
    bool? enabled,
    int? volumePercent,
    int? ttsVolumePercent,
    int? maxQueue,
    int? maxDurationSeconds,
    int? cacheMaxMb,
    bool? controlServerEnabled,
    int? controlServerPort,
  }) => MusicSettings(
    enabled: enabled ?? this.enabled,
    volumePercent: volumePercent ?? this.volumePercent,
    ttsVolumePercent: ttsVolumePercent ?? this.ttsVolumePercent,
    maxQueue: maxQueue ?? this.maxQueue,
    maxDurationSeconds: maxDurationSeconds ?? this.maxDurationSeconds,
    cacheMaxMb: cacheMaxMb ?? this.cacheMaxMb,
    controlServerEnabled: controlServerEnabled ?? this.controlServerEnabled,
    controlServerPort: controlServerPort ?? this.controlServerPort,
  );

  Map<String, Object> toJson() => {
    'enabled': enabled,
    'volume_percent': volumePercent,
    'tts_volume_percent': ttsVolumePercent,
    'max_queue': maxQueue,
    'max_duration_seconds': maxDurationSeconds,
    'cache_max_mb': cacheMaxMb,
    'control_server_enabled': controlServerEnabled,
    'control_server_port': controlServerPort,
  };
}
