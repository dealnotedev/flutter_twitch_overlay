import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:obssource/config/obs_config.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/di/service_locator.dart';
import 'package:obssource/follow/follow_widget.dart';
import 'package:obssource/l10n/app_localizations.dart';
import 'package:obssource/logged_widget.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/pixels/pixel_rain_animator.dart';
import 'package:obssource/pixels/pixel_rain_avatar.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/ws_event.dart';
import 'package:obssource/twitch/ws_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Settings settings;
  late ObsConfig config;
  late _FakeWebSocketManager websocket;
  late ServiceLocator locator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = Settings();
    await settings.init();
    config = ObsConfig();
    config.config.set(Config(valid: true, json: {'followers': true}));
    websocket = _FakeWebSocketManager(settings);
    locator = _FakeLocator({
      Settings: settings,
      ObsConfig: config,
      WebSocketManager: websocket,
    });
  });

  tearDown(() async {
    await websocket.close();
  });

  testWidgets('shows the invalid OBS config indicator only while invalid', (
    tester,
  ) async {
    config.config.set(Config(valid: false, json: const {}));

    await _pumpLoggedWidget(tester, locator);

    expect(
      find.byKey(const ValueKey('invalid_obs_config_indicator')),
      findsOneWidget,
    );
    expect(find.text('Invalid OBS config'), findsOneWidget);

    config.config.set(Config(valid: true, json: const {}));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('invalid_obs_config_indicator')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reveals overlay settings and selects a Twitch reward', (
    tester,
  ) async {
    final catalog = _FakeRewardCatalog([_reward(id: 'reward-1')]);
    await _pumpLoggedWidget(tester, locator, rewardCatalog: catalog);

    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('overlay_settings_button_reveal')),
          )
          .opacity,
      0,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('connection_indicator'))),
    );
    await tester.pump(const Duration(milliseconds: 180));

    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('overlay_settings_button_reveal')),
          )
          .opacity,
      1,
    );

    await tester.tap(find.byKey(const ValueKey('overlay_settings_button')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Overlay settings'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('overlay_settings_reward_wrap')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('twitch_reward_reward-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('twitch_reward_reward-1')));
    await tester.pump();
    expect(settings.musicRewardId, 'reward-1');

    await tester.tap(
      find.byKey(const ValueKey('overlay_settings_refresh_rewards')),
    );
    await tester.pump();
    await tester.pump();
    expect(catalog.loadCount, 2);

    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('creates and automatically selects a default Twitch reward', (
    tester,
  ) async {
    final catalog = _FakeRewardCatalog(
      const [],
      createdReward: _reward(id: 'created-reward'),
    );
    await _pumpLoggedWidget(tester, locator, rewardCatalog: catalog);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('connection_indicator'))),
    );
    await tester.pump(const Duration(milliseconds: 180));
    await tester.tap(find.byKey(const ValueKey('overlay_settings_button')));
    await tester.pump();
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('overlay_settings_create_reward')),
    );
    await tester.pump();
    await tester.pump();

    expect(catalog.createCount, 1);
    expect(settings.musicRewardId, 'created-reward');
    expect(
      find.byKey(const ValueKey('twitch_reward_created-reward')),
      findsOneWidget,
    );

    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows follow events without injecting a debug follow', (
    tester,
  ) async {
    await _pumpLoggedWidget(tester, locator);

    expect(find.byKey(const ValueKey('connection_indicator')), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(FollowWidget), findsNothing);

    websocket.add(
      _message(
        type: 'channel.follow',
        event: {
          'user_id': 'follower-id',
          'user_login': 'follower_login',
          'user_name': 'Follower',
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(FollowWidget), findsOneWidget);
    expect(
      tester.widget<FollowWidget>(find.byType(FollowWidget)).event.userName,
      'Follower',
    );
    expect(
      tester.widget<FollowWidget>(find.byType(FollowWidget)).renderer,
      AvatarPixelRenderer.rawAtlas,
    );
    expect(
      tester.widget<FollowWidget>(find.byType(FollowWidget)).avatarResolution,
      48,
    );
    expect(tester.widget<RainyAvatar>(find.byType(RainyAvatar)).resolution, 48);
    expect(tester.widget<RainyAvatar>(find.byType(RainyAvatar)).pixelSize, 8);

    config.config.set(
      Config(
        valid: true,
        json: {
          'followers': true,
          'follow_animation_renderer': 'legacy',
          'follow_avatar_resolution': 40,
        },
      ),
    );
    await tester.pump();

    expect(
      tester.widget<FollowWidget>(find.byType(FollowWidget)).renderer,
      AvatarPixelRenderer.legacyCanvas,
    );
    expect(
      tester.widget<FollowWidget>(find.byType(FollowWidget)).avatarResolution,
      40,
    );
    expect(tester.widget<RainyAvatar>(find.byType(RainyAvatar)).resolution, 40);
    expect(tester.widget<RainyAvatar>(find.byType(RainyAvatar)).pixelSize, 8);

    await tester.pump(const Duration(seconds: 20));
    expect(find.byType(FollowWidget), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows any custom reward and ignores removed event types', (
    tester,
  ) async {
    await _pumpLoggedWidget(tester, locator);

    websocket.add(
      _message(
        type: 'channel.channel_points_custom_reward_redemption.add',
        event: {
          'id': 'reward-id',
          'user_id': 'redeemer-id',
          'user_login': 'redeemer_login',
          'user_name': 'Redeemer',
          'reward': {'title': 'Any reward', 'cost': 1000},
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('reward-id')), findsOneWidget);

    websocket.add(
      _message(
        type: 'channel.subscribe',
        event: {
          'id': 'removed-event-id',
          'user_id': 'subscriber-id',
          'user_login': 'subscriber_login',
          'user_name': 'Subscriber',
          'reward': {'title': 'Must not render', 'cost': 1},
        },
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('removed-event-id')), findsNothing);
    expect(find.byType(FollowWidget), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('expands the music player for the !music chat command', (
    tester,
  ) async {
    final musicRequests = _FakeMusicRequests(_musicSnapshot());
    addTearDown(musicRequests.close);
    locator = _FakeLocator({
      Settings: settings,
      ObsConfig: config,
      WebSocketManager: websocket,
      MusicRequests: musicRequests,
    });

    await _pumpLoggedWidget(tester, locator);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 421));

    expect(find.byKey(const ValueKey('music_player_compact')), findsOneWidget);

    websocket.add(
      _message(
        type: 'channel.chat.message',
        event: {
          'message_id': 'message-id',
          'message': {'text': '  !MUSIC  '},
        },
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('music_player_expanded')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

MusicQueueSnapshot _musicSnapshot() {
  final item = MusicQueueItem(
    id: 'playing-track',
    requestedBy: 'Viewer',
    sourceUrl: Uri.parse('https://youtu.be/playing-track'),
    phase: MusicQueueItemPhase.ready,
    title: 'Playing track',
    author: 'Artist',
    duration: const Duration(minutes: 3),
    thumbnail: null,
    downloadProgress: 1,
  );

  return MusicQueueSnapshot(
    revision: 1,
    nowPlaying: MusicNowPlaying(
      item: item,
      startedAt: DateTime.now(),
      position: Duration.zero,
      positionUpdatedAt: DateTime.now(),
      paused: false,
    ),
    queue: const [],
    lastError: null,
  );
}

Future<void> _pumpLoggedWidget(
  WidgetTester tester,
  ServiceLocator locator, {
  TwitchRewardCatalog? rewardCatalog,
}) async {
  const user = UserDto(
    id: 'user-id',
    login: 'user_login',
    displayName: 'User',
    profileImageUrl: 'https://example.test/avatar.png',
  );

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: LoggedWidget(
        locator: locator,
        userLoader:
            (id) async => UserDto(
              id: id,
              login: user.login,
              displayName: user.displayName,
              profileImageUrl:
                  id == 'follower-id' ? user.profileImageUrl : null,
            ),
        avatarLoader: (_) async => img.Image(width: 64, height: 64),
        rewardCatalog: rewardCatalog,
      ),
    ),
  );
}

TwitchCustomReward _reward({required String id}) => TwitchCustomReward(
  id: id,
  title: 'Play Music',
  prompt: 'Paste a URL',
  cost: 1000,
  backgroundColor: '#9147FF',
  image: null,
  isEnabled: true,
  isPaused: false,
  isInStock: true,
  isUserInputRequired: true,
  shouldRedemptionsSkipRequestQueue: false,
);

class _FakeRewardCatalog implements TwitchRewardCatalog {
  final List<TwitchCustomReward> rewards;
  final TwitchCustomReward? createdReward;
  int loadCount = 0;
  int createCount = 0;

  _FakeRewardCatalog(this.rewards, {this.createdReward});

  @override
  Future<List<TwitchCustomReward>> load() async {
    loadCount++;
    return List.unmodifiable(rewards);
  }

  @override
  Future<TwitchCustomReward> createDefault() async {
    createCount++;
    return createdReward!;
  }
}

WsMessage _message({required String type, required Map<String, Object> event}) {
  return WsMessage.fromJson({
    'payload': {
      'subscription': {'type': type},
      'event': event,
    },
  });
}

class _FakeWebSocketManager extends WebSocketManager {
  final _messages = StreamController<WsMessage>.broadcast();

  _FakeWebSocketManager(Settings settings) : super('ws://unused', settings);

  void add(WsMessage message) {
    _messages.add(message);
  }

  Future<void> close() => _messages.close();

  @override
  Stream<WsMessage> get messages => _messages.stream;
}

class _FakeMusicRequests implements MusicRequests {
  final MusicQueueSnapshot _current;

  _FakeMusicRequests(this._current);

  @override
  MusicQueueSnapshot get current => _current;

  @override
  Stream<MusicQueueSnapshot> get states => const Stream.empty();

  @override
  Future<bool> setPaused(bool paused) async => true;

  @override
  Future<bool> seek(Duration position) async => true;

  @override
  Future<bool> skip() async => true;

  @override
  Future<bool> remove(String itemId) async => true;

  @override
  Future<void> close() async {}
}

class _FakeLocator implements ServiceLocator {
  final Map<Type, Object> values;

  _FakeLocator(this.values);

  @override
  T provide<T>() => values[T] as T;
}
