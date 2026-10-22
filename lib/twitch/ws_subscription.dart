enum SubscriptionEventType {
  subscribe('channel.subscribe'),
  message('channel.subscription.message'),
  gift('channel.subscription.gift');

  const SubscriptionEventType(this.wireName);
  final String wireName;
}

class WsSubscription {
  final SubscriptionEventType type;
  final int tier;
  final int? months;
  final int? count;
  final bool isAnonymous;

  const WsSubscription({
    required this.type,
    required this.tier,
    this.months,
    this.count,
    this.isAnonymous = false,
  });

  static WsSubscription? tryParse(dynamic json, String? eventType) {
    final types = SubscriptionEventType.values.where(
      (type) => type.wireName == eventType,
    );
    if (types.isEmpty) return null;
    final type = types.single;
    final tier = switch (json['tier']) {
      '1000' => 1,
      '2000' => 2,
      '3000' => 3,
      _ => null,
    };
    if (tier == null) return null;
    // Gift recipients are covered by the single notification for the giver.
    if (type == SubscriptionEventType.subscribe && json['is_gift'] != false) {
      return null;
    }
    final months = json['cumulative_months'];
    final count = json['total'];
    if (type == SubscriptionEventType.message &&
        (months is! int || months < 1)) {
      return null;
    }
    if (type == SubscriptionEventType.gift && (count is! int || count < 1)) {
      return null;
    }
    return WsSubscription(
      type: type,
      tier: tier,
      months: months is int ? months : null,
      count: count is int ? count : null,
      isAnonymous:
          type == SubscriptionEventType.gift && json['is_anonymous'] == true,
    );
  }
}
