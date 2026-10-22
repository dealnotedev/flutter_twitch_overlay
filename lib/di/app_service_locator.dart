import 'package:obssource/config/obs_config.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/di/service_locator.dart';
import 'package:obssource/music/control/music_control_server_controller.dart';
import 'package:obssource/music/local_music_runtime.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/music/music_reward_controller.dart';
import 'package:obssource/music/music_source_controller.dart';
import 'package:obssource/music/obs_audio_music_track_player.dart';
import 'package:obssource/music/youtube_connection_controller.dart';
import 'package:obssource/twitch/ws_manager.dart';

class AppServiceLocator extends ServiceLocator {
  static late final AppServiceLocator instance;
  static AppServiceLocator init(Settings settings, ObsConfig config) =>
      instance = AppServiceLocator._(settings, config);

  final Settings settings;
  final ObsConfig config;
  final Map<Type, Object> map = {};
  late final MusicSourceController musicSource;
  Future<void>? _closing;

  MusicControlServerController? get musicControlServer =>
      musicSource.local?.server;
  MusicRewardController? get musicRewardController => musicSource.local?.reward;
  YoutubeConnectionController? get youtubeConnection =>
      musicSource.local?.youtubeConnection;
  MusicRequestManager? get musicRequests => musicSource.local?.requests;

  AppServiceLocator._(this.settings, this.config) {
    final wsManager = WebSocketManager(
      'wss://eventsub.wss.twitch.tv/ws?keepalive_timeout_seconds=30',
      settings,
    );
    musicSource = MusicSourceController(
      settings: settings,
      createLocal: (_) => LocalMusicRuntime(settings, wsManager),
    );
    map[Settings] = settings;
    map[ObsConfig] = config;
    map[ServiceLocator] = this;
    map[WebSocketManager] = wsManager;
    map[MusicRequests] = musicSource;
    map[MusicSourceController] = musicSource;
  }

  @override
  T provide<T>() {
    if (T == ObsAudioMusicTrackPlayer) return musicSource.local!.player as T;
    return map[T] as T;
  }

  Future<void> close() =>
      _closing ??= () async {
        await musicSource.close();
        await provide<WebSocketManager>().close();
      }();
}
