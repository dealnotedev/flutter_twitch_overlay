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
  final WsRaid? raid;
  final WsSubscription? subscription;

  WsMessageEvent({
    required this.id,
    required this.user,
    required this.reward,
    required this.userInput,
    required this.messageText,
    required this.redeemedAt,
    this.raid,
    this.subscription,
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
      redeemedAt: DateTime.tryParse(json['redeemed_at'] as String? ?? ''),
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

  static UserInfo? parseUserInfo(dynamic json) {
    final id = json['user_id'] as String?;
    final login = json['user_login'] as String?;
    final name = json['user_name'] as String?;

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
