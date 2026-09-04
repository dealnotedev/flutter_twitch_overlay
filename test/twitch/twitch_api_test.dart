import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/twitch_redemption.dart';

void main() {
  test('subscribes to chat messages for the broadcaster websocket', () async {
    final api = TwitchApi(settings: Settings(), clientSecret: 'unused');
    RequestOptions? capturedRequest;
    api.dio.interceptors
      ..clear()
      ..add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedRequest = options;
            handler.resolve(
              Response<void>(requestOptions: options, statusCode: 202),
            );
          },
        ),
      );

    await api.subscribeChatMessages(
      broadcasterUserId: 'broadcaster-1',
      userId: 'broadcaster-1',
      sessionId: 'session-1',
    );

    expect(capturedRequest?.path, '/eventsub/subscriptions');
    expect(capturedRequest?.data, {
      'version': '1',
      'type': 'channel.chat.message',
      'condition': {
        'broadcaster_user_id': 'broadcaster-1',
        'user_id': 'broadcaster-1',
      },
      'transport': {'session_id': 'session-1', 'method': 'websocket'},
    });
  });

  test('loads only custom rewards manageable by this app', () async {
    final api = TwitchApi(settings: Settings(), clientSecret: 'unused');
    RequestOptions? capturedRequest;
    api.dio.interceptors
      ..clear()
      ..add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedRequest = options;
            handler.resolve(
              Response<Map<String, Object>>(
                requestOptions: options,
                data: {
                  'data': [
                    {
                      'id': 'reward-1',
                      'title': 'Play Music',
                      'prompt': 'Paste a URL',
                      'cost': 750,
                      'background_color': '#9147FF',
                      'is_enabled': true,
                      'is_paused': false,
                      'is_in_stock': true,
                      'is_user_input_required': true,
                      'should_redemptions_skip_request_queue': false,
                      'default_image': {
                        'url_4x': 'https://example.test/reward.png',
                      },
                    },
                  ],
                },
              ),
            );
          },
        ),
      );

    final rewards = await api.getCustomRewards(
      broadcasterUserId: 'broadcaster-1',
      onlyManageableRewards: true,
    );

    expect(capturedRequest?.path, '/channel_points/custom_rewards');
    expect(capturedRequest?.queryParameters, {
      'broadcaster_id': 'broadcaster-1',
      'only_manageable_rewards': true,
    });
    expect(rewards.single.id, 'reward-1');
    expect(rewards.single.cost, 750);
    expect(rewards.single.isMusicRequestCompatible, isTrue);
    expect(rewards.single.image, Uri.parse('https://example.test/reward.png'));
  });

  test('creates a queue-backed reward that requires viewer input', () async {
    final api = TwitchApi(settings: Settings(), clientSecret: 'unused');
    RequestOptions? capturedRequest;
    api.dio.interceptors
      ..clear()
      ..add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedRequest = options;
            handler.resolve(
              Response<Map<String, Object>>(
                requestOptions: options,
                data: {
                  'data': [
                    {
                      'id': 'created-reward',
                      'title': 'Music Request (Freydis)',
                      'cost': 1000,
                      'is_enabled': true,
                      'is_user_input_required': true,
                      'should_redemptions_skip_request_queue': false,
                    },
                  ],
                },
              ),
            );
          },
        ),
      );

    final reward = await api.createCustomReward(
      broadcasterUserId: 'broadcaster-1',
      title: 'Music Request (Freydis)',
      cost: 1000,
      prompt: 'Paste a YouTube link',
      backgroundColor: '#9147FF',
    );

    expect(capturedRequest?.method, 'POST');
    expect(capturedRequest?.queryParameters, {
      'broadcaster_id': 'broadcaster-1',
    });
    expect(capturedRequest?.data, {
      'title': 'Music Request (Freydis)',
      'cost': 1000,
      'prompt': 'Paste a YouTube link',
      'background_color': '#9147FF',
      'is_enabled': true,
      'is_user_input_required': true,
      'should_redemptions_skip_request_queue': false,
    });
    expect(reward.id, 'created-reward');
  });

  test('updates a redemption to a terminal status', () async {
    final api = TwitchApi(settings: Settings(), clientSecret: 'unused');
    RequestOptions? capturedRequest;
    api.dio.interceptors
      ..clear()
      ..add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedRequest = options;
            handler.resolve(
              Response<void>(requestOptions: options, statusCode: 200),
            );
          },
        ),
      );

    await api.updateRedemptionStatus(
      broadcasterUserId: 'broadcaster-1',
      rewardId: 'reward-1',
      redemptionId: 'redemption-1',
      status: TwitchRedemptionStatus.canceled,
    );

    expect(capturedRequest?.method, 'PATCH');
    expect(capturedRequest?.path, '/channel_points/custom_rewards/redemptions');
    expect(capturedRequest?.queryParameters, {
      'broadcaster_id': 'broadcaster-1',
      'reward_id': 'reward-1',
      'id': 'redemption-1',
    });
    expect(capturedRequest?.data, {'status': 'CANCELED'});
  });
}
