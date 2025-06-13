// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String user_redeemed_reward_title(
    String user,
    String reward,
    String currency_icon,
    String cost,
  ) {
    return '$user бере $reward за $currency_icon $cost';
  }

  @override
  String by_user(String user_avatar, String user) {
    return 'від $user_avatar $user';
  }

  @override
  String user_now_following_title(String user_avatar, String user) {
    return '$user_avatar $user тепер з нами!';
  }

  @override
  String get chat_message_first => 'Перше повідомлення';

  @override
  String get chat_message_highlighted => 'Важливе';

  @override
  String get config_invalid => 'Неправильна конфігурація OBS';

  @override
  String raid_text(String broadcaster, int raiders) {
    String _temp0 = intl.Intl.pluralLogic(
      raiders,
      locale: localeName,
      other: '$raiders глядачами',
      one: '$raiders глядачем',
    );
    return '$broadcaster вривається рейдом разом із $_temp0!';
  }

  @override
  String subscription_subscribe_description(String tier) {
    return 'тепер підписник $tier-го рівня';
  }

  @override
  String subscription_gift_description(String tier, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count підписок',
      few: '$count підписки',
      one: '$count підписку',
    );
    return 'дарує $_temp0 $tier-го рівня';
  }

  @override
  String subscription_message_description(String tier, int months) {
    return 'підписник $tier-го рівня вже $months міс.';
  }

  @override
  String get subscription_anonymous => 'Анонімно';
}
