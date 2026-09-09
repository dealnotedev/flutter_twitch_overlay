import 'package:image/image.dart' as img;
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/ws_subscription.dart';

class UserFollowEvent {
  final DateTime time;
  final DateTime end;
  final String userName;
  final UserDto? user;
  final img.Image? avatar;

  UserFollowEvent({
    required this.userName,
    required this.user,
    this.avatar,
    required this.time,
    required this.end,
  });
}

class UserSubscriptionEvent {
  final String? userName;
  final WsSubscription subscription;
  final img.Image? avatar;

  UserSubscriptionEvent({
    required this.userName,
    required this.subscription,
    this.avatar,
  });
}

class UserRaidEvent {
  final String userName;
  final int viewers;
  final img.Image? avatar;

  UserRaidEvent({required this.userName, required this.viewers, this.avatar});
}

class UserRedeemedEvent {
  final String id;
  final DateTime time;
  final String user;
  final String reward;
  final String? avatar;
  final int cost;

  UserRedeemedEvent(
    this.id, {
    required this.user,
    required this.reward,
    required this.avatar,
    required this.cost,
    required this.time,
  });
}
