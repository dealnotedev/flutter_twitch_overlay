import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/twitch/ws_event.dart';

void main() {
  late StreamController<WsMessage> events;
  late Directory cache;
  late _FakeFetcher fetcher;
  late _FakePlayer player;
  MusicRequestManager? manager;

  setUp(() async {
    events = StreamController<WsMessage>.broadcast();
    cache = await Directory.systemTemp.createTemp('music_requests_test_');
    fetcher = _FakeFetcher(cache);
    player = _FakePlayer();
  });

  tearDown(() async {
    await manager?.close();
    await events.close();
    if (await cache.exists()) await cache.delete(recursive: true);
  });

  MusicRequestManager createManager({
    String? rewardId = 'reward-1',
    Stream<String?>? rewardIdChanges,
  }) {
    return manager = MusicRequestManager(
      events: events.stream,
      fetcher: fetcher,
      player: player,
      enabled: true,
      maxQueueLength: 10,
      maxDuration: const Duration(minutes: 10),
      rewardId: rewardId,
      rewardIdChanges: rewardIdChanges,
    );
  }

  test('ignores redemptions for a different reward', () async {
    final subject = createManager(rewardId: 'reward-1');

    events.add(_redemption(id: 'one', rewardId: 'reward-2'));
    await _flushEvents();

    expect(fetcher.inspected, isEmpty);
    expect(subject.current.queue, isEmpty);
    expect(subject.current.nowPlaying, isNull);
  });

  test('ignores all redemptions when no reward is selected', () async {
    final subject = createManager(rewardId: null);

    events.add(_redemption(id: 'one'));
    await _flushEvents();

    expect(fetcher.inspected, isEmpty);
    expect(subject.current.queue, isEmpty);
    expect(subject.current.nowPlaying, isNull);
  });

  test('switches to the selected reward id without restarting', () async {
    final rewardIds = StreamController<String?>.broadcast();
    addTearDown(rewardIds.close);
    final subject = createManager(
      rewardId: 'reward-1',
      rewardIdChanges: rewardIds.stream,
    );

    events.add(
      _redemption(id: 'wrong', rewardId: 'reward-2', title: 'Play Music'),
    );
    await _flushEvents();
    expect(fetcher.inspected, isEmpty);

    rewardIds.add('reward-2');
    await _flushEvents();
    events.add(
      _redemption(
        id: 'accepted',
        rewardId: 'reward-2',
        title: 'Renamed on Twitch',
      ),
    );
    await _waitUntil(() => subject.current.nowPlaying?.item.id == 'accepted');

    expect(subject.current.nowPlaying?.item.id, 'accepted');
  });

  test('rejects an invalid YouTube URL without invoking yt-dlp', () async {
    final subject = createManager();

    events.add(
      _redemption(id: 'one', input: 'https://example.com/not-youtube'),
    );
    await _waitUntil(() => subject.current.lastError != null);

    expect(
      subject.current.lastError?.type,
      MusicQueueErrorType.invalidYoutubeUrl,
    );
    expect(subject.current.lastError?.requester, 'Viewer one');
    expect(fetcher.inspected, isEmpty);
    expect(player.played, isEmpty);
  });

  test('downloads and plays accepted requests in FIFO order', () async {
    final subject = createManager();

    events
      ..add(_redemption(id: 'one', input: 'https://youtu.be/one'))
      ..add(_redemption(id: 'two', input: 'https://youtube.com/watch?v=two'));

    await _waitUntil(
      () => player.played.length == 1 && fetcher.downloaded.length == 2,
    );
    expect(player.played.single.itemId, 'one');
    expect(subject.current.nowPlaying?.item.id, 'one');
    expect(subject.current.queue.map((item) => item.id), ['two']);

    player.finishCurrent();
    await _waitUntil(() => player.played.length == 2);

    expect(player.played.map((track) => track.itemId), ['one', 'two']);
    expect(subject.current.nowPlaying?.item.id, 'two');
    expect(
      await File('${cache.path}${Platform.pathSeparator}one.mp3').exists(),
      isTrue,
    );
  });

  test('pauses and resumes the current track without advancing', () async {
    final subject = createManager();
    events.add(_redemption(id: 'one'));
    await _waitUntil(() => player.played.length == 1);

    expect(await subject.setPaused(true), isTrue);
    expect(subject.current.nowPlaying?.paused, isTrue);
    expect(player.pauseChanges, [true]);

    await _flushEvents();
    expect(subject.current.nowPlaying?.item.id, 'one');

    expect(await subject.setPaused(false), isTrue);
    expect(subject.current.nowPlaying?.paused, isFalse);
    expect(player.pauseChanges, [true, false]);
  });

  test('cannot pause when no track is playing', () async {
    final subject = createManager();

    expect(await subject.setPaused(true), isFalse);
    expect(player.pauseChanges, isEmpty);
  });

  test('seeks the current track and updates its reported position', () async {
    final subject = createManager();
    events.add(_redemption(id: 'one'));
    await _waitUntil(() => player.played.length == 1);

    expect(await subject.seek(const Duration(minutes: 2)), isTrue);

    expect(player.seekPositions, [const Duration(minutes: 2)]);
    expect(subject.current.nowPlaying?.position.inSeconds, 120);
  });

  test('removes a waiting track without deleting its cached file', () async {
    final subject = createManager();
    events
      ..add(_redemption(id: 'one', input: 'https://youtu.be/one'))
      ..add(_redemption(id: 'two', input: 'https://youtu.be/two'));
    await _waitUntil(
      () => player.played.length == 1 && fetcher.downloaded.length == 2,
    );
    final queuedFile = File('${cache.path}${Platform.pathSeparator}two.mp3');
    expect(await queuedFile.exists(), isTrue);

    expect(await subject.remove('two'), isTrue);

    expect(subject.current.queue, isEmpty);
    expect(await queuedFile.exists(), isTrue);
    expect(await subject.remove('one'), isFalse);
  });

  test('removing the track being downloaded cancels the fetcher', () async {
    final subject = createManager();
    fetcher.blockedDownloads.add('default');
    events.add(_redemption(id: 'one'));
    await _waitUntil(() => fetcher.activeBlocks.containsKey('default'));

    expect(await subject.remove('one'), isTrue);

    expect(subject.current.queue, isEmpty);
    expect(fetcher.cancelCount, 1);
  });
}

