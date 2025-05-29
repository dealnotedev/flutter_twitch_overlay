import 'package:obssource/twitch/twitch_api.dart';

class UserFollowEvent {
  final DateTime time;
  final DateTime end;
  final String userName;
  final UserDto? user;

  UserFollowEvent({
    required this.userName,
    required this.user,
    required this.time,
    required this.end,
  });
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
