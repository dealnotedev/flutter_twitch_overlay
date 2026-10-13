import 'package:obssource/data/events.dart';
import 'package:obssource/twitch/ws_event.dart';
import 'package:obssource/twitch/ws_subscription.dart';

/// Overlay event normalized from Twitch EventSub or a local integration.
///
/// Holds plain data only; profiles, avatars and widgets are resolved by the
/// effect runtime when the event is shown.
sealed class AlertEvent {
  const AlertEvent();
}

class FollowEvent extends AlertEvent {
  final UserInfo user;

  const FollowEvent({required this.user});
}

/// Incoming raid to the connected channel.
class RaidEvent extends AlertEvent {
  final UserInfo from;
  final int viewers;

  const RaidEvent({required this.from, required this.viewers});
}

class SubscriptionEvent extends AlertEvent {
  final WsSubscription subscription;

  /// Subscriber or gifter; `null` only for anonymous gifts.
  final UserInfo? user;

  const SubscriptionEvent({required this.subscription, required this.user});
}

class RedemptionEvent extends AlertEvent {
  final String id;
  final String? rewardId;
  final String rewardTitle;
  final int cost;
  final UserInfo user;
  final String? input;

  const RedemptionEvent({
    required this.id,
    required this.rewardId,
    required this.rewardTitle,
    required this.cost,
    required this.user,
    this.input,
  });
}

class ChatEvent extends AlertEvent {
  static const highlightedType = 'channel_points_highlighted';

  final String messageId;

  /// May be absent in malformed payloads; chat cards need it, commands do not.
  final UserInfo? chatter;
  final String? messageType;
  final WsChatMessage message;

  const ChatEvent({
    required this.messageId,
    required this.chatter,
    required this.messageType,
    required this.message,
  });

  bool get highlighted => messageType == highlightedType;
  String get text => message.text ?? '';
}

class KillEvent extends AlertEvent {
  final KillInfo kill;

  const KillEvent(this.kill);
}
