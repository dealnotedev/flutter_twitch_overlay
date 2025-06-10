// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String user_redeemed_reward_title(
    String user,
    String reward,
    String currency_icon,
    String cost,
  ) {
    return '$user redeemed $reward for $currency_icon $cost';
  }

  @override
  String by_user(String user_avatar, String user) {
    return 'by $user_avatar $user';
  }

  @override
  String user_now_following_title(String user_avatar, String user) {
    return '$user_avatar $user just followed!';
  }

  @override
  String get chat_message_first => 'First message';

  @override
  String get chat_message_highlighted => 'Highlighted';

  @override
  String get config_invalid => 'Invalid OBS config';

  @override
  String raid_text(String broadcaster, int raiders) {
    return '$broadcaster is raiding with a party of $raiders';
  }
}
