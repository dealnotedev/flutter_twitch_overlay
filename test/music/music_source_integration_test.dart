import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_music_player_protocol/dart_music_player_protocol_io.dart';
import 'package:obssource/config/obs_config.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/di/app_service_locator.dart';
import 'package:obssource/di/service_locator.dart';
import 'package:obssource/local_server.dart';
import 'package:obssource/main.dart';
import 'package:obssource/l10n/app_localizations.dart';
import 'package:obssource/music/music_overlay.dart';
import 'package:obssource/music/music_settings.dart';
import 'package:obssource/twitch/twitch_creds.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('player style changes preserve the existing overlay', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = Settings();
    await settings.init();
    settings.twitchAuth = TwitchCreds(
      accessToken: 'token',
      refreshToken: 'refresh',
      broadcasterId: 'channel',
      clientId: 'client',
    );
    settings.playerAlwaysExpanded = true;
    final player = _Requests();
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MusicOverlay(
            locator: _Locator(settings, player),
            child: const SizedBox.expand(key: ValueKey('existing_overlay')),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('music_player_expanded')), findsOneWidget);
    expect(find.byKey(const ValueKey('existing_overlay')), findsOneWidget);
    await settings.saveMusic(
      settings.music.copyWith(playerStyle: MusicPlayerStyle.turntable),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('music_turntable')), findsOneWidget);
    expect(find.byKey(const ValueKey('existing_overlay')), findsOneWidget);
    expect(find.byKey(const ValueKey('music_player_expanded')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await player.close();
  });

  test(
    'switches local/external, reconnects unchanged state and owns only its connection',
    () => HttpOverrides.runWithHttpOverrides(() async {
      SharedPreferences.setMockInitialValues({});
      final settings = Settings();
      await settings.init();
      final reservation = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final port = reservation.port;
      await reservation.close(force: true);
      final player = _Requests();
      final server = MusicControlServer(requests: player, requestedPort: port);
      await server.start();
      await settings.saveMusic(
        settings.music.copyWith(
          source: MusicSourceKind.external,
          externalPort: port,
          controlServerEnabled: false,
        ),
      );
      final locator = AppServiceLocator.init(
        settings,
        ObsConfig(),
        LocalServer(),
      );
      final source = locator.musicSource;
      addTearDown(() async {
        await locator.close();
        await server.close();
        await player.close();
      });
      expect(source.local, isNull);
      await _until(
        () =>
            source.current.nowPlaying != null &&
            source.connection?.phase == MusicControlConnectionPhase.connected,
      );
      expect(await source.setPaused(true), isTrue);
      expect(await source.seek(const Duration(seconds: 12)), isTrue);
      expect(await source.remove('queued'), isTrue);
      expect(await source.skip(), isTrue);
      expect(player.commands, [
        'pause:true',
        'seek:12',
        'remove:queued',
        'skip',
      ]);

      await server.close();
      await _until(
        () =>
            source.connection?.phase ==
            MusicControlConnectionPhase.reconnecting,
      );
      expect(source.current.nowPlaying, isNull);
      expect(await source.skip(), isFalse);
      await server.start();
      await _until(
        () =>
            source.current.nowPlaying != null &&
            source.connection?.phase == MusicControlConnectionPhase.connected,
      );
      // Same server identity and revision after restart must restore cleared UI.
      expect(source.current.revision, 7);

      final secondPlayer = _Requests(revision: 1);
      final secondServer = MusicControlServer(
        requests: secondPlayer,
        requestedPort: 0,
      );
      await secondServer.start();
      addTearDown(() async {
        await secondServer.close();
        await secondPlayer.close();
      });
      await settings.saveMusic(
        settings.music.copyWith(externalPort: secondServer.port),
      );
      await _until(
        () =>
            source.current.revision == 1 &&
            source.connection?.phase == MusicControlConnectionPhase.connected,
      );
      expect(await source.setPaused(false), isTrue);
      expect(secondPlayer.commands, ['pause:false']);
      expect(player.commands, [
        'pause:true',
        'seek:12',
        'remove:queued',
        'skip',
      ]);

      await settings.saveMusic(
        settings.music.copyWith(source: MusicSourceKind.local),
      );
      await _until(() => source.local != null && !source.switching);
      expect(source.connection, isNull);
      expect(source.current.nowPlaying, isNull);
      expect(player.closes, 0);

      await settings.saveMusic(
        settings.music.copyWith(source: MusicSourceKind.external),
      );
      await _until(
        () =>
            source.local == null &&
            source.current.nowPlaying != null &&
            source.connection?.phase == MusicControlConnectionPhase.connected,
      );
      await locator.close();
      expect(player.closes, 0);
      expect(player.current.nowPlaying, isNotNull);
      expect(server.isRunning, isTrue);
    }, _RealHttp()),
  );

  for (final style in MusicPlayerStyle.values) {
    testWidgets(
      'external ${style.name} view and settings work without Twitch login',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final settings = Settings();
        await settings.init();
        settings.playerAlwaysExpanded = true;
        await settings.saveMusic(
          settings.music.copyWith(
            source: MusicSourceKind.external,
            playerStyle: style,
          ),
        );
        final player = _Requests();
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MyApp(locator: _Locator(settings, player)));
        for (var frame = 0; frame < 300; frame++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(
          find.byKey(
            ValueKey(
              style == MusicPlayerStyle.cosmic
                  ? 'music_player_expanded'
                  : 'music_turntable',
            ),
          ),
          findsOneWidget,
        );
        expect(settings.twitchAuth, isNull);
        await tester.tap(
          find.byKey(const ValueKey('unauthenticated_settings')),
        );
        await tester.pump(const Duration(milliseconds: 400));
        final port = find.byKey(const ValueKey('music_external_port'));
        await tester.ensureVisible(port);
        await tester.enterText(port, '0');
        await tester.tap(
          find.byKey(const ValueKey('music_external_port_apply')),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(settings.music.externalPort, 47822);
        await tester.enterText(port, '49001');
        await tester.tap(
          find.byKey(const ValueKey('music_external_port_apply')),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(settings.music.externalPort, 49001);
        await tester.ensureVisible(
          find.byKey(const ValueKey('music_source_local')),
        );
        await tester.tap(find.byKey(const ValueKey('music_source_local')));
        await tester.pump(const Duration(milliseconds: 400));
        expect(settings.music.source, MusicSourceKind.local);
        await tester.tap(find.byKey(const ValueKey('music_source_external')));
        await tester.pump(const Duration(milliseconds: 400));
        expect(settings.music.source, MusicSourceKind.external);
        expect(find.byKey(const ValueKey('music_max_queue')), findsNothing);
        final restored = Settings();
        await restored.init();
        expect(restored.music.source, MusicSourceKind.external);
        expect(restored.music.externalPort, 49001);
        expect(restored.music.playerStyle, style);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await player.close();
      },
    );
  }
}

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Player source did not settle');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _RealHttp extends HttpOverrides {}

