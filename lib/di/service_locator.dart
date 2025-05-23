import 'package:obssource/di/app_service_locator.dart';

abstract class ServiceLocator {
  T provide<T>();

  static T get<T>() => AppServiceLocator.instance.provide<T>();
}
