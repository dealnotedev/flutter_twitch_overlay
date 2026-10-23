import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
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
import 'package:obssource/music/vinyl_record.dart';

void main() {
  for (final edition in VinylEdition.values) {
    testWidgets(
      '${edition.name} vinyl stays the same through playback updates',
      (tester) async {
        final itemId = List.generate(
          1000,
          (index) => 'edition-$index',
        ).firstWhere((id) => VinylEdition.forItem(id) == edition);
        final requests = _Requests(itemId: itemId)..start();
        final capture = GlobalKey();
        await _loadFonts(tester);
        await tester.pumpWidget(_surface(requests, capture));
        await _animate(tester, 5);
        VinylEdition visibleEdition() =>
            tester.widget<VinylRecord>(find.byType(VinylRecord)).edition;
        expect(visibleEdition(), edition);
        await requests.seek(const Duration(seconds: 120));
        await tester.pump();
        expect(visibleEdition(), edition);
        await requests.setPaused(true);
        await tester.pump();
        expect(visibleEdition(), edition);
        await requests.setPaused(false);
        await tester.pump();
        expect(visibleEdition(), edition);
        await _capture(tester, capture, 'turntable-edition-${edition.name}');
        await tester.pumpWidget(const SizedBox.shrink());
        await requests.close();
      },
    );
  }

  testWidgets('places after metadata without waiting for the artwork image', (
    tester,
  ) async {
    final coverUrl = Uri.parse('https://example.invalid/pending-cover.png');
    final provider = CachedNetworkImageProvider(
      coverUrl.toString(),
      maxWidth: 256,
      maxHeight: 256,
    );
    final artwork = Completer<ImageInfo>();
    PaintingBinding.instance.imageCache.putIfAbsent(
      provider,
      () => OneFrameImageStreamCompleter(artwork.future),
    );
    addTearDown(() => PaintingBinding.instance.imageCache.evict(provider));
    final requests = _Requests()..setQueue([_resolvingItem('one')]);
    await tester.pumpWidget(_surface(requests, GlobalKey()));
    await _animate(tester, 5);
    expect(find.byKey(const ValueKey('turntable_deck')), findsOneWidget);
    expect(find.byType(VinylRecord), findsNothing);

    requests.setQueue([
      _queuedItem(
        'one',
        phase: MusicQueueItemPhase.downloading,
        artwork: coverUrl,
      ),
    ]);
    await tester.pump();
    final record = find.byType(VinylRecord);
    expect(record, findsOneWidget);
    final startingLeft = tester.getTopLeft(record).dx;
    await _animate(tester, 0.5);
    expect(tester.getTopLeft(record).dx, lessThan(startingLeft));
    expect(artwork.isCompleted, isFalse);
    expect(requests.current.nowPlaying, isNull);
    expect(tester.widget<VinylRecord>(record).artwork, provider);
    expect(find.textContaining('Song one', findRichText: true), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await requests.close();
  });

  testWidgets(
    'waits for metadata of the next track after removing the old one',
    (tester) async {
      final requests = _Requests()..start();
      requests.setQueue([_resolvingItem('two')]);
      await tester.pumpWidget(_surface(requests, GlobalKey()));
      await _animate(tester, 5);
      expect(find.byType(VinylRecord), findsOneWidget);

      requests.emit(
        MusicQueueSnapshot(
          revision: requests.current.revision + 1,
          nowPlaying: null,
          queue: requests.current.queue,
          lastError: null,
        ),
      );
      await tester.pump();
      await _animate(tester, 5);
      expect(find.byType(VinylRecord), findsNothing);
      expect(find.byKey(const ValueKey('turntable_deck')), findsOneWidget);

      requests.setQueue([
        _queuedItem('two', phase: MusicQueueItemPhase.downloading),
      ]);
      await tester.pump();
      await _animate(tester, 0.5);
      expect(find.byType(VinylRecord), findsOneWidget);
      expect(
        find.textContaining('Song two', findRichText: true),
        findsOneWidget,
      );
      expect(requests.current.nowPlaying, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await requests.close();
    },
  );

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
    await _animate(tester, 0.74);
    expect(find.byType(VinylRecord), findsNothing);
    await _capture(tester, capture, 'turntable-empty');
    await _animate(tester, 3.26);
    expect(find.byType(Tooltip), findsNothing);
    expect(find.byType(VinylRecord), findsOneWidget);
    await _capture(tester, capture, 'turntable-waiting');

    requests.start();
    await tester.pump();
    expect(requests.current.nowPlaying!.starting, isFalse);
    await _animate(tester, 0.65);
    expect(find.byType(Tooltip), findsNothing);
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

  testWidgets(
    'compact track strip grows with text scale and controls stay on deck',
    (tester) async {
      final requests = _Requests()..start();
      final capture = GlobalKey();
      await _loadFonts(tester);
      await tester.pumpWidget(_surface(requests, capture));
      await _animate(tester, 5);
      final player = find.byKey(const ValueKey('music_turntable'));
      final normalHeight = tester.getSize(player).height;

      void expectPanelPadding() {
        final panel = find.byKey(const ValueKey('turntable_info_panel'));
        final row = find.byKey(const ValueKey('turntable_track_marquee'));
        final panelRect = tester.getRect(panel);
        final rowRect = tester.getRect(row);
        expect(rowRect.left, closeTo(panelRect.left, 0.001));
        expect(rowRect.top - panelRect.top, closeTo(10, 0.001));
        expect(rowRect.right, closeTo(panelRect.right, 0.001));
        expect(
          tester
                  .getTopLeft(
                    find.byKey(const ValueKey('turntable_track_text')),
                  )
                  .dx -
              panelRect.left,
          closeTo(16, 0.001),
        );
        expect(panelRect.bottom - rowRect.bottom, closeTo(10, 0.001));
        final deckRect = tester.getRect(
          find.byKey(const ValueKey('turntable_deck')),
        );
        for (final key in [
          'turntable_pause',
          'turntable_skip',
          'turntable_queue',
        ]) {
          expect(
            deckRect.contains(tester.getCenter(find.byKey(ValueKey(key)))),
            isTrue,
          );
        }
      }

      expectPanelPadding();
      expect(normalHeight, lessThan(325));
      await tester.pumpWidget(_surface(requests, capture, textScale: 1.75));
      await tester.pump();
      expect(tester.getSize(player).height, greaterThan(normalHeight));
      expectPanelPadding();
      expect(tester.takeException(), isNull);
      await _capture(tester, capture, 'turntable-panel-large-text');
      await tester.pumpWidget(const SizedBox.shrink());
      await requests.close();
    },
  );

  testWidgets(
    'long track metadata scrolls on one line without moving the controls',
    (tester) async {
      final requests = _Requests(
        title:
            'A very long track title that keeps the full song name readable while the record is playing',
      )..start();
      final capture = GlobalKey();
      await _loadFonts(tester);
      await tester.pumpWidget(_surface(requests, capture));
      await _animate(tester, 1);
      final initialStrip = tester.getRect(
        find.byKey(const ValueKey('turntable_track_marquee')),
      );
      final initialTitle = tester.getTopLeft(
        find.byKey(const ValueKey('turntable_track_text')),
      );
      expect(initialTitle.dx - initialStrip.left, closeTo(16, 0.001));
      await _animate(tester, 4);
      final title = find.byKey(const ValueKey('turntable_track_text'));
      final strip = find.byKey(const ValueKey('turntable_track_marquee'));
      final pause = find.byKey(const ValueKey('turntable_pause'));
      final titleLeft = tester.getTopLeft(title).dx;
      final buttonRect = tester.getRect(pause);
      final stripRect = tester.getRect(strip);
      await _animate(tester, 0.5);
      expect(tester.getTopLeft(title).dx, lessThan(titleLeft));
      expect(tester.getTopLeft(title).dx, lessThan(stripRect.left));
      expect(tester.getRect(strip), stripRect);
      expect(tester.getRect(pause), buttonRect);
      expect(tester.widget<Text>(title).maxLines, 1);
      expect(
        tester.widget<Text>(title).textSpan!.toPlainText(),
        contains(' • M83 • Viewer'),
      );
      await _capture(tester, capture, 'turntable-long-track');
      await tester.pumpWidget(const SizedBox.shrink());
      await requests.close();
    },
  );

  testWidgets('author glyphs match text painted without a vertical clip', (
    tester,
  ) async {
    final requests = _Requests(
      title: 'My Only Heart',
      author: 'Nightjacket - Topic',
      requestedBy: 'dealnoteDev',
    )..start();
    final capture = GlobalKey();
    await _loadFonts(tester);
    for (final scale in [1.0, 1.75]) {
      await tester.pumpWidget(_surface(requests, capture, textScale: scale));
      await _animate(tester, 5);
      for (final ratio in [1.0, 1.25, 1.5, 2.0]) {
        await _expectUnclippedAuthor(
          tester,
          capture,
          scale: scale,
          ratio: ratio,
        );
      }
    }
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

  testWidgets('all vinyl editions preserve the cover and record dimensions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1080, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cover = (await tester.runAsync(_sampleCover))!;
    final capture = GlobalKey();
    await _loadFonts(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'TurntableTestFont'),
        home: Scaffold(
          backgroundColor: const Color(0xFF101322),
          body: Center(
            child: RepaintBoundary(
              key: capture,
              child: ColoredBox(
                color: const Color(0xFF101322),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final edition in VinylEdition.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                edition.name.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFFEAE4F4),
                                  fontSize: 14,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 20),
                              VinylRecord(
                                edition: edition,
                                artwork: MemoryImage(cover),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        MemoryImage(cover),
        tester.element(find.byType(VinylRecord).first),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(VinylRecord), findsNWidgets(4));
    expect(find.byType(Image), findsNWidgets(4));
    for (final record in find.byType(VinylRecord).evaluate()) {
      expect(
        tester.getSize(find.byWidget(record.widget)),
        const Size.square(220),
      );
    }
    for (final artwork in find.byType(Image).evaluate()) {
      expect(
        tester.getSize(find.byWidget(artwork.widget)),
        const Size.square(128),
      );
    }
    expect(tester.takeException(), isNull);
    await _capture(tester, capture, 'vinyl-editions');
  });

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
      final trackTwo = find.byKey(const ValueKey('turntable_queue_text_two'));
      final trackThree = find.byKey(
        const ValueKey('turntable_queue_text_three'),
      );
      expect(queue, findsNothing);
      expect(divider, findsNothing);
      expect(tester.widget<Text>(count).data, '2');

      void expectPanelSpacing() {
        final panelRect = tester.getRect(
          find.byKey(const ValueKey('turntable_info_panel')),
        );
        final currentRect = tester.getRect(
          find.byKey(const ValueKey('turntable_track_marquee')),
        );
        final dividerRect = tester.getRect(divider);
        final queueRect = tester.getRect(queue);
        final topPadding = currentRect.top - panelRect.top;
        expect(
          dividerRect.top - currentRect.bottom,
          closeTo(topPadding, 0.001),
        );
        expect(queueRect.top - dividerRect.bottom, closeTo(topPadding, 0.001));
        expect(panelRect.bottom - queueRect.bottom, closeTo(topPadding, 0.001));
      }

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
      expect(trackTwo, findsOneWidget);
      expect(trackThree, findsOneWidget);
      expect(
        tester.widget<Text>(trackTwo).textSpan!.toPlainText(),
        'Song two • Artist • Listener',
      );
      expect(
        tester.widget<Text>(trackThree).textSpan!.toPlainText(),
        'Song three • Artist • Listener',
      );
      expect(tester.widget<Text>(trackTwo).maxLines, isNull);
      expect(tester.widget<Text>(trackTwo).softWrap, isTrue);
      expect(tester.getSize(queue).height, lessThan(72));
      expectPanelSpacing();
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('UP NEXT'), findsNothing);
      expect(tester.widget<Text>(count).data, '2');
      expect(
        tester.getRect(trackTwo).left,
        tester
                .getRect(find.byKey(const ValueKey('turntable_info_panel')))
                .left +
            16,
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

      final shortTrackHeight = tester.getSize(trackTwo).height;
      requests.setQueue([
        _queuedItem(
          'two',
          title:
              'A much longer track title that wraps naturally onto another line without scrolling',
          phase: MusicQueueItemPhase.downloading,
          progress: 0.75,
        ),
        _queuedItem('three'),
      ]);
      await tester.pump();
      expect(find.text('75%'), findsOneWidget);
      final wrappedRect = tester.getRect(trackTwo);
      expectPanelSpacing();
      expect(wrappedRect.height, greaterThan(shortTrackHeight));
      expect(
        tester.getCenter(find.text('75%')).dy,
        closeTo(wrappedRect.center.dy, 0.001),
      );
      expect(
        tester.getCenter(find.byKey(const ValueKey('remove_music_two'))).dy,
        closeTo(wrappedRect.center.dy, 0.001),
      );
      await _animate(tester, 0.5);
      expect(tester.getRect(trackTwo), wrappedRect);
      await _capture(tester, capture, 'turntable-queue-wrapped');
      await tester.tap(find.byKey(const ValueKey('remove_music_two')));
      await tester.pump();
      expect(trackTwo, findsNothing);
      expect(trackThree, findsOneWidget);
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
      final track = find.byKey(const ValueKey('turntable_track_marquee'));
      final currentTrackTop = tester.getTopLeft(track).dy;
      final queueButton = find.byKey(const ValueKey('turntable_queue'));
      final queueButtonTop = tester.getTopLeft(queueButton).dy;
      await _capture(tester, capture, 'turntable-queue-scroll-top');

      await tester.drag(scrollView, const Offset(0, -240));
      await _animate(tester, 0.6);
      expect(position.pixels, greaterThan(0));
      expect(tester.getTopLeft(track).dy, lessThan(currentTrackTop));
      expect(tester.getTopLeft(player).dy, playerTop);
      expect(tester.getTopLeft(queueButton).dy, queueButtonTop);
      expect(queueButton.hitTestable(), findsOneWidget);
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      final lastRemove = find.byKey(const ValueKey('remove_music_long-19'));
      expect(lastRemove.hitTestable(), findsOneWidget);
      await _capture(tester, capture, 'turntable-queue-scroll-bottom');
      await tester.tap(lastRemove);
      await tester.pump();
      expect(requests.current.queue.length, 19);
      expect(
        find.byKey(const ValueKey('turntable_queue_text_long-19')),
        findsNothing,
      );

      requests.setQueue([_queuedItem('short')]);
      await tester.pump();
      expect(tester.getSize(panel).height, lessThan(480));
      expect(position.maxScrollExtent, 0);
      expect(position.pixels, 0);
      expect(track.hitTestable(), findsOneWidget);
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
  String? title,
  MusicQueueItemPhase phase = MusicQueueItemPhase.ready,
  double? progress,
  Uri? artwork,
}) => MusicQueueItem(
  id: id,
  requestedBy: 'Listener',
  sourceUrl: Uri.parse('https://youtu.be/$id'),
  phase: phase,
  title: title ?? 'Song $id',
  author: 'Artist',
  duration: const Duration(minutes: 3),
  thumbnail: artwork,
  downloadProgress: progress,
);

MusicQueueItem _resolvingItem(String id) => MusicQueueItem(
  id: id,
  requestedBy: 'Listener',
  sourceUrl: Uri.parse('https://youtu.be/$id'),
  phase: MusicQueueItemPhase.resolving,
  title: null,
  author: null,
  duration: null,
  thumbnail: null,
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
  theme: ThemeData(fontFamily: 'TurntableTestFont', useMaterial3: false),
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

Future<void> _expectUnclippedAuthor(
  WidgetTester tester,
  GlobalKey capture, {
  required double scale,
  required double ratio,
}) async {
  final title = find.byKey(const ValueKey('turntable_track_text'));
  final richText = find.descendant(of: title, matching: find.byType(RichText));
  final richWidget = tester.widget<RichText>(richText);
  final chassis =
      find
          .ancestor(
            of: title,
            matching: find.byWidgetPredicate(
              (widget) => widget is CustomPaint && widget.painter != null,
            ),
          )
          .first;
  final boundary =
      capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final boundaryOrigin = tester.getTopLeft(find.byKey(capture));
  final textOrigin = tester.getTopLeft(richText) - boundaryOrigin;
  final chassisOrigin = tester.getTopLeft(chassis) - boundaryOrigin;
  final chassisSize = tester.getSize(chassis);
  final painter = TextPainter(
    text: richWidget.text,
    textDirection: richWidget.textDirection,
    textScaler: richWidget.textScaler,
    locale: richWidget.locale,
    textHeightBehavior: richWidget.textHeightBehavior,
    maxLines: 1,
  )..layout();
  final start = richWidget.text.toPlainText().indexOf('Nightjacket');
  final authorBox = painter
      .getBoxesForSelection(
        TextSelection(
          baseOffset: start,
          extentOffset: start + 'Nightjacket - Topic'.length,
        ),
      )
      .first
      .toRect()
      .shift(textOrigin);
  // Compare inside the rounded chassis edge, where only vertical clipping matters.
  final left = math.max(
    authorBox.left,
    chassisOrigin.dx + TurntableGeometry.chassisOrigin.dx + 19,
  );
  final right = math.min(
    authorBox.right,
    chassisOrigin.dx +
        chassisSize.width -
        TurntableGeometry.chassisOrigin.dx -
        19,
  );
  expect(right, greaterThan(left));
  final differentPixels = await tester.runAsync(() async {
    final actual = await boundary.toImage(pixelRatio: ratio);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(ratio);
    canvas.save();
    canvas.translate(chassisOrigin.dx, chassisOrigin.dy);
    tester.widget<CustomPaint>(chassis).painter!.paint(canvas, chassisSize);
    canvas.restore();
    painter.paint(canvas, textOrigin);
    final picture = recorder.endRecording();
    final expected = await picture.toImage(actual.width, actual.height);
    final maskRecorder = ui.PictureRecorder();
    painter.paint(Canvas(maskRecorder)..scale(ratio), textOrigin);
    final maskPicture = maskRecorder.endRecording();
    final mask = await maskPicture.toImage(actual.width, actual.height);
    final maskBytes =
        (await mask.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
    final actualBytes =
        (await actual.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
    final expectedBytes =
        (await expected.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
    var differentPixels = 0;
    for (
      var y = ((textOrigin.dy - 2) * ratio).floor();
      y < ((textOrigin.dy + painter.height + 4) * ratio).ceil();
      y++
    ) {
      for (var x = (left * ratio).ceil(); x < (right * ratio).floor(); x++) {
        final index = (y * actual.width + x) * 4;
        if (maskBytes[index + 3] == 0) continue;
        for (var channel = 0; channel < 4; channel++) {
          if ((actualBytes[index + channel] - expectedBytes[index + channel])
                  .abs() >
              2) {
            differentPixels++;
            break;
          }
        }
      }
    }
    if (Platform.environment['MUSIC_CAPTURE'] == '1') {
      for (final (name, image) in [
        ('actual', actual),
        ('expected', expected),
      ]) {
        final file = File(
          'build/test-screenshots/turntable-glyphs-$scale-$ratio-$name.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(
          (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List(),
        );
      }
    }
    actual.dispose();
    expected.dispose();
    picture.dispose();
    mask.dispose();
    maskPicture.dispose();
    return differentPixels;
  });
  painter.dispose();
  expect(
    differentPixels,
    0,
    reason:
        'Every author glyph pixel must remain visible at text scale $scale and pixel ratio $ratio.',
  );
}

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
      ('TurntableTestFont', r'C:\Windows\Fonts\segoeuib.ttf'),
      ('TurntableTestFont', r'C:\Windows\Fonts\segoeuii.ttf'),
      ('TurntableTestFont', r'C:\Windows\Fonts\segoeuiz.ttf'),
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

  _Requests({
    String itemId = 'one',
    Uri? artwork,
    String title = 'Midnight City',
    String author = 'M83',
    String requestedBy = 'Viewer',
  }) : _current = MusicQueueSnapshot(
         revision: 1,
         nowPlaying: null,
         queue: [
           MusicQueueItem(
             id: itemId,
             requestedBy: requestedBy,
             sourceUrl: Uri.parse('https://youtu.be/$itemId'),
             phase: MusicQueueItemPhase.downloading,
             title: title,
             author: author,
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
