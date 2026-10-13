import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/config/alerts_settings.dart';
import 'package:obssource/config/reward_effects_settings.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/effects/flashbang.dart';
import 'package:obssource/effects/kill_widget.dart';
import 'package:obssource/follow/follow_balloons.dart';
import 'package:obssource/follow/follow_widget.dart';
import 'package:obssource/l10n/app_localizations.dart';
import 'package:obssource/raid/classic_raid_widget.dart';
import 'package:obssource/settings/overlay_settings_dialog.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Settings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = Settings();
    await settings.init();
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(1600, 900),
    Future<List<TwitchCustomReward>> Function()? loadAllRewards,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('uk'),
        home: Scaffold(
          body: OverlaySettingsDialog(
            settings: settings,
            rewardCatalog: _Catalog(),
            loadAllRewards: loadAllRewards,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> section(WidgetTester tester, String name) async {
    final button = find.byKey(ValueKey('overlay_settings_${name}_section'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
    await tester.pump();
  }

  Future<void> play(WidgetTester tester, Duration duration) async {
    final end = tester.binding.clock.now().add(duration);
    while (tester.binding.clock.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('follow page saves its look and previews it', (tester) async {
    await open(tester);
    await section(tester, 'follow');

    await tapKey(tester, 'follow_style_balloons');
    expect(settings.alerts.follow.style, FollowStyle.balloons);
    await tapKey(tester, 'follow_sound_none');
    expect(settings.alerts.follow.sound, FollowSound.none);
    await tapKey(tester, 'follow_enabled');
    expect(settings.alerts.follow.enabled, isFalse);

    final volume = find.byKey(const ValueKey('follow_volume'));
    await tester.ensureVisible(volume);
    await tester.pump();
    final rect = tester.getRect(volume);
    await tester.tapAt(Offset(rect.left + 1, rect.center.dy));
    await tester.pump();
    await tester.pump();
    expect(settings.alerts.follow.volumePercent, 0);

    final restored = Settings();
    await restored.init();
    expect(restored.alerts.toJson(), settings.alerts.toJson());

    // The preview shows the follow although it is turned off.
    await tapKey(tester, 'preview_sample_long');
    expect(find.byType(FollowBalloonsWidget), findsOneWidget);
    await tapKey(tester, 'preview_stop');
    await tester.pump();
    expect(find.byType(FollowBalloonsWidget), findsNothing);

    await tapKey(tester, 'follow_style_pixel');
    await tapKey(tester, 'preview_sample_short');
    expect(find.byType(FollowWidget), findsOneWidget);
    await play(tester, const Duration(seconds: 20));
    expect(find.byType(FollowWidget), findsNothing);
    await close(tester);
  });

  testWidgets('raid page switches between styles', (tester) async {
    await open(tester);
    await section(tester, 'raid');

    expect(find.byKey(const ValueKey('raid_hold')), findsOneWidget);
    expect(find.byKey(const ValueKey('raid_max_animals')), findsNothing);
    await tapKey(tester, 'raid_style_classic');
    expect(settings.alerts.raid.style, RaidStyle.classic);
    expect(find.byKey(const ValueKey('raid_hold')), findsNothing);
    expect(find.byKey(const ValueKey('raid_max_animals')), findsOneWidget);
    await tapKey(tester, 'raid_sound_classic');
    expect(settings.alerts.raid.sound, RaidSound.classic);

    await tapKey(tester, 'preview_sample_raid_1000');
    expect(find.byType(ClassicRaidWidget), findsOneWidget);
    await play(tester, const Duration(seconds: 45));
    expect(find.byType(ClassicRaidWidget), findsNothing);
    await close(tester);
  });

  testWidgets('effect rewards come from all channel rewards', (tester) async {
    await settings.saveMusicRewardId('music');
    var loads = 0;
    await open(
      tester,
      loadAllRewards: () async {
        loads++;
        return [
          _reward('music', 'Music Request'),
          _reward('bang', 'Флешбенг'),
          _reward('other', 'Hydrate'),
        ];
      },
    );
    await section(tester, 'flashbang');
    expect(loads, 1);

    expect(find.byKey(const ValueKey('flashbang_reward_music')), findsNothing);
    expect(find.byKey(const ValueKey('flashbang_reward_none')), findsOneWidget);
    await tapKey(tester, 'flashbang_reward_bang');
    final binding = settings.rewardEffects.binding(RewardAction.flashbang);
    expect(binding.rewardId, 'bang');
    expect(binding.rewardTitle, 'Флешбенг');

    await tapKey(tester, 'preview_sample_golden');
    final flashbang = tester.widget<FlashbangWidget>(
      find.byType(FlashbangWidget),
    );
    expect(flashbang.flashbang.pro, isTrue);
    await play(tester, Flashbang.duration);

    // Rewards are loaded once per dialog.
    await section(tester, 'crt');
    expect(loads, 1);
    await tapKey(tester, 'crt_reward_other');
    expect(settings.rewardEffects.actionsFor('other'), [RewardAction.crt]);
    await tapKey(tester, 'crt_reward_none');
    expect(settings.rewardEffects.binding(RewardAction.crt).isBound, isFalse);
    await close(tester);
  });

  testWidgets('bound rewards stay visible without Twitch', (tester) async {
    await settings.saveRewardEffects(
      settings.rewardEffects.withBinding(
        RewardAction.pause,
        const RewardEffectBinding(rewardId: 'pause', rewardTitle: 'Пауза'),
      ),
    );
    await open(tester);
    await section(tester, 'pause');

    expect(find.byKey(const ValueKey('pause_reward_bound')), findsOneWidget);
    expect(find.text('Підключіть Twitch, щоб вибрати нагороду.'), findsOne);
    await close(tester);
  });

  testWidgets('kill page validates the address before saving', (tester) async {
    await open(tester);
    await section(tester, 'kills');

    await tapKey(tester, 'kills_enabled');
    expect(settings.kills.enabled, isTrue);

    await tester.enterText(
      find.byKey(const ValueKey('kills_address')),
      'nonsense',
    );
    await tapKey(tester, 'kills_apply');
    expect(find.text('Введіть правильну IP-адресу та порт.'), findsOneWidget);
    expect(settings.kills.address, '0.0.0.0');

    await tester.enterText(
      find.byKey(const ValueKey('kills_address')),
      '127.0.0.1',
    );
    await tester.enterText(find.byKey(const ValueKey('kills_port')), '5050');
    await tapKey(tester, 'kills_apply');
    expect(settings.kills.address, '127.0.0.1');
    expect(settings.kills.port, 5050);
    expect(find.text('Слухає http://127.0.0.1:5050/kill'), findsOneWidget);

    await tapKey(tester, 'preview_sample_streak_5');
    expect(find.byType(KillWidget), findsOneWidget);
    await play(tester, const Duration(seconds: 3));
    expect(find.byType(KillWidget), findsNothing);
    await close(tester);
  });

  testWidgets('every page fits a small overlay', (tester) async {
    await open(tester, size: const Size(900, 620));
    for (final name in [
      'follow',
      'raid',
      'subscriptions',
      'reward_cards',
      'chat',
      'flashbang',
      'crt',
      'pause',
      'stickers',
      'kills',
      'player',
    ]) {
      await section(tester, name);
      expect(tester.takeException(), isNull, reason: name);
    }
    await close(tester);
  });
}

TwitchCustomReward _reward(String id, String title, {bool userInput = false}) =>
    TwitchCustomReward(
      id: id,
      title: title,
      prompt: '',
      cost: 500,
      backgroundColor: '#9147FF',
      image: null,
      isEnabled: true,
      isPaused: false,
      isInStock: true,
      isUserInputRequired: userInput,
      shouldRedemptionsSkipRequestQueue: false,
    );

class _Catalog implements TwitchRewardCatalog {
  @override
  Future<List<TwitchCustomReward>> load() async => [
    _reward('music', 'Music Request', userInput: true),
  ];

  @override
  Future<TwitchCustomReward> createDefault() => throw UnimplementedError();
}
