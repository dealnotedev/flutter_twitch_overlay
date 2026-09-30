enum TtsMood {
  neutral('neutral'),
  calm('calm'),
  lively('lively');

  final String apiValue;
  const TtsMood(this.apiValue);

  static TtsMood fromJson(Object? value) => values.firstWhere(
    (mood) => mood.apiValue == value,
    orElse: () => neutral,
  );
}

class TtsSettings {
  static const defaultBaseUrl = 'https://api.teamplay.com.ua/tts/v1';
  static const maxVolumePercent = 200;

  final bool enabled;
  final String baseUrl;
  final TtsMood mood;
  final int volumePercent;
  final String? rewardId;
  final String? broadcasterId;

  const TtsSettings({
    this.enabled = false,
    this.baseUrl = defaultBaseUrl,
    this.mood = TtsMood.neutral,
    this.volumePercent = 100,
    this.rewardId,
    this.broadcasterId,
  });

  static String normalizeBaseUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Enter an HTTP(S) service URL');
    }
    final path = uri.path.replaceAll(RegExp(r'/+$'), '');
    return uri.replace(path: path).toString();
  }

  TtsSettings copyWith({
    bool? enabled,
    String? baseUrl,
    TtsMood? mood,
    int? volumePercent,
    String? rewardId,
    String? broadcasterId,
    bool clearReward = false,
  }) => TtsSettings(
    enabled: enabled ?? this.enabled,
    baseUrl: baseUrl ?? this.baseUrl,
    mood: mood ?? this.mood,
    volumePercent: volumePercent ?? this.volumePercent,
    rewardId: clearReward ? null : rewardId ?? this.rewardId,
    broadcasterId: clearReward ? null : broadcasterId ?? this.broadcasterId,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'baseUrl': baseUrl,
    'mood': mood.apiValue,
    'volumePercent': volumePercent,
    'rewardId': rewardId,
    'broadcasterId': broadcasterId,
  };

  factory TtsSettings.fromJson(Map<String, dynamic> json) {
    final baseUrl = normalizeBaseUrl(
      json['baseUrl'] as String? ?? defaultBaseUrl,
    );
    return TtsSettings(
      enabled: json['enabled'] == true,
      // Upgrade the previous default; custom API paths stay explicit.
      baseUrl:
          baseUrl == 'https://api.teamplay.com.ua/tts'
              ? defaultBaseUrl
              : baseUrl,
      mood: TtsMood.fromJson(json['mood']),
      volumePercent: (json['volumePercent'] as num? ?? 100).round().clamp(
        0,
        maxVolumePercent,
      ),
      rewardId: json['rewardId'] as String?,
      broadcasterId: json['broadcasterId'] as String?,
    );
  }
}
