import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:dart_music_player_protocol/dart_music_player_protocol_io.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/music/local_music_runtime.dart';
import 'package:obssource/music/music_settings.dart';
import 'package:obssource/music/music_vu_profile.dart';
import 'package:obssource/music/music_vu_profiles.dart';

/// One stable interface for views while the owned local/remote player changes.
class MusicSourceController extends ChangeNotifier implements MusicRequests {
  final Settings settings;
  final LocalMusicRuntime Function(MusicSettings) createLocal;
  LocalMusicRuntime? local;
  RemoteMusicRequests? _remote;
  MusicVuProfiles? _externalVuProfiles;
  late MusicRequests _active;
  late MusicSettings _options;
  late final StreamSubscription<MusicSettings> _settingsSubscription;
  StreamSubscription<MusicQueueSnapshot>? _statesSubscription;
  StreamSubscription<MusicControlConnectionState>? _connectionSubscription;
  final _states = StreamController<MusicQueueSnapshot>.broadcast();
  MusicQueueSnapshot _current = MusicQueueSnapshot.empty;
  Future<void> _pending = Future.value();
  Future<void>? _closing;
  bool _closed = false;
  bool switching = false;
  String? error;

  MusicSourceController({required this.settings, required this.createLocal}) {
    _open(settings.music);
    _settingsSubscription = settings.musicChanges.listen((value) {
      unawaited(configure(value));
    });
  }

  MusicControlConnectionState? get connection => _remote?.currentConnection;

  Future<MusicVuProfile?> vuProfileFor(MusicQueueItem item) {
    if (_closed) return Future.value(null);
    final profiles =
        local?.vuProfiles ??
        (_externalVuProfiles ??= MusicVuProfiles.defaultCache());
    return profiles.loadFor(item);
  }

  void _open(MusicSettings value) {
    _options = value;
    if (value.source == MusicSourceKind.local) {
      final host = local = createLocal(value);
      _active = host.requests;
    } else {
      final remote =
          _remote = RemoteMusicRequests(
            endpoint: Uri.parse('http://127.0.0.1:${value.externalPort}'),
          );
      _active = remote;
      _connectionSubscription = remote.connectionStates.listen((_) {
        if (_closed) return;
        notifyListeners();
      });
      remote.start();
    }
    _current = _active.current;
    _statesSubscription = _active.states.listen(_emit);
  }

  Future<void> configure(MusicSettings value) =>
      _pending = _pending.then((_) async {
        if (_closed) return;
        if (value.source == _options.source &&
            (value.source == MusicSourceKind.local ||
                value.externalPort == _options.externalPort)) {
          _options = value;
          local?.updateSettings(value);
          return;
        }
        switching = true;
        error = null;
        _emit(MusicQueueSnapshot.empty);
        notifyListeners();
        try {
          await _disconnect();
          if (!_closed) _open(value);
        } catch (failure) {
          error = failure.toString();
        } finally {
          switching = false;
          if (!_closed) notifyListeners();
        }
      });

  Future<void> _disconnect() async {
    await _statesSubscription?.cancel();
    await _connectionSubscription?.cancel();
    _statesSubscription = null;
    _connectionSubscription = null;
    await local?.close();
    await _remote?.close();
    local = null;
    _remote = null;
  }

  void _emit(MusicQueueSnapshot value) {
    if (_closed) return;
    _current = value;
    _states.add(value);
  }

  @override
  MusicQueueSnapshot get current => _current;
  @override
  Stream<MusicQueueSnapshot> get states async* {
    yield _current;
    yield* _states.stream;
  }

  bool get _canControl => !_closed && !switching && error == null;
  @override
  Future<bool> setPaused(bool paused) async =>
      _canControl && await _active.setPaused(paused);
  @override
  Future<bool> seek(Duration position) async =>
      _canControl && await _active.seek(position);
  @override
  Future<bool> skip() async => _canControl && await _active.skip();
  @override
  Future<bool> remove(String itemId) async =>
      _canControl && await _active.remove(itemId);

  @override
  Future<void> close() =>
      _closing ??= () async {
        _closed = true;
        await _settingsSubscription.cancel();
        await _pending;
        await _disconnect();
        await _externalVuProfiles?.close();
        await _states.close();
        dispose();
      }();
}
