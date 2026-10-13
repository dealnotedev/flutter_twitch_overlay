import 'package:obssource/config/json_fields.dart';

/// Overlay effect a channel points reward can trigger.
enum RewardAction {
  flashbang,
  crt,
  pause,
  sticker,
  crosshair;

  /// Reward titles hard-coded by the old master build, used once to bind
  /// existing rewards after an upgrade.
  String get legacyTitle => switch (this) {
    RewardAction.flashbang => 'Флешбенг',
    RewardAction.crt => 'Дуля (30с)',
    RewardAction.pause => 'Пауза',
    RewardAction.sticker => 'Плюнуть в екран',
    RewardAction.crosshair => 'Прицілитись',
  };
}

/// Link between a Twitch reward and an overlay effect.
class RewardEffectBinding {
  final bool enabled;
  final String? rewardId;

  /// Last known reward title, shown while the reward list is not loaded.
  final String? rewardTitle;
  final int volumePercent;

  const RewardEffectBinding({
    this.enabled = true,
    this.rewardId,
    this.rewardTitle,
    this.volumePercent = 100,
  });

  factory RewardEffectBinding.fromJson(Map<String, dynamic> json) =>
      RewardEffectBinding(
        enabled: json.boolean('enabled', true),
        rewardId: json.string('reward_id'),
        rewardTitle: json.string('reward_title'),
        volumePercent: json.integer('volume_percent', 100),
      ).normalized();

  bool get isBound => rewardId != null;
  bool get isActive => enabled && isBound;

  Map<String, Object> toJson() => {
    'enabled': enabled,
    if (rewardId case final id?) 'reward_id': id,
    if (rewardTitle case final title?) 'reward_title': title,
    'volume_percent': volumePercent,
  };

  RewardEffectBinding normalized() {
    final id = rewardId?.trim();
    return RewardEffectBinding(
      enabled: enabled,
      rewardId: id == null || id.isEmpty ? null : id,
      rewardTitle: id == null || id.isEmpty ? null : rewardTitle,
      volumePercent: volumePercent.clamp(0, 100),
    );
  }

  RewardEffectBinding copyWith({bool? enabled, int? volumePercent}) =>
      RewardEffectBinding(
        enabled: enabled ?? this.enabled,
        rewardId: rewardId,
        rewardTitle: rewardTitle,
        volumePercent: volumePercent ?? this.volumePercent,
      );

  /// Binds another reward, or clears the binding with `null`.
  RewardEffectBinding withReward({String? id, String? title}) =>
      RewardEffectBinding(
        enabled: enabled,
        rewardId: id,
        rewardTitle: id == null ? null : title,
        volumePercent: volumePercent,
      ).normalized();
}

/// Persisted channel points effects and their parameters.
class RewardEffectsSettings {
  static const maxCrtSeconds = 120;
  static const minCrtSeconds = 5;
  static const maxPauseMinutes = 240;
  static const minCrosshairSeconds = 5;
  static const maxCrosshairSeconds = 300;

  final Map<RewardAction, RewardEffectBinding> bindings;

  /// Chance of the golden "pro" flashbang.
  final int flashbangProChancePercent;
  final int crtSeconds;

  /// Longest pause a viewer can request.
  final int pauseMaxMinutes;
  final int crosshairSeconds;

  const RewardEffectsSettings({
    this.bindings = const {},
    this.flashbangProChancePercent = 10,
    this.crtSeconds = 30,
    this.pauseMaxMinutes = 60,
    this.crosshairSeconds = 60,
  });

  factory RewardEffectsSettings.fromJson(Map<String, dynamic> json) {
    final bindingsJson = json.object('bindings');
    return RewardEffectsSettings(
      bindings: {
        for (final action in RewardAction.values)
          if (bindingsJson[action.name] is Map<String, dynamic>)
            action: RewardEffectBinding.fromJson(
              bindingsJson[action.name] as Map<String, dynamic>,
            ),
      },
      flashbangProChancePercent: json.integer('flashbang_pro_chance', 10),
      crtSeconds: json.integer('crt_seconds', 30),
      pauseMaxMinutes: json.integer('pause_max_minutes', 60),
      crosshairSeconds: json.integer('crosshair_seconds', 60),
    ).normalized();
  }

  RewardEffectBinding binding(RewardAction action) =>
      bindings[action] ?? const RewardEffectBinding();

  /// Active effects bound to [rewardId], in a stable order.
  List<RewardAction> actionsFor(String? rewardId) {
    if (rewardId == null) return const [];
    return [
      for (final action in RewardAction.values)
        if (binding(action) case final b
            when b.isActive && b.rewardId == rewardId)
          action,
    ];
  }

  Map<String, Object> toJson() => {
    'bindings': {
      for (final entry in bindings.entries)
        entry.key.name: entry.value.toJson(),
    },
    'flashbang_pro_chance': flashbangProChancePercent,
    'crt_seconds': crtSeconds,
    'pause_max_minutes': pauseMaxMinutes,
    'crosshair_seconds': crosshairSeconds,
  };

  RewardEffectsSettings normalized() => RewardEffectsSettings(
    bindings: {
      for (final entry in bindings.entries) entry.key: entry.value.normalized(),
    },
    flashbangProChancePercent: flashbangProChancePercent.clamp(0, 100),
    crtSeconds: crtSeconds.clamp(minCrtSeconds, maxCrtSeconds),
    pauseMaxMinutes: pauseMaxMinutes.clamp(1, maxPauseMinutes),
    crosshairSeconds: crosshairSeconds.clamp(
      minCrosshairSeconds,
      maxCrosshairSeconds,
    ),
  );

  RewardEffectsSettings copyWith({
    int? flashbangProChancePercent,
    int? crtSeconds,
    int? pauseMaxMinutes,
    int? crosshairSeconds,
  }) => RewardEffectsSettings(
    bindings: bindings,
    flashbangProChancePercent:
        flashbangProChancePercent ?? this.flashbangProChancePercent,
    crtSeconds: crtSeconds ?? this.crtSeconds,
    pauseMaxMinutes: pauseMaxMinutes ?? this.pauseMaxMinutes,
    crosshairSeconds: crosshairSeconds ?? this.crosshairSeconds,
  );

  RewardEffectsSettings withBinding(
    RewardAction action,
    RewardEffectBinding value,
  ) => RewardEffectsSettings(
    bindings: {...bindings, action: value},
    flashbangProChancePercent: flashbangProChancePercent,
    crtSeconds: crtSeconds,
    pauseMaxMinutes: pauseMaxMinutes,
    crosshairSeconds: crosshairSeconds,
  );
}
