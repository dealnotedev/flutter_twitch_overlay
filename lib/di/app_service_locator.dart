import 'dart:async';
import 'dart:io';

import 'package:obssource/config/obs_config.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/di/service_locator.dart';
import 'package:obssource/music/music_file_cache.dart';
import 'package:obssource/music/control/music_control_protocol.dart';
import 'package:obssource/music/control/music_control_server.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/music/music_tool_paths.dart';
import 'package:obssource/music/obs_audio_music_track_player.dart';
import 'package:obssource/music/yt_dlp_music_track_fetcher.dart';
import 'package:obssource/secrets.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/twitch_redemption_service.dart';
import 'package:obssource/twitch/ws_manager.dart';

class AppServiceLocator extends ServiceLocator {
  static late final AppServiceLocator instance;

  static AppServiceLocator init(
    Settings settings,
    ObsConfig config, {
    bool startMusicControlServer = false,
  }) {
    instance = AppServiceLocator._(
      settings,
      config,
      startMusicControlServer: startMusicControlServer,
    );
    return instance;
  }

  final Settings settings;
  final ObsConfig config;
  final Map<Type, Object> map = {};
  late final StreamSubscription<Config> _musicVolumeSubscription;
  MusicControlServer? _musicControlServer;

  AppServiceLocator._(
    this.settings,
    this.config, {
    required bool startMusicControlServer,
  }) {
    final wsManager = WebSocketManager(
      'wss://eventsub.wss.twitch.tv/ws?keepalive_timeout_seconds=30',
      settings,
    );
    final maxQueue = config.getInt('music_max_queue', fallback: 10);
    final maxDurationSeconds = config.getInt(
      'music_max_duration_seconds',
      fallback: 600,
    );
    final configuredCacheMaxMb = config.getInt(
      'music_cache_max_mb',
      fallback: 2048,
    );
    final cacheMaxMb = configuredCacheMaxMb < 0 ? 2048 : configuredCacheMaxMb;
    final tools = MusicToolPaths.resolve(
      executableDirectory: File(Platform.resolvedExecutable).parent,
      ytDlpOverride: config.getString('music_ytdlp_path', fallback: ''),
      ffmpegOverride: config.getString('music_ffmpeg_location', fallback: ''),
      denoOverride: config.getString('music_deno_path', fallback: ''),
    );
    final musicCache = MusicFileCache(
      rootDirectory: defaultMusicCacheDirectory(),
      maxBytes: cacheMaxMb * 1024 * 1024,
    );
    final trackFetcher = YtDlpMusicTrackFetcher(
      executable: tools.ytDlpExecutable,
      ffmpegLocation: tools.ffmpegLocation,
      denoPath: tools.denoPath,
      cache: musicCache,
    );
    final musicPlayer = ObsAudioMusicTrackPlayer(volume: _musicVolume(config));
    final redemptionService = TwitchApiRedemptionService(
      api: TwitchApi(settings: settings, clientSecret: twitchClientSecret),
      settings: settings,
    );
    final musicRequests = MusicRequestManager(
      events: wsManager.messages,
      fetcher: trackFetcher,
      player: musicPlayer,
      enabled: config.getBool('music_enabled', fallback: true),
      maxQueueLength: maxQueue > 0 ? maxQueue : 10,
      maxDuration: Duration(
        seconds: maxDurationSeconds > 0 ? maxDurationSeconds : 600,
      ),
      rewardId: settings.musicRewardId,
      rewardIdChanges: settings.musicRewardIdChanges,
      redemptionService: redemptionService,
    );

    map[Settings] = settings;
    map[ObsConfig] = config;
    map[ServiceLocator] = this;
    map[WebSocketManager] = wsManager;
    map[ObsAudioMusicTrackPlayer] = musicPlayer;
    map[TwitchRedemptionService] = redemptionService;
    map[MusicRequests] = musicRequests;

    if (startMusicControlServer &&
        config.getBool('music_control_server_enabled', fallback: true)) {
      final configuredPort = config.getInt(
        'music_control_server_port',
        fallback: MusicControlProtocol.defaultPort,
      );
      final server = MusicControlServer(
        requests: musicRequests,
        requestedPort:
            configuredPort > 0 && configuredPort <= 65535
                ? configuredPort
                : MusicControlProtocol.defaultPort,
      );
      _musicControlServer = server;
      map[MusicControlServer] = server;
      unawaited(
        server.start().catchError((Object error) {
          stderr.writeln('Unable to start music control server: $error');
        }),
      );
    }

    _musicVolumeSubscription = config.config.changes.listen((_) {
      unawaited(musicPlayer.setVolume(_musicVolume(config)));
    });
  }

  @override
  T provide<T>() => map[T] as T;

  Future<void> close() async {
    await _musicVolumeSubscription.cancel();
    await _musicControlServer?.close();
    await (map[MusicRequests]! as MusicRequests).close();
  }
}

double _musicVolume(ObsConfig config) {
  final percent = config.getInt('music_volume_percent', fallback: 70);
  return (percent / 100).clamp(0.0, 1.0).toDouble();
}
