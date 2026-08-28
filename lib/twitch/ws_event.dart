class WsMessage {
  final WsMessagePayload payload;

  WsMessage({required this.payload});

  factory WsMessage.fromJson(dynamic json) {
    return WsMessage(payload: WsMessagePayload.fromJson(json['payload']));
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
      event: eventJson != null ? WsMessageEvent.fromJson(eventJson) : null,
    );
  }
}

class WsReward {
  final String title;
  final int cost;

  WsReward({required this.title, required this.cost});

  factory WsReward.fromJson(dynamic json) {
    return WsReward(title: json['title'] as String, cost: json['cost'] as int);
  }
}

class WsMessageEvent {
  final String? id;
  final UserInfo? user;
  final WsReward? reward;

  WsMessageEvent({required this.id, required this.user, required this.reward});

  factory WsMessageEvent.fromJson(dynamic json) {
    final rewardJson = json['reward'];

    return WsMessageEvent(
      id: json['id'] as String?,
      user: ParseUtil.parseUserInfo(json),
      reward: rewardJson != null ? WsReward.fromJson(rewardJson) : null,
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
