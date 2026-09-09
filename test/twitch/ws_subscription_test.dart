import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/twitch/ws_event.dart';
import 'package:obssource/twitch/ws_subscription.dart';
import 'package:obssource/l10n/app_localizations_uk.dart';
import 'package:obssource/subs/subscription_text.dart';

void main() {
  final l10n = AppLocalizationsUk();
  test('parses subscription payload and maps all tiers', () {
    for (var tier = 1; tier <= 3; tier++) {
      final message = WsMessage.fromJson({
        'payload': {
          'subscription': {'type': 'channel.subscribe'},
          'event': {'tier': '${tier}000', 'is_gift': false},
        },
      });
      expect(
        message.payload.event?.subscription?.description(l10n),
        'дякую за T$tier підписку!',
      );
    }
  });

  test('resub uses cumulative months and Ukrainian plural forms', () {
    for (final entry
        in {
          1: 'місяць',
          2: 'місяці',
          5: 'місяців',
          11: 'місяців',
          12: 'місяців',
          14: 'місяців',
          21: 'місяць',
          22: 'місяці',
          111: 'місяців',
        }.entries) {
      final sub = WsSubscription.tryParse({
        'tier': '2000',
        'cumulative_months': entry.key,
        'streak_months': 1,
        'duration_months': 1,
      }, 'channel.subscription.message');
      expect(
        sub?.description(l10n),
        'дякую за ${entry.key} ${entry.value} T2 підписки!',
      );
    }
  });

  test('named and anonymous gifts share descriptions', () {
    for (final anonymous in [false, true]) {
      for (final entry
          in {
            1: 'дарує T3 підписку!',
            2: 'дарує 2 T3 підписки!',
            5: 'дарує 5 T3 підписок!',
            11: 'дарує 11 T3 підписок!',
            21: 'дарує 21 T3 підписку!',
            24: 'дарує 24 T3 підписки!',
          }.entries) {
        final sub = WsSubscription.tryParse({
          'tier': '3000',
          'total': entry.key,
          'is_anonymous': anonymous,
        }, 'channel.subscription.gift');
        expect(sub?.description(l10n), entry.value);
        expect(sub?.isAnonymous, anonymous);
      }
    }
  });

  test('ignores gift recipients, unrelated and incomplete payloads', () {
    expect(
      WsSubscription.tryParse({
        'tier': '1000',
        'is_gift': true,
      }, 'channel.subscribe'),
      isNull,
    );
    expect(
      WsSubscription.tryParse({'tier': '1000'}, 'channel.subscription.end'),
      isNull,
    );
    expect(
      WsSubscription.tryParse({'tier': '1000'}, 'channel.subscription.message'),
      isNull,
    );
    expect(
      WsSubscription.tryParse({
        'tier': '1000',
        'total': 0,
      }, 'channel.subscription.gift'),
      isNull,
    );
    expect(
      WsSubscription.tryParse({
        'tier': 'invalid',
        'is_gift': false,
      }, 'channel.subscribe'),
      isNull,
    );
  });
}
