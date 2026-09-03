import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/music/music_queue_overlay.dart';
import 'package:obssource/music/music_requests.dart';

void main() {
  const collapseDelay = Duration(seconds: 1);
  const animationDuration = Duration(milliseconds: 200);

  testWidgets('collapses to an artwork square and expands on hover', (
    tester,
  ) async {
    final requests = _FakeMusicRequests(_snapshot());
    addTearDown(requests.dispose);

    await tester.pumpWidget(
      _TestSurface(
        requests: requests,
        collapseDelay: collapseDelay,
        animationDuration: animationDuration,
      ),
    );

    expect(find.byKey(const ValueKey('music_player_expanded')), findsOneWidget);

    await tester.pump(collapseDelay);

    expect(find.byKey(const ValueKey('music_player_expanded')), findsOneWidget);
    expect(find.byKey(const ValueKey('music_player_compact')), findsOneWidget);

    await tester.pump(animationDuration);
    await tester.pump(const Duration(milliseconds: 1));

    final compact = find.byKey(const ValueKey('music_player_compact'));
    expect(compact, findsOneWidget);
    expect(find.byKey(const ValueKey('music_player_expanded')), findsNothing);
    expect(tester.getSize(compact), const Size.square(82));
    expect(
      find.byKey(const ValueKey('music_compact_border_progress')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(compact));
    await tester.pump();

    expect(find.byKey(const ValueKey('music_player_expanded')), findsOneWidget);
    await mouse.removePointer();
  });

  testWidgets('playback and queue changes reveal the player again', (
    tester,
  ) async {
    final requests = _FakeMusicRequests(_snapshot());
    addTearDown(requests.dispose);

    await tester.pumpWidget(
      _TestSurface(
        requests: requests,
        collapseDelay: collapseDelay,
        animationDuration: animationDuration,
      ),
    );
    await _collapse(tester, collapseDelay, animationDuration);

    requests.emit(_snapshot(revision: 2, paused: true));
    await tester.pump();
    expect(find.byKey(const ValueKey('music_player_expanded')), findsOneWidget);

    await _collapse(tester, collapseDelay, animationDuration);
    requests.emit(
      _snapshot(revision: 3, paused: true, queue: [_queueItem('queued-track')]),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('music_player_expanded')), findsOneWidget);
    expect(find.text('ДАЛІ'), findsOneWidget);
  });

  testWidgets('download phase changes keep the player compact', (tester) async {
    final requests = _FakeMusicRequests(
      _snapshot(
        queue: [
          _queueItem('queued-track', phase: MusicQueueItemPhase.downloading),
        ],
      ),
    );
    addTearDown(requests.dispose);

    await tester.pumpWidget(
      _TestSurface(
        requests: requests,
        collapseDelay: collapseDelay,
        animationDuration: animationDuration,
      ),
    );
    await _collapse(tester, collapseDelay, animationDuration);

    requests.emit(
      _snapshot(
        revision: 2,
        queue: [_queueItem('queued-track', phase: MusicQueueItemPhase.ready)],
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('music_player_compact')), findsOneWidget);
    expect(find.byKey(const ValueKey('music_player_expanded')), findsNothing);
  });

  testWidgets('expanded player seeks, skips, and removes queued tracks', (
    tester,
  ) async {
    final requests = _FakeMusicRequests(
      _snapshot(queue: [_queueItem('queued-track')]),
    );
    addTearDown(requests.dispose);

    await tester.pumpWidget(
      _TestSurface(
        requests: requests,
        collapseDelay: collapseDelay,
        animationDuration: animationDuration,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('music_skip_button')));
    await tester.tap(find.byKey(const ValueKey('remove_music_queued-track')));

    final seekBar = find.byKey(const ValueKey('music_seek_bar'));
    final seekRect = tester.getRect(seekBar);
    await tester.tapAt(
      Offset(seekRect.left + seekRect.width * 0.75, seekRect.center.dy),
    );
    await tester.pump();

    expect(requests.skipCount, 1);
    expect(requests.removedItemIds, ['queued-track']);
    expect(requests.seekPositions.single.inSeconds, 135);
  });
}

Future<void> _collapse(
  WidgetTester tester,
  Duration collapseDelay,
  Duration animationDuration,
) async {
  await tester.pump(collapseDelay);
  await tester.pump(animationDuration);
  await tester.pump(const Duration(milliseconds: 1));
  expect(find.byKey(const ValueKey('music_player_compact')), findsOneWidget);
}

MusicQueueSnapshot _snapshot({
  int revision = 1,
  bool paused = false,
  List<MusicQueueItem> queue = const [],
}) {
  final item = _queueItem('playing-track');
  return MusicQueueSnapshot(
    revision: revision,
    nowPlaying: MusicNowPlaying(
      item: item,
      startedAt: DateTime(2026, 9, 3, 12),
      position: const Duration(minutes: 1),
      positionUpdatedAt: DateTime.now(),
      paused: paused,
    ),
    queue: queue,
    lastError: null,
  );
}

MusicQueueItem _queueItem(
  String id, {
  MusicQueueItemPhase phase = MusicQueueItemPhase.ready,
}) {
  return MusicQueueItem(
    id: id,
    requestedBy: 'Viewer',
    sourceUrl: Uri.parse('https://youtu.be/$id'),
    phase: phase,
    title: 'Track $id',
    author: 'Artist',
    duration: const Duration(minutes: 3),
    thumbnail: null,
    downloadProgress: 1,
  );
}

class _TestSurface extends StatelessWidget {
  final MusicRequests requests;
  final Duration collapseDelay;
  final Duration animationDuration;

  const _TestSurface({
    required this.requests,
    required this.collapseDelay,
    required this.animationDuration,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(
              right: 24,
              bottom: 24,
              child: MusicQueueOverlay(
                requests: requests,
                collapseDelay: collapseDelay,
                animationDuration: animationDuration,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FakeMusicRequests implements MusicRequests {
  final _states = StreamController<MusicQueueSnapshot>.broadcast();
  final List<Duration> seekPositions = [];
  final List<String> removedItemIds = [];
  MusicQueueSnapshot _current;
  int skipCount = 0;

  _FakeMusicRequests(this._current);

  @override
  MusicQueueSnapshot get current => _current;

  @override
  Stream<MusicQueueSnapshot> get states => _states.stream;

  void emit(MusicQueueSnapshot snapshot) {
    _current = snapshot;
    _states.add(snapshot);
  }

  Future<void> dispose() => _states.close();

  @override
  Future<void> close() => dispose();

  @override
  Future<bool> setPaused(bool paused) async => true;

  @override
  Future<bool> seek(Duration position) async {
    seekPositions.add(position);
    return true;
  }

  @override
  Future<bool> skip() async {
    skipCount++;
    return true;
  }

  @override
  Future<bool> remove(String itemId) async {
    removedItemIds.add(itemId);
    return true;
  }
}
