// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get music_settings_player_style => 'Вигляд плеєра';

  @override
  String get music_settings_style_cosmic => 'Космічний';

  @override
  String get music_settings_style_turntable => 'Вініловий програвач';

  @override
  String get music_settings_style_hint =>
      'Програвач чекає на готовність аудіо й опускає голку перед відтворенням. Налаштування згортання діють для космічного плеєра.';

  @override
  String get music_turntable_preparing => 'Готуємо платівку';

  @override
  String get music_turntable_cueing => 'Опускаємо голку';

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
  String get music_requests_paused => 'ЗАМОВЛЕННЯ МУЗИКИ ПРИЗУПИНЕНО';

  @override
  String get music_queue_status_waiting => 'очікує';

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
  String music_error_operation_failed(String requester) {
    return '$requester: не вдалося підготувати трек. Спробуйте пізніше.';
  }

  @override
  String get music_control_title => 'Керування музикою';

  @override
  String get music_error_youtube_access =>
      'Замовлення призупинено: YouTube просить перевірку. Треки в черзі продовжаться або бали повернуться.';

  @override
  String get music_error_youtube_download_blocked =>
      'Замовлення призупинено: YouTube блокує завантаження аудіо. Треки в черзі продовжаться або бали повернуться.';

  @override
  String get music_error_youtube_rate_limited =>
      'Замовлення призупинено: YouTube тимчасово обмежив запити. Треки в черзі продовжаться або бали повернуться.';

  @override
  String music_error_youtube_unavailable(String requester) {
    return '$requester: це відео недоступне. Оберіть інше.';
  }

  @override
  String get music_youtube_title => 'Підключення YouTube';

  @override
  String get music_youtube_description =>
      'Якщо YouTube просить перевірку, підключіть його тут. Сесія YouTube зберігається лише на цьому комп’ютері.';

  @override
  String get music_youtube_disconnected =>
      'Загальнодоступні треки працюють без входу, доки YouTube не попросить перевірку.';

  @override
  String get music_youtube_opening => 'Підготовка підключення YouTube…';

  @override
  String get music_youtube_instructions =>
      '1. Відкрийте й запустіть потрібне відео у вікні браузера, що відкрилося. Якщо відкрилася головна сторінка YouTube, оберіть коротке загальнодоступне відео.\n2. Пройдіть перевірку, якщо вона з’явиться. Спочатку можна перевірити підключення без входу в обліковий запис.\n3. Залиште вкладку з відео відкритою, поверніться сюди й натисніть «Перевірити підключення». Вікно закриється, коли почнеться перевірка.';

  @override
  String get music_youtube_account_warning =>
      'Якщо входите в обліковий запис, використовуйте додатковий акаунт Google: YouTube може обмежувати акаунти, які використовують для завантаження.';

  @override
  String get music_youtube_checking =>
      'Перевірка доступу до YouTube та завантаження аудіо…';

  @override
  String get music_youtube_connected =>
      'YouTube підключено. Замовлення в черзі продовжаться автоматично.';

  @override
  String get music_youtube_saved =>
      'Сесію YouTube збережено на цьому комп’ютері, вона використовується для замовлень музики.';

  @override
  String get music_youtube_saved_attention =>
      'Сесію YouTube збережено, але остання перевірка або запит не вдалися. Причина нижче.';

  @override
  String get music_youtube_connect => 'Підключити YouTube';

  @override
  String get music_youtube_reconnect => 'Перепідключити YouTube';

  @override
  String get music_youtube_reopen => 'Відкрити YouTube знову';

  @override
  String get music_youtube_verify => 'Перевірити підключення';

  @override
  String get music_youtube_cancel => 'Скасувати';

  @override
  String get music_youtube_disconnect => 'Відключити';

  @override
  String get music_youtube_disconnect_confirm =>
      'Видалити збережену сесію YouTube і окремий профіль браузера разом із входом у Google, якщо він там є?';

  @override
  String get music_youtube_disconnect_remove => 'Видалити';

  @override
  String get music_youtube_disconnect_keep => 'Залишити';

  @override
  String get music_youtube_hold_title => 'Замовлення музики призупинено';

  @override
  String music_youtube_hold_body(int count, int minutes) {
    return 'Замовлень у черзі: $count. Винагороду Twitch тим часом призупинено. Якщо замовлення чекає довше ніж $minutes хв, бали повертаються.';
  }

  @override
  String get music_youtube_resume => 'Відновити замовлення';

  @override
  String get music_youtube_no_browser =>
      'Встановіть Microsoft Edge або Google Chrome, потім знову натисніть «Підключити YouTube».';

  @override
  String get music_youtube_browser_closed =>
      'Вікно YouTube закрито. Відкрийте YouTube знову й не закривайте вікно, доки не натиснете «Перевірити підключення».';

  @override
  String get music_youtube_verification_required =>
      'YouTube просить підтвердити, що ви не бот. Відкрийте YouTube кнопкою нижче, пройдіть перевірку в цьому вікні, потім перевірте підключення.';

  @override
  String get music_youtube_download_blocked =>
      'YouTube заблокував завантаження аудіо (403). Часто допомагає новіша версія застосунку з оновленим yt-dlp. Також можна відкрити YouTube нижче, увійти в додатковий акаунт Google у цьому вікні й перевірити знову; це може допомогти, але не гарантує доступу.';

  @override
  String get music_youtube_rate_limited =>
      'YouTube тимчасово обмежив запити з цього комп’ютера, зазвичай до години. Зачекайте, потім натисніть «Відновити замовлення». Нове підключення навряд чи допоможе одразу.';

  @override
  String get music_youtube_network_error =>
      'Не вдалося з’єднатися з YouTube. Перевірте інтернет і спробуйте ще раз.';

  @override
  String get music_youtube_tools_error =>
      'Компоненти музики відсутні або недоступні. Перевстановіть найновішу повну версію застосунку.';

  @override
  String get music_youtube_storage_error =>
      'Не вдалося зберегти підключення YouTube. Перевірте доступ до запису у вашу папку користувача й спробуйте ще раз.';

  @override
  String get music_youtube_choose_video =>
      'Залиште у вікні YouTube лише вкладку з потрібним відео, закрийте інші вкладки з відео й перевірте підключення знову.';

  @override
  String get music_youtube_video_unavailable =>
      'YouTube не надає плеєру доступ до цього відео. Відкрийте YouTube, оберіть інше загальнодоступне відео й перевірте підключення знову.';

  @override
  String get music_youtube_video_too_long =>
      'Відео перевищує ліміт тривалості треку або є прямим ефіром. Відкрийте YouTube і оберіть коротше відео або збільште ліміт тривалості нижче, потім перевірте підключення знову.';

  @override
  String music_youtube_checked_video(String url) {
    return 'Перевірене відео: $url';
  }

  @override
  String get music_youtube_error_details => 'Деталі помилки';

  @override
  String get music_youtube_check_error =>
      'Не вдалося підготувати аудіо. Відкрийте «Деталі помилки», щоб з’ясувати причину перед повторною спробою.';

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
      'Замовлення музики, відтворення, вигляд і локальне керування.';

  @override
  String get overlay_settings_avatar => 'Аватар';

  @override
  String get avatar_settings_description =>
      'Роздільність аватара та рендер анімацій сповіщень про фолови, рейди й підписки. Зміни застосовуються одразу.';

  @override
  String get avatar_settings_resolution => 'Роздільність аватара';

  @override
  String get avatar_settings_resolution_hint =>
      'Вища роздільність додає деталей і збільшує навантаження на рендер.';

  @override
  String get avatar_settings_renderer => 'Рендер анімації';

  @override
  String get avatar_settings_renderer_optimized => 'Оптимізований';

  @override
  String get avatar_settings_renderer_legacy => 'Класичний';

  @override
  String get avatar_settings_renderer_hint =>
      'Рендер застосовується до аватарів, тексту та піксельних ефектів у сповіщеннях.';

  @override
  String get music_settings_enabled => 'Приймати замовлення музики';

  @override
  String get music_settings_enabled_hint =>
      'Вимкнення призупиняє нагороду Twitch. Прийняті треки продовжують грати; запізнілі замовлення повертають бали.';

  @override
  String get music_settings_volume => 'Гучність музики';

  @override
  String get music_settings_limits => 'Черга та кеш';

  @override
  String get music_settings_queue => 'Максимальна кількість треків';

  @override
  String get music_settings_queue_hint =>
      'Включає поточний трек. Зміна ліміту зберігає прийняті замовлення.';

  @override
  String get music_settings_duration =>
      'Максимальна тривалість треку (секунди)';

  @override
  String get music_settings_duration_hint =>
      '60–1200 секунд (1–20 хвилин). Застосовується до нових замовлень.';

  @override
  String get music_settings_cache => 'Розмір кешу';

  @override
  String music_settings_cache_mb(int size) {
    return '$size МБ';
  }

  @override
  String music_settings_cache_gb(int size) {
    return '$size ГБ';
  }

  @override
  String get music_settings_cache_hint =>
      '128 МБ–2 ГБ. Спочатку видаляються старі невикористані файли; треки поточного сеансу зберігаються.';

  @override
  String get music_settings_server => 'Локальний сервер керування музикою';

  @override
  String get music_settings_server_hint =>
      'Дозволяє окремому контролеру підключитися на цьому комп’ютері. Відтворення триває, коли сервер вимкнений.';

  @override
  String get music_settings_port => 'Порт сервера';

  @override
  String get music_settings_port_hint =>
      'Укажіть цей самий порт у контролері. Новий порт застосовується одразу з перезапуском сервера.';

  @override
  String get music_settings_apply => 'Застосувати';

  @override
  String get music_settings_retry => 'Спробувати ще раз';

  @override
  String get music_settings_invalid_port => 'Введіть порт від 1 до 65535.';

  @override
  String get music_settings_server_stopped => 'Сервер вимкнений';

  @override
  String get music_settings_server_starting => 'Запуск сервера…';

  @override
  String music_settings_server_running(String address) {
    return 'Сервер працює: $address';
  }

  @override
  String get music_settings_server_failed =>
      'Не вдалося запустити сервер. Перевірте, чи порт не зайнятий іншою програмою або джерелом OBS, або виберіть інший порт.';

  @override
  String get music_settings_reward_error =>
      'Не вдалося оновити нагороду Twitch. Перевірте з’єднання та спробуйте ще раз.';

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
  String get overlay_settings_collapse_delay => 'Затримка згортання';

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
  String get settings_on => 'Увімкнено';

  @override
  String get settings_off => 'Вимкнено';

  @override
  String get music_source_title => 'Джерело плеєра';

  @override
  String get music_source_local => 'Локальний плеєр';

  @override
  String get music_source_external => 'Зовнішній плеєр';

  @override
  String get music_source_external_hint =>
      'Підключення до плеєра на цьому комп’ютері. Twitch Listener використовує порт 47822. Звук відтворюється у зовнішній програмі; захоплюйте його в OBS окремо.';

  @override
  String get music_source_login_hint =>
      'Увійдіть у Twitch, щоб налаштувати локальну музичну нагороду.';

  @override
  String get music_queue_status_analyzing => 'АНАЛІЗ';

  @override
  String get music_queue_status_normalizing => 'НОРМАЛІЗАЦІЯ';
}
