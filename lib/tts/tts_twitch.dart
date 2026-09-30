import 'package:obssource/config/settings.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/twitch_redemption.dart';

abstract interface class TtsTwitch {
  Future<List<TwitchCustomReward>> rewards(String channel);
  Future<void> pause(String channel, String reward, bool paused);
  Future<void> settle(
    String channel,
    String reward,
    String redemption,
    bool fulfilled,
  );
  Future<TwitchRedemptionStatus?> status(
    String channel,
    String reward,
    String redemption,
  );
}

class ApiTtsTwitch implements TtsTwitch {
  final TwitchApi api;
  final Settings settings;
  ApiTtsTwitch(this.api, this.settings) {
    api.dio.options.connectTimeout = const Duration(seconds: 10);
    api.dio.options.receiveTimeout = const Duration(seconds: 10);
    api.dio.options.sendTimeout = const Duration(seconds: 10);
  }
  void _check(String channel) {
    if (settings.twitchAuth?.broadcasterId != channel) {
      throw StateError('Connect the Twitch account that owns this request');
    }
  }

  @override
  Future<List<TwitchCustomReward>> rewards(String channel) {
    _check(channel);
    return api.getCustomRewards(
      broadcasterUserId: channel,
      onlyManageableRewards: true,
    );
  }

  @override
  Future<void> pause(String channel, String reward, bool paused) async {
    _check(channel);
    await api.updateCustomReward(
      broadcasterUserId: channel,
      rewardId: reward,
      paused: paused,
    );
  }

  @override
  Future<void> settle(
    String channel,
    String reward,
    String redemption,
    bool fulfilled,
  ) {
    _check(channel);
    return api.updateRedemptionStatus(
      broadcasterUserId: channel,
      rewardId: reward,
      redemptionId: redemption,
      status:
          fulfilled
              ? TwitchRedemptionStatus.fulfilled
              : TwitchRedemptionStatus.canceled,
    );
  }

  @override
  Future<TwitchRedemptionStatus?> status(
    String channel,
    String reward,
    String redemption,
  ) {
    _check(channel);
    return api.getRewardRedemptionStatus(
      broadcasterUserId: channel,
      rewardId: reward,
      redemptionId: redemption,
    );
  }
}

/// A newly created TTS reward stays hidden until it can be published paused.
class TtsRewardCatalog implements TwitchRewardCatalog {
  final TwitchApi api;
  final Settings settings;
  const TtsRewardCatalog({required this.api, required this.settings});
  String get _channel =>
      settings.twitchAuth?.broadcasterId ??
      (throw StateError('Connect Twitch first'));

  @override
  Future<List<TwitchCustomReward>> load() => api.getCustomRewards(
    broadcasterUserId: _channel,
    onlyManageableRewards: true,
  );

  @override
  Future<TwitchCustomReward> createDefault() async {
    final all = await api.getCustomRewards(broadcasterUserId: _channel);
    final titles = all.map((r) => r.title.toLowerCase()).toSet();
    var title = 'TTS (Freydis)';
    for (var suffix = 2; titles.contains(title.toLowerCase()); suffix++) {
      title = 'TTS (Freydis $suffix)';
    }
    return api.createCustomReward(
      broadcasterUserId: _channel,
      title: title,
      cost: 1000,
      prompt: 'Введіть текст для озвучення, до 1024 символів включно.',
      backgroundColor: '#EA4AAB',
      isEnabled: false,
    );
  }

  Future<void> publishPaused(TwitchCustomReward reward) async {
    await api.updateCustomReward(
      broadcasterUserId: _channel,
      rewardId: reward.id,
      paused: true,
      enabled: true,
    );
  }
}
