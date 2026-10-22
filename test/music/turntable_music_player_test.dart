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
import 'package:obssource/music/turntable_geometry.dart';
import 'package:obssource/music/turntable_music_player.dart';

void main() {
  testWidgets('animates playback snapshots without delaying the player', (
    tester,
  ) async {
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
      () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: cover))),
    );
    addTearDown(() => PaintingBinding.instance.imageCache.evict(provider));
    final requests = _Requests(artwork: coverUrl);
    final capture = GlobalKey();
    await _loadFonts(tester);
    await tester.pumpWidget(_surface(requests, capture));
    await _animate(tester, 4);
    expect(find.text('PREPARING THE RECORD'), findsOneWidget);
    expect(find.byType(VinylRecord), findsOneWidget);
    await _capture(tester, capture, 'turntable-waiting');

    requests.start();
    await tester.pump();
    expect(requests.current.nowPlaying!.starting, isFalse);
    await _animate(tester, 0.65);
    expect(find.text('PLACING THE NEEDLE'), findsOneWidget);
    await _capture(tester, capture, 'turntable-cueing');
    await _animate(tester, 0.7);
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
    await requests.close();
  });

  for (final screenWidth in [800.0, 320.0]) {
    testWidgets(
      'paused player reveals on hover and leaves 64 at the edge at width $screenWidth',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(screenWidth, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final requests = _Requests()..start();
        final capture = GlobalKey();
        await _loadFonts(tester);
        await tester.pumpWidget(_surface(requests, capture));
        await _animate(tester, 5);
        final player = find.byKey(const ValueKey('music_turntable'));
        final expanded = tester.getRect(player);
        final scale = expanded.width / TurntableGeometry.deckSize.width;
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: Offset.zero);

        await requests.setPaused(true);
        await tester.pump();
        await _animate(tester, 4);
        requests.setQueue([_queuedItem('next')]);
        await tester.pump();
        await _animate(tester, 0.98);
        expect(tester.getRect(player).left, expanded.left);
        await _animate(tester, 0.6);
        void expectHiddenStrip() {
          final bodyLeft =
              tester.getRect(player).left +
              TurntableGeometry.chassisOrigin.dx * scale;
          expect(screenWidth - bodyLeft, closeTo(64, 0.01));
        }

        expectHiddenStrip();
        await _capture(tester, capture, 'turntable-paused-hidden-$screenWidth');

        final hoverPoint = Offset(screenWidth - 32, expanded.center.dy);
        await mouse.moveTo(hoverPoint);
        await tester.pump();
        await _animate(tester, 0.5);
        expect(tester.getRect(player).left, closeTo(expanded.left, 0.01));
        await _animate(tester, 6);
        expect(tester.getRect(player).left, closeTo(expanded.left, 0.01));
        await _capture(tester, capture, 'turntable-paused-hover-$screenWidth');

        await mouse.moveTo(Offset.zero);
        await tester.pump();
        await _animate(tester, 0.5);
        expectHiddenStrip();
        await requests.setPaused(false);
        await tester.pump();
        await _animate(tester, 0.5);
        expect(tester.getRect(player).left, closeTo(expanded.left, 0.01));
        await mouse.removePointer();
        await tester.pumpWidget(const SizedBox.shrink());
        await requests.close();
      },
    );
  }

  testWidgets(
    'resuming cancels the pause delay and unmounting cancels its timer',
    (tester) async {
      final requests = _Requests()..start();
      await requests.setPaused(true);
      final capture = GlobalKey();
      await tester.pumpWidget(_surface(requests, capture));
      await _animate(tester, 4);
      final player = find.byKey(const ValueKey('music_turntable'));
      final expandedLeft = tester.getRect(player).left;
      await requests.setPaused(false);
      await tester.pump();
      await _animate(tester, 2);
      expect(tester.getRect(player).left, expandedLeft);
      await requests.setPaused(true);
      await tester.pump();
      await _animate(tester, 4.9);
      expect(tester.getRect(player).left, expandedLeft);
      await _animate(tester, 0.6);
      expect(tester.getRect(player).left, greaterThan(expandedLeft));
      await requests.setPaused(false);
      await tester.pump();
      await _animate(tester, 0.5);
      expect(tester.getRect(player).left, expandedLeft);
      await requests.setPaused(true);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
      await requests.close();
    },
  );

  testWidgets('info panel keeps 16 padding and grows with text scale', (
    tester,
  ) async {
    final requests = _Requests()..start();
    final capture = GlobalKey();
    await _loadFonts(tester);
    await tester.pumpWidget(_surface(requests, capture));
    await _animate(tester, 5);
    final player = find.byKey(const ValueKey('music_turntable'));
    final normalHeight = tester.getSize(player).height;

    void expectPanelPadding() {
      final panel = find.byKey(const ValueKey('turntable_info_panel'));
      final row = find.descendant(of: panel, matching: find.byType(Row));
      final panelRect = tester.getRect(panel);
      final rowRect = tester.getRect(row);
      expect(rowRect.left - panelRect.left, closeTo(16, 0.001));
      expect(rowRect.top - panelRect.top, closeTo(16, 0.001));
      expect(panelRect.right - rowRect.right, closeTo(16, 0.001));
      expect(panelRect.bottom - rowRect.bottom, closeTo(16, 0.001));
      for (final key in [
        'turntable_pause',
        'turntable_skip',
        'turntable_queue',
      ]) {
        expect(
          panelRect.contains(tester.getCenter(find.byKey(ValueKey(key)))),
          isTrue,
        );
      }
    }

    expectPanelPadding();
    await tester.pumpWidget(_surface(requests, capture, textScale: 1.75));
    await tester.pump();
    expect(tester.getSize(player).height, greaterThan(normalHeight));
    expectPanelPadding();
    expect(tester.takeException(), isNull);
    await _capture(tester, capture, 'turntable-panel-large-text');
    await tester.pumpWidget(const SizedBox.shrink());
    await requests.close();
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

  testWidgets(
    'queue toggles inside the chassis and updates its count, statuses and removals',
    (tester) async {
      final requests = _Requests()..start();
      requests.setQueue([
        _queuedItem(
          'two',
          phase: MusicQueueItemPhase.downloading,
          progress: 0.5,
        ),
        _queuedItem('three'),
      ]);
      final capture = GlobalKey();
      await _loadFonts(tester);
      await tester.pumpWidget(_surface(requests, capture));
      await _animate(tester, 5);
      final queueButton = find.byKey(const ValueKey('turntable_queue'));
      final queue = find.byKey(const ValueKey('turntable_inline_queue'));
      final player = find.byKey(const ValueKey('music_turntable'));
      final collapsedHeight = tester.getSize(player).height;
      final count = find.byKey(const ValueKey('turntable_queue_count'));
      final divider = find.byKey(const ValueKey('turntable_queue_divider'));
      expect(queue, findsNothing);
      expect(divider, findsNothing);
      expect(tester.widget<Text>(count).data, '2');

      await tester.tap(queueButton);
      await tester.pump();
      expect(queue, findsOneWidget);
      expect(divider, findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('turntable_info_panel')),
          matching: queue,
        ),
        findsOneWidget,
      );
      expect(find.text('Song two'), findsOneWidget);
      expect(find.text('Song three'), findsOneWidget);
      expect(find.text('Artist · Listener'), findsNWidgets(2));
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('UP NEXT'), findsNothing);
      expect(tester.widget<Text>(count).data, '2');
      expect(
        tester.getRect(find.text('Song two')).left,
        tester.getRect(find.text('Midnight City')).left,
      );
      for (final id in ['two', 'three']) {
        final remove = find.byKey(ValueKey('remove_music_$id'));
        expect(
          tester.getRect(queue).right - tester.getRect(remove).right,
          inInclusiveRange(0, 8),
        );
      }
      expect(
        tester.getRect(queue).top,
        greaterThan(tester.getRect(queueButton).bottom),
      );
      expect(tester.getSize(player).height, greaterThan(collapsedHeight));
      expect(
        tester.getRect(player).contains(tester.getRect(queue).bottomRight),
        isTrue,
      );
      await _capture(tester, capture, 'turntable-queue-open');

      requests.setQueue([
        _queuedItem(
          'two',
          phase: MusicQueueItemPhase.downloading,
          progress: 0.75,
        ),
        _queuedItem('three'),
      ]);
      await tester.pump();
      expect(find.text('75%'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('remove_music_two')));
      await tester.pump();
      expect(find.text('Song two'), findsNothing);
      expect(find.text('Song three'), findsOneWidget);
      expect(queue, findsOneWidget);
      expect(tester.widget<Text>(count).data, '1');

      await tester.tap(queueButton);
      await tester.pump();
      expect(queue, findsNothing);
      expect(tester.getSize(player).height, collapsedHeight);
      expect(divider, findsNothing);
      expect(tester.widget<Text>(count).data, '1');
      await tester.tap(queueButton);
      await tester.pump();
      expect(queue, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await requests.close();
    },
  );

  testWidgets(
    'the whole info panel shares one scroll and caps its height at 480',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final requests = _Requests()..start();
      requests.setQueue([_queuedItem('short')]);
      final capture = GlobalKey();
      await _loadFonts(tester);
      await tester.pumpWidget(_surface(requests, capture));
      await _animate(tester, 5);
      final player = find.byKey(const ValueKey('music_turntable'));
      final panel = find.byKey(const ValueKey('turntable_info_panel'));
      final scrollView = find.byKey(const ValueKey('turntable_info_scroll'));
      final queue = find.byKey(const ValueKey('turntable_inline_queue'));
      final scrollable = find.descendant(
        of: player,
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsOneWidget);
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(tester.getSize(panel).height, lessThan(480));
      expect(position.maxScrollExtent, 0);

      await tester.tap(find.byKey(const ValueKey('turntable_queue')));
      await tester.pump();
      expect(tester.getSize(panel).height, lessThan(480));
      expect(position.maxScrollExtent, 0);
      expect(
        find.descendant(of: queue, matching: find.byType(Scrollable)),
        findsNothing,
      );

      requests.setQueue(
        List.generate(20, (index) => _queuedItem('long-$index')),
      );
      await tester.pump();
      expect(tester.getSize(panel).height, 480);
      expect(scrollable, findsOneWidget);
      expect(position.maxScrollExtent, greaterThan(0));
      final playerTop = tester.getTopLeft(player).dy;
      final currentTrackTop = tester.getTopLeft(find.text('Midnight City')).dy;
      await _capture(tester, capture, 'turntable-queue-scroll-top');

      await tester.drag(scrollView, const Offset(0, -240));
      await _animate(tester, 0.6);
      expect(position.pixels, greaterThan(0));
      expect(
        tester.getTopLeft(find.text('Midnight City')).dy,
        lessThan(currentTrackTop),
      );
      expect(tester.getTopLeft(player).dy, playerTop);
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      final lastRemove = find.byKey(const ValueKey('remove_music_long-19'));
      expect(lastRemove.hitTestable(), findsOneWidget);
      await _capture(tester, capture, 'turntable-queue-scroll-bottom');
      await tester.tap(lastRemove);
      await tester.pump();
      expect(requests.current.queue.length, 19);
      expect(find.text('Song long-19'), findsNothing);

      requests.setQueue([_queuedItem('short')]);
      await tester.pump();
      expect(tester.getSize(panel).height, lessThan(480));
      expect(position.maxScrollExtent, 0);
      expect(position.pixels, 0);
      expect(find.text('Midnight City').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await requests.close();
    },
  );

  testWidgets('empty queue disables the button and closes the inline panel', (
    tester,
  ) async {
    final requests = _Requests()..start();
    final capture = GlobalKey();
    await _loadFonts(tester);
    await tester.pumpWidget(_surface(requests, capture));
    await _animate(tester, 5);
    final queueButton = find.byKey(const ValueKey('turntable_queue'));
    final queue = find.byKey(const ValueKey('turntable_inline_queue'));
    final count = find.byKey(const ValueKey('turntable_queue_count'));
    bool buttonEnabled() =>
        tester
            .widget<IconButton>(
              find.descendant(
                of: queueButton,
                matching: find.byType(IconButton),
              ),
            )
            .onPressed !=
        null;
    expect(buttonEnabled(), isFalse);
    expect(queue, findsNothing);
    expect(count, findsNothing);
    await _capture(tester, capture, 'turntable-queue-empty');

    requests.setQueue([
      _queuedItem('held', phase: MusicQueueItemPhase.resolving),
    ], hold: MusicQueueErrorType.youtubeAccessRequired);
    await tester.pump();
    expect(buttonEnabled(), isTrue);
    expect(tester.widget<Text>(count).data, '1');
    await tester.tap(queueButton);
    await tester.pump();
    expect(queue, findsOneWidget);
    expect(find.text('WAITING'), findsOneWidget);

    requests.setQueue([]);
    await tester.pump();
    expect(queue, findsNothing);
    expect(buttonEnabled(), isFalse);
    expect(count, findsNothing);
    requests.setQueue([_queuedItem('new')]);
    await tester.pump();
    expect(buttonEnabled(), isTrue);
    expect(queue, findsNothing);
    await tester.tap(queueButton);
    await tester.pump();
    expect(queue, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('remove_music_new')));
    await tester.pump();
    expect(requests.current.queue, isEmpty);
    expect(queue, findsNothing);
    expect(buttonEnabled(), isFalse);
    expect(count, findsNothing);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await requests.close();
  });
}

