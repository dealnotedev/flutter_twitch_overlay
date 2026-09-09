import 'package:obssource/l10n/app_localizations.dart';
import 'package:obssource/twitch/ws_subscription.dart';

extension SubscriptionText on WsSubscription {
  String description(AppLocalizations l10n) => switch (type) {
    SubscriptionEventType.subscribe => l10n.subscription_thanks(tier),
    SubscriptionEventType.message => l10n.subscription_resub_thanks(
      months!,
      tier,
    ),
    SubscriptionEventType.gift when count == 1 => l10n.subscription_gift(tier),
    SubscriptionEventType.gift => l10n.subscription_gifts(count!, tier),
  };
}
