import 'package:obssource/music/music_requests.dart';

/// Wire contract shared by the overlay server and remote controllers.
abstract final class MusicControlProtocol {
  static const int version = 1;
  static const int defaultPort = 47821;

  static const String healthPath = '/v1/health';
  static const String playerPath = '/v1/player';
  static const String commandsPath = '/v1/player/commands';
  static const String eventsPath = '/v1/player/events';

  static Map<String, Object?> snapshotEnvelope({
    required String serverId,
    required MusicQueueSnapshot snapshot,
  }) => {
    'protocolVersion': version,
    'serverId': serverId,
    'type': 'snapshot',
    'snapshot': snapshotToJson(snapshot),
  };

  static MusicControlSnapshotEnvelope snapshotEnvelopeFromJson(Object? value) {
    final json = _object(value, 'envelope');
    final protocolVersion = _integer(
      json['protocolVersion'],
      'protocolVersion',
    );
    if (protocolVersion != version) {
      throw MusicControlVersionException(
        actual: protocolVersion,
        expected: version,
      );
    }
    if (json['type'] != 'snapshot') {
      throw const MusicControlProtocolException('Expected a snapshot message');
    }

    return MusicControlSnapshotEnvelope(
      serverId: _string(json['serverId'], 'serverId'),
      snapshot: snapshotFromJson(json['snapshot']),
    );
  }

  static Map<String, Object?> snapshotToJson(MusicQueueSnapshot snapshot) => {
    'revision': snapshot.revision,
    'nowPlaying':
        snapshot.nowPlaying == null
            ? null
            : _nowPlayingToJson(snapshot.nowPlaying!),
    'queue': snapshot.queue.map(_queueItemToJson).toList(growable: false),
    'lastError':
        snapshot.lastError == null ? null : _errorToJson(snapshot.lastError!),
  };

  static MusicQueueSnapshot snapshotFromJson(Object? value) {
    final json = _object(value, 'snapshot');
    final queueValue = json['queue'];
    if (queueValue is! List<Object?>) {
      throw const MusicControlProtocolException('queue must be a JSON array');
    }

    return MusicQueueSnapshot(
      revision: _integer(json['revision'], 'revision'),
      nowPlaying:
          json['nowPlaying'] == null
              ? null
              : _nowPlayingFromJson(json['nowPlaying']),
      queue: List.unmodifiable(queueValue.map(_queueItemFromJson)),
      lastError:
          json['lastError'] == null ? null : _errorFromJson(json['lastError']),
    );
  }

  static Map<String, Object?> _nowPlayingToJson(MusicNowPlaying playing) => {
    'item': _queueItemToJson(playing.item),
    'startedAtMs': playing.startedAt.toUtc().millisecondsSinceEpoch,
    'positionMs': playing.position.inMilliseconds,
    'positionUpdatedAtMs':
        playing.positionUpdatedAt.toUtc().millisecondsSinceEpoch,
    'paused': playing.paused,
  };

  static MusicNowPlaying _nowPlayingFromJson(Object? value) {
    final json = _object(value, 'nowPlaying');
    return MusicNowPlaying(
      item: _queueItemFromJson(json['item']),
      startedAt:
          DateTime.fromMillisecondsSinceEpoch(
            _integer(json['startedAtMs'], 'startedAtMs'),
            isUtc: true,
          ).toLocal(),
      position: Duration(
        milliseconds: _integer(json['positionMs'], 'positionMs'),
      ),
      positionUpdatedAt:
          DateTime.fromMillisecondsSinceEpoch(
            _integer(json['positionUpdatedAtMs'], 'positionUpdatedAtMs'),
            isUtc: true,
          ).toLocal(),
      paused: _boolean(json['paused'], 'paused'),
    );
  }

  static Map<String, Object?> _queueItemToJson(MusicQueueItem item) => {
    'id': item.id,
    'requestedBy': item.requestedBy,
    'sourceUrl': item.sourceUrl.toString(),
    'phase': item.phase.name,
    'title': item.title,
    'author': item.author,
    'durationMs': item.duration?.inMilliseconds,
    'thumbnail': item.thumbnail?.toString(),
    'downloadProgress': item.downloadProgress,
  };

  static MusicQueueItem _queueItemFromJson(Object? value) {
    final json = _object(value, 'queueItem');
    return MusicQueueItem(
      id: _string(json['id'], 'id'),
      requestedBy: _string(json['requestedBy'], 'requestedBy'),
      sourceUrl: _uri(json['sourceUrl'], 'sourceUrl'),
      phase: _enumValue(MusicQueueItemPhase.values, json['phase'], 'phase'),
      title: _nullableString(json['title'], 'title'),
      author: _nullableString(json['author'], 'author'),
      duration:
          json['durationMs'] == null
              ? null
              : Duration(
                milliseconds: _integer(json['durationMs'], 'durationMs'),
              ),
      thumbnail:
          json['thumbnail'] == null
              ? null
              : _uri(json['thumbnail'], 'thumbnail'),
      downloadProgress: _nullableDouble(
        json['downloadProgress'],
        'downloadProgress',
      ),
    );
  }

  static Map<String, Object?> _errorToJson(MusicQueueError error) => {
    'requester': error.requester,
    'type': error.type.name,
    'details': error.details,
  };

  static MusicQueueError _errorFromJson(Object? value) {
    final json = _object(value, 'lastError');
    return MusicQueueError(
      requester: _string(json['requester'], 'requester'),
      type: _enumValue(MusicQueueErrorType.values, json['type'], 'error.type'),
      details: _nullableString(json['details'], 'details'),
    );
  }

  static Map<String, dynamic> _object(Object? value, String field) {
    if (value is Map<String, dynamic>) return value;
    throw MusicControlProtocolException('$field must be a JSON object');
  }

  static String _string(Object? value, String field) {
    if (value is String && value.isNotEmpty) return value;
    throw MusicControlProtocolException('$field must be a non-empty string');
  }

  static String? _nullableString(Object? value, String field) {
    if (value == null || value is String) return value as String?;
    throw MusicControlProtocolException('$field must be a string or null');
  }

  static int _integer(Object? value, String field) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.round();
    }
    throw MusicControlProtocolException('$field must be an integer');
  }

  static double? _nullableDouble(Object? value, String field) {
    if (value == null) return null;
    if (value is num && value.isFinite) return value.toDouble();
    throw MusicControlProtocolException('$field must be a number or null');
  }

  static bool _boolean(Object? value, String field) {
    if (value is bool) return value;
    throw MusicControlProtocolException('$field must be a boolean');
  }

  static Uri _uri(Object? value, String field) {
    final text = _string(value, field);
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme) {
      throw MusicControlProtocolException('$field must be an absolute URI');
    }
    return uri;
  }

  static T _enumValue<T extends Enum>(
    List<T> values,
    Object? value,
    String field,
  ) {
    if (value is String) {
      for (final candidate in values) {
        if (candidate.name == value) return candidate;
      }
    }
    throw MusicControlProtocolException('$field has an unsupported value');
  }
}

class MusicControlSnapshotEnvelope {
  final String serverId;
  final MusicQueueSnapshot snapshot;

  const MusicControlSnapshotEnvelope({
    required this.serverId,
    required this.snapshot,
  });
}

class MusicControlProtocolException implements Exception {
  final String message;

  const MusicControlProtocolException(this.message);

  @override
  String toString() => message;
}

class MusicControlVersionException extends MusicControlProtocolException {
  final int actual;
  final int expected;

  MusicControlVersionException({required this.actual, required this.expected})
    : super('Unsupported protocol version $actual (expected $expected)');
}
