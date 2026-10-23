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

  /// No description provided for @twitch_login_failed.
  ///
  /// In en, this message translates to:
  /// **'Twitch sign-in could not finish. Please try again.'**
  String get twitch_login_failed;

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

  /// No description provided for @by_user.
  ///
  /// In en, this message translates to:
  /// **'by {user_avatar} {user}'**
  String by_user(String user_avatar, String user);

  /// No description provided for @user_now_following_title.
  ///
  /// In en, this message translates to:
  /// **'{user_avatar} {user} just followed!'**
  String user_now_following_title(String user_avatar, String user);

  /// No description provided for @chat_message_first.
  ///
  /// In en, this message translates to:
  /// **'First message'**
  String get chat_message_first;

  /// No description provided for @chat_message_highlighted.
  ///
  /// In en, this message translates to:
  /// **'Highlighted'**
  String get chat_message_highlighted;

  /// No description provided for @config_invalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid OBS config'**
  String get config_invalid;

  /// No description provided for @raid_text.
  ///
  /// In en, this message translates to:
  /// **'{broadcaster} is raiding with a party of {raiders}'**
  String raid_text(String broadcaster, int raiders);

  /// No description provided for @subscription_subscribe_description.
  ///
  /// In en, this message translates to:
  /// **'is now Tier {tier} subscriber'**
  String subscription_subscribe_description(String tier);

  /// No description provided for @subscription_gift_description.
  ///
  /// In en, this message translates to:
  /// **'is gifting {count} Tier {tier} Subs'**
  String subscription_gift_description(String tier, int count);

  /// No description provided for @subscription_message_description.
  ///
  /// In en, this message translates to:
  /// **'subscribed at Tier {tier} for {months} months'**
  String subscription_message_description(String tier, int months);

  /// No description provided for @subscription_anonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get subscription_anonymous;

  /// No description provided for @music_settings_player_style.
  ///
  /// In en, this message translates to:
  /// **'Player appearance'**
  String get music_settings_player_style;

  /// No description provided for @music_settings_style_cosmic.
  ///
  /// In en, this message translates to:
  /// **'Cosmic'**
  String get music_settings_style_cosmic;

  /// No description provided for @music_settings_style_turntable.
  ///
  /// In en, this message translates to:
  /// **'Vinyl turntable'**
  String get music_settings_style_turntable;

  /// No description provided for @music_settings_style_hint.
  ///
  /// In en, this message translates to:
  /// **'Vinyl waits for the audio to load, then places the needle before starting playback. Collapse settings apply to the cosmic player.'**
  String get music_settings_style_hint;

  /// No description provided for @music_turntable_preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing the record'**
  String get music_turntable_preparing;

  /// No description provided for @music_turntable_cueing.
  ///
  /// In en, this message translates to:
  /// **'Placing the needle'**
  String get music_turntable_cueing;

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

  /// No description provided for @music_requests_paused.
  ///
  /// In en, this message translates to:
  /// **'MUSIC REQUESTS PAUSED'**
  String get music_requests_paused;

  /// No description provided for @music_queue_status_waiting.
  ///
  /// In en, this message translates to:
  /// **'waiting'**
  String get music_queue_status_waiting;

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
  /// **'{requester}: couldn\'t prepare this track. Please try again later.'**
  String music_error_operation_failed(String requester);

  /// No description provided for @music_control_title.
  ///
  /// In en, this message translates to:
  /// **'Music controller'**
  String get music_control_title;

  /// No description provided for @music_error_youtube_access.
  ///
  /// In en, this message translates to:
  /// **'Requests are paused: YouTube asked for verification. Waiting tracks will continue or be refunded.'**
  String get music_error_youtube_access;

  /// No description provided for @music_error_youtube_download_blocked.
  ///
  /// In en, this message translates to:
  /// **'Requests are paused: YouTube blocked audio downloads. Waiting tracks will continue or be refunded.'**
  String get music_error_youtube_download_blocked;

  /// No description provided for @music_error_youtube_rate_limited.
  ///
  /// In en, this message translates to:
  /// **'Requests are paused: YouTube temporarily limited requests. Waiting tracks will continue or be refunded.'**
  String get music_error_youtube_rate_limited;

  /// No description provided for @music_error_youtube_unavailable.
  ///
  /// In en, this message translates to:
  /// **'{requester}: this video is unavailable. Please choose another.'**
  String music_error_youtube_unavailable(String requester);

  /// No description provided for @music_youtube_title.
  ///
  /// In en, this message translates to:
  /// **'YouTube connection'**
  String get music_youtube_title;

  /// No description provided for @music_youtube_description.
  ///
  /// In en, this message translates to:
  /// **'If YouTube asks for verification, connect it here. Your YouTube session is saved only on this computer.'**
  String get music_youtube_description;

  /// No description provided for @music_youtube_disconnected.
  ///
  /// In en, this message translates to:
  /// **'Public tracks work without signing in until YouTube asks for verification.'**
  String get music_youtube_disconnected;

  /// No description provided for @music_youtube_opening.
  ///
  /// In en, this message translates to:
  /// **'Preparing the YouTube connection…'**
  String get music_youtube_opening;

  /// No description provided for @music_youtube_instructions.
  ///
  /// In en, this message translates to:
  /// **'1. Open and play the requested video in the browser window that opened. If the YouTube homepage opened, choose a short public video.\n2. Complete any verification. You can try checking the connection without signing in first.\n3. Leave the video tab open, return here and press Check connection. The window closes when the check starts.'**
  String get music_youtube_instructions;

  /// No description provided for @music_youtube_account_warning.
  ///
  /// In en, this message translates to:
  /// **'If you sign in, use a secondary Google account: YouTube may restrict accounts used for downloading.'**
  String get music_youtube_account_warning;

  /// No description provided for @music_youtube_checking.
  ///
  /// In en, this message translates to:
  /// **'Checking YouTube access and audio download…'**
  String get music_youtube_checking;

  /// No description provided for @music_youtube_connected.
  ///
  /// In en, this message translates to:
  /// **'YouTube connected. Waiting requests continue automatically.'**
  String get music_youtube_connected;

  /// No description provided for @music_youtube_saved.
  ///
  /// In en, this message translates to:
  /// **'A YouTube session is saved on this computer and used for music requests.'**
  String get music_youtube_saved;

  /// No description provided for @music_youtube_saved_attention.
  ///
  /// In en, this message translates to:
  /// **'A YouTube session is saved, but the last check or request failed. See the reason below.'**
  String get music_youtube_saved_attention;

  /// No description provided for @music_youtube_connect.
  ///
  /// In en, this message translates to:
  /// **'Connect YouTube'**
  String get music_youtube_connect;

  /// No description provided for @music_youtube_reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect YouTube'**
  String get music_youtube_reconnect;

  /// No description provided for @music_youtube_reopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen YouTube'**
  String get music_youtube_reopen;

  /// No description provided for @music_youtube_verify.
  ///
  /// In en, this message translates to:
  /// **'Check connection'**
  String get music_youtube_verify;

  /// No description provided for @music_youtube_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get music_youtube_cancel;

  /// No description provided for @music_youtube_disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get music_youtube_disconnect;

  /// No description provided for @music_youtube_disconnect_confirm.
  ///
  /// In en, this message translates to:
  /// **'Remove the saved YouTube session and the dedicated browser profile, including any Google sign-in there?'**
  String get music_youtube_disconnect_confirm;

  /// No description provided for @music_youtube_disconnect_remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get music_youtube_disconnect_remove;

  /// No description provided for @music_youtube_disconnect_keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get music_youtube_disconnect_keep;

  /// No description provided for @music_youtube_hold_title.
  ///
  /// In en, this message translates to:
  /// **'Music requests are paused'**
  String get music_youtube_hold_title;

  /// No description provided for @music_youtube_hold_body.
  ///
  /// In en, this message translates to:
  /// **'Waiting requests: {count}. The Twitch reward is paused meanwhile. A request that waits longer than {minutes} min is refunded.'**
  String music_youtube_hold_body(int count, int minutes);

  /// No description provided for @music_youtube_resume.
  ///
  /// In en, this message translates to:
  /// **'Resume requests'**
  String get music_youtube_resume;

  /// No description provided for @music_youtube_no_browser.
  ///
  /// In en, this message translates to:
  /// **'Install Microsoft Edge or Google Chrome, then press Connect YouTube again.'**
  String get music_youtube_no_browser;

  /// No description provided for @music_youtube_browser_closed.
  ///
  /// In en, this message translates to:
  /// **'The YouTube window was closed. Open YouTube again and keep the window open until you press Check connection.'**
  String get music_youtube_browser_closed;

  /// No description provided for @music_youtube_verification_required.
  ///
  /// In en, this message translates to:
  /// **'YouTube asked to confirm you\'re not a bot. Open YouTube with the button below, complete the verification in that window, then check the connection.'**
  String get music_youtube_verification_required;

  /// No description provided for @music_youtube_download_blocked.
  ///
  /// In en, this message translates to:
  /// **'YouTube blocked the audio download (403). A newer application version with an updated yt-dlp often fixes this. You can also open YouTube below, sign in with a secondary Google account in that window and check again; this can help but doesn\'t guarantee access.'**
  String get music_youtube_download_blocked;

  /// No description provided for @music_youtube_rate_limited.
  ///
  /// In en, this message translates to:
  /// **'YouTube temporarily limited requests from this computer, usually for up to an hour. Wait, then press Resume requests. A new connection rarely helps right away.'**
  String get music_youtube_rate_limited;

  /// No description provided for @music_youtube_network_error.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach YouTube. Check your internet connection and try again.'**
  String get music_youtube_network_error;

  /// No description provided for @music_youtube_tools_error.
  ///
  /// In en, this message translates to:
  /// **'Music components are missing or unavailable. Reinstall the latest full version of the application.'**
  String get music_youtube_tools_error;

  /// No description provided for @music_youtube_storage_error.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the YouTube connection. Check that your user folder is writable and try again.'**
  String get music_youtube_storage_error;

  /// No description provided for @music_youtube_choose_video.
  ///
  /// In en, this message translates to:
  /// **'Leave only the video you want to check open in the YouTube window, close other video tabs, then check again.'**
  String get music_youtube_choose_video;

  /// No description provided for @music_youtube_video_unavailable.
  ///
  /// In en, this message translates to:
  /// **'YouTube won\'t let the player access this video. Open YouTube, choose another public video and check again.'**
  String get music_youtube_video_unavailable;

  /// No description provided for @music_youtube_video_too_long.
  ///
  /// In en, this message translates to:
  /// **'This video exceeds your track duration limit or is a live stream. Open YouTube and choose a shorter video, or increase the duration limit below, then check again.'**
  String get music_youtube_video_too_long;

  /// No description provided for @music_youtube_checked_video.
  ///
  /// In en, this message translates to:
  /// **'Checked video: {url}'**
  String music_youtube_checked_video(String url);

  /// No description provided for @music_youtube_error_details.
  ///
  /// In en, this message translates to:
  /// **'Error details'**
  String get music_youtube_error_details;

  /// No description provided for @music_youtube_check_error.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t prepare the audio. Open Error details to find the cause before trying again.'**
  String get music_youtube_check_error;

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

  /// No description provided for @overlay_settings_avatar.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get overlay_settings_avatar;

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
  /// **'60–1200 seconds (1–20 minutes). Applies to new requests.'**
  String get music_settings_duration_hint;

  /// No description provided for @music_settings_cache.
  ///
  /// In en, this message translates to:
  /// **'Cache size'**
  String get music_settings_cache;

  /// No description provided for @music_settings_cache_mb.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String music_settings_cache_mb(int size);

  /// No description provided for @music_settings_cache_gb.
  ///
  /// In en, this message translates to:
  /// **'{size} GB'**
  String music_settings_cache_gb(int size);

  /// No description provided for @music_settings_cache_hint.
  ///
  /// In en, this message translates to:
  /// **'128 MB–2 GB. Old unused files are removed first; tracks used this session are kept.'**
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
  /// **'Preferred port. If it is busy, a free port is selected automatically. Use the listening address shown below in the controller.'**
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

  /// No description provided for @overlay_settings_collapse_delay.
  ///
  /// In en, this message translates to:
  /// **'Collapse delay'**
  String get overlay_settings_collapse_delay;

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

  /// No description provided for @music_source_title.
  ///
  /// In en, this message translates to:
  /// **'Player source'**
  String get music_source_title;

  /// No description provided for @music_source_local.
  ///
  /// In en, this message translates to:
  /// **'Local player'**
  String get music_source_local;

  /// No description provided for @music_source_external.
  ///
  /// In en, this message translates to:
  /// **'External player'**
  String get music_source_external;

  /// No description provided for @music_source_external_hint.
  ///
  /// In en, this message translates to:
  /// **'Connect to a player on this computer. Twitch Listener uses port 47822. Audio plays in the external application; capture it separately in OBS.'**
  String get music_source_external_hint;

  /// No description provided for @music_source_login_hint.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Twitch to configure a local music reward.'**
  String get music_source_login_hint;

  /// No description provided for @music_queue_status_analyzing.
  ///
  /// In en, this message translates to:
  /// **'ANALYZING'**
  String get music_queue_status_analyzing;

  /// No description provided for @music_queue_status_normalizing.
  ///
  /// In en, this message translates to:
  /// **'NORMALIZING'**
  String get music_queue_status_normalizing;

  /// No description provided for @settings_on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get settings_on;

  /// No description provided for @settings_off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settings_off;
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
