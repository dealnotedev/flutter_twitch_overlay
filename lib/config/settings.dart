import 'dart:async';
import 'dart:convert';

import 'package:obssource/config/alerts_settings.dart';
import 'package:obssource/config/avatar_settings.dart';
import 'package:obssource/config/kills_settings.dart';
import 'package:obssource/config/reward_effects_settings.dart';
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
  static const _kAlerts = 'alerts_v1';
  static const _kRewardEffects = 'reward_effects_v1';
  static const _kKills = 'kills_v1';

  // Migration bookkeeping, see [_migrate].
  static const _kSchema = 'settings_schema';
  static const _kOldTwitchAuth = 'twitch_credentials';
  static const _kInstallOrigin = 'install_origin';
  static const _kLegacyRewardTitlesPending = 'legacy_reward_titles_pending';
  static const _kObsFlagsImported = 'obs_flags_imported';
  static const _schemaVersion = 1;

  /// Keys written only by freydis builds. Early freydis builds also used
  /// `twitch_credentials`, so that key alone does not identify master.
  static const _freydisKeys = [
    _kTwitchAuth,
    _kMusicRewardId,
    _kMusicSettings,
    _kAvatarSettings,
    _kPlayerCollapseSeconds,
    _kPlayerAlwaysExpanded,
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    await _migrate(prefs);
    alerts = AlertsSettings.fromJson(_readJson(prefs, _kAlerts));
    rewardEffects = RewardEffectsSettings.fromJson(
      _readJson(prefs, _kRewardEffects),
    );
    kills = KillsSettings.fromJson(_readJson(prefs, _kKills));
    _origin = _InstallOrigin.values.firstWhere(
      (origin) => origin.name == prefs.getString(_kInstallOrigin),
      orElse: () => _InstallOrigin.fresh,
    );
    legacyRewardTitlesPending =
        prefs.getBool(_kLegacyRewardTitlesPending) ?? false;
    _obsFlagsImported = prefs.getBool(_kObsFlagsImported) ?? false;

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

  /// One-time upgrade of installations made by the master or freydis builds.
  ///
  /// Installations with data of freydis builds keep the freydis look. Only
  /// `twitch_credentials` without any freydis data means the old master
  /// build; it starts with the master look so the stream does not change
  /// after the update. That token is dropped in both cases because it lacks
  /// the `channel:manage:redemptions` scope.
  Future<void> _migrate(SharedPreferences prefs) async {
    if ((prefs.getInt(_kSchema) ?? 0) >= _schemaVersion) return;

    final origin =
        _freydisKeys.any(prefs.containsKey)
            ? _InstallOrigin.freydis
            : prefs.containsKey(_kOldTwitchAuth)
            ? _InstallOrigin.master
            : _InstallOrigin.fresh;
    final legacyMaster = origin == _InstallOrigin.master;
    if (!prefs.containsKey(_kAlerts)) {
      final alerts =
          legacyMaster
              ? const AlertsSettings.legacyMaster()
              : const AlertsSettings();
      await _writeJson(prefs, _kAlerts, alerts.toJson());
    }
    if (!prefs.containsKey(_kKills)) {
      await _writeJson(
        prefs,
        _kKills,
        KillsSettings(enabled: legacyMaster).toJson(),
      );
    }
    if (legacyMaster) await prefs.setBool(_kLegacyRewardTitlesPending, true);
    await prefs.setString(_kInstallOrigin, origin.name);
    await prefs.remove(_kOldTwitchAuth);
    if (!await prefs.setInt(_kSchema, _schemaVersion)) {
      throw StateError('Could not save settings schema');
    }
  }

  static Map<String, dynamic> _readJson(SharedPreferences prefs, String key) {
    try {
      final raw = prefs.get(key);
      final json = jsonDecode(raw is String ? raw : '{}');
      return json is Map<String, dynamic> ? json : const {};
    } on FormatException {
      return const {};
    }
  }

  static Future<void> _writeJson(
    SharedPreferences prefs,
    String key,
    Map<String, Object> json,
  ) async {
    if (!await prefs.setString(key, jsonEncode(json))) {
      throw StateError('Could not save $key');
    }
  }

  _InstallOrigin _origin = _InstallOrigin.fresh;
  bool _obsFlagsImported = false;

  /// Old master rewards are still to be matched by their hard-coded titles.
  bool legacyRewardTitlesPending = false;

  AlertsSettings alerts = const AlertsSettings();
  final _alertsSubject = StreamController<AlertsSettings>.broadcast();
  Stream<AlertsSettings> get alertsChanges => _alertsSubject.stream;

  Future<void> saveAlerts(AlertsSettings value) async {
    final normalized = value.normalized();
    final prefs = await SharedPreferences.getInstance();
    await _writeJson(prefs, _kAlerts, normalized.toJson());
    alerts = normalized;
    _alertsSubject.add(alerts);
  }

  RewardEffectsSettings rewardEffects = const RewardEffectsSettings();
  final _rewardEffectsSubject =
      StreamController<RewardEffectsSettings>.broadcast();
  Stream<RewardEffectsSettings> get rewardEffectsChanges =>
      _rewardEffectsSubject.stream;

  Future<void> saveRewardEffects(RewardEffectsSettings value) async {
    final normalized = value.normalized();
    final prefs = await SharedPreferences.getInstance();
    await _writeJson(prefs, _kRewardEffects, normalized.toJson());
    rewardEffects = normalized;
    _rewardEffectsSubject.add(rewardEffects);
  }

  KillsSettings kills = const KillsSettings();
  final _killsSubject = StreamController<KillsSettings>.broadcast();
  Stream<KillsSettings> get killsChanges => _killsSubject.stream;

  Future<void> saveKills(KillsSettings value) async {
    final normalized = value.normalized();
    final prefs = await SharedPreferences.getInstance();
    await _writeJson(prefs, _kKills, normalized.toJson());
    kills = normalized;
    _killsSubject.add(kills);
  }

  Future<void> completeLegacyRewardTitles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLegacyRewardTitlesPending);
    legacyRewardTitlesPending = false;
  }

  /// Moves the alert switches of the OBS source JSON into local settings once.
  ///
  /// Only switches the installed build actually read are imported, and
  /// missing keys keep their meaning there: master treated every missing
  /// switch as off; freydis read only `followers` (missing means off),
  /// `raids` and `subscriptions` (missing means on). New installations had no
  /// behavior to keep and use the defaults.
  Future<void> importLegacyObsFlags(Map<String, dynamic> json) async {
    if (_obsFlagsImported) return;
    _obsFlagsImported = true;

    bool flag(String key, bool missing) {
      final value = json[key];
      return value is bool ? value : missing;
    }

    final master = _origin == _InstallOrigin.master;
    if (_origin != _InstallOrigin.fresh) {
      final subscriptions = flag('subscriptions', !master);
      await saveAlerts(
        alerts.copyWith(
          follow: alerts.follow.copyWith(enabled: flag('followers', false)),
          raid: alerts.raid.copyWith(enabled: flag('raids', !master)),
          subscriptions: alerts.subscriptions.copyWith(
            subscribe: subscriptions,
            resubscribe: subscriptions,
            gift: subscriptions,
          ),
          chat:
              master
                  ? alerts.chat.copyWith(
                    firstMessage: flag('first_chat_message', false),
                  )
                  : alerts.chat,
        ),
      );
    }

    if (master) {
      final screenAttack = flag('screen_attack_game', false);
      var effects = rewardEffects;
      for (final action in [RewardAction.sticker, RewardAction.crosshair]) {
        effects = effects.withBinding(
          action,
          effects.binding(action).copyWith(enabled: screenAttack),
        );
      }
      await saveRewardEffects(effects);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kObsFlagsImported, true);
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

/// Build that wrote the settings before the merged overlay.
enum _InstallOrigin { master, freydis, fresh }