class _Locator extends ServiceLocator {
  final Settings settings;
  final MusicRequests player;
  _Locator(this.settings, this.player);
  @override
  T provide<T>() => (T == Settings ? settings : player) as T;
}

class _Requests implements MusicRequests {
  final int revision;
  _Requests({this.revision = 7});
  final commands = <String>[];
  int closes = 0;
  @override
  MusicQueueSnapshot get current {
    final now = DateTime.now();
    return MusicQueueSnapshot(
      revision: revision,
      nowPlaying: MusicNowPlaying(
        item: MusicQueueItem(
          id: 'playing',
          requestedBy: 'Listener',
          sourceUrl: Uri.parse('https://youtu.be/aaaaaaaaaaa'),
          phase: MusicQueueItemPhase.ready,
          title: 'External track',
          author: 'Artist',
          duration: const Duration(minutes: 4),
          thumbnail: null,
        ),
        startedAt: now,
        position: const Duration(seconds: 10),
        positionUpdatedAt: now,
        paused: false,
      ),
      queue: [],
      lastError: null,
    );
  }

  @override
  Stream<MusicQueueSnapshot> get states => Stream.value(current);
  @override
  Future<bool> setPaused(bool paused) async {
    commands.add('pause:$paused');
    return true;
  }

  @override
  Future<bool> seek(Duration position) async {
    commands.add('seek:${position.inSeconds}');
    return true;
  }

  @override
  Future<bool> skip() async {
    commands.add('skip');
    return true;
  }

  @override
  Future<bool> remove(String itemId) async {
    commands.add('remove:$itemId');
    return true;
  }

  @override
  Future<void> close() async {
    closes++;
  }
}
