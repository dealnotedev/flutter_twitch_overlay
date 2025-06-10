import 'package:image/image.dart' as img;
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

class Pause {
  final img.Image image;
  final Duration duration;
  final Duration fallDuration;

  Pause({
    required this.image,
    required this.duration,
    required this.fallDuration,
  });
}

class UserRedeemedEvent {
  final String id;
  final DateTime time;
  final String user;
  final String reward;
  final String? avatar;
  final int cost;
  final String? input;

  UserRedeemedEvent(
    this.id, {
    required this.user,
    required this.reward,
    required this.avatar,
    required this.cost,
    required this.time,
    required this.input,
  });
}
