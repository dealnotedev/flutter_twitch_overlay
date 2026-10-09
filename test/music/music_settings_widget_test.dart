import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/l10n/app_localizations.dart';
import 'package:obssource/music/control/music_control_server_controller.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/music/music_settings.dart';
import 'package:obssource/music/yt_dlp_music_track_fetcher.dart';
import 'package:obssource/music/youtube_browser_session.dart';
import 'package:obssource/music/youtube_connection_controller.dart';
import 'package:obssource/settings/overlay_settings_dialog.dart';
import 'package:obssource/settings/neon_settings_controls.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/ws_event.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final language in ['uk', 'en']) {
    testWidgets('YouTube connection guides verification and retry in $language', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final settings = Settings();
      await settings.init();
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _loadCaptureFonts(tester);
      final directory =
          (await tester.runAsync(
            () => Directory.systemTemp.createTemp('youtube_settings_ui_'),
          ))!;
      final browser = _YoutubeBrowser();
      var checks = 0;
      // Created with real async so its file operations are not stuck in the
      // fake test zone.
      final connection =
          (await tester.runAsync(
            () async => YoutubeConnectionController(
              directory: directory,
              browser: browser,
              verifyAccess: (_, __, ___) async {
                if (++checks == 1) {
                  throw const YtDlpException(
                    'challenge',
                    errorType: MusicQueueErrorType.youtubeAccessRequired,
                    diagnostic: 'yt-dlp: ERROR: YouTube verification required',
                  );
                }
                if (checks == 2) {
                  throw const YtDlpException(
                    'media blocked',
                    errorType: MusicQueueErrorType.youtubeDownloadBlocked,
                    diagnostic:
                        'yt-dlp: ERROR: unable to download video data: HTTP Error 403: Forbidden',
                  );
                }
              },
            ),
          ))!;
      addTearDown(
        () => tester.runAsync(() async {
          await connection.close();
          directory.deleteSync(recursive: true);
        }),
      );
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'RobotoMono'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale(language),
          home: Scaffold(
            backgroundColor: const Color(0xff080516),
            body: RepaintBoundary(
              key: capture,
              child: OverlaySettingsDialog(
                settings: settings,
                rewardCatalog: _Catalog(),
                youtubeConnection: connection,
              ),
            ),
          ),
        ),
      );
      await _pump(tester);
      final connect = find.byKey(const ValueKey('music_youtube_connect'));
      await tester.ensureVisible(connect);
      await tester.runAsync(() async {
        tester.widget<NeonSettingsButton>(connect).onPressed!();
        await connection.connect();
      });
      await _pump(tester);
      final l = AppLocalizations.of(tester.element(connect))!;
      expect(find.text(l.music_youtube_instructions), findsOneWidget);
      final verify = find.byKey(const ValueKey('music_youtube_verify'));
      await tester.ensureVisible(verify);
      await tester.ensureVisible(find.text(l.music_youtube_title));
      await _pump(tester);
      await _capture(tester, capture, 'youtube-connect-$language');

      // Presses a button and waits for the asynchronous work it started.
      Future<void> press(String key, {bool Function()? until}) async {
        final button = find.byKey(ValueKey(key));
        await tester.ensureVisible(button);
        await tester.runAsync(() async {
          tester.widget<NeonSettingsButton>(button).onPressed!();
          while (connection.busy || !(until?.call() ?? true)) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        });
        await _pump(tester);
      }

      Future<void> showPanel() async {
        await tester.ensureVisible(find.text(l.music_youtube_title));
        await _pump(tester);
      }

      expect(find.text(l.music_youtube_account_warning), findsOneWidget);
      await press('music_youtube_verify');
      // The browser closes for the check, so the reason says how to retry.
      expect(connection.status, YoutubeConnectionStatus.disconnected);
      expect(find.text(l.music_youtube_verification_required), findsOneWidget);
      expect(find.text(l.music_youtube_connected), findsNothing);
      expect(verify, findsNothing);
      expect(
        find.text(
          l.music_youtube_checked_video(
            'https://www.youtube.com/watch?v=4YFu4dvMHHY',
          ),
        ),
        findsOneWidget,
      );
      final details = find.byKey(const ValueKey('music_youtube_diagnostic'));
      expect(details, findsOneWidget);
      await tester.ensureVisible(details);
      await tester.tap(find.text(l.music_youtube_error_details));
      await _pump(tester);
      expect(find.text(connection.diagnostic!), findsOneWidget);
      await showPanel();
      await _capture(tester, capture, 'youtube-check-error-$language');

      await press('music_youtube_connect');
      await press('music_youtube_verify');
      expect(find.text(l.music_youtube_download_blocked), findsOneWidget);
      expect(find.text(l.music_youtube_connected), findsNothing);
      await showPanel();
      await _capture(tester, capture, 'youtube-media-403-$language');

      await press('music_youtube_connect');
      await press('music_youtube_verify');
      expect(find.text(l.music_youtube_connected), findsOneWidget);
      expect(details, findsNothing);
      expect(
        tester.widget<NeonSettingsButton>(connect).label,
        l.music_youtube_reconnect,
      );

      // Cancelling a reconnection keeps the verified session.
      await press('music_youtube_connect');
      await press(
        'music_youtube_cancel',
        until: () => connection.status == YoutubeConnectionStatus.connected,
      );
      expect(connection.hasSession, isTrue);
      expect(find.text(l.music_youtube_saved), findsOneWidget);

      // Removing the session asks for confirmation first.
      await press('music_youtube_disconnect');
      expect(find.text(l.music_youtube_disconnect_confirm), findsOneWidget);
      await showPanel();
      await _capture(tester, capture, 'youtube-disconnect-$language');
      await press('music_youtube_disconnect_keep');
      expect(find.text(l.music_youtube_disconnect_confirm), findsNothing);
      expect(connection.hasSession, isTrue);
      await press('music_youtube_disconnect');
      await press(
        'music_youtube_disconnect_remove',
        until: () => !connection.hasSession,
      );
      expect(find.text(l.music_youtube_disconnected), findsOneWidget);
      expect(
        find.byKey(const ValueKey('music_youtube_disconnect')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('paused music requests explain the hold and can resume', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = Settings();
    await settings.init();
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _loadCaptureFonts(tester);
    final directory =
        (await tester.runAsync(
          () => Directory.systemTemp.createTemp('youtube_hold_ui_'),
        ))!;
    final events = StreamController<WsMessage>.broadcast();
    final fetcher = _BlockedFetcher();
    // Real async keeps the queue's preparation loop out of the fake zone.
    final (requests, connection) =
        (await tester.runAsync(() async {
          final connection = YoutubeConnectionController(
            directory: directory,
            browser: _YoutubeBrowser(),
            verifyAccess: (_, __, ___) async {},
          );
          final requests = MusicRequestManager(
            events: events.stream,
            fetcher: fetcher,
            player: _SilentPlayer(),
            enabled: true,
            maxQueueLength: 10,
            maxDuration: const Duration(minutes: 10),
            rewardId: 'reward',
            onPreparationHeld: connection.requireCheck,
          );
          return (requests, connection);
        }))!;
    addTearDown(
      () => tester.runAsync(() async {
        await requests.close();
        await events.close();
        await connection.close();
        directory.deleteSync(recursive: true);
      }),
    );
    await tester.runAsync(() async {
      events.add(_redemption('blocked'));
      while (requests.current.hold == null) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    final capture = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'RobotoMono'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          backgroundColor: const Color(0xff080516),
          body: RepaintBoundary(
            key: capture,
            child: OverlaySettingsDialog(
              settings: settings,
              rewardCatalog: _Catalog(),
              youtubeConnection: connection,
              musicRequests: requests,
            ),
          ),
        ),
      ),
    );
    await _pump(tester);
    final resume = find.byKey(const ValueKey('music_youtube_resume'));
    final l = AppLocalizations.of(tester.element(resume))!;
    expect(find.text(l.music_youtube_hold_title), findsOneWidget);
    expect(find.text(l.music_youtube_hold_body(1, 15)), findsOneWidget);
    expect(find.text(l.music_youtube_verification_required), findsOneWidget);
    expect(find.text(l.music_youtube_disconnected), findsNothing);
    await tester.ensureVisible(find.text(l.music_youtube_title));
    await _pump(tester);
    await _capture(tester, capture, 'youtube-hold-en');
    await tester.runAsync(() async {
      tester.widget<NeonSettingsButton>(resume).onPressed!();
      while (fetcher.inspections < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await _pump(tester);
    expect(fetcher.inspections, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final language in ['uk', 'en']) {
    testWidgets('music settings validate, persist and render in $language', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final settings = Settings();
      await settings.init();
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _loadCaptureFonts(tester);
      final capture = GlobalKey();
      final server = MusicControlServerController(requests: _Requests());
      server.status = MusicControlServerStatus.failed;
      server.error = 'Port occupied';
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'RobotoMono'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale(language),
          home: Scaffold(
            backgroundColor: const Color(0xff080516),
            body: RepaintBoundary(
              key: capture,
              child: OverlaySettingsDialog(
                settings: settings,
                rewardCatalog: _Catalog(),
                musicServer: server,
              ),
            ),
          ),
        ),
      );
      await _pump(tester);
      final enabled = find.byKey(const ValueKey('music_enabled'));
      await tester.ensureVisible(enabled);
      await tester.tap(enabled);
      await _pump(tester);
      expect(settings.music.enabled, isFalse);
      final slider = find.byKey(const ValueKey('music_volume'));
      await tester.ensureVisible(slider);
      final rect = tester.getRect(slider);
      await tester.tapAt(Offset(rect.left + rect.width * 0.37, rect.center.dy));
      await _pump(tester);
      final percent = settings.music.volumePercent;
      expect(percent, inInclusiveRange(5, 95));
      expect(percent % 5, 0);
      await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
      await _pump(tester);
      expect(settings.music.volumePercent, 100);
      await tester.ensureVisible(enabled);
      await _pump(tester);
      await _capture(tester, capture, 'music-general-$language');

      Future<void> number(String key, String text) async {
        final field = find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(EditableText),
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, text);
        await _pump(tester);
        final apply = find.byKey(ValueKey('${key}_apply'));
        await tester.ensureVisible(apply);
        await _pump(tester);
        await tester.tap(apply);
        await _pump(tester);
      }

      Future<void> adjustSlider(
        String key,
        int min,
        int max,
        int Function() savedValue, {
        int step = 1,
      }) async {
        final slider = find.byKey(ValueKey(key));
        await tester.ensureVisible(slider);
        await _pump(tester);
        expect(find.byKey(ValueKey('${key}_apply')), findsNothing);
        final rect = tester.getRect(slider);
        await tester.tapAt(Offset(rect.left + 1, rect.center.dy));
        await _pump(tester);
        expect(savedValue(), min);
        await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
        await _pump(tester);
        expect(savedValue(), max);
        final drag = await tester.startGesture(rect.center);
        await _pump(tester);
        final draft = tester.widget<Slider>(slider).value.toInt();
        expect(draft, inInclusiveRange(min + 1, max - 1));
        expect((draft - min) % step, 0);
        expect(savedValue(), max);
        await drag.up();
        await _pump(tester);
        expect(savedValue(), draft);
      }

      await adjustSlider(
        'player_collapse_slider',
        1,
        60,
        () => settings.playerCollapseSeconds,
      );
      final collapse = find.byKey(const ValueKey('player_collapse_slider'));
      final alwaysExpanded = find.byKey(
        const ValueKey('player_always_expanded_switch'),
      );
      await tester.ensureVisible(alwaysExpanded);
      await _pump(tester);
      await tester.tap(alwaysExpanded);
      await _pump(tester);
      expect(settings.playerAlwaysExpanded, isTrue);
      final collapseSeconds = settings.playerCollapseSeconds;
      final collapseRect = tester.getRect(collapse);
      await tester.tapAt(Offset(collapseRect.left + 1, collapseRect.center.dy));
      await _pump(tester);
      expect(settings.playerCollapseSeconds, collapseSeconds);
      await tester.tap(alwaysExpanded);
      await _pump(tester);
      expect(settings.playerAlwaysExpanded, isFalse);

      await adjustSlider(
        'music_max_queue',
        1,
        50,
        () => settings.music.maxQueue,
      );
      await adjustSlider(
        'music_max_duration',
        60,
        1200,
        () => settings.music.maxDurationSeconds,
        step: 5,
      );
      await adjustSlider(
        'music_cache_max_mb',
        128,
        2048,
        () => settings.music.cacheMaxMb,
        step: 128,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('music_max_queue')));
      await _pump(tester);
      await _capture(tester, capture, 'music-limits-$language');

      for (final invalid in ['0', '65536', 'abc']) {
        await number('music_server_port', invalid);
        expect(settings.music.controlServerPort, 47821);
      }
      await number('music_server_port', '50001');
      expect(settings.music.controlServerPort, 50001);
      final serverEnabled = find.byKey(const ValueKey('music_server_enabled'));
      await tester.ensureVisible(serverEnabled);
      await tester.tap(serverEnabled);
      await _pump(tester);
      expect(settings.music.controlServerEnabled, isFalse);
      final retry = find.byKey(const ValueKey('music_server_retry'));
      await tester.ensureVisible(retry);
      await _capture(tester, capture, 'music-server-$language');
      await tester.tap(retry);
      await _pump(tester);
      expect(server.status, MusicControlServerStatus.stopped);
      expect(find.byKey(const ValueKey('music_server_retry')), findsNothing);
      expect(tester.takeException(), isNull);
      final restored = Settings();
      await restored.init();
      expect(restored.music.toJson(), settings.music.toJson());
      await tester.pumpWidget(const SizedBox.shrink());
      await server.close();
    });
  }

  testWidgets('failed save reports an error and keeps the saved value', (
    tester,
  ) async {
    final settings = _FailingSettings();
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: OverlaySettingsDialog(
          settings: settings,
          rewardCatalog: _Catalog(),
        ),
      ),
    );
    await _pump(tester);
    final enabled = find.byKey(const ValueKey('music_enabled'));
    await tester.ensureVisible(enabled);
    await tester.tap(enabled);
    await _pump(tester);
    expect(settings.music.enabled, isTrue);
    expect(tester.widget<NeonSettingsButton>(enabled).selected, isTrue);
    final l = AppLocalizations.of(tester.element(enabled))!;
    expect(find.text(l.overlay_settings_save_error), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _loadCaptureFonts(WidgetTester tester) async {
  if (Platform.environment['MUSIC_CAPTURE'] != '1') return;
  await tester.runAsync(() async {
    for (final (family, path) in [
      ('RobotoMono', r'C:\Windows\Fonts\segoeui.ttf'),
      ('Segoe Script', r'C:\Windows\Fonts\segoesc.ttf'),
      (
        'MaterialIcons',
        r'D:\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
      ),
    ]) {
      await (FontLoader(family)..addFont(
        Future.value(ByteData.sublistView(await File(path).readAsBytes())),
      )).load();
    }
  });
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (Platform.environment['MUSIC_CAPTURE'] != '1') return;
  await tester.pump();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/test-screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

class _Catalog implements TwitchRewardCatalog {
  @override
  Future<List<TwitchCustomReward>> load() async => [];
  @override
  Future<TwitchCustomReward> createDefault() => throw UnimplementedError();
}

class _YoutubeBrowser implements YoutubeBrowserSession {
  @override
  Future<Uri> readYoutubeVideoUrl() async =>
      Uri.parse('https://www.youtube.com/watch?v=4YFu4dvMHHY');

  @override
  Future<void> open(Uri url) async {}

  @override
  Future<void> close() async {}

  @override
  Future<List<Map<String, dynamic>>> readYoutubeCookies() async => [
    {'domain': '.youtube.com', 'name': 'test', 'value': 'fake', 'path': '/'},
  ];
}

WsMessage _redemption(String id) => WsMessage.fromJson({
  'payload': {
    'subscription': {
      'type': 'channel.channel_points_custom_reward_redemption.add',
    },
    'event': {
      'id': id,
      'user_id': 'user-$id',
      'user_login': 'viewer_$id',
      'user_name': 'Viewer $id',
      'user_input': 'https://youtu.be/$id',
      'redeemed_at': '2026-10-09T12:30:00Z',
      'reward': {'id': 'reward', 'title': 'Play Music', 'cost': 100},
    },
  },
});

class _BlockedFetcher implements MusicTrackFetcher {
  int inspections = 0;

  @override
  Future<MusicTrackMetadata> inspect(Uri sourceUrl) async {
    inspections++;
    throw const MusicTrackException(
      'bot check',
      errorType: MusicQueueErrorType.youtubeAccessRequired,
    );
  }

  @override
  Future<String> obtain({
    required MusicTrackMetadata metadata,
    required void Function(MusicDownloadProgress progress) onProgress,
  }) => throw UnimplementedError();

  @override
  Future<void> cancel() async {}
}

class _SilentPlayer implements MusicTrackPlayer {
  @override
  Future<void> play(DownloadedMusicTrack track) async {}

  @override
  Future<void> setPaused(bool paused) async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> stop() async {}
}

class _Requests implements MusicRequests {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingSettings extends Settings {
  @override
  Future<void> saveMusic(MusicSettings value) async =>
      throw StateError('disk full');
}
