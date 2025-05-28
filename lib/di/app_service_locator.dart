import 'package:obssource/di/service_locator.dart';
import 'package:obssource/settings.dart';
import 'package:obssource/twitch/ws_manager.dart';

class AppServiceLocator extends ServiceLocator {
  static late final AppServiceLocator instance;

  static AppServiceLocator init(Settings settings) {
    instance = AppServiceLocator._(settings);
    return instance;
  }

  final Settings settings;
  final Map<Type, Object> map = {};

  AppServiceLocator._(this.settings) {
    final wsManager = WebSocketManager(
      'wss://eventsub.wss.twitch.tv/ws?keepalive_timeout_seconds=30',
      settings,
      listenChat: true,
    );

    map[Settings] = settings;
    map[ServiceLocator] = this;
    map[WebSocketManager] = wsManager;
  }

  @override
  T provide<T>() => map[T] as T;
}
