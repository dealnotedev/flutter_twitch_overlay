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
  String get music_requests_paused => 'MUSIC REQUESTS PAUSED';

  @override
  String get music_queue_status_waiting => 'waiting';

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
  String music_error_operation_failed(String requester) {
    return '$requester: couldn\'t prepare this track. Please try again later.';
  }

  @override
  String get music_control_title => 'Music controller';

  @override
  String get music_error_youtube_access =>
      'Requests are paused: YouTube asked for verification. Waiting tracks will continue or be refunded.';

  @override
  String get music_error_youtube_download_blocked =>
      'Requests are paused: YouTube blocked audio downloads. Waiting tracks will continue or be refunded.';

  @override
  String get music_error_youtube_rate_limited =>
      'Requests are paused: YouTube temporarily limited requests. Waiting tracks will continue or be refunded.';

  @override
  String music_error_youtube_unavailable(String requester) {
    return '$requester: this video is unavailable. Please choose another.';
  }

  @override
  String get music_youtube_title => 'YouTube connection';

  @override
  String get music_youtube_description =>
      'If YouTube asks for verification, connect it here. Your YouTube session is saved only on this computer.';

  @override
  String get music_youtube_disconnected =>
      'Public tracks work without signing in until YouTube asks for verification.';

  @override
  String get music_youtube_opening => 'Preparing the YouTube connection…';

  @override
  String get music_youtube_instructions =>
      '1. Open and play the requested video in the browser window that opened. If the YouTube homepage opened, choose a short public video.\n2. Complete any verification. You can try checking the connection without signing in first.\n3. Leave the video tab open, return here and press Check connection. The window closes when the check starts.';

  @override
  String get music_youtube_account_warning =>
      'If you sign in, use a secondary Google account: YouTube may restrict accounts used for downloading.';

  @override
  String get music_youtube_checking =>
      'Checking YouTube access and audio download…';

  @override
  String get music_youtube_connected =>
      'YouTube connected. Waiting requests continue automatically.';

  @override
  String get music_youtube_saved =>
      'A YouTube session is saved on this computer and used for music requests.';

  @override
  String get music_youtube_saved_attention =>
      'A YouTube session is saved, but the last check or request failed. See the reason below.';

  @override
  String get music_youtube_connect => 'Connect YouTube';

  @override
  String get music_youtube_reconnect => 'Reconnect YouTube';

  @override
  String get music_youtube_reopen => 'Reopen YouTube';

  @override
  String get music_youtube_verify => 'Check connection';

  @override
  String get music_youtube_cancel => 'Cancel';

  @override
  String get music_youtube_disconnect => 'Disconnect';

  @override
  String get music_youtube_disconnect_confirm =>
      'Remove the saved YouTube session and the dedicated browser profile, including any Google sign-in there?';

  @override
  String get music_youtube_disconnect_remove => 'Remove';

  @override
  String get music_youtube_disconnect_keep => 'Keep';

  @override
  String get music_youtube_hold_title => 'Music requests are paused';

  @override
  String music_youtube_hold_body(int count, int minutes) {
    return 'Waiting requests: $count. The Twitch reward is paused meanwhile. A request that waits longer than $minutes min is refunded.';
  }

  @override
  String get music_youtube_resume => 'Resume requests';

  @override
  String get music_youtube_no_browser =>
      'Install Microsoft Edge or Google Chrome, then press Connect YouTube again.';

  @override
  String get music_youtube_browser_closed =>
      'The YouTube window was closed. Open YouTube again and keep the window open until you press Check connection.';

  @override
  String get music_youtube_verification_required =>
      'YouTube asked to confirm you\'re not a bot. Open YouTube with the button below, complete the verification in that window, then check the connection.';

  @override
  String get music_youtube_download_blocked =>
      'YouTube blocked the audio download (403). A newer application version with an updated yt-dlp often fixes this. You can also open YouTube below, sign in with a secondary Google account in that window and check again; this can help but doesn\'t guarantee access.';

  @override
  String get music_youtube_rate_limited =>
      'YouTube temporarily limited requests from this computer, usually for up to an hour. Wait, then press Resume requests. A new connection rarely helps right away.';

  @override
  String get music_youtube_network_error =>
      'Couldn\'t reach YouTube. Check your internet connection and try again.';

  @override
  String get music_youtube_tools_error =>
      'Music components are missing or unavailable. Reinstall the latest full version of the application.';

  @override
  String get music_youtube_storage_error =>
      'Couldn\'t save the YouTube connection. Check that your user folder is writable and try again.';

  @override
  String get music_youtube_choose_video =>
      'Leave only the video you want to check open in the YouTube window, close other video tabs, then check again.';

  @override
  String get music_youtube_video_unavailable =>
      'YouTube won\'t let the player access this video. Open YouTube, choose another public video and check again.';

  @override
  String get music_youtube_video_too_long =>
      'This video exceeds your track duration limit or is a live stream. Open YouTube and choose a shorter video, or increase the duration limit below, then check again.';

  @override
  String music_youtube_checked_video(String url) {
    return 'Checked video: $url';
  }

  @override
  String get music_youtube_error_details => 'Error details';

  @override
  String get music_youtube_check_error =>
      'Couldn\'t prepare the audio. Open Error details to find the cause before trying again.';

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
      'Music requests, playback, appearance and the local controller.';

  @override
  String get overlay_settings_avatar => 'Avatar';

  @override
  String get avatar_settings_description =>
      'Avatar resolution and animation rendering for follow, raid and subscription alerts. Changes apply immediately.';

  @override
  String get avatar_settings_resolution => 'Avatar resolution';

  @override
  String get avatar_settings_resolution_hint =>
      'Higher resolution adds more detail and increases rendering load.';

  @override
  String get avatar_settings_renderer => 'Animation renderer';

  @override
  String get avatar_settings_renderer_optimized => 'Optimized';

  @override
  String get avatar_settings_renderer_legacy => 'Classic';

  @override
  String get avatar_settings_renderer_hint =>
      'The renderer applies to avatars, text and pixel effects in alerts.';

  @override
  String get music_settings_enabled => 'Accept music requests';

  @override
  String get music_settings_enabled_hint =>
      'Turning this off pauses the Twitch reward. Accepted tracks keep playing; late requests are refunded.';

  @override
  String get music_settings_volume => 'Music volume';

  @override
  String get music_settings_limits => 'Queue and cache';

  @override
  String get music_settings_queue => 'Maximum number of tracks';

  @override
  String get music_settings_queue_hint =>
      'Includes the playing track. Changing the limit keeps accepted requests.';

  @override
  String get music_settings_duration => 'Maximum track duration (seconds)';

  @override
  String get music_settings_duration_hint =>
      '60–1200 seconds (1–20 minutes). Applies to new requests.';

  @override
  String get music_settings_cache => 'Cache size';

  @override
  String music_settings_cache_mb(int size) {
    return '$size MB';
  }

  @override
  String music_settings_cache_gb(int size) {
    return '$size GB';
  }

  @override
  String get music_settings_cache_hint =>
      '128 MB–2 GB. Old unused files are removed first; tracks used this session are kept.';

  @override
  String get music_settings_server => 'Local music controller server';

  @override
  String get music_settings_server_hint =>
      'Allows the separate music controller to connect on this computer. Playback continues when the server is off.';

  @override
  String get music_settings_port => 'Server port';

  @override
  String get music_settings_port_hint =>
      'Use the same port in the controller. Applying a new port reconnects the server immediately.';

  @override
  String get music_settings_apply => 'Apply';

  @override
  String get music_settings_retry => 'Retry';

  @override
  String get music_settings_invalid_port => 'Enter a port from 1 to 65535.';

  @override
  String get music_settings_server_stopped => 'Server is off';

  @override
  String get music_settings_server_starting => 'Starting server…';

  @override
  String music_settings_server_running(String address) {
    return 'Listening at $address';
  }

  @override
  String get music_settings_server_failed =>
      'Could not start the server. Check whether another app or OBS source is using this port, or choose another port.';

  @override
  String get music_settings_reward_error =>
      'Could not update the Twitch reward. Check the connection and retry.';

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
  String get overlay_settings_collapse_delay => 'Collapse delay';

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
  String get settings_on => 'On';

  @override
  String get settings_off => 'Off';

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
  String raid_text(String broadcaster, int raiders) {
    return '$broadcaster is raiding with a party of $raiders';
  }

  @override
  String get settings_group_overlay => 'Overlay';

  @override
  String get settings_group_alerts => 'Alerts';

  @override
  String get settings_group_effects => 'Channel points';

  @override
  String get settings_group_integrations => 'Integrations';

  @override
  String get settings_follow => 'Follows';

  @override
  String get settings_follow_description =>
      'New followers in the center of the stream.';

  @override
  String get settings_raid => 'Raids';

  @override
  String get settings_raid_description =>
      'Incoming raids in the center of the stream.';

  @override
  String get settings_subscriptions => 'Subscriptions';

  @override
  String get settings_subscriptions_description =>
      'New subscriptions, resubscriptions and gifts. Shares the queue with follows and raids.';

  @override
  String get settings_reward_cards => 'Reward cards';

  @override
  String get settings_reward_cards_description =>
      'A card on the left for every channel points redemption.';

  @override
  String get settings_chat => 'Chat messages';

  @override
  String get settings_chat_description =>
      'Animals carry highlighted messages and the first message of every viewer in this session.';

  @override
  String get settings_flashbang => 'Flashbang';

  @override
  String get settings_flashbang_description =>
      'A grenade flies in and blinds the screen.';

  @override
  String get settings_crt => 'Screen off';

  @override
  String get settings_crt_description =>
      'The screen switches off like an old TV and shows who did it. Another redemption extends the time.';

  @override
  String get settings_pause => 'Pause';

  @override
  String get settings_pause_description =>
      'A pixel picture assembles over the pause. The viewer enters minutes or m:ss and a message; 0 removes the pause.';

  @override
  String get settings_stickers => 'Stickers and crosshair';

  @override
  String get settings_stickers_description =>
      'One reward shows a moving crosshair, the other spits a sticker where it points.';

  @override
  String get settings_kills => 'Kill counter';

  @override
  String get settings_kills_description =>
      'Local HTTP endpoint for a kill tracker: GET /kill?text=…&in_match=…&in_match_streak=…&total_streak=…';

  @override
  String get settings_enabled => 'Enabled';

  @override
  String get settings_style => 'Look';

  @override
  String get settings_style_pixel => 'Pixels';

  @override
  String get settings_sound => 'Sound';

  @override
  String get settings_sound_classic => 'Classic';

  @override
  String get settings_sound_none => 'No sound';

  @override
  String get settings_volume => 'Volume';

  @override
  String settings_percent(int value) {
    return '$value %';
  }

  @override
  String settings_minutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get settings_hold => 'Text stays';

  @override
  String get settings_flight_time => 'Flight time';

  @override
  String get settings_duration => 'Duration';

  @override
  String get follow_style_balloons => 'Balloons';

  @override
  String get follow_sound_modern => 'New';

  @override
  String get raid_style_classic => 'Classic with animals';

  @override
  String get raid_sound_voice => 'Viewer count voice';

  @override
  String get raid_min_viewers => 'Minimum viewers';

  @override
  String get raid_max_animals => 'Maximum animals';

  @override
  String get raid_max_animals_hint =>
      'One animal per viewer up to this limit. The text keeps the exact count.';

  @override
  String get subscriptions_new => 'New subscription';

  @override
  String get subscriptions_resub => 'Resubscription';

  @override
  String get subscriptions_gift => 'Gifts';

  @override
  String get subscriptions_show_avatar => 'Show avatar';

  @override
  String get subscriptions_sound_distinct => 'Distinct sounds';

  @override
  String get chat_highlighted => 'Highlighted messages';

  @override
  String get chat_first_message => 'First message of a viewer';

  @override
  String get effect_reward => 'Reward';

  @override
  String get effect_reward_none => 'Not bound';

  @override
  String effect_reward_missing(String title) {
    return '$title (not found)';
  }

  @override
  String get effect_rewards_unavailable => 'Connect Twitch to choose a reward.';

  @override
  String get flashbang_pro_chance => 'Golden flashbang chance';

  @override
  String get pause_max => 'Longest pause';

  @override
  String get sticker_reward => 'Spit a sticker';

  @override
  String get crosshair_reward => 'Take aim';

  @override
  String get crosshair_duration => 'Crosshair time';

  @override
  String get kills_address => 'Address';

  @override
  String get kills_port => 'Port';

  @override
  String get kills_apply => 'Apply';

  @override
  String get kills_invalid => 'Enter a valid IP address and port.';

  @override
  String kills_listening(String url) {
    return 'Listening on $url';
  }

  @override
  String get kills_stopped => 'The server is off.';

  @override
  String get preview_title => 'Preview';

  @override
  String get preview_on_air => 'Settings and preview are visible on stream.';

  @override
  String get preview_play => 'Play';

  @override
  String get preview_stop => 'Stop';

  @override
  String get preview_repeat => 'Repeat';

  @override
  String get preview_sound => 'Sound on stream';

  @override
  String get preview_short_name => 'Short name';

  @override
  String get preview_long_name => 'Long name';

  @override
  String get preview_viewers => 'Viewers:';

  @override
  String preview_new_subscription(int tier) {
    return 'New T$tier';
  }

  @override
  String preview_resubscription(int months) {
    return '$months months';
  }

  @override
  String preview_gift(int count) {
    return 'Gift ×$count';
  }

  @override
  String get preview_anonymous_gift => 'Anonymous gift';

  @override
  String get preview_short_title => 'Short title';

  @override
  String get preview_long_title => 'Long title';

  @override
  String get preview_emote => 'With emote';

  @override
  String get preview_normal => 'Normal';

  @override
  String get preview_golden => 'Golden';

  @override
  String get preview_remove => 'Remove';

  @override
  String get preview_random_sticker => 'Random sticker';

  @override
  String get preview_crosshair => 'Crosshair';

  @override
  String preview_streak(int streak) {
    return 'Streak $streak';
  }
}
