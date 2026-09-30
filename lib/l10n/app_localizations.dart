import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('uk'),
  ];

  /// No description provided for @user_redeemed_reward_title.
  ///
  /// In en, this message translates to:
  /// **'{user} redeemed {reward} for {currency_icon} {cost}'**
  String user_redeemed_reward_title(
    String user,
    String reward,
    String currency_icon,
    String cost,
  );

  /// No description provided for @follow_thanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks for the follow!'**
  String get follow_thanks;

  /// No description provided for @subscription_anonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get subscription_anonymous;

  /// No description provided for @subscription_thanks.
  ///
  /// In en, this message translates to:
  /// **'thanks for the T{tier} subscription!'**
  String subscription_thanks(int tier);

  /// No description provided for @subscription_resub_thanks.
  ///
  /// In en, this message translates to:
  /// **'thanks for {months} {months, plural, one{month} other{months}} of T{tier} subscription!'**
  String subscription_resub_thanks(int months, int tier);

  /// No description provided for @subscription_gift.
  ///
  /// In en, this message translates to:
  /// **'gifts a T{tier} subscription!'**
  String subscription_gift(int tier);

  /// No description provided for @subscription_gifts.
  ///
  /// In en, this message translates to:
  /// **'gifts {count} T{tier} {count, plural, one{subscription} other{subscriptions}}!'**
  String subscription_gifts(int count, int tier);

  /// Number of viewers brought by the raiding broadcaster
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{brought {count} viewer} other{brought {count} viewers}}'**
  String raid_viewers(int count);

  /// No description provided for @config_invalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid OBS config'**
  String get config_invalid;

  /// No description provided for @music_queue_next.
  ///
  /// In en, this message translates to:
  /// **'UP NEXT'**
  String get music_queue_next;

  /// No description provided for @music_queue_more.
  ///
  /// In en, this message translates to:
  /// **'+{count} in queue'**
  String music_queue_more(int count);

  /// No description provided for @music_playback_paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get music_playback_paused;

  /// No description provided for @music_playback_now_playing.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get music_playback_now_playing;

  /// No description provided for @music_action_resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get music_action_resume;

  /// No description provided for @music_action_pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get music_action_pause;

  /// No description provided for @music_action_next.
  ///
  /// In en, this message translates to:
  /// **'Next track'**
  String get music_action_next;

  /// No description provided for @music_source_youtube.
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get music_source_youtube;

  /// No description provided for @music_preparing.
  ///
  /// In en, this message translates to:
  /// **'PREPARING MUSIC'**
  String get music_preparing;

  /// No description provided for @music_waiting_for_requests.
  ///
  /// In en, this message translates to:
  /// **'WAITING FOR MUSIC REQUESTS'**
  String get music_waiting_for_requests;

  /// No description provided for @music_queue_status_resolving.
  ///
  /// In en, this message translates to:
  /// **'searching'**
  String get music_queue_status_resolving;

  /// No description provided for @music_queue_status_downloading.
  ///
  /// In en, this message translates to:
  /// **'downloading'**
  String get music_queue_status_downloading;

  /// No description provided for @music_queue_status_ready.
  ///
  /// In en, this message translates to:
  /// **'ready'**
  String get music_queue_status_ready;

  /// No description provided for @music_error_missing_youtube_url.
  ///
  /// In en, this message translates to:
  /// **'{requester}: add a YouTube URL'**
  String music_error_missing_youtube_url(String requester);

  /// No description provided for @music_error_invalid_youtube_url.
  ///
  /// In en, this message translates to:
  /// **'{requester}: invalid YouTube URL'**
  String music_error_invalid_youtube_url(String requester);

  /// No description provided for @music_error_queue_full.
  ///
  /// In en, this message translates to:
  /// **'{requester}: the music queue is full'**
  String music_error_queue_full(String requester);

  /// No description provided for @music_error_track_too_long_or_live.
  ///
  /// In en, this message translates to:
  /// **'{requester}: the track is too long or is a live stream'**
  String music_error_track_too_long_or_live(String requester);

  /// No description provided for @music_error_operation_failed.
  ///
  /// In en, this message translates to:
  /// **'{requester}: {details}'**
  String music_error_operation_failed(String requester, String details);

  /// No description provided for @music_control_title.
  ///
  /// In en, this message translates to:
  /// **'Music controller'**
  String get music_control_title;

  /// No description provided for @music_control_connected.
  ///
  /// In en, this message translates to:
  /// **'Connected to the OBS overlay'**
  String get music_control_connected;

  /// No description provided for @music_control_connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to the OBS overlay…'**
  String get music_control_connecting;

  /// No description provided for @music_control_reconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnect attempt {attempt} in {seconds}s'**
  String music_control_reconnecting(int attempt, int seconds);

  /// No description provided for @music_control_disconnected.
  ///
  /// In en, this message translates to:
  /// **'OBS overlay is unavailable'**
  String get music_control_disconnected;

  /// No description provided for @music_control_incompatible.
  ///
  /// In en, this message translates to:
  /// **'Controller and overlay versions are incompatible'**
  String get music_control_incompatible;

  /// No description provided for @music_control_closed.
  ///
  /// In en, this message translates to:
  /// **'Connection closed'**
  String get music_control_closed;

  /// No description provided for @overlay_settings_title.
  ///
  /// In en, this message translates to:
  /// **'Overlay settings'**
  String get overlay_settings_title;

  /// No description provided for @overlay_settings_sections.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get overlay_settings_sections;

  /// No description provided for @overlay_settings_player.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get overlay_settings_player;

  /// No description provided for @overlay_settings_player_description.
  ///
  /// In en, this message translates to:
  /// **'Music requests, playback, appearance and the local controller.'**
  String get overlay_settings_player_description;

  /// No description provided for @music_settings_enabled.
  ///
  /// In en, this message translates to:
  /// **'Accept music requests'**
  String get music_settings_enabled;

  /// No description provided for @music_settings_enabled_hint.
  ///
  /// In en, this message translates to:
  /// **'Turning this off pauses the Twitch reward. Accepted tracks keep playing; late requests are refunded.'**
  String get music_settings_enabled_hint;

  /// No description provided for @music_settings_volume.
  ///
  /// In en, this message translates to:
  /// **'Music volume'**
  String get music_settings_volume;

  /// No description provided for @music_settings_tts_volume.
  ///
  /// In en, this message translates to:
  /// **'Music volume during TTS'**
  String get music_settings_tts_volume;

  /// No description provided for @music_settings_tts_volume_hint.
  ///
  /// In en, this message translates to:
  /// **'Percentage of the music volume above. 0% mutes music during TTS; 100% keeps it unchanged.'**
  String get music_settings_tts_volume_hint;

  /// No description provided for @music_settings_limits.
  ///
  /// In en, this message translates to:
  /// **'Queue and cache'**
  String get music_settings_limits;

  /// No description provided for @music_settings_queue.
  ///
  /// In en, this message translates to:
  /// **'Maximum number of tracks'**
  String get music_settings_queue;

  /// No description provided for @music_settings_queue_hint.
  ///
  /// In en, this message translates to:
  /// **'Includes the playing track. Changing the limit keeps accepted requests.'**
  String get music_settings_queue_hint;

  /// No description provided for @music_settings_duration.
  ///
  /// In en, this message translates to:
  /// **'Maximum track duration (seconds)'**
  String get music_settings_duration;

  /// No description provided for @music_settings_duration_hint.
  ///
  /// In en, this message translates to:
  /// **'Applies to new requests. 600 seconds = 10 minutes.'**
  String get music_settings_duration_hint;

  /// No description provided for @music_settings_cache.
  ///
  /// In en, this message translates to:
  /// **'Cache size (MB)'**
  String get music_settings_cache;

  /// No description provided for @music_settings_cache_hint.
  ///
  /// In en, this message translates to:
  /// **'0 = unlimited. Old unused files are removed first; tracks used this session are kept.'**
  String get music_settings_cache_hint;

  /// No description provided for @music_settings_server.
  ///
  /// In en, this message translates to:
  /// **'Local music controller server'**
  String get music_settings_server;

  /// No description provided for @music_settings_server_hint.
  ///
  /// In en, this message translates to:
  /// **'Allows the separate music controller to connect on this computer. Playback continues when the server is off.'**
  String get music_settings_server_hint;

  /// No description provided for @music_settings_port.
  ///
  /// In en, this message translates to:
  /// **'Server port'**
  String get music_settings_port;

  /// No description provided for @music_settings_port_hint.
  ///
  /// In en, this message translates to:
  /// **'Use the same port in the controller. Applying a new port reconnects the server immediately.'**
  String get music_settings_port_hint;

  /// No description provided for @music_settings_apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get music_settings_apply;

  /// No description provided for @music_settings_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get music_settings_retry;

  /// No description provided for @music_settings_invalid_positive.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number greater than 0.'**
  String get music_settings_invalid_positive;

  /// No description provided for @music_settings_invalid_nonnegative.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number of 0 or more.'**
  String get music_settings_invalid_nonnegative;

  /// No description provided for @music_settings_invalid_port.
  ///
  /// In en, this message translates to:
  /// **'Enter a port from 1 to 65535.'**
  String get music_settings_invalid_port;

  /// No description provided for @music_settings_server_stopped.
  ///
  /// In en, this message translates to:
  /// **'Server is off'**
  String get music_settings_server_stopped;

  /// No description provided for @music_settings_server_starting.
  ///
  /// In en, this message translates to:
  /// **'Starting server…'**
  String get music_settings_server_starting;

  /// No description provided for @music_settings_server_running.
  ///
  /// In en, this message translates to:
  /// **'Listening at {address}'**
  String music_settings_server_running(String address);

  /// No description provided for @music_settings_server_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the server. Check whether another app or OBS source is using this port, or choose another port.'**
  String get music_settings_server_failed;

  /// No description provided for @music_settings_reward_error.
  ///
  /// In en, this message translates to:
  /// **'Could not update the Twitch reward. Check the connection and retry.'**
  String get music_settings_reward_error;

  /// No description provided for @overlay_settings_collapse_title.
  ///
  /// In en, this message translates to:
  /// **'Auto-collapse'**
  String get overlay_settings_collapse_title;

  /// No description provided for @overlay_settings_never_collapse.
  ///
  /// In en, this message translates to:
  /// **'Never collapse'**
  String get overlay_settings_never_collapse;

  /// No description provided for @overlay_settings_stays_expanded.
  ///
  /// In en, this message translates to:
  /// **'The player stays expanded while it has content.'**
  String get overlay_settings_stays_expanded;

  /// No description provided for @overlay_settings_collapse_description.
  ///
  /// In en, this message translates to:
  /// **'Time before switching to compact mode. Hovering keeps the player expanded.'**
  String get overlay_settings_collapse_description;

  /// No description provided for @overlay_settings_seconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String overlay_settings_seconds(int seconds);

  /// No description provided for @overlay_settings_save_error.
  ///
  /// In en, this message translates to:
  /// **'Could not save the setting. Please try again.'**
  String get overlay_settings_save_error;

  /// No description provided for @overlay_settings_reward_title.
  ///
  /// In en, this message translates to:
  /// **'Reward button'**
  String get overlay_settings_reward_title;

  /// No description provided for @overlay_settings_reward_description.
  ///
  /// In en, this message translates to:
  /// **'Choose an app-managed reward that requires viewer input and keeps redemptions in the queue. Refresh after editing it on Twitch.'**
  String get overlay_settings_reward_description;

  /// No description provided for @overlay_settings_create_reward.
  ///
  /// In en, this message translates to:
  /// **'Create New'**
  String get overlay_settings_create_reward;

  /// No description provided for @overlay_settings_refresh_rewards.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get overlay_settings_refresh_rewards;

  /// No description provided for @overlay_settings_loading_rewards.
  ///
  /// In en, this message translates to:
  /// **'Loading Twitch rewards…'**
  String get overlay_settings_loading_rewards;

  /// No description provided for @overlay_settings_no_rewards_title.
  ///
  /// In en, this message translates to:
  /// **'No app-managed rewards yet'**
  String get overlay_settings_no_rewards_title;

  /// No description provided for @overlay_settings_no_rewards_body.
  ///
  /// In en, this message translates to:
  /// **'Create a default music request reward, then customize it on Twitch and refresh this list.'**
  String get overlay_settings_no_rewards_body;

  /// No description provided for @overlay_settings_load_error.
  ///
  /// In en, this message translates to:
  /// **'Could not load Twitch rewards'**
  String get overlay_settings_load_error;

  /// No description provided for @tts_description.
  ///
  /// In en, this message translates to:
  /// **'Read viewers’ messages aloud for Channel Points.'**
  String get tts_description;

  /// No description provided for @tts_enabled.
  ///
  /// In en, this message translates to:
  /// **'TTS processing'**
  String get tts_enabled;

  /// No description provided for @tts_on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get tts_on;

  /// No description provided for @tts_off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get tts_off;

  /// No description provided for @tts_base_url.
  ///
  /// In en, this message translates to:
  /// **'Service URL'**
  String get tts_base_url;

  /// No description provided for @tts_url_hint.
  ///
  /// In en, this message translates to:
  /// **'Include the API version, for example https://api.teamplay.com.ua/tts/v1'**
  String get tts_url_hint;

  /// No description provided for @tts_apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get tts_apply;

  /// No description provided for @tts_invalid_url.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTP(S) URL without a query or fragment.'**
  String get tts_invalid_url;

  /// No description provided for @tts_mood.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get tts_mood;

  /// No description provided for @tts_volume.
  ///
  /// In en, this message translates to:
  /// **'Speech volume'**
  String get tts_volume;

  /// No description provided for @tts_volume_hint.
  ///
  /// In en, this message translates to:
  /// **'Applies to speech only. The notification sound keeps its volume.'**
  String get tts_volume_hint;

  /// No description provided for @tts_neutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get tts_neutral;

  /// No description provided for @tts_calm.
  ///
  /// In en, this message translates to:
  /// **'Calm'**
  String get tts_calm;

  /// No description provided for @tts_lively.
  ///
  /// In en, this message translates to:
  /// **'Lively'**
  String get tts_lively;

  /// No description provided for @tts_service.
  ///
  /// In en, this message translates to:
  /// **'Last service status'**
  String get tts_service;

  /// No description provided for @tts_available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get tts_available;

  /// No description provided for @tts_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get tts_unavailable;

  /// No description provided for @tts_unknown.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet'**
  String get tts_unknown;

  /// No description provided for @tts_check.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get tts_check;

  /// No description provided for @tts_agents.
  ///
  /// In en, this message translates to:
  /// **'{healthy} healthy / {connected} connected agents'**
  String tts_agents(int healthy, int connected);

  /// No description provided for @tts_last_check.
  ///
  /// In en, this message translates to:
  /// **'Checked at {time} · updates every minute'**
  String tts_last_check(String time);

  /// No description provided for @tts_reward_description.
  ///
  /// In en, this message translates to:
  /// **'Choose a text-input reward. It pauses automatically when TTS is unavailable.'**
  String get tts_reward_description;

  /// No description provided for @tts_reward_empty.
  ///
  /// In en, this message translates to:
  /// **'Create a TTS reward, or choose one managed by this app.'**
  String get tts_reward_empty;

  /// No description provided for @tts_music_conflict.
  ///
  /// In en, this message translates to:
  /// **'Used for music requests'**
  String get tts_music_conflict;

  /// No description provided for @tts_reward_conflict.
  ///
  /// In en, this message translates to:
  /// **'Used for TTS'**
  String get tts_reward_conflict;

  /// No description provided for @tts_announcement.
  ///
  /// In en, this message translates to:
  /// **'Notification sound → 1 second pause → speech'**
  String get tts_announcement;

  /// No description provided for @tts_disabled.
  ///
  /// In en, this message translates to:
  /// **'TTS processing is off'**
  String get tts_disabled;

  /// No description provided for @tts_no_reward.
  ///
  /// In en, this message translates to:
  /// **'Choose a Twitch reward'**
  String get tts_no_reward;

  /// No description provided for @tts_twitch_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Twitch event connection is unavailable'**
  String get tts_twitch_unavailable;

  /// No description provided for @tts_audio_unavailable.
  ///
  /// In en, this message translates to:
  /// **'OBS audio is unavailable'**
  String get tts_audio_unavailable;

  /// No description provided for @tts_queue_full.
  ///
  /// In en, this message translates to:
  /// **'TTS queue is full'**
  String get tts_queue_full;

  /// No description provided for @tts_reward_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Reward is paused, disabled or incompatible'**
  String get tts_reward_unavailable;

  /// No description provided for @tts_no_agents.
  ///
  /// In en, this message translates to:
  /// **'No healthy agents available'**
  String get tts_no_agents;

  /// No description provided for @tts_timeout.
  ///
  /// In en, this message translates to:
  /// **'Speech request timed out'**
  String get tts_timeout;

  /// No description provided for @tts_invalid_text.
  ///
  /// In en, this message translates to:
  /// **'Enter between 1 and 1024 characters'**
  String get tts_invalid_text;

  /// No description provided for @tts_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the text aloud'**
  String get tts_failed;

  /// No description provided for @tts_canceled.
  ///
  /// In en, this message translates to:
  /// **'Speech canceled'**
  String get tts_canceled;

  /// No description provided for @tts_agents_unknown.
  ///
  /// In en, this message translates to:
  /// **'Agent count is unknown'**
  String get tts_agents_unknown;

  /// No description provided for @tts_settlement_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the request on Twitch. A moderator needs to resolve it.'**
  String get tts_settlement_failed;

  /// No description provided for @tts_operation_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not complete the operation. Please try again.'**
  String get tts_operation_failed;

  /// No description provided for @tts_test.
  ///
  /// In en, this message translates to:
  /// **'Test through OBS'**
  String get tts_test;

  /// No description provided for @tts_test_text.
  ///
  /// In en, this message translates to:
  /// **'Text to read aloud'**
  String get tts_test_text;

  /// No description provided for @tts_test_default.
  ///
  /// In en, this message translates to:
  /// **'Hello! This is a text-to-speech test.'**
  String get tts_test_default;

  /// No description provided for @tts_stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get tts_stop;

  /// No description provided for @tts_working.
  ///
  /// In en, this message translates to:
  /// **'Processing: {name}'**
  String tts_working(String name);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
