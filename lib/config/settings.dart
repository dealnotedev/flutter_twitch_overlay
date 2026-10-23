import 'dart:async';
import 'dart:convert';

import 'package:obssource/config/avatar_settings.dart';
import 'package:obssource/music/music_settings.dart';
import 'package:obssource/twitch/twitch_creds.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends _TwitchSettings {
  Settings(super.preferences);

  static const _kMusicRewardId = 'music_reward_id';
  static const _kMusicSettings = 'music_settings';
  static const _kAvatarSettings = 'avatar_settings';
  static const _kPlayerCollapseSeconds = 'player_collapse_seconds';
  static const _kPlayerAlwaysExpanded = 'player_always_expanded';

  @override
  Future<void> init() async {
    await super.init();
    await _initMusic();
  }

  Future<void> _initMusic() async {
    final values = await _preferences.getAll();
    if (values.containsKey(_kAvatarSettings)) {
      try {
        final raw = values[_kAvatarSettings];
        final json = jsonDecode(raw is String ? raw : '{}');
        avatar =
            json is Map<String, dynamic>
                ? AvatarSettings.fromJson(json)
                : const AvatarSettings();
      } on FormatException {
        avatar = const AvatarSettings();
      }
    }
    musicRewardId = values[_kMusicRewardId] as String?;
    if (values.containsKey(_kMusicSettings)) {
      try {
        final raw = values[_kMusicSettings];
        final json = jsonDecode(raw is String ? raw : '{}');
        music =
            json is Map<String, dynamic>
                ? MusicSettings.fromJson(json)
                : const MusicSettings();
      } on FormatException {
        music = const MusicSettings();
      }
    }
    playerCollapseSeconds = ((values[_kPlayerCollapseSeconds] as int?) ?? 5)
        .clamp(1, 60);
    playerAlwaysExpanded = values[_kPlayerAlwaysExpanded] as bool? ?? false;
  }

  int playerCollapseSeconds = 5;
  bool playerAlwaysExpanded = false;
  final _playerPresentationSubject = StreamController<void>.broadcast();
  Stream<void> get playerPresentationChanges =>
      _playerPresentationSubject.stream;

  AvatarSettings avatar = const AvatarSettings();
  final _avatarSubject = StreamController<AvatarSettings>.broadcast();
  Stream<AvatarSettings> get avatarChanges => _avatarSubject.stream;

  Future<void> saveAvatar(AvatarSettings value) async {
    final normalized = value.normalized();
    await _preferences.setString(
      _kAvatarSettings,
      jsonEncode(normalized.toJson()),
    );
    avatar = normalized;
    _avatarSubject.add(avatar);
  }

  MusicSettings music = const MusicSettings();
  final _musicSubject = StreamController<MusicSettings>.broadcast();
  Stream<MusicSettings> get musicChanges => _musicSubject.stream;

  Future<void> saveMusic(MusicSettings value) async {
    final normalized = value.normalized();
    await _preferences.setString(
      _kMusicSettings,
      jsonEncode(normalized.toJson()),
    );
    music = normalized;
    _musicSubject.add(music);
  }

  Future<void> savePlayerPresentation({
    required int collapseSeconds,
    required bool alwaysExpanded,
  }) async {
    final seconds = collapseSeconds.clamp(1, 60);
    await _preferences.setInt(_kPlayerCollapseSeconds, seconds);
    await _preferences.setBool(_kPlayerAlwaysExpanded, alwaysExpanded);
    playerCollapseSeconds = seconds;
    playerAlwaysExpanded = alwaysExpanded;
    _playerPresentationSubject.add(null);
  }

  Future<void> saveMusicRewardId(String? rewardId) async {
    final normalized = rewardId?.trim();

    if (normalized != null && normalized.isNotEmpty) {
      await _preferences.setString(_kMusicRewardId, normalized);
      musicRewardId = normalized;
    } else {
      await _preferences.remove(_kMusicRewardId);
      musicRewardId = null;
    }

    _musicRewardIdSubject.add(musicRewardId);
  }

  Stream<String?> get musicRewardIdChanges => _musicRewardIdSubject.stream;

  String? musicRewardId;
  final _musicRewardIdSubject = StreamController<String?>.broadcast();
}

class _TwitchSettings {
  _TwitchSettings(SharedPreferencesAsync preferences)
    : _preferences = preferences;

  final SharedPreferencesAsync _preferences;
  static const _kTwitchAuth = 'twitch_login';

  Future<void> init() async {
    final json = await _preferences.getString(_kTwitchAuth);
    twitchAuth = json != null ? TwitchCreds.fromJson(jsonDecode(json)) : null;
  }

  Future<void> saveTwitchAuth(TwitchCreds? creds) async {
    if (creds != null) {
      await _preferences.setString(_kTwitchAuth, jsonEncode(creds.toJson()));
    } else {
      await _preferences.remove(_kTwitchAuth);
    }

    twitchAuth = creds;
    _twitchAuthSubject.add(creds);
  }

  Stream<TwitchCreds?> get twitchAuthStream =>
      Stream.value(twitchAuth).concatWith([_twitchAuthSubject.stream]);

  Stream<TwitchCreds?> get twitchAuthChanges => _twitchAuthSubject.stream;

  TwitchCreds? twitchAuth;

  final _twitchAuthSubject = StreamController<TwitchCreds?>.broadcast();
}
