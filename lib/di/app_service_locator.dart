import 'dart:async';
import 'dart:io';

import 'package:obssource/config/legacy_reward_binder.dart';
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
import 'package:obssource/music/youtube_browser_session.dart';
import 'package:obssource/music/youtube_connection_controller.dart';
import 'package:obssource/secrets.dart';
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
  late final StreamSubscription<Config> _obsConfigSubscription;
  late final StreamSubscription<void> _legacyRewardsSubscription;
  MusicControlServerController? musicControlServer;
  late final MusicRewardController musicRewardController;
  late final YoutubeConnectionController youtubeConnection;
  late final MusicRequestManager musicRequests;
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

    final sessionDirectory = Directory(
      '${musicCache.rootDirectory.parent.path}${Platform.pathSeparator}youtube-session',
    );

    final trackFetcher = YtDlpMusicTrackFetcher(
      executable: tools.ytDlpExecutable,
      ffmpegLocation: tools.ffmpegLocation,
      denoPath: tools.denoPath,
      cache: musicCache,
      cookies: () => youtubeConnection.leaseCookies(),
    );

    YtDlpMusicTrackFetcher? youtubeProbe;
    var youtubeProbeCanceled = false;
    youtubeConnection = YoutubeConnectionController(
      directory: sessionDirectory,
      browser: ManagedYoutubeBrowserSession(
        profileDirectory: Directory(
          '${sessionDirectory.path}${Platform.pathSeparator}browser',
        ),
      ),
      toolVersion: trackFetcher.readVersion,
      onConnected: () => musicRequests.resumePreparation(),
      cancelVerification: () async {
        youtubeProbeCanceled = true;
        await youtubeProbe?.cancel();
      },
      verifyAccess: (cookies, url, onProgress) async {
        youtubeProbeCanceled = false;
        // A private, empty cache: a cached track would skip the download and
        // report success even though YouTube blocks audio downloads.
        final checkCache = Directory(
          '${sessionDirectory.path}${Platform.pathSeparator}check',
        );
        if (await checkCache.exists()) await checkCache.delete(recursive: true);
        final probe = YtDlpMusicTrackFetcher(
          executable: tools.ytDlpExecutable,
          ffmpegLocation: tools.ffmpegLocation,
          denoPath: tools.denoPath,
          cache: MusicFileCache(rootDirectory: checkCache, maxBytes: 0),
          cookies: () async => YtDlpCookieFile(cookies),
          downloadTimeout: const Duration(minutes: 2),
        );
        youtubeProbe = probe;
        try {
          final metadata = await probe.inspect(url);
          if (youtubeProbeCanceled) return;
          // Also verify audio retrieval; a successful metadata request alone is
          // insufficient when YouTube blocks media downloads.
          if (metadata.duration >
              Duration(seconds: settings.music.maxDurationSeconds)) {
            throw const MusicTrackException(
              'Choose a video within the configured duration limit.',
              errorType: MusicQueueErrorType.trackTooLongOrLive,
            );
          }
          await probe.obtain(metadata: metadata, onProgress: onProgress);
        } finally {
          youtubeProbe = null;
          try {
            if (await checkCache.exists()) {
              await checkCache.delete(recursive: true);
            }
          } on FileSystemException {
            // Removed before the next check.
          }
        }
      },
    );

    final musicPlayer = ObsAudioMusicTrackPlayer(
      volume: music.volumePercent / 100,
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

    musicRequests = MusicRequestManager(
      events: wsManager.messages,
      fetcher: trackFetcher,
      player: musicPlayer,
      enabled: music.enabled,
      maxQueueLength: music.maxQueue,
      maxDuration: Duration(seconds: music.maxDurationSeconds),
      rewardId: settings.musicRewardId,
      rewardIdChanges: settings.musicRewardIdChanges,
      redemptionService: redemptionService,
      onPreparationHeld: youtubeConnection.requireCheck,
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
      requestsHeld: musicRequests.current.hold != null,
      requestsHeldChanges: musicRequests.states.map(
        (snapshot) => snapshot.hold != null,
      ),
      pauseReward: (channel, reward, paused) async {
        if (settings.twitchAuth?.broadcasterId != channel) return;
        await musicApi.updateCustomReward(
          broadcasterUserId: channel,
          rewardId: reward,
          paused: paused,
        );
      },
    );

    void importObsFlags(Config value) {
      final json = value.json;
      if (!value.valid || json is! Map<String, dynamic>) return;
      unawaited(
        settings.importLegacyObsFlags(json).catchError((Object error) {
          stderr.writeln('Unable to import OBS alert switches: $error');
        }),
      );
    }

    importObsFlags(config.config.current);
    _obsConfigSubscription = config.config.changes.listen(importObsFlags);

    final legacyRewards = LegacyRewardBinder(
      settings: settings,
      loadRewards: () async {
        final broadcasterId = settings.twitchAuth?.broadcasterId;
        if (broadcasterId == null) return const [];
        return musicApi.getCustomRewards(broadcasterUserId: broadcasterId);
      },
    );
    _legacyRewardsSubscription = settings.twitchAuthStream
        .where((creds) => creds?.broadcasterId != null)
        .asyncMap(
          (_) => legacyRewards.run().catchError((Object error) {
            stderr.writeln('Unable to bind legacy rewards: $error');
          }),
        )
        .listen(null);

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
        musicPlayer.setVolume(value.volumePercent / 100).catchError((
          Object error,
        ) {
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
    await _obsConfigSubscription.cancel();
    await _legacyRewardsSubscription.cancel();
    await _musicSettingsSubscription.cancel();
    await _musicUpdates;
    await musicRewardController.close();
    await (map[WebSocketManager]! as WebSocketManager).close();
    await musicControlServer?.close();
    await (map[MusicRequests]! as MusicRequests).close();
    await youtubeConnection.close();
  }
}
