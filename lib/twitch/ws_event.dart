class WsMessage {
  final WsMessagePayload payload;

  WsMessage({required this.payload});

  static WsMessage fromJson(dynamic json) {
    return WsMessage(payload: WsMessagePayload.fromJson(json['payload']));
  }
}

class WsMessagePayload {
  final WsMessageSubscription? subscription;
  final WsMessageEvent? event;

  WsMessagePayload({required this.subscription, required this.event});

  static WsMessagePayload fromJson(dynamic json) {
    final eventJson = json['event'];
    final subsJson = json['subscription'];

    return WsMessagePayload(
      subscription:
          subsJson != null ? WsMessageSubscription.fromJson(subsJson) : null,
      event: eventJson != null ? WsMessageEvent.fromJson(eventJson) : null,
    );
  }
}

class WsReward {
  final String title;
  final int cost;

  WsReward({required this.title, required this.cost});

  static WsReward fromJson(dynamic json) {
    return WsReward(title: json['title'] as String, cost: json['cost'] as int);
  }
}

class WsMessageEvent {
  final String? id;
  final String? userName;
  final String? userId;

  final WsReward? reward;

  WsMessageEvent({
    required this.id,
    required this.userName,
    required this.userId,
    required this.reward,
  });

  static WsMessageEvent fromJson(dynamic json) {
    final rewardJson = json['reward'];

    return WsMessageEvent(
      id: json['id'] as String?,
      userName: json['user_name'] as String?,
      userId: json['user_id'] as String?,
      reward: rewardJson != null ? WsReward.fromJson(rewardJson) : null,
    );
  }
}

class WsMessageSubscription {
  final String type;

  WsMessageSubscription({required this.type});

  static WsMessageSubscription fromJson(dynamic json) {
    return WsMessageSubscription(type: json['type'] as String);
  }
}
