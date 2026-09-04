import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obssource/twitch/twitch_redemption.dart';
import 'package:obssource/twitch/twitch_redemption_service.dart';
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

  /// Returns a fetcher-owned local file. Callers must not delete it.
  Future<String> obtain({
    required MusicTrackMetadata metadata,
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
  final TwitchRedemptionService? _redemptionService;
  final int _maxQueueLength;
  final Duration _maxDuration;
  final bool _enabled;

  final _stateController = StreamController<MusicQueueSnapshot>.broadcast();
  final _processedRedemptionIds = <String>{};
  final _settlementRequestedIds = <String>{};
  final _queue = <_PendingMusicRequest>[];
  final _backgroundOperations = <Future<void>>{};

  late final StreamSubscription<WsMessage> _eventSubscription;
  StreamSubscription<String?>? _rewardIdSubscription;

  MusicQueueSnapshot _current = MusicQueueSnapshot.empty;
  String? _rewardId;
  _PendingMusicRequest? _nowPlaying;
  bool _preparing = false;
  bool _playbackRunning = false;
  bool _closed = false;
  _PendingMusicRequest? _preparingRequest;
  Future<void>? _preparationFuture;
  Future<void>? _playbackFuture;
  MusicQueueError? _lastError;

  MusicRequestManager({
    required Stream<WsMessage> events,
    required MusicTrackFetcher fetcher,
    required MusicTrackPlayer player,
    required bool enabled,
    required int maxQueueLength,
    required Duration maxDuration,
    String? rewardId,
    Stream<String?>? rewardIdChanges,
    TwitchRedemptionService? redemptionService,
  }) : _fetcher = fetcher,
       _player = player,
       _redemptionService = redemptionService,
       _rewardId = _normalizeRewardId(rewardId),
       _enabled = enabled,
       _maxQueueLength = maxQueueLength,
       _maxDuration = maxDuration {
    _eventSubscription = events.listen(_handleMessage);
    _rewardIdSubscription = rewardIdChanges?.listen(_handleRewardIdChanged);
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
    final reward = event?.reward;
    final rewardId = reward?.id;

    if (!_matchesReward(reward)) return;
    if (id == null || requester == null || rewardId == null) return;

    _acceptRedemption(
      id: id,
      rewardId: rewardId,
      requester: requester,
      input: event?.userInput,
    );
  }

  void _acceptRedemption({
    required String id,
    required String rewardId,
    required String requester,
    required String? input,
  }) {
    if (!_processedRedemptionIds.add(id)) return;

    final normalizedInput = input?.trim();
    if (normalizedInput == null || normalizedInput.isEmpty) {
      _rejectRedemption(
        MusicQueueError(
          requester: requester,
          type: MusicQueueErrorType.missingYoutubeUrl,
        ),
        id: id,
        rewardId: rewardId,
      );
      return;
    }

    final sourceUrl = Uri.tryParse(normalizedInput);
    if (sourceUrl == null || !_isYouTubeUrl(sourceUrl)) {
      _rejectRedemption(
        MusicQueueError(
          requester: requester,
          type: MusicQueueErrorType.invalidYoutubeUrl,
        ),
        id: id,
        rewardId: rewardId,
      );
      return;
    }

    final activeCount = _queue.length + (_nowPlaying == null ? 0 : 1);
    if (activeCount >= _maxQueueLength) {
      _rejectRedemption(
        MusicQueueError(
          requester: requester,
          type: MusicQueueErrorType.queueFull,
        ),
        id: id,
        rewardId: rewardId,
      );
      return;
    }

    _lastError = null;
    _queue.add(
      _PendingMusicRequest(
        id: id,
        rewardId: rewardId,
        requestedBy: requester,
        sourceUrl: sourceUrl,
      ),
    );
    _emit();
    _ensurePreparing();
  }

  void _rejectRedemption(
    MusicQueueError error, {
    required String id,
    required String rewardId,
  }) {
    _setError(error);
    _requestSettlement(
      redemptionId: id,
      rewardId: rewardId,
      status: TwitchRedemptionStatus.canceled,
    );
  }

  void _rejectRequest(_PendingMusicRequest request, MusicQueueError error) {
    _rejectRedemption(error, id: request.id, rewardId: request.rewardId);
  }

  bool _matchesReward(WsReward? reward) {
    final rewardId = _rewardId;
    return rewardId != null && reward?.id == rewardId;
  }

  static String? _normalizeRewardId(String? rewardId) {
    final normalized = rewardId?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
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
    final preparation = _prepareLoop();
    _preparationFuture = preparation;
    unawaited(preparation);
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
            _rejectRequest(
              request,
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

          final filePath = await _fetcher.obtain(
            metadata: metadata,
            onProgress: (progress) {
              if (!_queue.contains(request) || _closed) return;
              request.downloadProgress = progress.fraction;
              _emit();
            },
          );

          if (!_queue.contains(request) || _closed) continue;

          request
            ..filePath = filePath
            ..downloadProgress = 1
            ..phase = MusicQueueItemPhase.ready;
          _emit();
          _startIfPossible();
        } catch (error) {
          if (_queue.remove(request)) {
            if (!_closed) {
              _rejectRequest(request, _operationError(request, error));
            }
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

    final playback = _play(
      request,
      DownloadedMusicTrack(
        itemId: request.id,
        requestedBy: request.requestedBy,
        metadata: metadata,
        filePath: filePath,
      ),
    );
    _playbackFuture = playback;
    unawaited(playback);
  }

  Future<void> _play(
    _PendingMusicRequest request,
    DownloadedMusicTrack track,
  ) async {
    try {
      await _player.play(track);
      if (!_closed) {
        _requestSettlement(
          redemptionId: request.id,
          rewardId: request.rewardId,
          status: TwitchRedemptionStatus.fulfilled,
        );
      }
    } catch (error) {
      if (!_closed) {
        _lastError = _operationError(request, error);
        _requestSettlement(
          redemptionId: request.id,
          rewardId: request.rewardId,
          status: TwitchRedemptionStatus.canceled,
        );
      }
    } finally {
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
    _requestSettlement(
      redemptionId: request.id,
      rewardId: request.rewardId,
      status: TwitchRedemptionStatus.canceled,
    );
    _emit();

    if (cancelPreparation) {
      await _fetcher.cancel();
    }
    _startIfPossible();
    return true;
  }

  void _setError(MusicQueueError error) {
    _lastError = error;
    _emit();
  }

  void _requestSettlement({
    required String redemptionId,
    required String rewardId,
    required TwitchRedemptionStatus status,
  }) {
    final service = _redemptionService;
    if (service == null || !_settlementRequestedIds.add(redemptionId)) return;

    _trackBackgroundOperation(
      service
          .settle(
            rewardId: rewardId,
            redemptionId: redemptionId,
            status: status,
          )
          .catchError((Object error, StackTrace stackTrace) {
            debugPrint(
              'Unable to update Twitch redemption $redemptionId; '
              'it remains UNFULFILLED: $error',
            );
          }),
    );
  }

  void _handleRewardIdChanged(String? rewardId) {
    _rewardId = _normalizeRewardId(rewardId);
  }

  void _trackBackgroundOperation(Future<void> operation) {
    _backgroundOperations.add(operation);
    operation.whenComplete(() => _backgroundOperations.remove(operation));
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

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _eventSubscription.cancel();
    await _rewardIdSubscription?.cancel();
    await _fetcher.cancel();
    await _preparationFuture;
    await _player.stop();
    await _playbackFuture;
    await Future.wait(List.of(_backgroundOperations));

    await _stateController.close();
  }
}

class _PendingMusicRequest {
  final String id;
  final String rewardId;
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
    required this.rewardId,
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