MusicQueueItem _queuedItem(
  String id, {
  MusicQueueItemPhase phase = MusicQueueItemPhase.ready,
  double? progress,
}) => MusicQueueItem(
  id: id,
  requestedBy: 'Listener',
  sourceUrl: Uri.parse('https://youtu.be/$id'),
  phase: phase,
  title: 'Song $id',
  author: 'Artist',
  duration: const Duration(minutes: 3),
  thumbnail: null,
  downloadProgress: progress,
);

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
  GlobalKey capture, {
  double textScale = 1,
}) => MaterialApp(
  builder:
      (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  theme: ThemeData(fontFamily: 'TurntableTestFont'),
  home: Scaffold(
    backgroundColor: const Color(0xFF101322),
    body: LayoutBuilder(
      builder:
          (context, constraints) => Stack(
            children: [
              Positioned(
                right: 0,
                bottom: 24,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth - 24,
                  ),
                  child: RepaintBoundary(
                    key: capture,
                    child: TurntableMusicPlayer(requests: requests),
                  ),
                ),
              ),
            ],
          ),
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

  void setQueue(List<MusicQueueItem> queue, {MusicQueueErrorType? hold}) {
    emit(
      MusicQueueSnapshot(
        revision: current.revision + 1,
        nowPlaying: current.nowPlaying,
        queue: queue,
        lastError: current.lastError,
        hold: hold,
      ),
    );
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
  Future<bool> remove(String itemId) async {
    final remaining = current.queue.where((item) => item.id != itemId).toList();
    if (remaining.length == current.queue.length) return false;
    setQueue(remaining, hold: current.hold);
    return true;
  }

  @override
  Future<void> close() => _states.close();
}
