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
  String get subscription_anonymous => 'Анонім';

  @override
  String subscription_thanks(int tier) {
    return 'дякую за T$tier підписку!';
  }

  @override
  String subscription_resub_thanks(int months, int tier) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'місяців',
      many: 'місяців',
      few: 'місяці',
      one: 'місяць',
    );
    return 'дякую за $months $_temp0 T$tier підписки!';
  }

  @override
  String subscription_gift(int tier) {
    return 'дарує T$tier підписку!';
  }

  @override
  String subscription_gifts(int count, int tier) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'підписок',
      many: 'підписок',
      few: 'підписки',
      one: 'підписку',
    );
    return 'дарує $count T$tier $_temp0!';
  }

  @override
  String raid_viewers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'привів $count глядачів',
      many: 'привів $count глядачів',
      few: 'привів $count глядачів',
      one: 'привів $count глядача',
    );
    return '$_temp0';
  }

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

  @override
  String get overlay_settings_title => 'Налаштування оверлею';

  @override
  String get overlay_settings_sections => 'Розділи';

  @override
  String get overlay_settings_player => 'Плеєр';

  @override
  String get overlay_settings_player_description =>
      'Налаштуйте вигляд плеєра та замовлення музики за бали каналу.';

  @override
  String get overlay_settings_collapse_title => 'Автозгортання';

  @override
  String get overlay_settings_never_collapse => 'Не згортати';

  @override
  String get overlay_settings_stays_expanded =>
      'Плеєр залишається розгорнутим, поки має вміст.';

  @override
  String get overlay_settings_collapse_description =>
      'Час до компактного режиму. Під курсором плеєр залишається розгорнутим.';

  @override
  String overlay_settings_seconds(int seconds) {
    return '$seconds с';
  }

  @override
  String get overlay_settings_save_error =>
      'Не вдалося зберегти налаштування. Спробуйте ще раз.';

  @override
  String get overlay_settings_reward_title => 'Кнопка винагороди';

  @override
  String get overlay_settings_reward_description =>
      'Оберіть керовану винагороду, яка вимагає текст від глядача та залишає погашення в черзі. Оновіть список після змін у Twitch.';

  @override
  String get overlay_settings_create_reward => 'Створити';

  @override
  String get overlay_settings_refresh_rewards => 'Оновити';

  @override
  String get overlay_settings_loading_rewards =>
      'Завантажуємо винагороди Twitch…';

  @override
  String get overlay_settings_no_rewards_title =>
      'Керованих винагород ще немає';

  @override
  String get overlay_settings_no_rewards_body =>
      'Створіть стандартну винагороду для музики, налаштуйте її у Twitch та оновіть список.';

  @override
  String get overlay_settings_load_error =>
      'Не вдалося завантажити винагороди Twitch';

  @override
  String get tts_description =>
      'Озвучення повідомлень глядачів за бали каналу.';

  @override
  String get tts_enabled => 'Обробка TTS';

  @override
  String get tts_on => 'Увімкнено';

  @override
  String get tts_off => 'Вимкнено';

  @override
  String get tts_base_url => 'Адреса сервісу';

  @override
  String get tts_url_hint =>
      'Разом із версією API, наприклад https://api.teamplay.com.ua/tts/v1';

  @override
  String get tts_apply => 'Застосувати';

  @override
  String get tts_invalid_url =>
      'Введіть HTTP(S) адресу без параметрів запиту та фрагмента.';

  @override
  String get tts_mood => 'Настрій';

  @override
  String get tts_volume => 'Гучність озвучення';

  @override
  String get tts_volume_hint =>
      'Лише озвучення. Гучність звуку сповіщення не змінюється.';

  @override
  String get tts_neutral => 'Звичайний';

  @override
  String get tts_calm => 'Спокійний';

  @override
  String get tts_lively => 'Енергійний';

  @override
  String get tts_service => 'Останній стан сервісу';

  @override
  String get tts_available => 'Доступний';

  @override
  String get tts_unavailable => 'Недоступний';

  @override
  String get tts_unknown => 'Ще не перевірено';

  @override
  String get tts_check => 'Перевірити';

  @override
  String tts_agents(int healthy, int connected) {
    return 'Агенти: $healthy готові / $connected підключені';
  }

  @override
  String tts_last_check(String time) {
    return 'Перевірено о $time · оновлення щохвилини';
  }

  @override
  String get tts_reward_description =>
      'Оберіть винагороду з введенням тексту. Вона призупиняється, коли TTS недоступний.';

  @override
  String get tts_reward_empty =>
      'Створіть винагороду TTS або оберіть доступну цьому застосунку.';

  @override
  String get tts_music_conflict => 'Використовується для замовлення музики';

  @override
  String get tts_reward_conflict => 'Використовується для TTS';

  @override
  String get tts_announcement =>
      'Звук сповіщення → пауза 1 секунда → озвучення';

  @override
  String get tts_disabled => 'Обробку TTS вимкнено';

  @override
  String get tts_no_reward => 'Оберіть винагороду Twitch';

  @override
  String get tts_twitch_unavailable => 'Немає з’єднання з подіями Twitch';

  @override
  String get tts_audio_unavailable => 'Аудіо OBS недоступне';

  @override
  String get tts_queue_full => 'Черга TTS заповнена';

  @override
  String get tts_reward_unavailable =>
      'Винагорода призупинена, вимкнена або несумісна';

  @override
  String get tts_no_agents => 'Немає готових агентів';

  @override
  String get tts_timeout => 'Час очікування озвучення вичерпано';

  @override
  String get tts_invalid_text => 'Введіть від 1 до 1024 символів';

  @override
  String get tts_failed => 'Не вдалося озвучити текст';

  @override
  String get tts_canceled => 'Озвучення скасовано';

  @override
  String get tts_agents_unknown => 'Кількість агентів невідома';

  @override
  String get tts_settlement_failed =>
      'Не вдалося оновити заявку у Twitch. Потрібне втручання модератора.';

  @override
  String get tts_operation_failed =>
      'Не вдалося виконати дію. Спробуйте ще раз.';

  @override
  String get tts_test => 'Перевірити через OBS';

  @override
  String get tts_test_text => 'Текст для озвучення';

  @override
  String get tts_test_default => 'Привіт! Це перевірка озвучення.';

  @override
  String get tts_stop => 'Зупинити';

  @override
  String tts_working(String name) {
    return 'Обробляється: $name';
  }
}
