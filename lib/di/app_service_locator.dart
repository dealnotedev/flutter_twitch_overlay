import 'package:obssource/di/service_locator.dart';
import 'package:obssource/local_server.dart';

class AppServiceLocator extends ServiceLocator {
  static late final AppServiceLocator instance;

  static AppServiceLocator init(LocalServer localServer) {
    instance = AppServiceLocator._(localServer);
    return instance;
  }

  final LocalServer localServer;

  final Map<Type, Object> map = {};

  AppServiceLocator._(this.localServer) {
    map[LocalServer] = localServer;
    map[ServiceLocator] = this;
  }

  @override
  T provide<T>() => map[T] as T;
}