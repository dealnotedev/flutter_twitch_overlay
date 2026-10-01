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
import 'package:obssource/settings/overlay_settings_dialog.dart';
import 'package:obssource/settings/neon_settings_controls.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
      for (final key in ['music_volume', 'music_tts_volume']) {
        final slider = find.byKey(ValueKey(key));
        await tester.ensureVisible(slider);
        final rect = tester.getRect(slider);
        await tester.tapAt(
          Offset(rect.left + rect.width * 0.37, rect.center.dy),
        );
        await _pump(tester);
        final percent =
            key == 'music_volume'
                ? settings.music.volumePercent
                : settings.music.ttsVolumePercent;
        expect(percent, inInclusiveRange(5, 95));
        expect(percent % 5, 0);
        await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
        await _pump(tester);
      }
      expect(settings.music.volumePercent, 100);
      expect(settings.music.ttsVolumePercent, 100);
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

class _Requests implements MusicRequests {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingSettings extends Settings {
  @override
  Future<void> saveMusic(MusicSettings value) async =>
      throw StateError('disk full');
}
