import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/l10n/app_localizations.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/music/turntable_music_player.dart';
import 'package:obssource/music/turntable_playback_controller.dart';

void main() {
  test(
    'headless playback, interruption and detachment never block audio',
    () async {
      final playback = TurntablePlaybackController();
      final interrupted = Completer<void>();
      await playback.beforeStart(_track(), interrupted.future);
      playback.attach();
      var cued = false;
      final cue = playback
          .beforeStart(_track(), interrupted.future)
          .then((_) => cued = true);
      await Future<void>.delayed(Duration.zero);
      playback.needlePlaced('stale-track');
      await Future<void>.delayed(Duration.zero);
      expect(cued, isFalse);
      interrupted.complete();
      await cue;
      expect(playback.readyItemId, isNull);
      final secondCue = playback.beforeStart(
        _track(),
        Completer<void>().future,
      );
      playback.detach();
      await secondCue;
      playback.dispose();
    },
  );

  testWidgets(
    'only releases playback after native readiness and needle placement',
    (tester) async {
      final coverUrl = Uri.parse(
        'https://example.invalid/turntable-test-cover.png',
      );
      final provider = CachedNetworkImageProvider(
        coverUrl.toString(),
        maxWidth: 256,
        maxHeight: 256,
      );
      final cover =
          (await tester.runAsync(() async {
            final codec = await ui.instantiateImageCodec(await _sampleCover());
            final frame = await codec.getNextFrame();
            codec.dispose();
            return frame.image;
          }))!;
      PaintingBinding.instance.imageCache.putIfAbsent(
        provider,
        () =>
            OneFrameImageStreamCompleter(Future.value(ImageInfo(image: cover))),
      );
      addTearDown(() => PaintingBinding.instance.imageCache.evict(provider));
      final requests = _Requests(artwork: coverUrl);
      final playback = TurntablePlaybackController();
      final capture = GlobalKey();
      await _loadFonts(tester);
      await tester.pumpWidget(_surface(requests, playback, capture));
      await _animate(tester, 4);
      expect(find.text('PREPARING THE RECORD'), findsOneWidget);
      expect(find.byType(VinylRecord), findsOneWidget);
      await _capture(tester, capture, 'turntable-waiting');

      final interrupted = Completer<void>();
      var cued = false;
      final cue = playback
          .beforeStart(_track(), interrupted.future)
          .then((_) => cued = true);
      await tester.pump();
      await _animate(tester, 0.65);
      expect(cued, isFalse);
      expect(find.text('PLACING THE NEEDLE'), findsOneWidget);
      await _capture(tester, capture, 'turntable-cueing');
      await _animate(tester, 0.7);
      await cue;
      expect(cued, isTrue);
      requests.start();
      await tester.pump();
      await _capture(tester, capture, 'turntable-playing');

      await requests.seek(const Duration(seconds: 239));
      await tester.pump();
      await _animate(tester, 1);
      expect(find.byType(VinylRecord), findsOneWidget);
      await _capture(tester, capture, 'turntable-ending');

      await requests.seek(const Duration(seconds: 120));
      await tester.pump();
      await _animate(tester, 1);

      await tester.tap(find.byKey(const ValueKey('turntable_pause')));
      await tester.pump();
      expect(requests.current.nowPlaying!.paused, isTrue);
      await tester.tap(find.byKey(const ValueKey('turntable_pause')));
      await tester.pump();
      expect(requests.current.nowPlaying!.paused, isFalse);
      await tester.tap(find.byKey(const ValueKey('turntable_skip')));
      await tester.pump();
      await _animate(tester, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      playback.dispose();
      await requests.close();
    },
  );

  testWidgets('unmounting the turntable while cueing releases the audio gate', (
    tester,
  ) async {
    final requests = _Requests();
    final playback = TurntablePlaybackController();
    await tester.pumpWidget(_surface(requests, playback, GlobalKey()));
    final cue = playback.beforeStart(_track(), Completer<void>().future);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await cue;
    playback.dispose();
    await requests.close();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'artwork fills a circular oversized label while leaving vinyl grooves visible',
    (tester) async {
      final cover = (await tester.runAsync(_sampleCover))!;
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: capture,
              child: VinylRecord(artwork: MemoryImage(cover)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final artwork = find.byType(Image);
      expect(artwork, findsOneWidget);
      expect(tester.widget<Image>(artwork).fit, BoxFit.cover);
      expect(tester.getSize(artwork), const Size.square(128));
      expect(tester.getSize(find.byType(VinylRecord)), const Size.square(220));
      expect(
        find.ancestor(of: artwork, matching: find.byType(ClipOval)),
        findsOneWidget,
      );
      await _capture(tester, capture, 'turntable-artwork');
      expect(tester.takeException(), isNull);
    },
  );
}

Future<Uint8List> _sampleCover() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const bounds = Rect.fromLTWH(0, 0, 256, 256);
  canvas.drawRect(
    bounds,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF17285F), Color(0xFFC573AA), Color(0xFFFFB877)],
      ).createShader(bounds),
  );
  canvas.drawCircle(
    const Offset(161, 104),
    43,
    Paint()..color = const Color(0xFFFFE0A2),
  );
  canvas.drawPath(
    Path()
      ..moveTo(0, 172)
      ..lineTo(75, 123)
      ..lineTo(152, 202)
      ..lineTo(222, 164)
      ..lineTo(256, 202)
      ..lineTo(256, 256)
      ..lineTo(0, 256)
      ..close(),
    Paint()..color = const Color(0xFF272443),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(256, 256);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

Widget _surface(
  _Requests requests,
  TurntablePlaybackController playback,
  GlobalKey capture,
) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  theme: ThemeData(fontFamily: 'TurntableTestFont'),
  home: Scaffold(
    backgroundColor: const Color(0xFF101322),
    body: Stack(
      children: [
        Positioned(
          right: 24,
          bottom: 24,
          child: RepaintBoundary(
            key: capture,
            child: TurntableMusicPlayer(requests: requests, playback: playback),
          ),
        ),
      ],
    ),
  ),
);

