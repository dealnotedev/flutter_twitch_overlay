import 'package:obssource/events/alert_event.dart';
import 'package:obssource/events/recent_ids.dart';
import 'package:obssource/twitch/ws_event.dart';
import 'package:obssource/twitch/ws_subscription.dart';

/// Converts EventSub notifications into [AlertEvent]s and drops redeliveries.
class AlertEventMapper {
  final String? Function() _broadcasterId;
  final RecentIds _seen;

  AlertEventMapper({String? Function()? broadcasterId, int capacity = 512})
    : _broadcasterId = broadcasterId ?? (() => null),
      _seen = RecentIds(capacity: capacity);

  AlertEvent? map(WsMessage message) {
    final event = message.payload.event;
    final deliveryId = event?.id ?? message.messageId;
    if (deliveryId != null && !_seen.add(deliveryId)) return null;
    if (event == null) return null;

    final type = message.payload.subscription?.type;
    if (SubscriptionEventType.values.any((value) => value.wireName == type)) {
      return _subscription(event);
    }

    return switch (type) {
      'channel.follow' => _follow(event),
      'channel.raid' => _raid(event),
      'channel.channel_points_custom_reward_redemption.add' => _redemption(
        event,
      ),
      'channel.chat.message' => _chat(event),
      _ => null,
    };
  }

  AlertEvent? _follow(WsMessageEvent event) {
    final user = event.user;
    return user != null ? FollowEvent(user: user) : null;
  }

  AlertEvent? _raid(WsMessageEvent event) {
    final raid = event.raid;
    if (raid == null) return null;

    final broadcasterId = _broadcasterId();
    if (broadcasterId != null && raid.toBroadcasterId != broadcasterId) {
      // Outgoing raids are delivered too; only incoming ones are alerts.
      return null;
    }

    return RaidEvent(from: raid.fromBroadcaster, viewers: raid.viewers);
  }

  AlertEvent? _subscription(WsMessageEvent event) {
    final subscription = event.subscription;
    if (subscription == null) return null;

    final user = event.user;
    if (!subscription.isAnonymous && (user == null || user.name.isEmpty)) {
      return null;
    }

    return SubscriptionEvent(
      subscription: subscription,
      user: subscription.isAnonymous ? null : user,
    );
  }

  AlertEvent? _redemption(WsMessageEvent event) {
    final id = event.id;
    final user = event.user;
    final reward = event.reward;
    if (id == null || user == null || reward == null) return null;

    return RedemptionEvent(
      id: id,
      rewardId: reward.id,
      rewardTitle: reward.title,
      cost: reward.cost,
      user: user,
      input: event.userInput,
    );
  }

  AlertEvent? _chat(WsMessageEvent event) {
    final id = event.id;
    final message = event.chatMessage;
    if (id == null || message == null) return null;

    return ChatEvent(
      messageId: id,
      chatter: event.chatter,
      messageType: event.messageType,
      message: message,
    );
  }
}
