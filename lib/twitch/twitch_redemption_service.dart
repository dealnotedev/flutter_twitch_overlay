import 'package:obssource/config/settings.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/twitch_redemption.dart';

abstract interface class TwitchRedemptionService {
  Future<void> settle({
    required String rewardId,
    required String redemptionId,
    required TwitchRedemptionStatus status,
  });
}

class TwitchApiRedemptionService implements TwitchRedemptionService {
  final TwitchApi api;
  final Settings settings;

  TwitchApiRedemptionService({required this.api, required this.settings});

  String get _broadcasterId {
    final broadcasterId = settings.twitchAuth?.broadcasterId;
    if (broadcasterId == null || broadcasterId.isEmpty) {
      throw StateError('Connect Twitch to manage reward redemptions');
    }
    return broadcasterId;
  }

  @override
  Future<void> settle({
    required String rewardId,
    required String redemptionId,
    required TwitchRedemptionStatus status,
  }) async {
    if (status == TwitchRedemptionStatus.unfulfilled) {
      throw ArgumentError.value(status, 'status', 'Must be a terminal status');
    }

    await api.updateRedemptionStatus(
      broadcasterUserId: _broadcasterId,
      rewardId: rewardId,
      redemptionId: redemptionId,
      status: status,
    );
  }
}
