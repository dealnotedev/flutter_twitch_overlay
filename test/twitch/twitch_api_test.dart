import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/twitch/twitch_api.dart';

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
}
