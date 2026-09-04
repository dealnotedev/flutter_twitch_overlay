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
  /// **'Configure how viewers request music with Channel Points.'**
  String get overlay_settings_player_description;

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
