import 'package:dio/dio.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/twitch/twitch_creds_interceptor.dart';

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

  Future<int> cleanupInactiveEventSubs() async {
    final resp = await dio.get('/eventsub/subscriptions');
    final data = (resp.data['data'] as List).cast<Map<String, dynamic>>();

    int count = 0;

    for (final sub in data) {
      final status = sub['status'];
      final id = sub['id'];

      if (status == 'websocket_disconnected') {
        await dio.delete(
          '/eventsub/subscriptions',
          queryParameters: {'id': id},
        );
        count++;
      }
    }

    return count;
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

  Future<void> subscribeChatMessages({
    required String broadcasterUserId,
    required String userId,
    required String sessionId,
  }) {
    final data = {
      'version': '1',
      'type': 'channel.chat.message',
      'condition': {
        'broadcaster_user_id': broadcasterUserId,
        'user_id': userId,
      },
      'transport': {'session_id': sessionId, 'method': 'websocket'},
    };

    return dio.post('/eventsub/subscriptions', data: data);
  }

  Future<List<TwitchCustomReward>> getCustomRewards({
    required String broadcasterUserId,
    bool onlyManageableRewards = false,
  }) async {
    final response = await dio.get(
      '/channel_points/custom_rewards',
      queryParameters: {
        'broadcaster_id': broadcasterUserId,
        if (onlyManageableRewards) 'only_manageable_rewards': true,
      },
    );
    return _customRewardsFromResponse(response.data);
  }

  Future<TwitchCustomReward> createCustomReward({
    required String broadcasterUserId,
    required String title,
    required int cost,
    required String prompt,
    required String backgroundColor,
  }) async {
    final response = await dio.post(
      '/channel_points/custom_rewards',
      queryParameters: {'broadcaster_id': broadcasterUserId},
      data: {
        'title': title,
        'cost': cost,
        'prompt': prompt,
        'background_color': backgroundColor,
        'is_enabled': true,
        'is_user_input_required': true,
        'should_redemptions_skip_request_queue': false,
      },
    );
    final rewards = _customRewardsFromResponse(response.data);
    if (rewards.length != 1) {
      throw const FormatException(
        'Twitch did not return the created custom reward',
      );
    }
    return rewards.single;
  }

  Future<UserDto> getUser({required String? id}) {
    return dio
        .get(id != null ? '/users?id=$id' : '/users')
        .then((value) => value.data)
        .then((value) => value['data'] as List<dynamic>)
        .then((value) => value[0])
        .then(UserDto.fromJson);
  }

  static List<TwitchCustomReward> _customRewardsFromResponse(Object? value) {
    if (value is! Map<String, dynamic> || value['data'] is! List) {
      throw const FormatException('Invalid Twitch custom rewards response');
    }
    return List<TwitchCustomReward>.unmodifiable(
      (value['data'] as List).map(TwitchCustomReward.fromJson),
    );
  }
}

abstract interface class TwitchRewardCatalog {
  Future<List<TwitchCustomReward>> load();

  Future<TwitchCustomReward> createDefault();
}

class TwitchApiRewardCatalog implements TwitchRewardCatalog {
  static const _defaultTitle = 'Music Request (Freydis)';
  static const _defaultPrompt = 'Paste a YouTube link';
  static const _defaultCost = 1000;
  static const _defaultColor = '#9147FF';

  final TwitchApi api;
  final Settings settings;

  const TwitchApiRewardCatalog({required this.api, required this.settings});

  String get _broadcasterId {
    final broadcasterId = settings.twitchAuth?.broadcasterId;
    if (broadcasterId == null || broadcasterId.isEmpty) {
      throw StateError('Connect Twitch to manage music request rewards');
    }
    return broadcasterId;
  }

  @override
  Future<List<TwitchCustomReward>> load() => api.getCustomRewards(
    broadcasterUserId: _broadcasterId,
    onlyManageableRewards: true,
  );

  @override
  Future<TwitchCustomReward> createDefault() async {
    final broadcasterId = _broadcasterId;
    final allRewards = await api.getCustomRewards(
      broadcasterUserId: broadcasterId,
    );
    final title = _uniqueTitle(allRewards.map((reward) => reward.title));
    return api.createCustomReward(
      broadcasterUserId: broadcasterId,
      title: title,
      cost: _defaultCost,
      prompt: _defaultPrompt,
      backgroundColor: _defaultColor,
    );
  }

  static String _uniqueTitle(Iterable<String> existingTitles) {
    final normalized =
        existingTitles.map((title) => title.toLowerCase()).toSet();
    if (!normalized.contains(_defaultTitle.toLowerCase())) {
      return _defaultTitle;
    }

    for (var suffix = 2; suffix < 100; suffix++) {
      final candidate = 'Music Request (Freydis $suffix)';
      if (!normalized.contains(candidate.toLowerCase())) return candidate;
    }
    throw StateError('Unable to choose a unique Twitch reward title');
  }
}

class TwitchCustomReward {
  final String id;
  final String title;
  final String prompt;
  final int cost;
  final String backgroundColor;
  final Uri? image;
  final bool isEnabled;
  final bool isPaused;
  final bool isInStock;
  final bool isUserInputRequired;
  final bool shouldRedemptionsSkipRequestQueue;

  const TwitchCustomReward({
    required this.id,
    required this.title,
    required this.prompt,
    required this.cost,
    required this.backgroundColor,
    required this.image,
    required this.isEnabled,
    required this.isPaused,
    required this.isInStock,
    required this.isUserInputRequired,
    required this.shouldRedemptionsSkipRequestQueue,
  });

  bool get isMusicRequestCompatible =>
      isUserInputRequired && !shouldRedemptionsSkipRequestQueue;

  factory TwitchCustomReward.fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid Twitch custom reward');
    }

    String? imageUrlFrom(dynamic source) {
      if (source is! Map) return null;
      return source['url_4x'] as String? ??
          source['url_2x'] as String? ??
          source['url_1x'] as String?;
    }

    final id = value['id'];
    final title = value['title'];
    final cost = value['cost'];
    if (id is! String || title is! String || cost is! num) {
      throw const FormatException('Twitch custom reward is incomplete');
    }

    final imageUrl =
        imageUrlFrom(value['image']) ?? imageUrlFrom(value['default_image']);
    return TwitchCustomReward(
      id: id,
      title: title,
      prompt: value['prompt'] as String? ?? '',
      cost: cost.toInt(),
      backgroundColor: value['background_color'] as String? ?? '#9147FF',
      image:
          imageUrl == null || imageUrl.isEmpty ? null : Uri.tryParse(imageUrl),
      isEnabled: value['is_enabled'] as bool? ?? false,
      isPaused: value['is_paused'] as bool? ?? false,
      isInStock: value['is_in_stock'] as bool? ?? true,
      isUserInputRequired: value['is_user_input_required'] as bool? ?? false,
      shouldRedemptionsSkipRequestQueue:
          value['should_redemptions_skip_request_queue'] as bool? ?? false,
    );
  }
}

class UserDto {
  final String id;
  final String login;
  final String? displayName;
  final String? profileImageUrl;

  const UserDto({
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
