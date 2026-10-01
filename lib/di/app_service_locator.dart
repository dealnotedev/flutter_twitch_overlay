import 'dart:async';
import 'dart:io';

import 'package:obssource/config/obs_config.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/di/service_locator.dart';
import 'package:obssource/music/control/music_control_server_controller.dart';
import 'package:obssource/music/music_file_cache.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/music/music_reward_controller.dart';
import 'package:obssource/music/music_settings.dart';
import 'package:obssource/music/music_tool_paths.dart';
import 'package:obssource/music/obs_audio_music_track_player.dart';
import 'package:obssource/music/yt_dlp_music_track_fetcher.dart';
import 'package:obssource/secrets.dart';
import 'package:obssource/tts/tts_api.dart';
import 'package:obssource/tts/tts_controller.dart';
import 'package:obssource/tts/tts_player.dart';
import 'package:obssource/tts/tts_twitch.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/twitch_redemption_service.dart';
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
  late final StreamSubscription<MusicSettings> _musicSettingsSubscription;
  MusicControlServerController? musicControlServer;
  late final MusicRewardController musicRewardController;
  Future<void> _musicUpdates = Future.value();

  AppServiceLocator._(this.settings, this.config) {
    final wsManager = WebSocketManager(
      'wss://eventsub.wss.twitch.tv/ws?keepalive_timeout_seconds=30',
      settings,
    );

    final music = settings.music;
    final tools = MusicToolPaths.resolve(
      executableDirectory: File(Platform.resolvedExecutable).parent,
    );

    final musicCache = MusicFileCache(
      rootDirectory: defaultMusicCacheDirectory(),
      maxBytes: music.cacheMaxMb * 1024 * 1024,
    );

    final trackFetcher = YtDlpMusicTrackFetcher(
      executable: tools.ytDlpExecutable,
      ffmpegLocation: tools.ffmpegLocation,
      denoPath: tools.denoPath,
      cache: musicCache,
    );

    final musicPlayer = ObsAudioMusicTrackPlayer(
      volume: music.volumePercent / 100,
    );

    var ttsDucking = false;
    Future<void> applyMusicVolume() => musicPlayer.setVolume(
      settings.music.volumePercent /
          100 *
          (ttsDucking ? settings.music.ttsVolumePercent / 100 : 1),
    );

    final musicApi = TwitchApi(
      settings: settings,
      clientSecret: twitchClientSecret,
    );
    musicApi.dio.options
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 10)
      ..sendTimeout = const Duration(seconds: 10);

    final redemptionService = TwitchApiRedemptionService(
      api: musicApi,
      settings: settings,
    );

    final musicRequests = MusicRequestManager(
      events: wsManager.messages,
      fetcher: trackFetcher,
      player: musicPlayer,
      enabled: music.enabled,
      maxQueueLength: music.maxQueue,
      maxDuration: Duration(seconds: music.maxDurationSeconds),
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

    musicRewardController = MusicRewardController(
      settings: settings,
      connected: wsManager.rewardsReady,
      connectionChanges: wsManager.rewardsReadyChanges,
      pauseReward: (channel, reward, paused) async {
        if (settings.twitchAuth?.broadcasterId != channel) return;
        await musicApi.updateCustomReward(
          broadcasterUserId: channel,
          rewardId: reward,
          paused: paused,
        );
      },
    );

    final ttsApi = TwitchApi(
      settings: settings,
      clientSecret: twitchClientSecret,
    );

    final tts = TtsController(
      settings: settings,
      api: HttpTtsGateway(),
      twitch: ApiTtsTwitch(ttsApi, settings),
      player: ObsTtsPlayback(
        duckMusic: (active) {
          ttsDucking = active;
          return applyMusicVolume();
        },
      ),
      events: wsManager.messages,
      connected: wsManager.rewardsReady,
      connectionChanges: wsManager.rewardsReadyChanges,
    );

    map[TtsController] = tts;
    map[TtsRewardCatalog] = TtsRewardCatalog(api: ttsApi, settings: settings);

    musicControlServer = MusicControlServerController(requests: musicRequests);
    unawaited(
      musicControlServer?.configure(
        enabled: music.controlServerEnabled,
        port: music.controlServerPort,
      ),
    );

    _musicSettingsSubscription = settings.musicChanges.listen((value) {
      musicRequests.updateSettings(value);
      unawaited(
        applyMusicVolume().catchError((Object error) {
          stderr.writeln('Unable to change music volume: $error');
        }),
      );
      _musicUpdates = _musicUpdates
          .then((_) async {
            await musicCache.updateLimit(value.cacheMaxMb * 1024 * 1024);
          })
          .catchError((Object error) {
            stderr.writeln('Unable to update music cache limit: $error');
          });
      unawaited(
        musicControlServer?.configure(
          enabled: value.controlServerEnabled,
          port: value.controlServerPort,
        ),
      );
    });
  }

  @override
  T provide<T>() => map[T] as T;

  Future<void> close() async {
    await _musicSettingsSubscription.cancel();
    await _musicUpdates;
    await musicRewardController.close();
    await (map[TtsController]! as TtsController).close();
    await (map[WebSocketManager]! as WebSocketManager).close();
    await musicControlServer?.close();
    await (map[MusicRequests]! as MusicRequests).close();
  }
}
