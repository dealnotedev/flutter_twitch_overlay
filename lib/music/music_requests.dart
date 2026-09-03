import 'dart:async';
import 'dart:io';

import 'package:obssource/twitch/ws_event.dart';

enum MusicQueueItemPhase { resolving, downloading, ready }

enum MusicQueueErrorType {
  missingYoutubeUrl,
  invalidYoutubeUrl,
  queueFull,
  trackTooLongOrLive,
  operationFailed,
}

class MusicQueueError {
  final String requester;
  final MusicQueueErrorType type;
  final String? details;

  const MusicQueueError({
    required this.requester,
    required this.type,
    this.details,
  });

  String get signature => '$requester|$type|${details ?? ''}';
}

class MusicTrackMetadata {
  final String videoId;
  final String title;
  final String author;
  final Duration duration;
  final Uri? thumbnail;
  final Uri sourceUrl;

  const MusicTrackMetadata({
    required this.videoId,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnail,
    required this.sourceUrl,
  });
}

class DownloadedMusicTrack {
  final String itemId;
  final String requestedBy;
  final MusicTrackMetadata metadata;
  final String filePath;

  const DownloadedMusicTrack({
    required this.itemId,
    required this.requestedBy,
    required this.metadata,
    required this.filePath,
  });
}

class MusicQueueItem {
  final String id;
  final String requestedBy;
  final Uri sourceUrl;
  final MusicQueueItemPhase phase;
  final String? title;
  final String? author;
  final Duration? duration;
  final Uri? thumbnail;
  final double? downloadProgress;

  const MusicQueueItem({
    required this.id,
    required this.requestedBy,
    required this.sourceUrl,
    required this.phase,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnail,
    required this.downloadProgress,
  });
}

class MusicNowPlaying {
  final MusicQueueItem item;
  final DateTime startedAt;
  final Duration position;
  final DateTime positionUpdatedAt;
  final bool paused;

  const MusicNowPlaying({
    required this.item,
    required this.startedAt,
    required this.position,
    required this.positionUpdatedAt,
    required this.paused,
  });
}

class MusicQueueSnapshot {
  final int revision;
  final MusicNowPlaying? nowPlaying;
  final List<MusicQueueItem> queue;
  final MusicQueueError? lastError;

  const MusicQueueSnapshot({
    required this.revision,
    required this.nowPlaying,
    required this.queue,
    required this.lastError,
  });

  static const empty = MusicQueueSnapshot(
    revision: 0,
    nowPlaying: null,
    queue: [],
    lastError: null,
  );
}

class MusicDownloadProgress {
  final int downloadedBytes;
  final int? totalBytes;
  final Duration? eta;

  const MusicDownloadProgress({
    required this.downloadedBytes,
    required this.totalBytes,
    required this.eta,
  });

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (downloadedBytes / total).clamp(0.0, 1.0).toDouble();
  }
}

abstract interface class MusicTrackFetcher {
  Future<MusicTrackMetadata> inspect(Uri sourceUrl);

  Future<String> download({
    required String itemId,
    required Uri sourceUrl,
    required void Function(MusicDownloadProgress progress) onProgress,
  });

  Future<void> cancel();
}

abstract interface class MusicTrackPlayer {
  Future<void> play(DownloadedMusicTrack track);

  Future<void> setPaused(bool paused);

  Future<void> seek(Duration position);

  Future<void> stop();
}

abstract interface class MusicRequests {
  MusicQueueSnapshot get current;

  Stream<MusicQueueSnapshot> get states;

  Future<bool> setPaused(bool paused);

  Future<bool> seek(Duration position);

  Future<bool> skip();

  Future<bool> remove(String itemId);

  Future<void> close();
}

class MusicRequestManager implements MusicRequests {
  static const _redemptionType =
      'channel.channel_points_custom_reward_redemption.add';

  final MusicTrackFetcher _fetcher;
  final MusicTrackPlayer _player;
  final String _rewardTitle;
  final int _maxQueueLength;
  final Duration _maxDuration;
  final bool _enabled;

  final _stateController = StreamController<MusicQueueSnapshot>.broadcast();
  final _processedRedemptionIds = <String>{};
  final _queue = <_PendingMusicRequest>[];

  late final StreamSubscription<WsMessage> _eventSubscription;

  MusicQueueSnapshot _current = MusicQueueSnapshot.empty;
  _PendingMusicRequest? _nowPlaying;
  bool _preparing = false;
  bool _playbackRunning = false;
  bool _closed = false;
  _PendingMusicRequest? _preparingRequest;
  MusicQueueError? _lastError;

  MusicRequestManager({
    required Stream<WsMessage> events,
    required MusicTrackFetcher fetcher,
    required MusicTrackPlayer player,
    required String rewardTitle,
    required bool enabled,
    required int maxQueueLength,
    required Duration maxDuration,
  }) : _fetcher = fetcher,
       _player = player,
       _rewardTitle = rewardTitle,
       _enabled = enabled,
       _maxQueueLength = maxQueueLength,
       _maxDuration = maxDuration {
    _eventSubscription = events.listen(_handleMessage);
  }

