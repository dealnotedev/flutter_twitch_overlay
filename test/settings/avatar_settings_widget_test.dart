import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/config/avatar_settings.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/l10n/app_localizations.dart';
import 'package:obssource/pixels/pixel_rain_animator.dart';
import 'package:obssource/settings/neon_settings_controls.dart';
import 'package:obssource/settings/overlay_settings_dialog.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'avatar size uses half-pixel steps and persists with contour renderer',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = Settings();
      await settings.init();
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _showDialog(tester, settings, 'en', GlobalKey());
      await tester.tap(
        find.byKey(const ValueKey('overlay_settings_avatar_section')),
      );
      await _pump(tester);
      final size = find.byKey(const ValueKey('avatar_pixel_size'));
      final control = tester.widget<Slider>(size);
      expect(control.min, 4);
      expect(control.max, 32);
      expect(control.divisions, 28);
      expect(find.text('8 px'), findsOneWidget);
      await tester.ensureVisible(size);
      final rect = tester.getRect(size);
      await tester.tapAt(
        Offset(rect.left + rect.width * 3 / 28, rect.center.dy),
      );
      await _pump(tester);
      expect(settings.avatar.pixelSize, 3.5);
      expect(find.text('3.5 px'), findsOneWidget);
      final contour = find.byKey(const ValueKey('avatar_renderer_contour'));
      await tester.ensureVisible(contour);
      await tester.tap(contour);
      await _pump(tester);
      expect(settings.avatar.renderer, AvatarPixelRenderer.contourPoints);
      expect(tester.widget<NeonSettingsButton>(contour).selected, isTrue);
      final restored = Settings();
      await restored.init();
      expect(restored.avatar.pixelSize, 3.5);
      expect(restored.avatar.renderer, AvatarPixelRenderer.contourPoints);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final language in ['uk', 'en']) {
    testWidgets('avatar controls save and restore settings in $language', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final settings = Settings();
      await settings.init();
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final capture = GlobalKey();
      await _loadCaptureFonts(tester);
      await _showDialog(tester, settings, language, capture);

      final section = find.byKey(
        const ValueKey('overlay_settings_avatar_section'),
      );
      final slider = find.byKey(const ValueKey('avatar_resolution'));
      final optimized = find.byKey(const ValueKey('avatar_renderer_optimized'));
      final classic = find.byKey(const ValueKey('avatar_renderer_legacy'));
      expect(slider, findsNothing);
      await tester.tap(section);
      await _pump(tester);
      expect(tester.widget<NeonSettingsButton>(section).selected, isTrue);
      expect(tester.widget<Slider>(slider).value, 48);
      expect(tester.widget<NeonSettingsButton>(optimized).selected, isTrue);
      expect(find.text('48 × 48'), findsOneWidget);

      await _capture(tester, capture, 'avatar-settings-$language');
      await tester.ensureVisible(classic);
      await tester.tap(classic);
      await _pump(tester);
      expect(settings.avatar.renderer, AvatarPixelRenderer.legacyCanvas);
      await tester.ensureVisible(slider);
      final rect = tester.getRect(slider);
      await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
      await _pump(tester);
      expect(settings.avatar.resolution, AvatarSettings.maxResolution);

      final drag = await tester.startGesture(rect.center);
      await tester.pump();
      expect(settings.avatar.resolution, AvatarSettings.maxResolution);
      final draft = tester.widget<Slider>(slider).value.toInt();
      expect(
        draft,
        inExclusiveRange(
          AvatarSettings.minResolution,
          AvatarSettings.maxResolution,
        ),
      );
      await drag.up();
      await _pump(tester);
      expect(settings.avatar.resolution, draft);
      await tester.tapAt(Offset(rect.left + 1, rect.center.dy));
      await _pump(tester);
      expect(settings.avatar.resolution, AvatarSettings.minResolution);

      await tester.tap(
        find.byKey(const ValueKey('overlay_settings_player_section')),
      );
      await _pump(tester);
      expect(slider, findsNothing);
      await tester.tap(section);
      await _pump(tester);
      expect(tester.widget<Slider>(slider).value, AvatarSettings.minResolution);
      expect(tester.widget<NeonSettingsButton>(classic).selected, isTrue);
      final restored = Settings();
      await restored.init();
      expect(restored.avatar.toJson(), settings.avatar.toJson());
      await tester.pumpWidget(const SizedBox.shrink());
      await _showDialog(tester, restored, language, GlobalKey());
      await tester.tap(section);
      await _pump(tester);
      expect(tester.widget<Slider>(slider).value, AvatarSettings.minResolution);
      expect(tester.widget<NeonSettingsButton>(classic).selected, isTrue);
      await tester.ensureVisible(optimized);
      await tester.tap(optimized);
      await _pump(tester);
      expect(restored.avatar.renderer, AvatarPixelRenderer.rawAtlas);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('failed avatar save restores controls and allows retry', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = _FailingSettings();
    await settings.init();
    await _showDialog(tester, settings, 'en', GlobalKey());
    await tester.tap(
      find.byKey(const ValueKey('overlay_settings_avatar_section')),
    );
    await _pump(tester);
    final slider = find.byKey(const ValueKey('avatar_resolution'));
    final classic = find.byKey(const ValueKey('avatar_renderer_legacy'));
    final l = AppLocalizations.of(tester.element(classic))!;
    await tester.ensureVisible(classic);
    await tester.tap(classic);
    await _pump(tester);
    expect(settings.avatar.renderer, AvatarPixelRenderer.rawAtlas);
    expect(tester.widget<NeonSettingsButton>(classic).selected, isFalse);
    expect(find.text(l.overlay_settings_save_error), findsOneWidget);
    await tester.ensureVisible(slider);
    final rect = tester.getRect(slider);
    await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
    await _pump(tester);
    expect(tester.widget<Slider>(slider).value, 48);
    expect(settings.avatar.resolution, 48);
    final pixelSize = find.byKey(const ValueKey('avatar_pixel_size'));
    await tester.ensureVisible(pixelSize);
    final pixelRect = tester.getRect(pixelSize);
    await tester.tapAt(Offset(pixelRect.left + 1, pixelRect.center.dy));
    await _pump(tester);
    expect(settings.avatar.pixelSize, 8);
    expect(tester.widget<Slider>(pixelSize).value, 16);
    settings.fail = false;
    await tester.ensureVisible(classic);
    await tester.tap(classic);
    await _pump(tester);
    expect(settings.avatar.renderer, AvatarPixelRenderer.legacyCanvas);
    expect(find.text(l.overlay_settings_save_error), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _showDialog(
  WidgetTester tester,
  Settings settings,
  String language,
  GlobalKey capture,
) async {
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
          ),
        ),
      ),
    ),
  );
  await _pump(tester);
}

Future<void> _loadCaptureFonts(WidgetTester tester) async {
  if (Platform.environment['AVATAR_CAPTURE'] != '1') return;
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
  if (Platform.environment['AVATAR_CAPTURE'] != '1') return;
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

class _FailingSettings extends Settings {
  bool fail = true;

  @override
  Future<void> saveAvatar(AvatarSettings value) async {
    if (fail) throw StateError('disk full');
    await super.saveAvatar(value);
  }
}
