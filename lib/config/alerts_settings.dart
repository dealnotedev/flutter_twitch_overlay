import 'package:obssource/config/json_fields.dart';
import 'package:obssource/twitch/ws_subscription.dart';

enum FollowStyle { pixel, balloons }

enum FollowSound { modern, classic, none }

enum RaidStyle { pixel, classic }

enum RaidSound { voice, classic, none }

enum SubscriptionSound { distinct, classic, none }

/// Shared limits of the alert sliders.
abstract final class AlertLimits {
  static const minHoldSeconds = 3;
  static const maxHoldSeconds = 30;
  static const defaultHoldSeconds = 10;
  static const maxVolumePercent = 100;
}

int _volume(int value) => value.clamp(0, AlertLimits.maxVolumePercent);

int _hold(int value) =>
    value.clamp(AlertLimits.minHoldSeconds, AlertLimits.maxHoldSeconds);

class FollowAlertSettings {
  final bool enabled;
  final FollowStyle style;
  final FollowSound sound;
  final int volumePercent;

  /// Pixel alert hold time, or the balloon flight time.
  final int holdSeconds;

  const FollowAlertSettings({
    this.enabled = true,
    this.style = FollowStyle.pixel,
    this.sound = FollowSound.modern,
    this.volumePercent = 100,
    this.holdSeconds = AlertLimits.defaultHoldSeconds,
  });

  factory FollowAlertSettings.fromJson(Map<String, dynamic> json) =>
      FollowAlertSettings(
        enabled: json.boolean('enabled', true),
        style: json.option('style', FollowStyle.values, FollowStyle.pixel),
        sound: json.option('sound', FollowSound.values, FollowSound.modern),
        volumePercent: json.integer('volume_percent', 100),
        holdSeconds: json.integer(
          'hold_seconds',
          AlertLimits.defaultHoldSeconds,
        ),
      ).normalized();

  Map<String, Object> toJson() => {
    'enabled': enabled,
    'style': style.name,
    'sound': sound.name,
    'volume_percent': volumePercent,
    'hold_seconds': holdSeconds,
  };

  FollowAlertSettings normalized() => copyWith(
    volumePercent: _volume(volumePercent),
    holdSeconds: _hold(holdSeconds),
  );

  FollowAlertSettings copyWith({
    bool? enabled,
    FollowStyle? style,
    FollowSound? sound,
    int? volumePercent,
    int? holdSeconds,
  }) => FollowAlertSettings(
    enabled: enabled ?? this.enabled,
    style: style ?? this.style,
    sound: sound ?? this.sound,
    volumePercent: volumePercent ?? this.volumePercent,
    holdSeconds: holdSeconds ?? this.holdSeconds,
  );
}

class RaidAlertSettings {
  static const maxMinViewers = 1000;
  static const maxAnimalsLimit = 100;

  final bool enabled;
  final RaidStyle style;
  final RaidSound sound;
  final int volumePercent;

  /// Pixel alert hold time; the classic raid has its own timeline.
  final int holdSeconds;

  /// Smaller raids are ignored.
  final int minViewers;

  /// Upper bound of running animals in the classic raid; 0 hides them.
  final int maxAnimals;

  const RaidAlertSettings({
    this.enabled = true,
    this.style = RaidStyle.pixel,
    this.sound = RaidSound.voice,
    this.volumePercent = 100,
    this.holdSeconds = AlertLimits.defaultHoldSeconds,
    this.minViewers = 1,
    this.maxAnimals = 30,
  });

  factory RaidAlertSettings.fromJson(Map<String, dynamic> json) =>
      RaidAlertSettings(
        enabled: json.boolean('enabled', true),
        style: json.option('style', RaidStyle.values, RaidStyle.pixel),
        sound: json.option('sound', RaidSound.values, RaidSound.voice),
        volumePercent: json.integer('volume_percent', 100),
        holdSeconds: json.integer(
          'hold_seconds',
          AlertLimits.defaultHoldSeconds,
        ),
        minViewers: json.integer('min_viewers', 1),
        maxAnimals: json.integer('max_animals', 30),
      ).normalized();

