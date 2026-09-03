import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/twitch/ws_event.dart';

void main() {
  test('parses custom reward redemption music fields', () {
    final message = WsMessage.fromJson({
      'payload': {
        'subscription': {
          'type': 'channel.channel_points_custom_reward_redemption.add',
        },
        'event': {
          'id': 'redemption-1',
          'user_id': 'user-1',
          'user_login': 'viewer',
          'user_name': 'Viewer',
          'user_input': 'https://youtu.be/video-1',
          'redeemed_at': '2026-09-03T12:30:00Z',
          'reward': {'id': 'reward-1', 'title': 'Play Music', 'cost': 100},
        },
      },
    });

    final event = message.payload.event!;
    expect(event.id, 'redemption-1');
    expect(event.userInput, 'https://youtu.be/video-1');
    expect(event.redeemedAt, DateTime.utc(2026, 9, 3, 12, 30));
    expect(event.reward?.id, 'reward-1');
    expect(event.reward?.title, 'Play Music');
  });

  test('parses chat message id and text', () {
    final message = WsMessage.fromJson({
      'payload': {
        'subscription': {'type': 'channel.chat.message'},
        'event': {
          'message_id': 'message-1',
          'chatter_user_id': 'user-1',
          'chatter_user_login': 'viewer',
          'chatter_user_name': 'Viewer',
          'message': {'text': ' !music ', 'fragments': <Object>[]},
        },
      },
    });

    final event = message.payload.event!;
    expect(event.id, 'message-1');
    expect(event.messageText, ' !music ');
  });
}