WsMessage _redemption({
  required String id,
  String rewardId = 'reward-1',
  String title = 'Play Music',
  String input = 'https://youtu.be/default',
}) {
  return WsMessage.fromJson({
    'payload': {
      'subscription': {
        'type': 'channel.channel_points_custom_reward_redemption.add',
      },
      'event': {
        'id': id,
        'user_id': 'user-$id',
        'user_login': 'viewer_$id',
        'user_name': 'Viewer $id',
        'user_input': input,
        'redeemed_at': '2026-09-03T12:30:00Z',
        'reward': {'id': rewardId, 'title': title, 'cost': 100},
      },
    },
  });
}

Future<void> _flushEvents() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for an asynchronous music queue transition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class _FakeFetcher implements MusicTrackFetcher {
  final Directory cache;
  final List<Uri> inspected = [];
  final List<Uri> downloaded = [];
  final Set<String> blockedDownloads = {};
  final Map<String, Completer<void>> activeBlocks = {};
  int cancelCount = 0;

  _FakeFetcher(this.cache);

  @override
  Future<MusicTrackMetadata> inspect(Uri sourceUrl) async {
    inspected.add(sourceUrl);
    final videoId =
        sourceUrl.pathSegments.lastOrNull ??
        sourceUrl.queryParameters['v'] ??
        'video';
    return MusicTrackMetadata(
      videoId: videoId,
      title: 'Track $videoId',
      author: 'Artist',
      duration: const Duration(minutes: 3),
      thumbnail: null,
      sourceUrl: sourceUrl,
    );
  }

  @override
  Future<String> obtain({
    required MusicTrackMetadata metadata,
    required void Function(MusicDownloadProgress progress) onProgress,
  }) async {
    downloaded.add(metadata.sourceUrl);
    if (blockedDownloads.contains(metadata.videoId)) {
      final blocker = Completer<void>();
      activeBlocks[metadata.videoId] = blocker;
      await blocker.future;
      activeBlocks.remove(metadata.videoId);
    }
    onProgress(
      const MusicDownloadProgress(
        downloadedBytes: 50,
        totalBytes: 100,
        eta: Duration(seconds: 1),
      ),
    );
    final file = File(
      '${cache.path}${Platform.pathSeparator}${metadata.videoId}.mp3',
    );
    await file.writeAsBytes([1, 2, 3]);
    return file.path;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    for (final blocker in activeBlocks.values) {
      if (!blocker.isCompleted) blocker.complete();
    }
    activeBlocks.clear();
  }
}

class _FakePlayer implements MusicTrackPlayer {
  final List<DownloadedMusicTrack> played = [];
  final List<bool> pauseChanges = [];
  final List<Duration> seekPositions = [];
  Completer<void>? _current;

  @override
  Future<void> play(DownloadedMusicTrack track) async {
    played.add(track);
    final completer = Completer<void>();
    _current = completer;
    await completer.future;
  }

  void finishCurrent() {
    final completer = _current;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  @override
  Future<void> setPaused(bool paused) async {
    pauseChanges.add(paused);
  }

  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
  }

  @override
  Future<void> stop() async => finishCurrent();
}

extension on List<String> {
  String? get lastOrNull => this.isEmpty ? null : last;
}