  Map<String, Object> toJson() => {
    'enabled': enabled,
    'style': style.name,
    'sound': sound.name,
    'volume_percent': volumePercent,
    'hold_seconds': holdSeconds,
    'min_viewers': minViewers,
    'max_animals': maxAnimals,
  };

  RaidAlertSettings normalized() => copyWith(
    volumePercent: _volume(volumePercent),
    holdSeconds: _hold(holdSeconds),
    minViewers: minViewers.clamp(1, maxMinViewers),
    maxAnimals: maxAnimals.clamp(0, maxAnimalsLimit),
  );

  RaidAlertSettings copyWith({
    bool? enabled,
    RaidStyle? style,
    RaidSound? sound,
    int? volumePercent,
    int? holdSeconds,
    int? minViewers,
    int? maxAnimals,
  }) => RaidAlertSettings(
    enabled: enabled ?? this.enabled,
    style: style ?? this.style,
    sound: sound ?? this.sound,
    volumePercent: volumePercent ?? this.volumePercent,
    holdSeconds: holdSeconds ?? this.holdSeconds,
    minViewers: minViewers ?? this.minViewers,
    maxAnimals: maxAnimals ?? this.maxAnimals,
  );
}

class SubscriptionAlertSettings {
  final bool subscribe;
  final bool resubscribe;
  final bool gift;
  final bool showAvatar;
  final SubscriptionSound sound;
  final int volumePercent;
  final int holdSeconds;

  const SubscriptionAlertSettings({
    this.subscribe = true,
    this.resubscribe = true,
    this.gift = true,
    this.showAvatar = true,
    this.sound = SubscriptionSound.distinct,
    this.volumePercent = 100,
    this.holdSeconds = AlertLimits.defaultHoldSeconds,
  });

  factory SubscriptionAlertSettings.fromJson(Map<String, dynamic> json) =>
      SubscriptionAlertSettings(
        subscribe: json.boolean('subscribe', true),
        resubscribe: json.boolean('resubscribe', true),
        gift: json.boolean('gift', true),
        showAvatar: json.boolean('show_avatar', true),
        sound: json.option(
          'sound',
          SubscriptionSound.values,
          SubscriptionSound.distinct,
        ),
        volumePercent: json.integer('volume_percent', 100),
        holdSeconds: json.integer(
          'hold_seconds',
          AlertLimits.defaultHoldSeconds,
        ),
      ).normalized();

  bool enabledFor(SubscriptionEventType type) => switch (type) {
    SubscriptionEventType.subscribe => subscribe,
    SubscriptionEventType.message => resubscribe,
    SubscriptionEventType.gift => gift,
  };

  bool get anyEnabled => subscribe || resubscribe || gift;

  Map<String, Object> toJson() => {
    'subscribe': subscribe,
    'resubscribe': resubscribe,
    'gift': gift,
    'show_avatar': showAvatar,
    'sound': sound.name,
    'volume_percent': volumePercent,
    'hold_seconds': holdSeconds,
  };

  SubscriptionAlertSettings normalized() => copyWith(
    volumePercent: _volume(volumePercent),
    holdSeconds: _hold(holdSeconds),
  );

  SubscriptionAlertSettings copyWith({
    bool? subscribe,
    bool? resubscribe,
    bool? gift,
    bool? showAvatar,
    SubscriptionSound? sound,
    int? volumePercent,
    int? holdSeconds,
  }) => SubscriptionAlertSettings(
    subscribe: subscribe ?? this.subscribe,
    resubscribe: resubscribe ?? this.resubscribe,
    gift: gift ?? this.gift,
    showAvatar: showAvatar ?? this.showAvatar,
    sound: sound ?? this.sound,
    volumePercent: volumePercent ?? this.volumePercent,
    holdSeconds: holdSeconds ?? this.holdSeconds,
  );
}

/// Card listing who redeemed which channel points reward.
class RewardCardSettings {
  static const minSeconds = 3;
  static const maxSeconds = 30;

  final bool enabled;
  final int seconds;

  const RewardCardSettings({this.enabled = true, this.seconds = 8});

  factory RewardCardSettings.fromJson(Map<String, dynamic> json) =>
      RewardCardSettings(
        enabled: json.boolean('enabled', true),
        seconds: json.integer('seconds', 8),
      ).normalized();

  Map<String, Object> toJson() => {'enabled': enabled, 'seconds': seconds};

