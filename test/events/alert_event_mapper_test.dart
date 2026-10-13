import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/events/alert_event.dart';
import 'package:obssource/events/alert_event_mapper.dart';
import 'package:obssource/events/recent_ids.dart';
import 'package:obssource/twitch/ws_event.dart';
import 'package:obssource/twitch/ws_subscription.dart';

void main() {
  late AlertEventMapper mapper;

  setUp(() {
    mapper = AlertEventMapper(broadcasterId: () => '1337');
  });

  test('maps a follow notification', () {
    final event = mapper.map(
      _message('channel.follow', {
        'user_id': '1234',
        'user_login': 'cool_user',
        'user_name': 'Cool_User',
        'broadcaster_user_id': '1337',
        'followed_at': '2026-10-13T12:00:00Z',
      }),
    );

    expect(event, isA<FollowEvent>());
    expect((event as FollowEvent).user.id, '1234');
    expect(event.user.name, 'Cool_User');
  });

  test('maps incoming raids and drops outgoing ones', () {
    Map<String, Object> raid(String toId) => {
      'from_broadcaster_user_id': '1234',
      'from_broadcaster_user_login': 'cool_user',
      'from_broadcaster_user_name': 'Cool_User',
      'to_broadcaster_user_id': toId,
      'to_broadcaster_user_login': 'channel',
      'to_broadcaster_user_name': 'Channel',
      'viewers': 9001,
    };

    final incoming = mapper.map(
      _message('channel.raid', raid('1337'), deliveryId: 'raid-1'),
    );
    expect(incoming, isA<RaidEvent>());
    expect((incoming as RaidEvent).from.name, 'Cool_User');
    expect(incoming.viewers, 9001);

    final outgoing = mapper.map(
      _message('channel.raid', raid('someone-else'), deliveryId: 'raid-2'),
    );
    expect(outgoing, isNull);
  });

  test('keeps raids when the broadcaster is not known yet', () {
    final unknown = AlertEventMapper();
    final event = unknown.map(
      _message('channel.raid', {
        'from_broadcaster_user_id': '1234',
        'from_broadcaster_user_login': 'cool_user',
        'from_broadcaster_user_name': 'Cool_User',
        'to_broadcaster_user_id': 'anyone',
        'viewers': 3,
      }),
    );
    expect(event, isA<RaidEvent>());
  });

  test('maps subscriptions, resubscriptions and anonymous gifts', () {
    final subscribe = mapper.map(
      _message('channel.subscribe', {
        'user_id': '1234',
        'user_login': 'cool_user',
        'user_name': 'Cool_User',
        'tier': '1000',
        'is_gift': false,
      }, deliveryId: 'sub-1'),
    );
    expect(subscribe, isA<SubscriptionEvent>());
    expect(
      (subscribe as SubscriptionEvent).subscription.type,
      SubscriptionEventType.subscribe,
    );
    expect(subscribe.user?.name, 'Cool_User');

    final resub = mapper.map(
      _message('channel.subscription.message', {
        'user_id': '1234',
        'user_login': 'cool_user',
        'user_name': 'Cool_User',
        'tier': '2000',
        'cumulative_months': 15,
        'message': {'text': 'Love the stream!', 'emotes': <Object>[]},
      }, deliveryId: 'sub-2'),
    );
    expect((resub as SubscriptionEvent).subscription.months, 15);
    expect(resub.subscription.tier, 2);

    final gift = mapper.map(
      _message('channel.subscription.gift', {
        'user_id': null,
        'user_login': null,
        'user_name': null,
        'total': 5,
        'tier': '1000',
        'is_anonymous': true,
      }, deliveryId: 'sub-3'),
    );
    expect((gift as SubscriptionEvent).subscription.isAnonymous, isTrue);
    expect(gift.user, isNull);
  });

  test('drops gifted recipient subscriptions and nameless subscribers', () {
    final recipient = mapper.map(
      _message('channel.subscribe', {
        'user_id': '1234',
        'user_login': 'cool_user',
        'user_name': 'Cool_User',
        'tier': '1000',
        'is_gift': true,
      }, deliveryId: 'gifted'),
    );
    expect(recipient, isNull);

    final nameless = mapper.map(
      _message('channel.subscribe', {
        'tier': '1000',
        'is_gift': false,
      }, deliveryId: 'nameless'),
    );
    expect(nameless, isNull);
  });

  test('maps a redemption with reward ID and user input', () {
    final event = mapper.map(
      _message('channel.channel_points_custom_reward_redemption.add', {
        'id': 'redemption-1',
        'broadcaster_user_id': '1337',
        'user_id': '9001',
        'user_login': 'cooler_user',
        'user_name': 'Cooler_User',
        'user_input': '1:30 Скоро повернуся',
        'status': 'unfulfilled',
        'reward': {
          'id': 'reward-1',
          'title': 'Пауза',
          'cost': 100,
          'prompt': 'Minutes and message',
        },
        'redeemed_at': '2026-10-13T12:00:00Z',
      }),
    );

    expect(event, isA<RedemptionEvent>());
    final redemption = event as RedemptionEvent;
    expect(redemption.id, 'redemption-1');
    expect(redemption.rewardId, 'reward-1');
    expect(redemption.rewardTitle, 'Пауза');
    expect(redemption.cost, 100);
    expect(redemption.user.name, 'Cooler_User');
    expect(redemption.input, '1:30 Скоро повернуся');
  });

  test('maps a highlighted chat message with emote fragments', () {
    final event = mapper.map(
      _message('channel.chat.message', {
        'broadcaster_user_id': '1337',
        'chatter_user_id': '4145994',
        'chatter_user_login': 'viptest',
        'chatter_user_name': 'viptest',
        'message_id': 'cc106a89-1814-919d-454c-f4f2f970aae7',
        'message': {
          'text': 'Hi chat Kappa',
          'fragments': [
            {
              'type': 'text',
              'text': 'Hi chat ',
              'cheermote': null,
              'emote': null,
              'mention': null,
            },
            {
              'type': 'emote',
              'text': 'Kappa',
              'cheermote': null,
              'emote': {
                'id': '25',
                'emote_set_id': '0',
                'owner_id': '0',
                'format': ['static'],
              },
              'mention': null,
            },
          ],
        },
        'color': '#00FF7F',
        'message_type': 'channel_points_highlighted',
      }),
    );

    expect(event, isA<ChatEvent>());
    final chat = event as ChatEvent;
    expect(chat.messageId, 'cc106a89-1814-919d-454c-f4f2f970aae7');
    expect(chat.chatter?.id, '4145994');
    expect(chat.highlighted, isTrue);
    expect(chat.text, 'Hi chat Kappa');
    expect(chat.message.fragments.map((fragment) => fragment.type), [
      WsFragmentType.text,
      WsFragmentType.emote,
    ]);
    expect(chat.message.fragments.last.emote?.id, '25');
    expect(chat.message.fragments.last.emote?.animated, isFalse);
  });

  test('drops repeated deliveries of the same event', () {
    final message = _message('channel.follow', {
      'user_id': '1234',
      'user_login': 'cool_user',
      'user_name': 'Cool_User',
    }, deliveryId: 'delivery-1');

    expect(mapper.map(message), isA<FollowEvent>());
    expect(mapper.map(message), isNull);
  });

  test('ignores unknown and malformed notifications', () {
    expect(
      mapper.map(_message('channel.update', {'title': 'New title'})),
      isNull,
    );
    expect(
      mapper.map(
        _message('channel.channel_points_custom_reward_redemption.add', {
          'id': 'no-reward',
          'user_id': '1',
          'user_login': 'a',
          'user_name': 'A',
        }),
      ),
      isNull,
    );
    expect(
      mapper.map(WsMessage.fromJson({'payload': <String, Object>{}})),
      isNull,
    );
  });

  test('recent IDs forget the oldest entries beyond capacity', () {
    final ids = RecentIds(capacity: 2);
    expect(ids.add('a'), isTrue);
    expect(ids.add('b'), isTrue);
    expect(ids.add('a'), isFalse);
    expect(ids.add('c'), isTrue);
    expect(ids.add('a'), isTrue);
    expect(ids.add('c'), isFalse);
  });
}

var _deliveries = 0;

WsMessage _message(
  String type,
  Map<String, Object?> event, {
  String? deliveryId,
}) => WsMessage.fromJson({
  'metadata': {
    'message_id': deliveryId ?? 'delivery-${_deliveries++}',
    'message_type': 'notification',
  },
  'payload': {
    'subscription': {'type': type, 'version': '1'},
    'event': event,
  },
});
