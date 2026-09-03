import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/music/control/music_control_protocol.dart';
import 'package:obssource/music/music_requests.dart';

void main() {
  test('round-trips a complete music queue snapshot', () {
    final updatedAt = DateTime(2026, 9, 3, 14, 30, 15, 250);
    final playingItem = _item(
      'playing',
      phase: MusicQueueItemPhase.ready,
      progress: 1,
    );
    final original = MusicQueueSnapshot(
      revision: 42,
      nowPlaying: MusicNowPlaying(
        item: playingItem,
        startedAt: updatedAt.subtract(const Duration(seconds: 20)),
        position: const Duration(seconds: 20),
        positionUpdatedAt: updatedAt,
        paused: true,
      ),
      queue: [
        _item('resolving', phase: MusicQueueItemPhase.resolving),
        _item(
          'downloading',
          phase: MusicQueueItemPhase.downloading,
          progress: 0.375,
        ),
      ],
      lastError: const MusicQueueError(
        requester: 'viewer',
        type: MusicQueueErrorType.operationFailed,
        details: 'network unavailable',
      ),
    );

    final envelope = MusicControlProtocol.snapshotEnvelopeFromJson(
      MusicControlProtocol.snapshotEnvelope(
        serverId: 'server-1',
        snapshot: original,
      ),
    );

    expect(envelope.serverId, 'server-1');
    expect(envelope.snapshot.revision, 42);
    expect(envelope.snapshot.nowPlaying?.item.id, 'playing');
    expect(envelope.snapshot.nowPlaying?.paused, isTrue);
    expect(envelope.snapshot.nowPlaying?.position, const Duration(seconds: 20));
    expect(envelope.snapshot.nowPlaying?.positionUpdatedAt, updatedAt);
    expect(envelope.snapshot.queue.map((item) => item.phase), [
      MusicQueueItemPhase.resolving,
      MusicQueueItemPhase.downloading,
    ]);
    expect(envelope.snapshot.queue.last.downloadProgress, 0.375);
    expect(
      envelope.snapshot.lastError?.type,
      MusicQueueErrorType.operationFailed,
    );
    expect(envelope.snapshot.lastError?.details, 'network unavailable');
  });

  test('rejects incompatible protocol versions', () {
    expect(
      () => MusicControlProtocol.snapshotEnvelopeFromJson({
        'protocolVersion': MusicControlProtocol.version + 1,
        'serverId': 'server-1',
        'type': 'snapshot',
        'snapshot': MusicControlProtocol.snapshotToJson(
          MusicQueueSnapshot.empty,
        ),
      }),
      throwsA(isA<MusicControlProtocolException>()),
    );
  });
}

MusicQueueItem _item(
  String id, {
  required MusicQueueItemPhase phase,
  double? progress,
}) => MusicQueueItem(
  id: id,
  requestedBy: 'viewer',
  sourceUrl: Uri.parse('https://youtu.be/$id'),
  phase: phase,
  title: 'Track $id',
  author: 'Artist',
  duration: const Duration(minutes: 3),
  thumbnail: Uri.parse('https://img.youtube.com/$id.jpg'),
  downloadProgress: progress,
);
