import 'package:dio/dio.dart';
import 'package:obssource/settings.dart';
import 'package:obssource/twitch/twitch_creds_interceptor.dart';

class Statuses {
  static const resolved = 'RESOLVED';
  static const active = 'ACTIVE';
  static const locked = 'LOCKED';
  static const canceled = 'CANCELED';
}

class TwitchApi {
  late final Dio dio;

  TwitchApi({required Settings settings, required String clientSecret}) {
    final interceptor = TwitchCredsInterceptor(
      settings: settings,
      clientSecret: clientSecret,
    );
    dio = Dio(BaseOptions(baseUrl: 'https://api.twitch.tv/helix'));
    dio.interceptors.add(interceptor);
  }

  Future<void> subscribeCustomRewards({
    required String? broadcasterUserId,
    required String sessionId,
  }) {
    final data = {
      'version': '1',
      'type': 'channel.channel_points_custom_reward_redemption.add',
      'condition': {'broadcaster_user_id': broadcasterUserId},
      'transport': {'session_id': sessionId, 'method': 'websocket'},
    };

    return dio.post('/eventsub/subscriptions', data: data);
  }

  Future<void> subscribeChat({
    required String? broadcasterUserId,
    required String sessionId,
  }) {
    final data = {
      'version': '1',
      'type': 'channel.chat.message',
      'condition': {
        'broadcaster_user_id': broadcasterUserId,
        'user_id': broadcasterUserId,
      },
      'transport': {'session_id': sessionId, 'method': 'websocket'},
    };

    return dio.post('/eventsub/subscriptions', data: data);
  }

  Future<void> subscribeFollowEvents({
    required String? broadcasterUserId,
    required String sessionId,
  }) {
    final data = {
      'version': '2',
      'type': 'channel.follow',
      'condition': {
        'broadcaster_user_id': broadcasterUserId,
        'moderator_user_id': broadcasterUserId,
      },
      'transport': {'session_id': sessionId, 'method': 'websocket'},
    };

    return dio.post('/eventsub/subscriptions', data: data);
  }

  Future<UserDto> getUser({required String? id}) {
    return dio
        .get(id != null ? '/users?id=$id' : '/users')
        .then((value) => value.data)
        .then((value) => value['data'] as List<dynamic>)
        .then((value) => value[0])
        .then(UserDto.fromJson);
  }
}

class UserDto {
  final String id;
  final String login;
  final String? displayName;
  final String? profileImageUrl;

  UserDto({
    required this.id,
    required this.login,
    required this.displayName,
    required this.profileImageUrl,
  });

  static UserDto fromJson(dynamic json) {
    return UserDto(
      id: json['id'] as String,
      login: json['login'] as String,
      displayName: json['display_name'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
    );
  }
}