  RewardCardSettings normalized() =>
      copyWith(seconds: seconds.clamp(minSeconds, maxSeconds));

  RewardCardSettings copyWith({bool? enabled, int? seconds}) =>
      RewardCardSettings(
        enabled: enabled ?? this.enabled,
        seconds: seconds ?? this.seconds,
      );
}

/// Cards for highlighted messages and first messages of a session.
class ChatAlertSettings {
  static const minSeconds = 3;
  static const maxSeconds = 60;

  final bool highlighted;
  final bool firstMessage;
  final int seconds;

  const ChatAlertSettings({
    this.highlighted = false,
    this.firstMessage = false,
    this.seconds = 10,
  });

  factory ChatAlertSettings.fromJson(Map<String, dynamic> json) =>
      ChatAlertSettings(
        highlighted: json.boolean('highlighted', false),
        firstMessage: json.boolean('first_message', false),
        seconds: json.integer('seconds', 10),
      ).normalized();

  Map<String, Object> toJson() => {
    'highlighted': highlighted,
    'first_message': firstMessage,
    'seconds': seconds,
  };

  ChatAlertSettings normalized() =>
      copyWith(seconds: seconds.clamp(minSeconds, maxSeconds));

  ChatAlertSettings copyWith({
    bool? highlighted,
    bool? firstMessage,
    int? seconds,
  }) => ChatAlertSettings(
    highlighted: highlighted ?? this.highlighted,
    firstMessage: firstMessage ?? this.firstMessage,
    seconds: seconds ?? this.seconds,
  );
}

/// Persisted presentation of Twitch alerts.
class AlertsSettings {
  final FollowAlertSettings follow;
  final RaidAlertSettings raid;
  final SubscriptionAlertSettings subscriptions;
  final RewardCardSettings rewardCard;
  final ChatAlertSettings chat;

  const AlertsSettings({
    this.follow = const FollowAlertSettings(),
    this.raid = const RaidAlertSettings(),
    this.subscriptions = const SubscriptionAlertSettings(),
    this.rewardCard = const RewardCardSettings(),
    this.chat = const ChatAlertSettings(),
  });

  /// Look of installations upgraded from the old master build.
  const AlertsSettings.legacyMaster()
    : follow = const FollowAlertSettings(
        style: FollowStyle.balloons,
        sound: FollowSound.classic,
      ),
      raid = const RaidAlertSettings(
        style: RaidStyle.classic,
        sound: RaidSound.classic,
      ),
      subscriptions = const SubscriptionAlertSettings(
        showAvatar: false,
        sound: SubscriptionSound.classic,
      ),
      rewardCard = const RewardCardSettings(),
      chat = const ChatAlertSettings(highlighted: true);

  factory AlertsSettings.fromJson(Map<String, dynamic> json) => AlertsSettings(
    follow: FollowAlertSettings.fromJson(json.object('follow')),
    raid: RaidAlertSettings.fromJson(json.object('raid')),
    subscriptions: SubscriptionAlertSettings.fromJson(
      json.object('subscriptions'),
    ),
    rewardCard: RewardCardSettings.fromJson(json.object('reward_card')),
    chat: ChatAlertSettings.fromJson(json.object('chat')),
  );

  Map<String, Object> toJson() => {
    'follow': follow.toJson(),
    'raid': raid.toJson(),
    'subscriptions': subscriptions.toJson(),
    'reward_card': rewardCard.toJson(),
    'chat': chat.toJson(),
  };

  AlertsSettings normalized() => copyWith(
    follow: follow.normalized(),
    raid: raid.normalized(),
    subscriptions: subscriptions.normalized(),
    rewardCard: rewardCard.normalized(),
    chat: chat.normalized(),
  );

  AlertsSettings copyWith({
    FollowAlertSettings? follow,
    RaidAlertSettings? raid,
    SubscriptionAlertSettings? subscriptions,
    RewardCardSettings? rewardCard,
    ChatAlertSettings? chat,
  }) => AlertsSettings(
    follow: follow ?? this.follow,
    raid: raid ?? this.raid,
    subscriptions: subscriptions ?? this.subscriptions,
    rewardCard: rewardCard ?? this.rewardCard,
    chat: chat ?? this.chat,
  );
}
