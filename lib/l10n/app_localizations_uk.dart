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
  String get follow_thanks => 'Дякую за фолов!';

  @override
  String get config_invalid => 'Неправильна конфігурація OBS';

  @override
  String get music_queue_next => 'ДАЛІ';

  @override
  String music_queue_more(int count) {
    return '+$count у черзі';
  }

  @override
  String get music_playback_paused => 'Пауза';

  @override
  String get music_playback_now_playing => 'Зараз грає';

  @override
  String get music_action_resume => 'Продовжити';

  @override
  String get music_action_pause => 'Пауза';

  @override
  String get music_action_next => 'Наступний трек';

  @override
  String get music_source_youtube => 'YouTube';

  @override
  String get music_preparing => 'ГОТУЄМО МУЗИКУ';

  @override
  String get music_waiting_for_requests => 'ОЧІКУЄМО МУЗИЧНІ ЗАПИТИ';

  @override
  String get music_queue_status_resolving => 'пошук';

  @override
  String get music_queue_status_downloading => 'завантаження';

  @override
  String get music_queue_status_ready => 'готово';

  @override
  String music_error_missing_youtube_url(String requester) {
    return '$requester: додайте URL YouTube';
  }

  @override
  String music_error_invalid_youtube_url(String requester) {
    return '$requester: некоректний URL YouTube';
  }

  @override
  String music_error_queue_full(String requester) {
    return '$requester: черга музики заповнена';
  }

  @override
  String music_error_track_too_long_or_live(String requester) {
    return '$requester: трек задовгий або це пряма трансляція';
  }

  @override
  String music_error_operation_failed(String requester, String details) {
    return '$requester: $details';
  }

  @override
  String get music_control_title => 'Керування музикою';

  @override
  String get music_control_connected => 'Підключено до оверлею OBS';

  @override
  String get music_control_connecting => 'Підключення до оверлею OBS…';

  @override
  String music_control_reconnecting(int attempt, int seconds) {
    return 'Спроба перепідключення $attempt через $seconds с';
  }

  @override
  String get music_control_disconnected => 'Оверлей OBS недоступний';

  @override
  String get music_control_incompatible =>
      'Версії контролера та оверлею несумісні';

  @override
  String get music_control_closed => 'Підключення закрито';
}