Future<void> _animate(WidgetTester tester, double seconds) async {
  for (var i = 0; i < (seconds * 50).ceil(); i++) {
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.takeException(), isNull);
  }
}

Future<void> _loadFonts(WidgetTester tester) async {
  if (Platform.environment['MUSIC_CAPTURE'] != '1') return;
  await tester.runAsync(() async {
    for (final (family, path) in [
      ('TurntableTestFont', r'C:\Windows\Fonts\segoeui.ttf'),
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
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/test-screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

DownloadedMusicTrack _track() => DownloadedMusicTrack(
  itemId: 'one',
  requestedBy: 'Viewer',
  metadata: MusicTrackMetadata(
    videoId: 'one',
    title: 'Midnight City',
    author: 'M83',
    duration: const Duration(minutes: 4),
    thumbnail: null,
    sourceUrl: Uri.parse('https://youtu.be/one'),
  ),
  filePath: 'one.mp3',
);

class _Requests implements MusicRequests {
  final _states = StreamController<MusicQueueSnapshot>.broadcast();
  MusicQueueSnapshot _current;

  _Requests({Uri? artwork})
    : _current = MusicQueueSnapshot(
        revision: 1,
        nowPlaying: null,
        queue: [
          MusicQueueItem(
            id: 'one',
            requestedBy: 'Viewer',
            sourceUrl: Uri.parse('https://youtu.be/one'),
            phase: MusicQueueItemPhase.downloading,
            title: 'Midnight City',
            author: 'M83',
            duration: const Duration(minutes: 4),
            thumbnail: artwork,
            downloadProgress: 0.4,
          ),
        ],
        lastError: null,
      );

  void emit(MusicQueueSnapshot snapshot) {
    _current = snapshot;
    _states.add(snapshot);
  }

  void start() {
    final item = current.queue.single;
    final now = DateTime.now();
    emit(
      MusicQueueSnapshot(
        revision: 2,
        nowPlaying: MusicNowPlaying(
          item: item,
          startedAt: now,
          position: Duration.zero,
          positionUpdatedAt: now,
          paused: false,
        ),
        queue: [],
        lastError: null,
      ),
    );
  }

  @override
  MusicQueueSnapshot get current => _current;
  @override
  Stream<MusicQueueSnapshot> get states => _states.stream;
  @override
  Future<bool> setPaused(bool paused) async {
    final playing = current.nowPlaying!;
    emit(
      MusicQueueSnapshot(
        revision: current.revision + 1,
        nowPlaying: MusicNowPlaying(
          item: playing.item,
          startedAt: playing.startedAt,
          position: playing.position,
          positionUpdatedAt: DateTime.now(),
          paused: paused,
        ),
        queue: [],
        lastError: null,
      ),
    );
    return true;
  }

  @override
  Future<bool> seek(Duration position) async {
    final playing = current.nowPlaying!;
    emit(
      MusicQueueSnapshot(
        revision: current.revision + 1,
        nowPlaying: MusicNowPlaying(
          item: playing.item,
          startedAt: playing.startedAt,
          position: position,
          positionUpdatedAt: DateTime.now(),
          paused: playing.paused,
        ),
        queue: [],
        lastError: null,
      ),
    );
    return true;
  }

  @override
  Future<bool> skip() async {
    emit(MusicQueueSnapshot.empty);
    return true;
  }

  @override
  Future<bool> remove(String itemId) async => true;
  @override
  Future<void> close() => _states.close();
}
