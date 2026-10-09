import 'dart:async';
import 'dart:convert';

import 'package:obssource/config/avatar_settings.dart';
import 'package:obssource/music/music_settings.dart';
import 'package:obssource/twitch/twitch_creds.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  static const _kTwitchAuth = 'twitch_login';
  static const _kMusicRewardId = 'music_reward_id';
  static const _kMusicSettings = 'music_settings';
  static const _kAvatarSettings = 'avatar_settings';
  static const _kPlayerCollapseSeconds = 'player_collapse_seconds';
  static const _kPlayerAlwaysExpanded = 'player_always_expanded';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    _initTwitchCreds(prefs);
    _initMusicRewardId(prefs);
    if (prefs.containsKey(_kAvatarSettings)) {
      try {
        final raw = prefs.get(_kAvatarSettings);
        final json = jsonDecode(raw is String ? raw : '{}');
        avatar =
            json is Map<String, dynamic>
                ? AvatarSettings.fromJson(json)
                : const AvatarSettings();
      } on FormatException {
        avatar = const AvatarSettings();
      }
    }
    if (prefs.containsKey(_kMusicSettings)) {
      try {
        final raw = prefs.get(_kMusicSettings);
        final json = jsonDecode(raw is String ? raw : '{}');
        music =
            json is Map<String, dynamic>
                ? MusicSettings.fromJson(json)
                : const MusicSettings();
      } on FormatException {
        music = const MusicSettings();
      }
    }
    playerCollapseSeconds = (prefs.getInt(_kPlayerCollapseSeconds) ?? 5).clamp(
      1,
      60,
    );
    playerAlwaysExpanded = prefs.getBool(_kPlayerAlwaysExpanded) ?? false;
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
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      _kAvatarSettings,
      jsonEncode(normalized.toJson()),
    )) {
      throw StateError('Could not save avatar settings');
    }
    avatar = normalized;
    _avatarSubject.add(avatar);
  }

  MusicSettings music = const MusicSettings();
  final _musicSubject = StreamController<MusicSettings>.broadcast();
  Stream<MusicSettings> get musicChanges => _musicSubject.stream;

  Future<void> saveMusic(MusicSettings value) async {
    final normalized = value.normalized();
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      _kMusicSettings,
      jsonEncode(normalized.toJson()),
    )) {
      throw StateError('Could not save music settings');
    }
    music = normalized;
    _musicSubject.add(music);
  }

  Future<void> savePlayerPresentation({
    required int collapseSeconds,
    required bool alwaysExpanded,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final seconds = collapseSeconds.clamp(1, 60);
    await prefs.setInt(_kPlayerCollapseSeconds, seconds);
    await prefs.setBool(_kPlayerAlwaysExpanded, alwaysExpanded);
    playerCollapseSeconds = seconds;
    playerAlwaysExpanded = alwaysExpanded;
    _playerPresentationSubject.add(null);
  }

  Future<void> saveTwitchAuth(TwitchCreds? creds) async {
    final prefs = await SharedPreferences.getInstance();

    if (creds != null) {
      prefs.setString(_kTwitchAuth, jsonEncode(creds.toJson()));
    } else {
      prefs.remove(_kTwitchAuth);
    }

    twitchAuth = creds;
    _twitchAuthSubject.add(creds);
  }

  Stream<TwitchCreds?> get twitchAuthStream =>
      Stream.value(twitchAuth).concatWith([_twitchAuthSubject.stream]);

  Stream<TwitchCreds?> get twitchAuthChanges => _twitchAuthSubject.stream;

  Future<void> saveMusicRewardId(String? rewardId) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = rewardId?.trim();

    if (normalized != null && normalized.isNotEmpty) {
      await prefs.setString(_kMusicRewardId, normalized);
      musicRewardId = normalized;
    } else {
      await prefs.remove(_kMusicRewardId);
      musicRewardId = null;
    }

    _musicRewardIdSubject.add(musicRewardId);
  }

  Stream<String?> get musicRewardIdChanges => _musicRewardIdSubject.stream;

  TwitchCreds? twitchAuth;
  String? musicRewardId;

  final _twitchAuthSubject = StreamController<TwitchCreds?>.broadcast();
  final _musicRewardIdSubject = StreamController<String?>.broadcast();

  void _initTwitchCreds(SharedPreferences prefs) {
    final json = prefs.getString(_kTwitchAuth);
    twitchAuth = json != null ? TwitchCreds.fromJson(jsonDecode(json)) : null;
  }

  void _initMusicRewardId(SharedPreferences prefs) {
    musicRewardId = prefs.getString(_kMusicRewardId);
  }
}
