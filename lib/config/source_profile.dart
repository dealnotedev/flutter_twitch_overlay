import 'dart:io';

/// The stable identity used for a source's persisted settings and sessions.
class SourceProfile {
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  const SourceProfile.standalone() : id = 'standalone';

  const SourceProfile._(this.id);

  factory SourceProfile.fromArguments(List<String> arguments) {
    if (arguments.isEmpty) return const SourceProfile.standalone();
    final id = arguments.first.trim().toLowerCase();
    if (!_uuid.hasMatch(id)) {
      throw ArgumentError.value(
        arguments.first,
        'sourceId',
        'Expected an OBS source UUID',
      );
    }
    return SourceProfile._(id);
  }

  final String id;

  Directory youtubeSessionDirectory(Directory applicationDirectory) =>
      Directory(
        '${applicationDirectory.path}${Platform.pathSeparator}youtube-session'
        '${Platform.pathSeparator}$id',
      );
}
