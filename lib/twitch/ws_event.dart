import 'package:obssource/twitch/twitch_redemption.dart';
import 'package:obssource/twitch/ws_subscription.dart';

class WsMessage {
  final WsMessagePayload payload;
  final String? messageId;

  WsMessage({required this.payload, this.messageId});

  factory WsMessage.fromJson(dynamic json) {
    return WsMessage(
      payload: WsMessagePayload.fromJson(json['payload']),
      messageId: json['metadata']?['message_id'] as String?,
    );
  }
}

class WsMessagePayload {
  final WsMessageSubscription? subscription;
  final WsMessageEvent? event;

  WsMessagePayload({required this.subscription, required this.event});

  factory WsMessagePayload.fromJson(dynamic json) {
    final eventJson = json['event'];
    final subscriptionJson = json['subscription'];

    return WsMessagePayload(
      subscription:
          subscriptionJson != null
              ? WsMessageSubscription.fromJson(subscriptionJson)
              : null,
      event:
          eventJson != null
              ? WsMessageEvent.fromJson(
                eventJson,
                eventType: subscriptionJson?['type'] as String?,
              )
              : null,
    );
  }
}

class WsReward {
  final String? id;
  final String title;
  final int cost;

  WsReward({required this.id, required this.title, required this.cost});

  factory WsReward.fromJson(dynamic json) {
    return WsReward(
      id: json['id'] as String?,
      title: json['title'] as String,
      cost: json['cost'] as int,
    );
  }
}

class WsMessageEvent {
  final String? id;
  final UserInfo? user;
  final WsReward? reward;
  final String? userInput;
  final String? messageText;
  final DateTime? redeemedAt;
  final TwitchRedemptionStatus? redemptionStatus;
  final String? broadcasterId;
  final WsRaid? raid;
  final WsSubscription? subscription;

  /// Chat sender of a `channel.chat.message` event.
  final UserInfo? chatter;

  /// Chat message kind, e.g. `text` or `channel_points_highlighted`.
  final String? messageType;
  final WsChatMessage? chatMessage;

  WsMessageEvent({
    required this.id,
    required this.user,
    required this.reward,
    required this.userInput,
    required this.messageText,
    required this.redeemedAt,
    this.raid,
    this.subscription,
    this.redemptionStatus,
    this.broadcasterId,
    this.chatter,
    this.messageType,
    this.chatMessage,
  });

  factory WsMessageEvent.fromJson(dynamic json, {String? eventType}) {
    final rewardJson = json['reward'];
    final messageJson = json['message'];

    return WsMessageEvent(
      id: (json['id'] ?? json['message_id']) as String?,
      user: ParseUtil.parseUserInfo(json),
      reward: rewardJson != null ? WsReward.fromJson(rewardJson) : null,
      userInput: json['user_input'] as String?,
      messageText: messageJson is Map ? messageJson['text'] as String? : null,
      chatter: ParseUtil.parseUserInfo(json, prefix: 'chatter_'),
      messageType: json['message_type'] as String?,
      chatMessage:
          messageJson is Map ? WsChatMessage.fromJson(messageJson) : null,
      redeemedAt: DateTime.tryParse(json['redeemed_at'] as String? ?? ''),
      redemptionStatus: TwitchRedemptionStatus.fromApi(
        json['status'] as String?,
      ),
      broadcasterId: json['broadcaster_user_id'] as String?,
      raid: WsRaid.tryParse(json),
      subscription: WsSubscription.tryParse(json, eventType),
    );
  }
}

class WsRaid {
  final UserInfo fromBroadcaster;
  final String toBroadcasterId;
  final int viewers;

  WsRaid({
    required this.fromBroadcaster,
    required this.toBroadcasterId,
    required this.viewers,
  });

  static WsRaid? tryParse(dynamic json) {
    final id = json['from_broadcaster_user_id'];
    final login = json['from_broadcaster_user_login'];
    final name = json['from_broadcaster_user_name'];
    final toId = json['to_broadcaster_user_id'];
    final viewers = json['viewers'];
    if (id is! String ||
        login is! String ||
        name is! String ||
        toId is! String ||
        viewers is! int ||
        viewers < 1) {
      return null;
    }
    return WsRaid(
      fromBroadcaster: UserInfo(id: id, login: login, name: name),
      toBroadcasterId: toId,
      viewers: viewers,
    );
  }
}

class UserInfo {
  final String id;
  final String login;
  final String name;

  UserInfo({required this.id, required this.login, required this.name});
}

class ParseUtil {
  ParseUtil._();

  static UserInfo? parseUserInfo(dynamic json, {String prefix = ''}) {
    final id = json['${prefix}user_id'] as String?;
    final login = json['${prefix}user_login'] as String?;
    final name = json['${prefix}user_name'] as String?;

    if (id == null || login == null || name == null) {
      return null;
    }

    return UserInfo(id: id, login: login, name: name);
  }
}

class WsMessageSubscription {
  final String type;

  WsMessageSubscription({required this.type});

  factory WsMessageSubscription.fromJson(dynamic json) {
    return WsMessageSubscription(type: json['type'] as String);
  }
}

class WsChatMessage {
  final String? text;
  final List<WsChatMessageFragment> fragments;

  const WsChatMessage({required this.text, required this.fragments});

  factory WsChatMessage.fromJson(dynamic json) {
    final fragments = json['fragments'];
    return WsChatMessage(
      text: json['text'] as String?,
      fragments:
          fragments is List
              ? fragments
                  .whereType<Map>()
                  .map(WsChatMessageFragment.fromJson)
                  .toList(growable: false)
              : const [],
    );
  }
}

enum WsFragmentType {
  mention,
  text,
  emote,
  unknown;

  static WsFragmentType fromString(String? type) => WsFragmentType.values
      .firstWhere((value) => value.name == type, orElse: () => unknown);
}

class WsChatMessageFragment {
  final WsFragmentType type;
  final String? text;
  final WsChatEmote? emote;

  const WsChatMessageFragment({
    required this.type,
    required this.text,
    this.emote,
  });

  factory WsChatMessageFragment.fromJson(dynamic json) {
    final emoteJson = json['emote'];
    return WsChatMessageFragment(
      type: WsFragmentType.fromString(json['type'] as String?),
      text: json['text'] as String?,
      emote: emoteJson is Map ? WsChatEmote.tryParse(emoteJson) : null,
    );
  }
}

class WsChatEmote {
  final String id;
  final List<String> format;

  const WsChatEmote({required this.id, required this.format});

  bool get animated => format.contains('animated');

  static WsChatEmote? tryParse(dynamic json) {
    final id = json['id'];
    if (id is! String) return null;
    final format = json['format'];
    return WsChatEmote(
      id: id,
      format:
          format is List
              ? format.map((value) => value.toString()).toList(growable: false)
              : const [],
    );
  }
}
