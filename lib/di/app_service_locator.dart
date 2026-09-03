import 'dart:async';
import 'dart:io';

import 'package:obssource/config/obs_config.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/di/service_locator.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/music/music_tool_paths.dart';
import 'package:obssource/music/obs_audio_music_track_player.dart';
import 'package:obssource/music/yt_dlp_music_track_fetcher.dart';
import 'package:obssource/twitch/ws_manager.dart';

class AppServiceLocator extends ServiceLocator {
  static late final AppServiceLocator instance;

  static AppServiceLocator init(Settings settings, ObsConfig config) {
    instance = AppServiceLocator._(settings, config);
    return instance;
  }

  final Settings settings;
  final ObsConfig config;
  final Map<Type, Object> map = {};
  late final StreamSubscription<Config> _musicVolumeSubscription;

  AppServiceLocator._(this.settings, this.config) {
    final wsManager = WebSocketManager(
      'wss://eventsub.wss.twitch.tv/ws?keepalive_timeout_seconds=30',
      settings,
    );
    final maxQueue = config.getInt('music_max_queue', fallback: 10);
    final maxDurationSeconds = config.getInt(
      'music_max_duration_seconds',
      fallback: 600,
    );
    final tools = MusicToolPaths.resolve(
      executableDirectory: File(Platform.resolvedExecutable).parent,
      ytDlpOverride: config.getString('music_ytdlp_path', fallback: ''),
      ffmpegOverride: config.getString('music_ffmpeg_location', fallback: ''),
      denoOverride: config.getString('music_deno_path', fallback: ''),
    );
    final cacheDirectory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}obssource_music',
    );
    final trackFetcher = YtDlpMusicTrackFetcher(
      executable: tools.ytDlpExecutable,
      ffmpegLocation: tools.ffmpegLocation,
      denoPath: tools.denoPath,
      cacheDirectory: cacheDirectory,
    );
    final musicPlayer = ObsAudioMusicTrackPlayer(volume: _musicVolume(config));
    final musicRequests = MusicRequestManager(
      events: wsManager.messages,
      fetcher: trackFetcher,
      player: musicPlayer,
      rewardTitle: config.getString(
        'music_reward_title',
        fallback: 'Play Music',
      ),
      enabled: config.getBool('music_enabled', fallback: true),
      maxQueueLength: maxQueue > 0 ? maxQueue : 10,
      maxDuration: Duration(
        seconds: maxDurationSeconds > 0 ? maxDurationSeconds : 600,
      ),
    );

    map[Settings] = settings;
    map[ObsConfig] = config;
    map[ServiceLocator] = this;
    map[WebSocketManager] = wsManager;
    map[ObsAudioMusicTrackPlayer] = musicPlayer;
    map[MusicRequests] = musicRequests;

    _musicVolumeSubscription = config.config.changes.listen((_) {
      unawaited(musicPlayer.setVolume(_musicVolume(config)));
    });
  }

  @override
  T provide<T>() => map[T] as T;

  Future<void> close() async {
    await _musicVolumeSubscription.cancel();
    await (map[MusicRequests]! as MusicRequests).close();
  }
}

double _musicVolume(ObsConfig config) {
  final percent = config.getInt('music_volume_percent', fallback: 70);
  return (percent / 100).clamp(0.0, 1.0).toDouble();
}