  @override
  MusicQueueSnapshot get current => _current;

  @override
  Stream<MusicQueueSnapshot> get states async* {
    yield _current;
    yield* _stateController.stream;
  }

  void _handleMessage(WsMessage message) {
    if (!_enabled || _closed) return;
    if (message.payload.subscription?.type != _redemptionType) return;

    final event = message.payload.event;
    final id = event?.id;
    final requester = event?.user?.name;
    final rewardTitle = event?.reward?.title;
    final input = event?.userInput?.trim();

    if (rewardTitle?.toLowerCase() != _rewardTitle.toLowerCase()) return;
    if (id == null || requester == null) return;
    if (!_processedRedemptionIds.add(id)) return;

    if (input == null || input.isEmpty) {
      _setError(
        MusicQueueError(
          requester: requester,
          type: MusicQueueErrorType.missingYoutubeUrl,
        ),
      );
      return;
    }

    final sourceUrl = Uri.tryParse(input);
    if (sourceUrl == null || !_isYouTubeUrl(sourceUrl)) {
      _setError(
        MusicQueueError(
          requester: requester,
          type: MusicQueueErrorType.invalidYoutubeUrl,
        ),
      );
      return;
    }

    final activeCount = _queue.length + (_nowPlaying == null ? 0 : 1);
    if (activeCount >= _maxQueueLength) {
      _setError(
        MusicQueueError(
          requester: requester,
          type: MusicQueueErrorType.queueFull,
        ),
      );
      return;
    }

    _lastError = null;
    _queue.add(
      _PendingMusicRequest(
        id: id,
        requestedBy: requester,
        sourceUrl: sourceUrl,
      ),
    );
    _emit();
    _ensurePreparing();
  }

  static bool _isYouTubeUrl(Uri uri) {
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;

    final host = uri.host.toLowerCase();
    return host == 'youtu.be' ||
        host == 'youtube.com' ||
        host.endsWith('.youtube.com');
  }

  void _ensurePreparing() {
    if (_preparing || _closed) return;
    _preparing = true;
    unawaited(_prepareLoop());
  }

  Future<void> _prepareLoop() async {
    try {
      while (!_closed) {
        final request = _firstResolvingRequest();
        if (request == null) return;
        _preparingRequest = request;

        try {
          final metadata = await _fetcher.inspect(request.sourceUrl);
          if (!_queue.contains(request) || _closed) continue;

          if (metadata.duration <= Duration.zero ||
              metadata.duration > _maxDuration) {
            _queue.remove(request);
            _setError(
              MusicQueueError(
                requester: request.requestedBy,
                type: MusicQueueErrorType.trackTooLongOrLive,
              ),
            );
            continue;
          }

          request
            ..metadata = metadata
            ..phase = MusicQueueItemPhase.downloading;
          _emit();

          final filePath = await _fetcher.download(
            itemId: request.id,
            sourceUrl: request.sourceUrl,
            onProgress: (progress) {
              if (!_queue.contains(request) || _closed) return;
              request.downloadProgress = progress.fraction;
              _emit();
            },
          );

          if (!_queue.contains(request) || _closed) {
            await _deleteFile(filePath);
            continue;
          }

          request
            ..filePath = filePath
            ..downloadProgress = 1
            ..phase = MusicQueueItemPhase.ready;
          _emit();
          _startIfPossible();
        } catch (error) {
          if (_queue.remove(request)) {
            _setError(_operationError(request, error));
          }
        } finally {
          if (identical(_preparingRequest, request)) {
            _preparingRequest = null;
          }
        }
      }
    } finally {
      _preparing = false;
      if (!_closed && _firstResolvingRequest() != null) {
        _ensurePreparing();
      }
    }
  }

  _PendingMusicRequest? _firstResolvingRequest() {
    for (final request in _queue) {
      if (request.phase == MusicQueueItemPhase.resolving) return request;
    }
    return null;
  }

  void _startIfPossible() {
    if (_closed || _playbackRunning || _queue.isEmpty) return;

    final request = _queue.first;
    final metadata = request.metadata;
    final filePath = request.filePath;
    if (request.phase != MusicQueueItemPhase.ready ||
        metadata == null ||
        filePath == null) {
      return;
    }

    _queue.removeAt(0);
    _nowPlaying = request;
    request.startPlayback(DateTime.now());
    _playbackRunning = true;
    _lastError = null;
    _emit();

    unawaited(
      _play(
        request,
        DownloadedMusicTrack(
          itemId: request.id,
          requestedBy: request.requestedBy,
          metadata: metadata,
          filePath: filePath,
        ),
      ),
    );
  }

  Future<void> _play(
    _PendingMusicRequest request,
    DownloadedMusicTrack track,
  ) async {
    try {
      await _player.play(track);
    } catch (error) {
      _lastError = _operationError(request, error);
    } finally {
      await _deleteFile(track.filePath);
      if (_nowPlaying == request) {
        _nowPlaying = null;
      }
      _playbackRunning = false;
      if (!_closed) {
        _emit();
        _startIfPossible();
      }
    }
  }

