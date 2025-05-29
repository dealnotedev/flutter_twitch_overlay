import 'package:obssource/config/obs_config.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/di/service_locator.dart';
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

  AppServiceLocator._(this.settings, this.config) {
    final wsManager = WebSocketManager(
      'wss://eventsub.wss.twitch.tv/ws?keepalive_timeout_seconds=30',
      settings,
      listenChat: true,
    );

    map[Settings] = settings;
    map[ObsConfig] = config;
    map[ServiceLocator] = this;
    map[WebSocketManager] = wsManager;
  }

  @override
  T provide<T>() => map[T] as T;
}
