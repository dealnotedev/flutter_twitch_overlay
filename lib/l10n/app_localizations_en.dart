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
  String get follow_thanks => 'Thanks for the follow!';

  @override
  String get subscription_anonymous => 'Anonymous';

  @override
  String subscription_thanks(int tier) {
    return 'thanks for the T$tier subscription!';
  }

  @override
  String subscription_resub_thanks(int months, int tier) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'months',
      one: 'month',
    );
    return 'thanks for $months $_temp0 of T$tier subscription!';
  }

  @override
  String subscription_gift(int tier) {
    return 'gifts a T$tier subscription!';
  }

  @override
  String subscription_gifts(int count, int tier) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'subscriptions',
      one: 'subscription',
    );
    return 'gifts $count T$tier $_temp0!';
  }

  @override
  String raid_viewers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'brought $count viewers',
      one: 'brought $count viewer',
    );
    return '$_temp0';
  }

  @override
  String get config_invalid => 'Invalid OBS config';

  @override
  String get music_queue_next => 'UP NEXT';

  @override
  String music_queue_more(int count) {
    return '+$count in queue';
  }

  @override
  String get music_playback_paused => 'Paused';

  @override
  String get music_playback_now_playing => 'Now playing';

  @override
  String get music_action_resume => 'Resume';

  @override
  String get music_action_pause => 'Pause';

  @override
  String get music_action_next => 'Next track';

  @override
  String get music_source_youtube => 'YouTube';

  @override
  String get music_preparing => 'PREPARING MUSIC';

  @override
  String get music_waiting_for_requests => 'WAITING FOR MUSIC REQUESTS';

  @override
  String get music_queue_status_resolving => 'searching';

  @override
  String get music_queue_status_downloading => 'downloading';

  @override
  String get music_queue_status_ready => 'ready';

  @override
  String music_error_missing_youtube_url(String requester) {
    return '$requester: add a YouTube URL';
  }

  @override
  String music_error_invalid_youtube_url(String requester) {
    return '$requester: invalid YouTube URL';
  }

  @override
  String music_error_queue_full(String requester) {
    return '$requester: the music queue is full';
  }

  @override
  String music_error_track_too_long_or_live(String requester) {
    return '$requester: the track is too long or is a live stream';
  }

  @override
  String music_error_operation_failed(String requester, String details) {
    return '$requester: $details';
  }

  @override
  String get music_control_title => 'Music controller';

  @override
  String get music_control_connected => 'Connected to the OBS overlay';

  @override
  String get music_control_connecting => 'Connecting to the OBS overlay…';

  @override
  String music_control_reconnecting(int attempt, int seconds) {
    return 'Reconnect attempt $attempt in ${seconds}s';
  }

  @override
  String get music_control_disconnected => 'OBS overlay is unavailable';

  @override
  String get music_control_incompatible =>
      'Controller and overlay versions are incompatible';

  @override
  String get music_control_closed => 'Connection closed';

  @override
  String get overlay_settings_title => 'Overlay settings';

  @override
  String get overlay_settings_sections => 'Sections';

  @override
  String get overlay_settings_player => 'Player';

  @override
  String get overlay_settings_player_description =>
      'Configure the player appearance and music requests with Channel Points.';

  @override
  String get overlay_settings_collapse_title => 'Auto-collapse';

  @override
  String get overlay_settings_never_collapse => 'Never collapse';

  @override
  String get overlay_settings_stays_expanded =>
      'The player stays expanded while it has content.';

  @override
  String get overlay_settings_collapse_description =>
      'Time before switching to compact mode. Hovering keeps the player expanded.';

  @override
  String overlay_settings_seconds(int seconds) {
    return '$seconds s';
  }

  @override
  String get overlay_settings_save_error =>
      'Could not save the setting. Please try again.';

  @override
  String get overlay_settings_reward_title => 'Reward button';

  @override
  String get overlay_settings_reward_description =>
      'Choose an app-managed reward that requires viewer input and keeps redemptions in the queue. Refresh after editing it on Twitch.';

  @override
  String get overlay_settings_create_reward => 'Create New';

  @override
  String get overlay_settings_refresh_rewards => 'Refresh';

  @override
  String get overlay_settings_loading_rewards => 'Loading Twitch rewards…';

  @override
  String get overlay_settings_no_rewards_title => 'No app-managed rewards yet';

  @override
  String get overlay_settings_no_rewards_body =>
      'Create a default music request reward, then customize it on Twitch and refresh this list.';

  @override
  String get overlay_settings_load_error => 'Could not load Twitch rewards';

  @override
  String get tts_description =>
      'Read viewers’ messages aloud for Channel Points.';

  @override
  String get tts_enabled => 'TTS processing';

  @override
  String get tts_on => 'On';

  @override
  String get tts_off => 'Off';

  @override
  String get tts_base_url => 'Service URL';

  @override
  String get tts_url_hint =>
      'Include the API version, for example https://api.teamplay.com.ua/tts/v1';

  @override
  String get tts_apply => 'Apply';

  @override
  String get tts_invalid_url =>
      'Enter a valid HTTP(S) URL without a query or fragment.';

  @override
  String get tts_mood => 'Mood';

  @override
  String get tts_volume => 'Speech volume';

  @override
  String get tts_volume_hint =>
      'Applies to speech only. The notification sound keeps its volume.';

  @override
  String get tts_neutral => 'Neutral';

  @override
  String get tts_calm => 'Calm';

  @override
  String get tts_lively => 'Lively';

  @override
  String get tts_service => 'Last service status';

  @override
  String get tts_available => 'Available';

  @override
  String get tts_unavailable => 'Unavailable';

  @override
  String get tts_unknown => 'Not checked yet';

  @override
  String get tts_check => 'Check now';

  @override
  String tts_agents(int healthy, int connected) {
    return '$healthy healthy / $connected connected agents';
  }

  @override
  String tts_last_check(String time) {
    return 'Checked at $time · updates every minute';
  }

  @override
  String get tts_reward_description =>
      'Choose a text-input reward. It pauses automatically when TTS is unavailable.';

  @override
  String get tts_reward_empty =>
      'Create a TTS reward, or choose one managed by this app.';

  @override
  String get tts_music_conflict => 'Used for music requests';

  @override
  String get tts_reward_conflict => 'Used for TTS';

  @override
  String get tts_announcement => 'Notification sound → 1 second pause → speech';

  @override
  String get tts_disabled => 'TTS processing is off';

  @override
  String get tts_no_reward => 'Choose a Twitch reward';

  @override
  String get tts_twitch_unavailable => 'Twitch event connection is unavailable';

  @override
  String get tts_audio_unavailable => 'OBS audio is unavailable';

  @override
  String get tts_queue_full => 'TTS queue is full';

  @override
  String get tts_reward_unavailable =>
      'Reward is paused, disabled or incompatible';

  @override
  String get tts_no_agents => 'No healthy agents available';

  @override
  String get tts_timeout => 'Speech request timed out';

  @override
  String get tts_invalid_text => 'Enter between 1 and 1024 characters';

  @override
  String get tts_failed => 'Could not read the text aloud';

  @override
  String get tts_canceled => 'Speech canceled';

  @override
  String get tts_agents_unknown => 'Agent count is unknown';

  @override
  String get tts_settlement_failed =>
      'Could not update the request on Twitch. A moderator needs to resolve it.';

  @override
  String get tts_operation_failed =>
      'Could not complete the operation. Please try again.';

  @override
  String get tts_test => 'Test through OBS';

  @override
  String get tts_test_text => 'Text to read aloud';

  @override
  String get tts_test_default => 'Hello! This is a text-to-speech test.';

  @override
  String get tts_stop => 'Stop';

  @override
  String tts_working(String name) {
    return 'Processing: $name';
  }
}
