import 'dart:async';
import 'dart:io';

import 'package:obssource/config/settings.dart';
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

/// Owns local playback and Twitch settlement; views only see MusicRequests.
class LocalMusicRuntime {
  final Settings settings;
  late final MusicRequestManager requests;
  late final ObsAudioMusicTrackPlayer player;
  late final MusicFileCache cache;
  late final MusicControlServerController server;
  late final MusicRewardController reward;
  late final YoutubeConnectionController youtubeConnection;
  Future<void> _updates = Future.value();

  LocalMusicRuntime(this.settings, WebSocketManager wsManager) {
    final music = settings.music;
    final tools = MusicToolPaths.resolve(
      executableDirectory: File(Platform.resolvedExecutable).parent,
    );

    cache = MusicFileCache(
      rootDirectory: defaultMusicCacheDirectory(),
      maxBytes: music.cacheMaxMb * 1024 * 1024,
    );

    final sessionDirectory = Directory(
      '${cache.rootDirectory.parent.path}${Platform.pathSeparator}youtube-session',
    );

    final trackFetcher = YtDlpMusicTrackFetcher(
      executable: tools.ytDlpExecutable,
      ffmpegLocation: tools.ffmpegLocation,
      denoPath: tools.denoPath,
      cache: cache,
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
      onConnected: () => requests.resumePreparation(),
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

    player = ObsAudioMusicTrackPlayer(volume: music.volumePercent / 100);

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

    requests = MusicRequestManager(
      events: wsManager.messages,
      fetcher: trackFetcher,
      player: player,
      enabled: music.enabled,
      volume: music.volumePercent / 100,
      maxQueueLength: music.maxQueue,
      maxDuration: Duration(seconds: music.maxDurationSeconds),
      rewardId: settings.musicRewardId,
      rewardIdChanges: settings.musicRewardIdChanges,
      redemptionService: redemptionService,
      onPreparationHeld: youtubeConnection.requireCheck,
    );

    reward = MusicRewardController(
      settings: settings,
      connected: wsManager.rewardsReady,
      connectionChanges: wsManager.rewardsReadyChanges,
      requestsHeld: requests.current.hold != null,
      requestsHeldChanges: requests.states.map(
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

    server = MusicControlServerController(requests: requests);
    unawaited(
      server.configure(
        enabled: music.controlServerEnabled,
        port: music.controlServerPort,
      ),
    );
  }

  void updateSettings(MusicSettings value) {
    requests.updateSettings(value);
    unawaited(
      player.setVolume(value.volumePercent / 100).catchError((Object error) {
        stderr.writeln('Unable to change music volume: $error');
      }),
    );
    _updates = _updates
        .then((_) async {
          await cache.updateLimit(value.cacheMaxMb * 1024 * 1024);
        })
        .catchError((Object error) {
          stderr.writeln('Unable to update music cache limit: $error');
        });
    unawaited(
      server.configure(
        enabled: value.controlServerEnabled,
        port: value.controlServerPort,
      ),
    );
  }

  Future<void> close() async {
    // Cancel incoming requests immediately, while Twitch pauses the reward.
    await Future.wait([reward.close(), server.close(), requests.close()]);
    await _updates;
    await youtubeConnection.close();
  }
}
