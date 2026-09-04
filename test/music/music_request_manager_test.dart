import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/twitch/twitch_redemption.dart';
import 'package:obssource/twitch/twitch_redemption_service.dart';
import 'package:obssource/twitch/ws_event.dart';

void main() {
  late StreamController<WsMessage> events;
  late Directory cache;
  late _FakeFetcher fetcher;
  late _FakePlayer player;
  late _FakeRedemptionService redemptions;
  MusicRequestManager? manager;

  setUp(() async {
    events = StreamController<WsMessage>.broadcast();
    cache = await Directory.systemTemp.createTemp('music_requests_test_');
    fetcher = _FakeFetcher(cache);
    player = _FakePlayer();
    redemptions = _FakeRedemptionService();
  });

  tearDown(() async {
    await manager?.close();
    await events.close();
    if (await cache.exists()) await cache.delete(recursive: true);
  });

  MusicRequestManager createManager({
    String? rewardId = 'reward-1',
    Stream<String?>? rewardIdChanges,
    int maxQueueLength = 10,
  }) {
    return manager = MusicRequestManager(
      events: events.stream,
      fetcher: fetcher,
      player: player,
      enabled: true,
      maxQueueLength: maxQueueLength,
      maxDuration: const Duration(minutes: 10),
      rewardId: rewardId,
      rewardIdChanges: rewardIdChanges,
      redemptionService: redemptions,
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
    await _waitUntil(
      () =>
          subject.current.lastError != null &&
          redemptions.settlements.isNotEmpty,
    );

    expect(
      subject.current.lastError?.type,
      MusicQueueErrorType.invalidYoutubeUrl,
    );
    expect(subject.current.lastError?.requester, 'Viewer one');
    expect(fetcher.inspected, isEmpty);
    expect(player.played, isEmpty);
    expect(redemptions.settlements.single.redemptionId, 'one');
    expect(
      redemptions.settlements.single.status,
      TwitchRedemptionStatus.canceled,
    );
  });

  test('refunds a redemption with missing viewer input', () async {
    final subject = createManager();

    events.add(_redemption(id: 'one', input: '  '));
    await _waitUntil(() => redemptions.settlements.isNotEmpty);

    expect(
      subject.current.lastError?.type,
      MusicQueueErrorType.missingYoutubeUrl,
    );
    expect(
      redemptions.settlements.single.status,
      TwitchRedemptionStatus.canceled,
    );
  });

  test('refunds a redemption when the queue is full', () async {
    final subject = createManager(maxQueueLength: 1);
    events.add(_redemption(id: 'one'));
    await _waitUntil(() => player.played.length == 1);

    events.add(_redemption(id: 'two', input: 'https://youtu.be/two'));
    await _waitUntil(() => redemptions.settlements.isNotEmpty);

    expect(subject.current.lastError?.type, MusicQueueErrorType.queueFull);
    expect(redemptions.settlements.single.redemptionId, 'two');
    expect(
      redemptions.settlements.single.status,
      TwitchRedemptionStatus.canceled,
    );
  });

  test('refunds a track that is too long', () async {
    final subject = createManager();
    fetcher.inspectedDuration = const Duration(minutes: 11);

    events.add(_redemption(id: 'one'));
    await _waitUntil(() => redemptions.settlements.isNotEmpty);

    expect(
      subject.current.lastError?.type,
      MusicQueueErrorType.trackTooLongOrLive,
    );
    expect(
      redemptions.settlements.single.status,
      TwitchRedemptionStatus.canceled,
    );
  });

  test('refunds a redemption when track preparation fails', () async {
    final subject = createManager();
    fetcher.inspectError = StateError('yt-dlp failed');

    events.add(_redemption(id: 'one'));
    await _waitUntil(() => redemptions.settlements.isNotEmpty);

    expect(
      subject.current.lastError?.type,
      MusicQueueErrorType.operationFailed,
    );
    expect(
      redemptions.settlements.single.status,
      TwitchRedemptionStatus.canceled,
    );
  });

  test('fulfills a redemption after normal playback completion', () async {
    final subject = createManager();
    events.add(_redemption(id: 'one'));
    await _waitUntil(() => player.played.length == 1);

    player.finishCurrent();
    await _waitUntil(() => redemptions.settlements.isNotEmpty);

    expect(redemptions.settlements.single.redemptionId, 'one');
    expect(
      redemptions.settlements.single.status,
      TwitchRedemptionStatus.fulfilled,
    );
    expect(subject.current.nowPlaying, isNull);
  });

  test('fulfills a redemption when playback is skipped', () async {
    final subject = createManager();
    events.add(_redemption(id: 'one'));
    await _waitUntil(() => player.played.length == 1);

    expect(await subject.skip(), isTrue);
    await _waitUntil(() => redemptions.settlements.isNotEmpty);

    expect(
      redemptions.settlements.single.status,
      TwitchRedemptionStatus.fulfilled,
    );
  });

  test('refunds a redemption when playback fails', () async {
    final subject = createManager();
    player.playError = StateError('native player failed');

    events.add(_redemption(id: 'one'));
    await _waitUntil(() => redemptions.settlements.isNotEmpty);

    expect(
      subject.current.lastError?.type,
      MusicQueueErrorType.operationFailed,
    );
    expect(
      redemptions.settlements.single.status,
      TwitchRedemptionStatus.canceled,
    );
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
    await _waitUntil(() => redemptions.settlements.isNotEmpty);
    expect(redemptions.settlements.single.redemptionId, 'two');
    expect(
      redemptions.settlements.single.status,
      TwitchRedemptionStatus.canceled,
    );
  });

  test('removing the track being downloaded cancels the fetcher', () async {
    final subject = createManager();
    fetcher.blockedDownloads.add('default');
    events.add(_redemption(id: 'one'));
    await _waitUntil(() => fetcher.activeBlocks.containsKey('default'));

    expect(await subject.remove('one'), isTrue);

    expect(subject.current.queue, isEmpty);
    expect(fetcher.cancelCount, 1);
    await _waitUntil(() => redemptions.settlements.isNotEmpty);
    expect(
      redemptions.settlements.single.status,
      TwitchRedemptionStatus.canceled,
    );
  });

  test('does not retry a failed Twitch status update', () async {
    redemptions.settleError = StateError('network unavailable');
    createManager();

    events.add(_redemption(id: 'one', input: 'not a YouTube URL'));
    await _waitUntil(() => redemptions.settlements.length == 1);
    events.add(_redemption(id: 'one', input: 'not a YouTube URL'));
    await _flushEvents();

    expect(redemptions.settlements.length, 1);
  });

  test(
    'does not settle active playback while the application is closing',
    () async {
      final subject = createManager();
      events.add(_redemption(id: 'one'));
      await _waitUntil(() => player.played.length == 1);

      await subject.close();
      manager = null;

      expect(redemptions.settlements, isEmpty);
    },
  );
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
  Duration inspectedDuration = const Duration(minutes: 3);
  Object? inspectError;
  Object? downloadError;

  _FakeFetcher(this.cache);

  @override
  Future<MusicTrackMetadata> inspect(Uri sourceUrl) async {
    inspected.add(sourceUrl);
    final inspectError = this.inspectError;
    if (inspectError != null) throw inspectError;
    final videoId =
        sourceUrl.pathSegments.lastOrNull ??
        sourceUrl.queryParameters['v'] ??
        'video';
    return MusicTrackMetadata(
      videoId: videoId,
      title: 'Track $videoId',
      author: 'Artist',
      duration: inspectedDuration,
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
    final downloadError = this.downloadError;
    if (downloadError != null) throw downloadError;
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
  Object? playError;

  @override
  Future<void> play(DownloadedMusicTrack track) async {
    played.add(track);
    final playError = this.playError;
    if (playError != null) throw playError;
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

class _FakeRedemptionService implements TwitchRedemptionService {
  final List<_Settlement> settlements = [];
  Object? settleError;

  @override
  Future<void> settle({
    required String rewardId,
    required String redemptionId,
    required TwitchRedemptionStatus status,
  }) async {
    settlements.add(
      _Settlement(
        rewardId: rewardId,
        redemptionId: redemptionId,
        status: status,
      ),
    );
    final error = settleError;
    if (error != null) throw error;
  }
}

class _Settlement {
  final String rewardId;
  final String redemptionId;
  final TwitchRedemptionStatus status;

  const _Settlement({
    required this.rewardId,
    required this.redemptionId,
    required this.status,
  });
}

extension on List<String> {
  String? get lastOrNull => this.isEmpty ? null : last;
}
