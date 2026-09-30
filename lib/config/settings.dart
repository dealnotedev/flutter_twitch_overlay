import 'dart:async';
import 'dart:convert';

import 'package:obssource/twitch/twitch_creds.dart';
import 'package:obssource/tts/tts_settings.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  static const _kTwitchAuth = 'twitch_login';
  static const _kMusicRewardId = 'music_reward_id';
  static const _kPlayerCollapseSeconds = 'player_collapse_seconds';
  static const _kPlayerAlwaysExpanded = 'player_always_expanded';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    _initTwitchCreds(prefs);
    _initMusicRewardId(prefs);
    final ttsJson = prefs.getString('tts_settings');
    if (ttsJson != null) {
      try {
        tts = TtsSettings.fromJson(jsonDecode(ttsJson) as Map<String, dynamic>);
      } on FormatException {
        tts = const TtsSettings();
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
    if (rewardId != null && rewardId.trim() == tts.rewardId) {
      throw StateError('This reward is already used for TTS');
    }
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

  TtsSettings tts = const TtsSettings();
  final _ttsSubject = StreamController<TtsSettings>.broadcast();
  Stream<TtsSettings> get ttsChanges => _ttsSubject.stream;

  Future<void> saveTts(TtsSettings value) async {
    if (value.rewardId != null && value.rewardId == musicRewardId) {
      throw StateError('This reward is already used for music');
    }
    final normalized = value.copyWith(
      baseUrl: TtsSettings.normalizeBaseUrl(value.baseUrl),
      volumePercent: value.volumePercent.clamp(0, TtsSettings.maxVolumePercent),
    );
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      'tts_settings',
      jsonEncode(normalized.toJson()),
    )) {
      throw StateError('Could not save TTS settings');
    }
    tts = normalized;
    _ttsSubject.add(tts);
  }

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
