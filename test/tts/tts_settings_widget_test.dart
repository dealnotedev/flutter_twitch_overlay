import 'dart:io';

import 'package:obssource/tts/tts_settings.dart';

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/tts/tts_controller.dart';
import 'package:obssource/l10n/app_localizations.dart';
import 'package:obssource/settings/overlay_settings_dialog.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tts_fakes.dart';

void main() {
  testWidgets(
    'TTS tab uses custom fields, saves mood and blocks the music reward',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final settings = configuredTtsSettings();
      await settings.saveMusicRewardId('music');
      final catalog = _Catalog();
      final capture = GlobalKey();
      final player = FakeTtsPlayer();
      final manager =
          (await tester.runAsync(() async {
            final value = TtsController(
              settings: settings,
              api: FakeTtsGateway(),
              twitch: FakeTtsTwitch(),
              player: player,
              events: const Stream.empty(),
              connectionChanges: const Stream.empty(),
              connected: true,
            );
            await value.ready;
            return value;
          }))!;
      if (Platform.environment['TTS_CAPTURE'] == '1') {
        await tester.runAsync(() async {
          final font = File(r'C:\Windows\Fonts\segoeui.ttf');
          final loader = FontLoader('PreviewFont')..addFont(
            Future.value(ByteData.sublistView(await font.readAsBytes())),
          );
          await loader.load();
          final mono = FontLoader('RobotoMono')..addFont(
            Future.value(ByteData.sublistView(await font.readAsBytes())),
          );
          await mono.load();
          final script = FontLoader('Segoe Script')..addFont(
            Future.value(
              ByteData.sublistView(
                await File(r'C:\Windows\Fonts\segoesc.ttf').readAsBytes(),
              ),
            ),
          );
          await script.load();
          final icons = FontLoader('MaterialIcons')..addFont(
            Future.value(
              ByteData.sublistView(
                await File(
                  r'D:\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
                ).readAsBytes(),
              ),
            ),
          );
          await icons.load();
        });
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'PreviewFont'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('uk'),
          home: Scaffold(
            backgroundColor: const Color(0xFF060815),
            body: Center(
              child: RepaintBoundary(
                key: capture,
                child: OverlaySettingsDialog(
                  settings: settings,
                  rewardCatalog: catalog,
                  ttsRewardCatalog: catalog,
                  ttsController: manager,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await _capture(tester, capture, 'player-settings-unified.png');
      await tester.tap(
        find.byKey(const ValueKey('overlay_settings_tts_section')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const ValueKey('tts_base_url')), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(DropdownButton<String>), findsNothing);
      expect(find.text('Голос'), findsNothing);
      await _capture(tester, capture, 'tts-settings-initial.png');
      await tester.tap(find.byKey(const ValueKey('tts_mood_calm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(settings.tts.mood, TtsMood.calm);
      final volume = find.byKey(const ValueKey('tts_volume_slider'));
      final drag = await tester.startGesture(
        Offset(tester.getRect(volume).right - 1, tester.getCenter(volume).dy),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<Slider>(volume).value, 200);
      await tester.runAsync(() async {});
      expect(player.volume, 2.0);
      expect(settings.tts.volumePercent, 100);
      await drag.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(settings.tts.volumePercent, 200);
      expect(find.text('200%'), findsOneWidget);
      await _capture(tester, capture, 'tts-settings-volume.png');
      final url = find.descendant(
        of: find.byKey(const ValueKey('tts_base_url')),
        matching: find.byType(EditableText),
      );
      await tester.enterText(url, 'https://example.test/tts/v1/');
      await tester.tap(find.byKey(const ValueKey('tts_apply_url')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(settings.tts.baseUrl, 'https://example.test/tts/v1');
      await tester.tap(find.byKey(const ValueKey('tts_enabled')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(settings.tts.enabled, isFalse);
      expect(tester.takeException(), isNull);
      await _capture(tester, capture, 'tts-settings-top.png');
      final music = find.byKey(const ValueKey('tts_reward_music'));
      await tester.ensureVisible(music);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(music);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(settings.tts.rewardId, 'tts');
      const conflict = 'Використовується для замовлення музики';
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getTopLeft(music) + const Offset(100, 40));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(conflict), findsNothing);
      final warning = find.descendant(
        of: music,
        matching: find.byIcon(Icons.warning_amber_rounded),
      );
      await mouse.moveTo(tester.getCenter(warning));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(conflict), findsOneWidget);
      await mouse.moveTo(Offset.zero);
      await tester.pump(const Duration(seconds: 1));
      await mouse.removePointer();
      expect(find.text(conflict), findsNothing);
      await tester.tap(find.byKey(const ValueKey('tts_reward_other')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(settings.tts.rewardId, 'other');
      expect(tester.takeException(), isNull);
      await _capture(tester, capture, 'tts-settings-rewards.png');
      expect(find.text('Відв’язати'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('tts_reward_other')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(settings.tts.rewardId, isNull);
      expect(settings.tts.broadcasterId, isNull);
      final lastReward = find.byKey(const ValueKey('tts_reward_extra-2'));
      await tester.ensureVisible(lastReward);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(lastReward);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(settings.tts.rewardId, 'extra-2');
      expect(tester.takeException(), isNull);
      await _capture(tester, capture, 'tts-settings-wrap.png');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(manager.close);
    },
  );
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (Platform.environment['TTS_CAPTURE'] != '1') return;
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/ic_twitch_channel_posints_32dp.png'),
      key.currentContext!,
    ),
  );
  await tester.pump(const Duration(milliseconds: 250));
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/tts-preview').create(recursive: true);
    await File(
      'build/tts-preview/$name',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

class _Catalog implements TwitchRewardCatalog {
  @override
  Future<List<TwitchCustomReward>> load() async => [
    ttsReward(id: 'music'),
    ttsReward(),
    ttsReward(id: 'other'),
    for (var i = 0; i < 3; i++) ttsReward(id: 'extra-$i'),
  ];
  @override
  Future<TwitchCustomReward> createDefault() async => ttsReward(id: 'created');
}
