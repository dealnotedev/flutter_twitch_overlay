import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:obssource/config/obs_config.dart';
import 'package:obssource/alerts/user_alert_widget.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/di/service_locator.dart';
import 'package:obssource/follow/follow_widget.dart';
import 'package:obssource/l10n/app_localizations.dart';
import 'package:obssource/logged_widget.dart';
import 'package:obssource/obs_audio.dart';
import 'package:obssource/raid/raid_widget.dart';
import 'package:obssource/subs/subs_widget.dart';
import 'package:obssource/twitch/twitch_creds.dart';
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
  late List<Map<String, dynamic>> audioCommands;
  const audioChannel = BasicMessageChannel<String>('obs_audio', StringCodec());

  setUp(() async {
    audioCommands = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<String>(audioChannel, (message) {
          audioCommands.add(jsonDecode(message!) as Map<String, dynamic>);
          return SynchronousFuture('{"ok":true,"events":false}');
        });
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
    final loadedIds =
        audioCommands
            .where((command) => command['cmd'] == 'load')
            .map((command) => command['id'] as int)
            .toSet();
    for (final id in loadedIds) {
      await ObsAudio.release(id);
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<String>(audioChannel, null);
    await websocket.close();
  });

  testWidgets(
    'subscription alert uses shared avatar settings and deduplicates deliveries',
    (tester) async {
      config.config.set(
        Config(
          valid: true,
          json: {
            'subscriptions': true,
            'alert_avatar_resolution': 32,
            'alert_animation_renderer': 'legacy',
          },
        ),
      );
      await _pumpLoggedWidget(tester, locator);
      final message = WsMessage.fromJson({
        'metadata': {'message_id': 'sub-delivery'},
        'payload': {
          'subscription': {'type': 'channel.subscription.message'},
          'event': {
            'user_id': 'follower-id',
            'user_login': 'subscriber',
            'user_name': 'Subscriber',
            'tier': '2000',
            'cumulative_months': 22,
          },
        },
      });
      websocket.add(message);
      websocket.add(message);
      await tester.pump();
      await tester.pump();
      final alert = tester.widget<UserAlertWidget>(
        find.byType(UserAlertWidget),
      );
      expect(alert.userName, 'Subscriber');
      expect(alert.description, 'thanks for 22 months of T2 subscription!');
      expect(alert.avatar, isNotNull);
      expect(alert.avatarResolution, 32);
      expect(alert.renderer, AvatarPixelRenderer.legacyCanvas);
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      expect(
        audioCommands.where((command) => command['cmd'] == 'play'),
        hasLength(1),
      );
      await tester.pump(const Duration(seconds: 21));
      expect(find.byType(UserAlertWidget), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'anonymous gifts avoid profile lookup and honor disabled subscriptions',
    (tester) async {
      var lookups = 0;
      await _pumpLoggedWidget(
        tester,
        locator,
        userLoader: (_) async {
          lookups++;
          throw StateError('unavailable');
        },
      );
      WsMessage gift(String id) => WsMessage.fromJson({
        'metadata': {'message_id': id},
        'payload': {
          'subscription': {'type': 'channel.subscription.gift'},
          'event': {'tier': '1000', 'total': 5, 'is_anonymous': true},
        },
      });
      websocket.add(gift('gift-one'));
      await tester.pump();
      await tester.pump();
      final alert = tester.widget<UserAlertWidget>(
        find.byType(UserAlertWidget),
      );
      expect(alert.userName, 'Anonymous');
      expect(alert.description, 'gifts 5 T1 subscriptions!');
      expect(alert.avatar, isNull);
      expect(lookups, 0);
      await tester.pump(const Duration(seconds: 21));
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      final giftLoad = audioCommands.singleWhere(
        (command) => command['cmd'] == 'load',
      );
      expect(giftLoad['asset'], 'assets/subscriptions/subscription_gift.wav');
      expect(
        audioCommands.where((command) => command['cmd'] == 'play').single['id'],
        giftLoad['id'],
      );
      audioCommands.clear();
      config.config.set(Config(valid: true, json: {'subscriptions': false}));
      websocket.add(gift('gift-two'));
      await tester.pump();
      expect(find.byType(UserAlertWidget), findsNothing);
      expect(audioCommands, isEmpty);
      await ObsAudio.release(giftLoad['id'] as int);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'queues mixed subscriptions with matching sounds despite slow or failed profiles',
    (tester) async {
      final firstProfile = Completer<UserDto?>();
      final lookups = <String>[];
      await _pumpLoggedWidget(
        tester,
        locator,
        userLoader: (id) {
          lookups.add(id);
          if (id == 'first') return firstProfile.future;
          throw StateError('profile unavailable');
        },
      );
      const types = {
        'first': 'channel.subscribe',
        'second': 'channel.subscription.message',
        'third': 'channel.subscription.gift',
      };
      const assets = [
        'assets/subscriptions/subscription_purchase.wav',
        'assets/subscriptions/subscription_renewal.wav',
        'assets/subscriptions/subscription_gift.wav',
      ];
      WsMessage sub(String id) => WsMessage.fromJson({
        'metadata': {'message_id': id},
        'payload': {
          'subscription': {'type': types[id]},
          'event': {
            'cumulative_months': 2,
            'total': 1,
            'user_id': id,
            'user_login': id,
            'user_name': id,
            'tier': '1000',
            'is_gift': false,
          },
        },
      });
      int plays() =>
          audioCommands.where((command) => command['cmd'] == 'play').length;
      for (final id in ['first', 'second', 'third']) {
        websocket.add(sub(id));
      }
      await tester.pump();
      expect(lookups, ['first']);
      expect(find.byType(UserAlertWidget), findsNothing);
      expect(plays(), 0);
      firstProfile.complete(null);
      await tester.pump();
      await tester.pump();
      for (var index = 0; index < 3; index++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pump();
        final name = ['first', 'second', 'third'][index];
        expect(find.byType(UserAlertWidget), findsOneWidget);
        expect(
          tester.widget<UserAlertWidget>(find.byType(UserAlertWidget)).userName,
          name,
        );
        expect(plays(), index + 1);
        final loads = audioCommands.where(
          (command) => command['cmd'] == 'load',
        );
        expect(loads, hasLength(index + 1));
        expect(loads.last['asset'], assets[index]);
        expect(
          audioCommands.lastWhere((command) => command['cmd'] == 'play')['id'],
          loads.last['id'],
        );
        await tester.pump(const Duration(seconds: 19));
        expect(
          tester.widget<UserAlertWidget>(find.byType(UserAlertWidget)).userName,
          name,
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
      }
      expect(find.byType(UserAlertWidget), findsNothing);
      expect(lookups, ['first', 'second', 'third']);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'disposal discards queued subscriptions before profile loading finishes',
    (tester) async {
      final profile = Completer<UserDto?>();
      var lookups = 0;
      await _pumpLoggedWidget(
        tester,
        locator,
        userLoader: (_) {
          lookups++;
          return profile.future;
        },
      );
      for (final id in ['first', 'second']) {
        websocket.add(
          WsMessage.fromJson({
            'metadata': {'message_id': id},
            'payload': {
              'subscription': {'type': 'channel.subscribe'},
              'event': {
                'user_id': id,
                'user_login': id,
                'user_name': id,
                'tier': '1000',
                'is_gift': false,
              },
            },
          }),
        );
      }
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      profile.complete(null);
      await tester.pump();
      expect(lookups, 1);
      expect(
        audioCommands.where((command) => command['cmd'] == 'play'),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

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
      find.byKey(const ValueKey('overlay_settings_reward_reward-1')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('overlay_settings_reward_reward-1')),
    );
    await tester.pump();
    final rewardTopLeft = tester.getTopLeft(
      find.byKey(const ValueKey('overlay_settings_reward_reward-1')),
    );
    await tester.tapAt(rewardTopLeft + const Offset(20, 20));
    await tester.pump();
    expect(settings.musicRewardId, 'reward-1');

    await tester.tapAt(rewardTopLeft + const Offset(20, 20));
    await tester.pump();
    expect(settings.musicRewardId, isNull);

    await tester.tapAt(rewardTopLeft + const Offset(20, 20));
    await tester.pump();
    expect(settings.musicRewardId, 'reward-1');

    final refresh = find.byKey(
      const ValueKey('overlay_settings_refresh_rewards'),
    );
    await tester.ensureVisible(refresh);
    await tester.pump();
    await tester.tap(refresh);
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

    final createReward = find.byKey(
      const ValueKey('overlay_settings_create_reward'),
    );
    await tester.ensureVisible(createReward);
    await tester.pump();
    await tester.tap(createReward);
    await tester.pump();
    await tester.pump();

    expect(catalog.createCount, 1);
    expect(settings.musicRewardId, 'created-reward');
    expect(
      find.byKey(const ValueKey('overlay_settings_reward_created-reward')),
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
          'alert_animation_renderer': 'legacy',
          'alert_avatar_resolution': 40,
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

  for (final viewers in [1, 100, 101]) {
    testWidgets(
      'shows incoming raid and plays its audio for $viewers viewers',
      (tester) async {
        await _pumpLoggedWidget(tester, locator);
        websocket.add(_raidMessage(viewers: viewers));
        await tester.pump();
        await tester.pump();

        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pump();

        final widget = tester.widget<RaidWidget>(find.byType(RaidWidget));
        expect(widget.event.userName, 'Raider');
        expect(widget.event.viewers, viewers);
        expect(widget.renderer, AvatarPixelRenderer.rawAtlas);
        expect(widget.avatarResolution, 48);
        expect(find.byType(RainyAvatar), findsOneWidget);
        expect(
          tester.widget<SubsWidget>(find.byType(SubsWidget)).description,
          viewers == 1 ? 'brought 1 viewer' : 'brought $viewers viewers',
        );
        expect(
          tester.widget<SubsWidget>(find.byType(SubsWidget)).who,
          'Raider',
        );
        final load = audioCommands.singleWhere(
          (command) => command['cmd'] == 'load',
        );
        expect(
          load['asset'],
          viewers > 100
              ? 'assets/raid/raid_over_100.wav'
              : 'assets/raid/raid_${viewers.toString().padLeft(3, '0')}.wav',
        );
        expect(
          audioCommands
              .where((command) => command['cmd'] == 'play')
              .single['id'],
          load['id'],
        );

        config.config.set(
          Config(
            valid: true,
            json: {
              'alert_animation_renderer': 'legacy',
              'alert_avatar_resolution': 40,
            },
          ),
        );
        await tester.pump();
        final updated = tester.widget<RaidWidget>(find.byType(RaidWidget));
        expect(updated.renderer, AvatarPixelRenderer.legacyCanvas);
        expect(updated.avatarResolution, 40);
        expect(
          tester.widget<RainyAvatar>(find.byType(RainyAvatar)).renderer,
          AvatarPixelRenderer.legacyCanvas,
        );
        expect(
          tester.widget<RainyAvatar>(find.byType(RainyAvatar)).resolution,
          40,
        );
        expect(
          tester.widget<SubsWidget>(find.byType(SubsWidget)).renderer,
          AvatarPixelRenderer.legacyCanvas,
        );

        // Twitch may deliver the same notification again.
        websocket.add(_raidMessage(viewers: viewers));
        await tester.pump();
        expect(find.byType(RaidWidget), findsOneWidget);
        expect(
          audioCommands.where((command) => command['cmd'] == 'play'),
          hasLength(1),
        );

        await tester.pump(const Duration(seconds: 20));
        expect(find.byType(RaidWidget), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('raid remains visible if profile lookup fails', (tester) async {
    await _pumpLoggedWidget(
      tester,
      locator,
      userLoader: (_) async => throw StateError('Profile unavailable'),
    );
    websocket.add(_raidMessage(viewers: 7));
    await tester.pump();
    await tester.pump();

    expect(find.byType(RaidWidget), findsOneWidget);
    expect(find.byType(RainyAvatar), findsNothing);
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    expect(tester.widget<SubsWidget>(find.byType(SubsWidget)).who, 'Raider');
    expect(
      audioCommands.where((command) => command['cmd'] == 'play'),
      hasLength(1),
    );

    await tester.pump(const Duration(seconds: 20));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ignores outgoing raids and disabled raid notifications', (
    tester,
  ) async {
    await _pumpLoggedWidget(tester, locator);
    settings.twitchAuth = TwitchCreds(
      accessToken: 'unused',
      refreshToken: 'unused',
      clientId: 'unused',
      broadcasterId: 'receiver-id',
    );
    websocket.add(
      _raidMessage(viewers: 20, toId: 'another-channel', messageId: 'outgoing'),
    );
    await tester.pump();
    expect(find.byType(RaidWidget), findsNothing);
    expect(audioCommands, isEmpty);

    config.config.set(Config(valid: true, json: {'raids': false}));
    websocket.add(_raidMessage(viewers: 20, messageId: 'disabled'));
    await tester.pump();
    expect(find.byType(RaidWidget), findsNothing);
    expect(audioCommands, isEmpty);
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
  Future<UserDto?> Function(String id)? userLoader,
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
            userLoader ??
            (id) async => UserDto(
              id: id,
              login: user.login,
              displayName: user.displayName,
              profileImageUrl:
                  id == 'follower-id' || id == 'raider-id'
                      ? user.profileImageUrl
                      : null,
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

WsMessage _raidMessage({
  required int viewers,
  String messageId = 'raid-delivery',
  String toId = 'receiver-id',
}) => WsMessage.fromJson({
  'metadata': {'message_id': messageId},
  'payload': {
    'subscription': {'type': 'channel.raid'},
    'event': {
      'from_broadcaster_user_id': 'raider-id',
      'from_broadcaster_user_login': 'raider_login',
      'from_broadcaster_user_name': 'Raider',
      'to_broadcaster_user_id': toId,
      'to_broadcaster_user_login': 'receiver_login',
      'to_broadcaster_user_name': 'Receiver',
      'viewers': viewers,
    },
  },
});

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