  @override
  Future<bool> setPaused(bool paused) async {
    final request = _nowPlaying;
    if (!_playbackRunning || _closed || request == null) return false;
    if (request.paused == paused) return true;

    try {
      await _player.setPaused(paused);
    } catch (error) {
      _setError(_operationError(request, error));
      return false;
    }

    if (!_playbackRunning || _closed || _nowPlaying != request) return false;

    if (paused) {
      request.pausePlayback(DateTime.now());
    } else {
      request.resumePlayback(DateTime.now());
    }
    _emit();
    return true;
  }

  @override
  Future<bool> seek(Duration position) async {
    final request = _nowPlaying;
    final duration = request?.metadata?.duration;
    if (!_playbackRunning || _closed || request == null || duration == null) {
      return false;
    }

    final target =
        position < Duration.zero
            ? Duration.zero
            : position > duration
            ? duration
            : position;
    try {
      await _player.seek(target);
    } catch (error) {
      _setError(_operationError(request, error));
      return false;
    }

    if (!_playbackRunning || _closed || _nowPlaying != request) return false;
    request.seekPlayback(target, DateTime.now());
    _emit();
    return true;
  }

  @override
  Future<bool> skip() async {
    if (!_playbackRunning || _closed) return false;
    await _player.stop();
    return true;
  }

  @override
  Future<bool> remove(String itemId) async {
    if (_closed) return false;
    final index = _queue.indexWhere((request) => request.id == itemId);
    if (index < 0) return false;

    final request = _queue.removeAt(index);
    final cancelPreparation = identical(_preparingRequest, request);
    _emit();

    if (cancelPreparation) {
      await _fetcher.cancel();
    }
    final filePath = request.filePath;
    if (filePath != null) await _deleteFile(filePath);
    _startIfPossible();
    return true;
  }

  void _setError(MusicQueueError error) {
    _lastError = error;
    _emit();
  }

  static MusicQueueError _operationError(
    _PendingMusicRequest request,
    Object error,
  ) {
    return MusicQueueError(
      requester: request.requestedBy,
      type: MusicQueueErrorType.operationFailed,
      details: _describeError(error),
    );
  }

  static String _describeError(Object error) {
    final value = error.toString();
    return value.length <= 180 ? value : '${value.substring(0, 177)}...';
  }

  void _emit() {
    if (_closed) return;

    _current = MusicQueueSnapshot(
      revision: _current.revision + 1,
      nowPlaying: _nowPlaying?.toNowPlaying(DateTime.now()),
      queue: List.unmodifiable(_queue.map((request) => request.toView())),
      lastError: _lastError,
    );
    _stateController.add(_current);
  }

  static Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Cache cleanup is best effort and must not stop the queue.
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _eventSubscription.cancel();
    await _fetcher.cancel();
    await _player.stop();

    for (final request in _queue) {
      final path = request.filePath;
      if (path != null) await _deleteFile(path);
    }

    await _stateController.close();
  }
}

class _PendingMusicRequest {
  final String id;
  final String requestedBy;
  final Uri sourceUrl;

  MusicQueueItemPhase phase = MusicQueueItemPhase.resolving;
  MusicTrackMetadata? metadata;
  String? filePath;
  double? downloadProgress;
  DateTime? startedAt;
  DateTime? _resumedAt;
  Duration _position = Duration.zero;
  bool paused = false;

  _PendingMusicRequest({
    required this.id,
    required this.requestedBy,
    required this.sourceUrl,
  });

  void startPlayback(DateTime now) {
    startedAt = now;
    _resumedAt = now;
    _position = Duration.zero;
    paused = false;
  }

  void pausePlayback(DateTime now) {
    _position = positionAt(now);
    _resumedAt = null;
    paused = true;
  }

  void resumePlayback(DateTime now) {
    _resumedAt = now;
    paused = false;
  }

  void seekPlayback(Duration position, DateTime now) {
    _position = position;
    _resumedAt = paused ? null : now;
  }

  Duration positionAt(DateTime now) {
    var value = _position;
    final resumedAt = _resumedAt;
    if (resumedAt != null) value += now.difference(resumedAt);

    final duration = metadata?.duration;
    if (duration != null && value > duration) return duration;
    return value.isNegative ? Duration.zero : value;
  }

  MusicNowPlaying toNowPlaying(DateTime now) => MusicNowPlaying(
    item: toView(playing: true),
    startedAt: startedAt!,
    position: positionAt(now),
    positionUpdatedAt: now,
    paused: paused,
  );

  MusicQueueItem toView({bool playing = false}) => MusicQueueItem(
    id: id,
    requestedBy: requestedBy,
    sourceUrl: sourceUrl,
    phase: playing ? MusicQueueItemPhase.ready : phase,
    title: metadata?.title,
    author: metadata?.author,
    duration: metadata?.duration,
    thumbnail: metadata?.thumbnail,
    downloadProgress: downloadProgress,
  );
}
