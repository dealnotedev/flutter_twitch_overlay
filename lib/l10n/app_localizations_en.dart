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
      'Configure how viewers request music with Channel Points.';

  @override
  String get overlay_settings_reward_title => 'Reward button';

  @override
  String get overlay_settings_reward_description =>
      'Choose an app-managed Twitch reward. Refresh after editing rewards on Twitch.';

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
}
