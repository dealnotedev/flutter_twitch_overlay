import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/config/alerts_settings.dart';
import 'package:obssource/config/kills_settings.dart';
import 'package:obssource/config/legacy_reward_binder.dart';
import 'package:obssource/config/reward_effects_settings.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/ws_subscription.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Settings> load([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    final settings = Settings();
    await settings.init();
    return settings;
  }

  Future<Settings> reload() async {
    final settings = Settings();
    await settings.init();
    return settings;
  }

  group('models', () {
    test('alert settings round-trip through JSON', () {
      const value = AlertsSettings(
        follow: FollowAlertSettings(
          enabled: false,
          style: FollowStyle.balloons,
          sound: FollowSound.none,
          volumePercent: 40,
          holdSeconds: 12,
        ),
        raid: RaidAlertSettings(
          style: RaidStyle.classic,
          sound: RaidSound.classic,
          minViewers: 5,
          maxAnimals: 12,
        ),
        subscriptions: SubscriptionAlertSettings(
          resubscribe: false,
          showAvatar: false,
          sound: SubscriptionSound.classic,
        ),
        rewardCard: RewardCardSettings(enabled: false, seconds: 5),
        chat: ChatAlertSettings(highlighted: true, firstMessage: true),
      );

      final restored = AlertsSettings.fromJson(
        jsonDecode(jsonEncode(value.toJson())) as Map<String, dynamic>,
      );

      expect(restored.toJson(), value.toJson());
      expect(
        restored.subscriptions.enabledFor(SubscriptionEventType.message),
        isFalse,
      );
      expect(
        restored.subscriptions.enabledFor(SubscriptionEventType.gift),
        isTrue,
      );
    });

    test('malformed and out-of-range alert values fall back or clamp', () {
      final settings = AlertsSettings.fromJson({
        'follow': {
          'style': 'unknown',
          'volume_percent': 500,
          'hold_seconds': 1,
        },
        'raid': {'min_viewers': -3, 'max_animals': 9000, 'sound': 7},
        'subscriptions': 'broken',
        'reward_card': {'seconds': 99},
        'chat': {'seconds': 0},
      });

      expect(settings.follow.style, FollowStyle.pixel);
      expect(settings.follow.volumePercent, 100);
      expect(settings.follow.holdSeconds, AlertLimits.minHoldSeconds);
      expect(settings.raid.minViewers, 1);
      expect(settings.raid.maxAnimals, RaidAlertSettings.maxAnimalsLimit);
      expect(settings.raid.sound, RaidSound.voice);
      expect(
        settings.subscriptions.toJson(),
        const SubscriptionAlertSettings().toJson(),
      );
      expect(settings.rewardCard.seconds, RewardCardSettings.maxSeconds);
      expect(settings.chat.seconds, ChatAlertSettings.minSeconds);
    });

    test('reward effects resolve active bindings by reward ID', () {
      final settings = RewardEffectsSettings.fromJson({
        'bindings': {
          'flashbang': {'reward_id': 'reward-1', 'reward_title': 'Bang'},
          'sticker': {'reward_id': 'reward-1', 'enabled': true},
          'crosshair': {'reward_id': 'reward-1', 'enabled': false},
          'pause': {'reward_id': '  '},
          'unknown': {'reward_id': 'reward-2'},
        },
        'crt_seconds': 1000,
        'flashbang_pro_chance': -5,
      });

      expect(settings.actionsFor('reward-1'), [
        RewardAction.flashbang,
        RewardAction.sticker,
      ]);
      expect(settings.actionsFor('reward-2'), isEmpty);
      expect(settings.actionsFor(null), isEmpty);
      expect(settings.binding(RewardAction.pause).isBound, isFalse);
      expect(settings.binding(RewardAction.flashbang).rewardTitle, 'Bang');
      expect(settings.crtSeconds, RewardEffectsSettings.maxCrtSeconds);
      expect(settings.flashbangProChancePercent, 0);

      final restored = RewardEffectsSettings.fromJson(
        jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>,
      );
      expect(restored.toJson(), settings.toJson());
    });

    test('clearing a binding also forgets its title', () {
      const binding = RewardEffectBinding(
        rewardId: 'reward-1',
        rewardTitle: 'Bang',
        volumePercent: 30,
      );
      final cleared = binding.withReward();
      expect(cleared.isBound, isFalse);
      expect(cleared.rewardTitle, isNull);
      expect(cleared.volumePercent, 30);
    });

    test('kill server settings reject invalid addresses and ports', () {
      final settings = KillsSettings.fromJson({
        'enabled': true,
        'address': 'not an address',
        'port': 70000,
        'seconds': 0,
      });
      expect(settings.enabled, isTrue);
      expect(settings.address, KillsSettings.defaultAddress);
      expect(settings.port, KillsSettings.defaultPort);
      expect(settings.seconds, KillsSettings.minSeconds);
      expect(
        KillsSettings.fromJson({'address': ' 127.0.0.1 '}).address,
        '127.0.0.1',
      );
    });
  });

  group('migration', () {
    test('a freydis installation keeps its pixel look', () async {
      final settings = await load({
        'twitch_login': jsonEncode(_creds),
        'music_reward_id': 'music',
      });

      expect(settings.alerts.toJson(), const AlertsSettings().toJson());
      expect(settings.kills.enabled, isFalse);
      expect(settings.legacyRewardTitlesPending, isFalse);
      expect(settings.twitchAuth?.broadcasterId, 'channel');
      expect(settings.musicRewardId, 'music');
    });

    test('a master installation keeps its classic look', () async {
      final settings = await load({'twitch_credentials': jsonEncode(_creds)});

      expect(
        settings.alerts.toJson(),
        const AlertsSettings.legacyMaster().toJson(),
      );
      expect(settings.alerts.follow.style, FollowStyle.balloons);
      expect(settings.alerts.raid.style, RaidStyle.classic);
      expect(settings.kills.enabled, isTrue);
      expect(settings.legacyRewardTitlesPending, isTrue);
      // The old token lacks the redemptions scope and must not be reused.
      expect(settings.twitchAuth, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('twitch_credentials'), isFalse);
    });

    test('a second start keeps user changes', () async {
      final settings = await load({'twitch_credentials': jsonEncode(_creds)});
      await settings.saveAlerts(
        settings.alerts.copyWith(
          follow: settings.alerts.follow.copyWith(style: FollowStyle.pixel),
        ),
      );

      final restored = await reload();
      expect(restored.alerts.follow.style, FollowStyle.pixel);
      expect(restored.alerts.raid.style, RaidStyle.classic);
      expect(restored.legacyRewardTitlesPending, isTrue);
    });

    test('saved sections emit and persist', () async {
      final settings = await load();
      final alerts = settings.alertsChanges.first;
      final effects = settings.rewardEffectsChanges.first;
      final kills = settings.killsChanges.first;

      await settings.saveAlerts(
        settings.alerts.copyWith(
          raid: settings.alerts.raid.copyWith(minViewers: 3),
        ),
      );
      await settings.saveRewardEffects(
        settings.rewardEffects.withBinding(
          RewardAction.pause,
          const RewardEffectBinding(rewardId: 'pause-id'),
        ),
      );
      await settings.saveKills(const KillsSettings(enabled: true, port: 5000));

      expect((await alerts).raid.minViewers, 3);
      expect((await effects).actionsFor('pause-id'), [RewardAction.pause]);
      expect((await kills).port, 5000);

      final restored = await reload();
      expect(restored.alerts.raid.minViewers, 3);
      expect(restored.rewardEffects.actionsFor('pause-id'), [
        RewardAction.pause,
      ]);
      expect(restored.kills.port, 5000);
    });
  });

  group('OBS switches', () {
    test('freydis semantics: missing followers off, others on', () async {
      final settings = await load({'twitch_login': jsonEncode(_creds)});
      await settings.importLegacyObsFlags({'subscriptions': false});

      expect(settings.alerts.follow.enabled, isFalse);
      expect(settings.alerts.raid.enabled, isTrue);
      expect(settings.alerts.subscriptions.anyEnabled, isFalse);
      expect(settings.alerts.chat.firstMessage, isFalse);
      expect(
        settings.rewardEffects.binding(RewardAction.sticker).enabled,
        isFalse,
      );
    });

    test('master semantics: every missing switch is off', () async {
      final settings = await load({'twitch_credentials': jsonEncode(_creds)});
      await settings.importLegacyObsFlags({
        'followers': true,
        'first_chat_message': true,
        'screen_attack_game': true,
      });

      expect(settings.alerts.follow.enabled, isTrue);
      expect(settings.alerts.raid.enabled, isFalse);
      expect(settings.alerts.subscriptions.anyEnabled, isFalse);
      expect(settings.alerts.chat.firstMessage, isTrue);
      expect(
        settings.rewardEffects.binding(RewardAction.sticker).enabled,
        isTrue,
      );
      expect(
        settings.rewardEffects.binding(RewardAction.crosshair).enabled,
        isTrue,
      );
    });

    test('switches are imported only once', () async {
      final settings = await load();
      await settings.importLegacyObsFlags({'followers': true});
      await settings.importLegacyObsFlags({'followers': false});
      expect(settings.alerts.follow.enabled, isTrue);

      final restored = await reload();
      await restored.importLegacyObsFlags({'followers': false});
      expect(restored.alerts.follow.enabled, isTrue);
    });
  });

  group('legacy rewards', () {
    test('binds old titles once and keeps existing bindings', () async {
      final settings = await load({'twitch_credentials': jsonEncode(_creds)});
      await settings.saveRewardEffects(
        settings.rewardEffects.withBinding(
          RewardAction.pause,
          const RewardEffectBinding(rewardId: 'chosen-pause'),
        ),
      );
      var loads = 0;
      final binder = LegacyRewardBinder(
        settings: settings,
        loadRewards: () async {
          loads++;
          return [
            _reward('flash', 'Флешбенг'),
            _reward('old-pause', 'Пауза'),
            _reward('spit', 'Плюнуть в екран'),
            _reward('other', 'Something else'),
          ];
        },
      );

      await binder.run();
      await binder.run();

      final effects = settings.rewardEffects;
      expect(loads, 1);
      expect(effects.binding(RewardAction.flashbang).rewardId, 'flash');
      expect(effects.binding(RewardAction.flashbang).rewardTitle, 'Флешбенг');
      expect(effects.binding(RewardAction.pause).rewardId, 'chosen-pause');
      expect(effects.binding(RewardAction.sticker).rewardId, 'spit');
      expect(effects.binding(RewardAction.crt).isBound, isFalse);
      expect(effects.binding(RewardAction.crosshair).isBound, isFalse);
      expect(settings.legacyRewardTitlesPending, isFalse);
      expect((await reload()).legacyRewardTitlesPending, isFalse);
    });

    test('does nothing for installations that never used titles', () async {
      final settings = await load({'twitch_login': jsonEncode(_creds)});
      final binder = LegacyRewardBinder(
        settings: settings,
        loadRewards: () async => fail('must not load rewards'),
      );
      await binder.run();
      expect(settings.rewardEffects.bindings, isEmpty);
    });

    test('a failed reward list keeps the binding pending', () async {
      final settings = await load({'twitch_credentials': jsonEncode(_creds)});
      final binder = LegacyRewardBinder(
        settings: settings,
        loadRewards: () async => throw StateError('offline'),
      );
      await expectLater(binder.run(), throwsStateError);
      expect(settings.legacyRewardTitlesPending, isTrue);
    });
  });
}

const _creds = {
  'accessToken': 'access',
  'refreshToken': 'refresh',
  'client_id': 'client',
  'broadcasterId': 'channel',
};

TwitchCustomReward _reward(String id, String title) => TwitchCustomReward(
  id: id,
  title: title,
  prompt: '',
  cost: 100,
  backgroundColor: '#9147FF',
  image: null,
  isEnabled: true,
  isPaused: false,
  isInStock: true,
  isUserInputRequired: false,
  shouldRedemptionsSkipRequestQueue: false,
);
