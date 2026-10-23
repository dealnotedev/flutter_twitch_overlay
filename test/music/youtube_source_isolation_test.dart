import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/config/source_profile.dart';
import 'package:obssource/music/youtube_browser_session.dart';
import 'package:obssource/music/youtube_connection_controller.dart';

final _profiles = [
  SourceProfile.fromArguments(['0a123456-1234-4567-89ab-123456789abc']),
  SourceProfile.fromArguments(['0b123456-1234-4567-89ab-123456789abc']),
  SourceProfile.fromArguments([]),
];

void main() {
  late Directory applicationDirectory;
  late List<YoutubeConnectionController> controllers;

  setUp(() async {
    applicationDirectory = await Directory.systemTemp.createTemp(
      'youtube_profiles_',
    );
    controllers = [];
  });

  tearDown(() async {
    for (final controller in controllers) {
      await controller.close();
    }
    await applicationDirectory.delete(recursive: true);
  });

  File profileFile(SourceProfile profile, String relativePath) => File(
    '${profile.youtubeSessionDirectory(applicationDirectory).path}'
    '${Platform.pathSeparator}$relativePath',
  );

  Future<void> seed(SourceProfile profile) async {
    for (final entry in ['cookies.txt', 'browser/marker', 'check/marker']) {
      final file = profileFile(profile, entry);
      await file.parent.create(recursive: true);
      await file.writeAsString(profile.id);
    }
  }

  YoutubeConnectionController start(SourceProfile profile) {
    final controller = YoutubeConnectionController(
      directory: profile.youtubeSessionDirectory(applicationDirectory),
      browser: _Browser(),
      verifyAccess: (_, __, ___) async {},
    );
    controllers.add(controller);
    return controller;
  }

  test(
    'source and standalone cookie leases cannot overwrite or clean each other',
    () async {
      for (final profile in _profiles) {
        await seed(profile);
      }
      final connections = _profiles.map(start).toList();
      final leases = [
        for (final controller in connections)
          (await controller.leaseCookies())!,
      ];
      expect(leases.map((lease) => lease.path).toSet(), hasLength(3));
      for (var index = 0; index < _profiles.length; index++) {
        expect(
          await File(leases[index].path).readAsString(),
          _profiles[index].id,
        );
        await File(
          leases[index].path,
        ).writeAsString('updated-${_profiles[index].id}');
      }
      await Future.wait([
        for (final lease in leases) lease.release(succeeded: true),
      ]);
      for (final profile in _profiles) {
        expect(
          await profileFile(profile, 'cookies.txt').readAsString(),
          'updated-${profile.id}',
        );
      }
    },
  );

  for (var selected = 0; selected < _profiles.length; selected++) {
    test(
      'disconnecting ${_profiles[selected].id} leaves other profiles intact',
      () async {
        for (final profile in _profiles) {
          await seed(profile);
        }
        final connections = _profiles.map(start).toList();
        final leases = [
          for (final controller in connections)
            (await controller.leaseCookies())!,
        ];
        for (final profile in _profiles) {
          await profileFile(profile, 'runs/idle.txt').writeAsString('idle');
        }

        await connections[selected].disconnect();
        expect(connections[selected].hasSession, isFalse);
        expect(connections[selected].issue, isNull);
        for (var index = 0; index < _profiles.length; index++) {
          final profile = _profiles[index];
          expect(
            await profileFile(profile, 'cookies.txt').exists(),
            index != selected,
          );
          expect(
            await profileFile(profile, 'browser/marker').exists(),
            index != selected,
          );
          expect(
            await profileFile(profile, 'runs/idle.txt').exists(),
            index != selected,
          );
          expect(
            await profileFile(profile, 'check/marker').readAsString(),
            profile.id,
          );
          expect(await File(leases[index].path).readAsString(), profile.id);
          if (index != selected) expect(connections[index].hasSession, isTrue);
        }

        await Future.wait([
          for (final lease in leases) lease.release(succeeded: true),
        ]);
        expect(
          await profileFile(_profiles[selected], 'cookies.txt').exists(),
          isFalse,
        );
        for (var index = 0; index < _profiles.length; index++) {
          if (index == selected) continue;
          expect(
            await profileFile(_profiles[index], 'cookies.txt').readAsString(),
            _profiles[index].id,
          );
        }
      },
    );
  }

  test(
    'the same source and standalone restore only their own sessions',
    () async {
      for (final profile in _profiles) {
        await seed(profile);
        await start(profile).close();
        final restoredProfile = SourceProfile.fromArguments(
          profile.id == 'standalone' ? [] : [profile.id.toUpperCase()],
        );
        final restored = start(restoredProfile);
        expect(restored.hasSession, isTrue);
        expect(await File(restored.cookieFilePath!).readAsString(), profile.id);
      }
    },
  );

  test(
    'the old shared YouTube session is neither imported nor removed',
    () async {
      final legacy = File(
        '${applicationDirectory.path}/youtube-session/cookies.txt',
      );
      await legacy.parent.create(recursive: true);
      await legacy.writeAsString('legacy-session');
      final browserMarker = File('${legacy.parent.path}/browser/marker');
      await browserMarker.parent.create(recursive: true);
      await browserMarker.writeAsString('legacy-browser');
      for (final profile in _profiles) {
        final controller = start(profile);
        expect(controller.hasSession, isFalse);
        await controller.disconnect();
      }
      expect(await legacy.readAsString(), 'legacy-session');
      expect(await browserMarker.readAsString(), 'legacy-browser');
    },
  );
}

class _Browser implements YoutubeBrowserSession {
  @override
  Future<void> close() async {}

  @override
  Future<void> open(Uri url) async => throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> readYoutubeCookies() async =>
      throw UnimplementedError();

  @override
  Future<Uri> readYoutubeVideoUrl() async => throw UnimplementedError();
}
