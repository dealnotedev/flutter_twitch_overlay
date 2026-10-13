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

  /// No description provided for @avatar_settings_description.
  ///
  /// In en, this message translates to:
  /// **'Avatar resolution and animation rendering for follow, raid and subscription alerts. Changes apply immediately.'**
  String get avatar_settings_description;

  /// No description provided for @avatar_settings_resolution.
  ///
  /// In en, this message translates to:
  /// **'Avatar resolution'**
  String get avatar_settings_resolution;

  /// No description provided for @avatar_settings_resolution_hint.
  ///
  /// In en, this message translates to:
  /// **'Higher resolution adds more detail and increases rendering load.'**
  String get avatar_settings_resolution_hint;

  /// No description provided for @avatar_settings_renderer.
  ///
  /// In en, this message translates to:
  /// **'Animation renderer'**
  String get avatar_settings_renderer;

  /// No description provided for @avatar_settings_renderer_optimized.
  ///
  /// In en, this message translates to:
  /// **'Optimized'**
  String get avatar_settings_renderer_optimized;

  /// No description provided for @avatar_settings_renderer_legacy.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get avatar_settings_renderer_legacy;

  /// No description provided for @avatar_settings_renderer_hint.
  ///
  /// In en, this message translates to:
  /// **'The renderer applies to avatars, text and pixel effects in alerts.'**
  String get avatar_settings_renderer_hint;

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

  /// No description provided for @raid_text.
  ///
  /// In en, this message translates to:
  /// **'{broadcaster} is raiding with a party of {raiders}'**
  String raid_text(String broadcaster, int raiders);

  /// No description provided for @settings_group_overlay.
  ///
  /// In en, this message translates to:
  /// **'Overlay'**
  String get settings_group_overlay;

  /// No description provided for @settings_group_alerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get settings_group_alerts;

  /// No description provided for @settings_group_effects.
  ///
  /// In en, this message translates to:
  /// **'Channel points'**
  String get settings_group_effects;

  /// No description provided for @settings_group_integrations.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get settings_group_integrations;

  /// No description provided for @settings_follow.
  ///
  /// In en, this message translates to:
  /// **'Follows'**
  String get settings_follow;

  /// No description provided for @settings_follow_description.
  ///
  /// In en, this message translates to:
  /// **'New followers in the center of the stream.'**
  String get settings_follow_description;

  /// No description provided for @settings_raid.
  ///
  /// In en, this message translates to:
  /// **'Raids'**
  String get settings_raid;

  /// No description provided for @settings_raid_description.
  ///
  /// In en, this message translates to:
  /// **'Incoming raids in the center of the stream.'**
  String get settings_raid_description;

  /// No description provided for @settings_subscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get settings_subscriptions;

  /// No description provided for @settings_subscriptions_description.
  ///
  /// In en, this message translates to:
  /// **'New subscriptions, resubscriptions and gifts. Shares the queue with follows and raids.'**
  String get settings_subscriptions_description;

  /// No description provided for @settings_reward_cards.
  ///
  /// In en, this message translates to:
  /// **'Reward cards'**
  String get settings_reward_cards;

  /// No description provided for @settings_reward_cards_description.
  ///
  /// In en, this message translates to:
  /// **'A card on the left for every channel points redemption.'**
  String get settings_reward_cards_description;

  /// No description provided for @settings_chat.
  ///
  /// In en, this message translates to:
  /// **'Chat messages'**
  String get settings_chat;

  /// No description provided for @settings_chat_description.
  ///
  /// In en, this message translates to:
  /// **'Animals carry highlighted messages and the first message of every viewer in this session.'**
  String get settings_chat_description;

  /// No description provided for @settings_flashbang.
  ///
  /// In en, this message translates to:
  /// **'Flashbang'**
  String get settings_flashbang;

  /// No description provided for @settings_flashbang_description.
  ///
  /// In en, this message translates to:
  /// **'A grenade flies in and blinds the screen.'**
  String get settings_flashbang_description;

  /// No description provided for @settings_crt.
  ///
  /// In en, this message translates to:
  /// **'Screen off'**
  String get settings_crt;

  /// No description provided for @settings_crt_description.
  ///
  /// In en, this message translates to:
  /// **'The screen switches off like an old TV and shows who did it. Another redemption extends the time.'**
  String get settings_crt_description;

  /// No description provided for @settings_pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get settings_pause;

  /// No description provided for @settings_pause_description.
  ///
  /// In en, this message translates to:
  /// **'A pixel picture assembles over the pause. The viewer enters minutes or m:ss and a message; 0 removes the pause.'**
  String get settings_pause_description;

  /// No description provided for @settings_stickers.
  ///
  /// In en, this message translates to:
  /// **'Stickers and crosshair'**
  String get settings_stickers;

  /// No description provided for @settings_stickers_description.
  ///
  /// In en, this message translates to:
  /// **'One reward shows a moving crosshair, the other spits a sticker where it points.'**
  String get settings_stickers_description;

  /// No description provided for @settings_kills.
  ///
  /// In en, this message translates to:
  /// **'Kill counter'**
  String get settings_kills;

  /// No description provided for @settings_kills_description.
  ///
  /// In en, this message translates to:
  /// **'Local HTTP endpoint for a kill tracker: GET /kill?text=…&in_match=…&in_match_streak=…&total_streak=…'**
  String get settings_kills_description;

  /// No description provided for @settings_enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get settings_enabled;

  /// No description provided for @settings_style.
  ///
  /// In en, this message translates to:
  /// **'Look'**
  String get settings_style;

  /// No description provided for @settings_style_pixel.
  ///
  /// In en, this message translates to:
  /// **'Pixels'**
  String get settings_style_pixel;

  /// No description provided for @settings_sound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get settings_sound;

  /// No description provided for @settings_sound_classic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get settings_sound_classic;

  /// No description provided for @settings_sound_none.
  ///
  /// In en, this message translates to:
  /// **'No sound'**
  String get settings_sound_none;

  /// No description provided for @settings_volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get settings_volume;

  /// No description provided for @settings_percent.
  ///
  /// In en, this message translates to:
  /// **'{value} %'**
  String settings_percent(int value);

  /// No description provided for @settings_minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String settings_minutes(int minutes);

  /// No description provided for @settings_hold.
  ///
  /// In en, this message translates to:
  /// **'Text stays'**
  String get settings_hold;

  /// No description provided for @settings_flight_time.
  ///
  /// In en, this message translates to:
  /// **'Flight time'**
  String get settings_flight_time;

  /// No description provided for @settings_duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get settings_duration;

  /// No description provided for @follow_style_balloons.
  ///
  /// In en, this message translates to:
  /// **'Balloons'**
  String get follow_style_balloons;

  /// No description provided for @follow_sound_modern.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get follow_sound_modern;

  /// No description provided for @raid_style_classic.
  ///
  /// In en, this message translates to:
  /// **'Classic with animals'**
  String get raid_style_classic;

  /// No description provided for @raid_sound_voice.
  ///
  /// In en, this message translates to:
  /// **'Viewer count voice'**
  String get raid_sound_voice;

  /// No description provided for @raid_min_viewers.
  ///
  /// In en, this message translates to:
  /// **'Minimum viewers'**
  String get raid_min_viewers;

  /// No description provided for @raid_max_animals.
  ///
  /// In en, this message translates to:
  /// **'Maximum animals'**
  String get raid_max_animals;

  /// No description provided for @raid_max_animals_hint.
  ///
  /// In en, this message translates to:
  /// **'One animal per viewer up to this limit. The text keeps the exact count.'**
  String get raid_max_animals_hint;

  /// No description provided for @subscriptions_new.
  ///
  /// In en, this message translates to:
  /// **'New subscription'**
  String get subscriptions_new;

  /// No description provided for @subscriptions_resub.
  ///
  /// In en, this message translates to:
  /// **'Resubscription'**
  String get subscriptions_resub;

  /// No description provided for @subscriptions_gift.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get subscriptions_gift;

  /// No description provided for @subscriptions_show_avatar.
  ///
  /// In en, this message translates to:
  /// **'Show avatar'**
  String get subscriptions_show_avatar;

  /// No description provided for @subscriptions_sound_distinct.
  ///
  /// In en, this message translates to:
  /// **'Distinct sounds'**
  String get subscriptions_sound_distinct;

  /// No description provided for @chat_highlighted.
  ///
  /// In en, this message translates to:
  /// **'Highlighted messages'**
  String get chat_highlighted;

  /// No description provided for @chat_first_message.
  ///
  /// In en, this message translates to:
  /// **'First message of a viewer'**
  String get chat_first_message;

  /// No description provided for @effect_reward.
  ///
  /// In en, this message translates to:
  /// **'Reward'**
  String get effect_reward;

  /// No description provided for @effect_reward_none.
  ///
  /// In en, this message translates to:
  /// **'Not bound'**
  String get effect_reward_none;

  /// No description provided for @effect_reward_missing.
  ///
  /// In en, this message translates to:
  /// **'{title} (not found)'**
  String effect_reward_missing(String title);

  /// No description provided for @effect_rewards_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Connect Twitch to choose a reward.'**
  String get effect_rewards_unavailable;

  /// No description provided for @flashbang_pro_chance.
  ///
  /// In en, this message translates to:
  /// **'Golden flashbang chance'**
  String get flashbang_pro_chance;

  /// No description provided for @pause_max.
  ///
  /// In en, this message translates to:
  /// **'Longest pause'**
  String get pause_max;

  /// No description provided for @sticker_reward.
  ///
  /// In en, this message translates to:
  /// **'Spit a sticker'**
  String get sticker_reward;

  /// No description provided for @crosshair_reward.
  ///
  /// In en, this message translates to:
  /// **'Take aim'**
  String get crosshair_reward;

  /// No description provided for @crosshair_duration.
  ///
  /// In en, this message translates to:
  /// **'Crosshair time'**
  String get crosshair_duration;

  /// No description provided for @kills_address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get kills_address;

  /// No description provided for @kills_port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get kills_port;

  /// No description provided for @kills_apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get kills_apply;

  /// No description provided for @kills_invalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid IP address and port.'**
  String get kills_invalid;

  /// No description provided for @kills_listening.
  ///
  /// In en, this message translates to:
  /// **'Listening on {url}'**
  String kills_listening(String url);

  /// No description provided for @kills_stopped.
  ///
  /// In en, this message translates to:
  /// **'The server is off.'**
  String get kills_stopped;

  /// No description provided for @kills_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not listen on {url}: the address is unavailable or the port is busy.'**
  String kills_failed(String url);

  /// No description provided for @preview_title.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview_title;

  /// No description provided for @preview_on_air.
  ///
  /// In en, this message translates to:
  /// **'Settings and preview are visible on stream.'**
  String get preview_on_air;

  /// No description provided for @preview_play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get preview_play;

  /// No description provided for @preview_stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get preview_stop;

  /// No description provided for @preview_repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get preview_repeat;

  /// No description provided for @preview_sound.
  ///
  /// In en, this message translates to:
  /// **'Sound on stream'**
  String get preview_sound;

  /// No description provided for @preview_short_name.
  ///
  /// In en, this message translates to:
  /// **'Short name'**
  String get preview_short_name;

  /// No description provided for @preview_long_name.
  ///
  /// In en, this message translates to:
  /// **'Long name'**
  String get preview_long_name;

  /// No description provided for @preview_viewers.
  ///
  /// In en, this message translates to:
  /// **'Viewers:'**
  String get preview_viewers;

  /// No description provided for @preview_new_subscription.
  ///
  /// In en, this message translates to:
  /// **'New T{tier}'**
  String preview_new_subscription(int tier);

  /// No description provided for @preview_resubscription.
  ///
  /// In en, this message translates to:
  /// **'{months} months'**
  String preview_resubscription(int months);

  /// No description provided for @preview_gift.
  ///
  /// In en, this message translates to:
  /// **'Gift ×{count}'**
  String preview_gift(int count);

  /// No description provided for @preview_anonymous_gift.
  ///
  /// In en, this message translates to:
  /// **'Anonymous gift'**
  String get preview_anonymous_gift;

  /// No description provided for @preview_short_title.
  ///
  /// In en, this message translates to:
  /// **'Short title'**
  String get preview_short_title;

  /// No description provided for @preview_long_title.
  ///
  /// In en, this message translates to:
  /// **'Long title'**
  String get preview_long_title;

  /// No description provided for @preview_emote.
  ///
  /// In en, this message translates to:
  /// **'With emote'**
  String get preview_emote;

  /// No description provided for @preview_normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get preview_normal;

  /// No description provided for @preview_golden.
  ///
  /// In en, this message translates to:
  /// **'Golden'**
  String get preview_golden;

  /// No description provided for @preview_remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get preview_remove;

  /// No description provided for @preview_random_sticker.
  ///
  /// In en, this message translates to:
  /// **'Random sticker'**
  String get preview_random_sticker;

  /// No description provided for @preview_crosshair.
  ///
  /// In en, this message translates to:
  /// **'Crosshair'**
  String get preview_crosshair;

  /// No description provided for @preview_streak.
  ///
  /// In en, this message translates to:
  /// **'Streak {streak}'**
  String preview_streak(int streak);
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
