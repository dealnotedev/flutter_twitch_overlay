import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/twitch/twitch_redemption.dart';
import 'package:obssource/twitch/ws_event.dart';

void main() {
  test(
    'parses redemption statuses and tolerates unknown or missing status',
    () {
      for (final (wireValue, expected) in <(String?, TwitchRedemptionStatus?)>[
        ('unfulfilled', TwitchRedemptionStatus.unfulfilled),
        ('fulfilled', TwitchRedemptionStatus.fulfilled),
        ('canceled', TwitchRedemptionStatus.canceled),
        ('CANCELED', TwitchRedemptionStatus.canceled),
        ('unknown', null),
        (null, null),
      ]) {
        final event = WsMessageEvent.fromJson({'status': wireValue});
        expect(event.redemptionStatus, expected);
      }
    },
  );

  test('parses a real raid payload and its delivery ID', () {
    final message = WsMessage.fromJson({
      'metadata': {'message_id': 'delivery-1'},
      'payload': {
        'subscription': {'type': 'channel.raid'},
        'event': {
          'from_broadcaster_user_id': '1234',
          'from_broadcaster_user_login': 'cool_user',
          'from_broadcaster_user_name': 'Cool_User',
          'to_broadcaster_user_id': '1337',
          'to_broadcaster_user_login': 'cooler_user',
          'to_broadcaster_user_name': 'Cooler_User',
          'viewers': 9001,
        },
      },
    });

    expect(message.messageId, 'delivery-1');
    final raid = message.payload.event!.raid!;
    expect(raid.fromBroadcaster.id, '1234');
    expect(raid.fromBroadcaster.login, 'cool_user');
    expect(raid.fromBroadcaster.name, 'Cool_User');
    expect(raid.toBroadcasterId, '1337');
    expect(raid.viewers, 9001);
    expect(message.payload.event!.user, isNull);
  });

  test('ignores malformed raid counts and missing broadcaster fields', () {
    final event = <String, Object>{
      'from_broadcaster_user_id': 'raider',
      'from_broadcaster_user_login': 'raider',
      'from_broadcaster_user_name': 'Raider',
      'to_broadcaster_user_id': 'receiver',
      'viewers': 1,
    };
    for (final count in <Object>[0, -1, '20', 1.5]) {
      expect(WsRaid.tryParse({...event, 'viewers': count}), isNull);
    }
    event.remove('from_broadcaster_user_id');
    expect(WsRaid.tryParse(event), isNull);
  });

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
