import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:obssource/config/obs_config.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/di/service_locator.dart';
import 'package:obssource/follow/follow_widget.dart';
import 'package:obssource/l10n/app_localizations.dart';
import 'package:obssource/local_server.dart';
import 'package:obssource/logged_widget.dart';
import 'package:obssource/pixels/pixel_rain_animator.dart';
import 'package:obssource/pixels/pixel_rain_avatar.dart';
import 'package:obssource/subs/subs_widget.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/twitch_creds.dart';
import 'package:obssource/twitch/ws_event.dart';
import 'package:obssource/twitch/ws_manager.dart';

void main() {
  testWidgets('simulates a freydis_in follow after five seconds', (
    tester,
  ) async {
    final settings = Settings();
    final config = ObsConfig();
    config.config.set(Config(valid: true, json: {'followers': true}));

    final websocket = _FakeWebSocketManager(settings);
    final locator = _FakeLocator({
      Settings: settings,
      ObsConfig: config,
      LocalServer: LocalServer(),
      WebSocketManager: websocket,
    });

    final creds = TwitchCreds(
      accessToken: 'unused',
      refreshToken: 'unused',
      broadcasterId: UserDto.dealnotedev.id,
      clientId: 'unused',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: LoggedWidget(
          locator: locator,
          creds: creds,
          avatarLoader: (_) async => img.Image(width: 64, height: 64),
        ),
      ),
    );

    expect(find.byType(FollowWidget), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(FollowWidget), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(FollowWidget), findsOneWidget);
    expect(
      tester.widget<FollowWidget>(find.byType(FollowWidget)).leavingMotion,
      AvatarPixelMotion.horizontalWaves,
    );
    expect(
      find.byKey(const ValueKey('follow_avatar_entering')),
      findsOneWidget,
    );
    final avatar = tester.widget<RainyAvatar>(
      find.byKey(const ValueKey('follow_avatar_entering')),
    );
    expect(avatar.pixelPadding, 0);
    expect(avatar.pixelRadius, const Radius.circular(1));

    final follow = tester.widget<SubsWidget>(find.byType(SubsWidget));
    expect(follow.who, UserDto.freydisIn.displayName);
    expect(follow.description, 'Thanks for the follow!');

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      if (find.byKey(const ValueKey('description')).evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.byKey(const ValueKey('description')), findsOneWidget);

    await tester.pump(const Duration(seconds: 11));
    expect(find.byKey(const ValueKey('heart')), findsOneWidget);
    expect(find.byKey(const ValueKey('heart_background')), findsOneWidget);
    expect(find.byKey(const ValueKey('follow_avatar_leaving')), findsOneWidget);

    await tester.pump(const Duration(seconds: 9));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _FakeWebSocketManager extends WebSocketManager {
  _FakeWebSocketManager(Settings settings)
    : super('ws://unused', settings, listenChat: false, listenSubs: false);

  @override
  WsState get currentState => WsState.connected;

  @override
  Stream<WsMessage> get messages => const Stream.empty();

  @override
  Stream<WsStateEvent> get state => const Stream.empty();
}

class _FakeLocator implements ServiceLocator {
  final Map<Type, Object> values;

  _FakeLocator(this.values);

  @override
  T provide<T>() => values[T] as T;
}
