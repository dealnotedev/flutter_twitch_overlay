import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/tts/tts_twitch.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/twitch_redemption.dart';

import 'tts_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('redemption status queries only the requested ID', () async {
    final settings = configuredTtsSettings();
    final api = TwitchApi(settings: settings, clientSecret: 'unused');
    final requests = <RequestOptions>[];
    api.dio.interceptors
      ..clear()
      ..add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': [
                    {'id': 'request', 'status': 'CANCELED'},
                  ],
                  'pagination': {'cursor': 'not-used'},
                },
              ),
            );
          },
        ),
      );
    final twitch = ApiTtsTwitch(api, settings);
    expect(
      await twitch.status('channel', 'tts', 'request'),
      TwitchRedemptionStatus.canceled,
    );
    expect(requests, hasLength(1));
    expect(requests.single.queryParameters, {
      'broadcaster_id': 'channel',
      'reward_id': 'tts',
      'id': 'request',
    });
  });

  test(
    'new reward is hidden until published paused, with text input and manual settlement',
    () async {
      final settings = configuredTtsSettings();
      final api = TwitchApi(settings: settings, clientSecret: 'unused');
      final requests = <RequestOptions>[];
      api.dio.interceptors
        ..clear()
        ..add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'data': [
                      if (options.method == 'GET')
                        {
                          'id': 'existing',
                          'title': 'TTS (Freydis)',
                          'cost': 1000,
                        }
                      else
                        {
                          'id': 'created',
                          'title': 'TTS (Freydis 2)',
                          'cost': 1000,
                          'is_enabled': options.data['is_enabled'],
                          'is_paused': options.data['is_paused'] ?? false,
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
      final catalog = TtsRewardCatalog(api: api, settings: settings);
      final reward = await catalog.createDefault();
      expect(reward.isEnabled, isFalse);
      final creation = requests.singleWhere((r) => r.method == 'POST');
      expect(creation.data['title'], 'TTS (Freydis 2)');
      expect(creation.data['is_user_input_required'], isTrue);
      expect(creation.data['should_redemptions_skip_request_queue'], isFalse);
      await catalog.publishPaused(reward);
      final publish = requests.singleWhere((r) => r.method == 'PATCH');
      expect(publish.data, {'is_paused': true, 'is_enabled': true});
      expect(publish.queryParameters, {
        'broadcaster_id': 'channel',
        'id': 'created',
      });
    },
  );
}
