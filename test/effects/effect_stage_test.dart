import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:obssource/config/alerts_settings.dart';
import 'package:obssource/config/kills_settings.dart';
import 'package:obssource/config/reward_effects_settings.dart';
import 'package:obssource/data/events.dart';
import 'package:obssource/effects/alert_audio.dart';
import 'package:obssource/effects/chat_card.dart';
import 'package:obssource/effects/crt_off.dart';
import 'package:obssource/effects/effect_runtime.dart';
import 'package:obssource/effects/effect_stage.dart';
import 'package:obssource/effects/flashbang.dart';
import 'package:obssource/effects/kill_widget.dart';
import 'package:obssource/effects/pause_effect.dart';
import 'package:obssource/effects/screen_attack_game.dart';
import 'package:obssource/events/alert_event.dart';
import 'package:obssource/follow/follow_balloons.dart';
import 'package:obssource/l10n/app_localizations.dart';
import 'package:obssource/raid/classic_raid_widget.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/ws_event.dart';

void main() {
  late AlertsSettings alerts;
  late RewardEffectsSettings effects;
  late EffectRuntime runtime;

  setUp(() {
    alerts = const AlertsSettings(
      follow: FollowAlertSettings(style: FollowStyle.balloons),
      raid: RaidAlertSettings(style: RaidStyle.classic, maxAnimals: 3),
      rewardCard: RewardCardSettings(enabled: false),
      chat: ChatAlertSettings(highlighted: true, firstMessage: true),
    );
    effects = const RewardEffectsSettings();
    for (final action in RewardAction.values) {
      effects = effects.withBinding(
        action,
        RewardEffectBinding(rewardId: action.name),
      );
    }
    runtime = EffectRuntime(
      alerts: () => alerts,
      rewardEffects: () => effects,
      kills: () => const KillsSettings(seconds: 3),
      // No profile pictures: the test must not reach the network.
      loadUser:
          (id) async => UserDto(
            id: id,
            login: id,
            displayName: id,
            profileImageUrl: null,
          ),
      loadAvatar: (_) async => img.Image(width: 64, height: 64),
      loadPauseImage: () async => img.Image(width: 32, height: 32),
      audio: const SilentAlertAudio(),
      random: Random(7),
    );
  });

  Future<void> pumpStage(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('uk'),
      home: LayoutBuilder(
        builder:
            (context, constraints) => Stack(
              children: [
                Positioned.fill(
                  child: EffectStage(
                    runtime: runtime,
                    constraints: constraints,
                  ),
                ),
              ],
            ),
      ),
    ),
  );

  Future<void> play(WidgetTester tester, Duration duration) async {
    final end = tester.binding.clock.now().add(duration);
    while (tester.binding.clock.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    runtime.dispose();
  }

  testWidgets('balloon follow flies through and leaves', (tester) async {
    await pumpStage(tester);
    runtime.handle(FollowEvent(user: _user('follower')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FollowBalloonsWidget), findsOneWidget);
    expect(
      find.textContaining('тепер з нами', findRichText: true),
      findsOneWidget,
    );

    await play(tester, const Duration(seconds: 10));
    expect(find.byType(FollowBalloonsWidget), findsNothing);
    await finish(tester);
  });

  testWidgets('classic raid runs its animals and reports done', (tester) async {
    await pumpStage(tester);
    runtime.handle(RaidEvent(from: _user('raider'), viewers: 250));
    await tester.pump();
    await tester.pump();
    expect(find.byType(ClassicRaidWidget), findsOneWidget);
    expect(
      find.textContaining('вривається рейдом', findRichText: true),
      findsOneWidget,
    );

    // 1 s + 3 animals × 0.75 s + 6 s run, the 10 s avatar, then 5 s tail.
    await play(tester, const Duration(seconds: 15));
    expect(find.byType(ClassicRaidWidget), findsNothing);
    await finish(tester);
  });

  testWidgets('flashbang bangs and fades', (tester) async {
    await pumpStage(tester);
    runtime.handle(_redemption('flashbang'));
    await tester.pump();
    expect(find.byType(FlashbangWidget), findsOneWidget);
    await play(tester, Flashbang.duration);
    expect(find.byType(FlashbangWidget), findsNothing);
    await finish(tester);
  });

  testWidgets('CRT switches off, shows the redeemer and restores', (
    tester,
  ) async {
    effects = effects.copyWith(crtSeconds: 5);
    await pumpStage(tester);
    runtime.handle(_redemption('crt', user: 'Prankster'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CrtOffEffectWidget), findsOneWidget);

    await play(tester, const Duration(seconds: 2));
    expect(
      find.textContaining('Prankster', findRichText: true),
      findsOneWidget,
    );

    await play(tester, const Duration(seconds: 3));
    expect(find.byType(CrtOffEffectWidget), findsNothing);
    await finish(tester);
  });

  testWidgets('pause shows its message until removed', (tester) async {
    await pumpStage(tester);
    runtime.handle(_redemption('pause', input: '1 Кава'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(PauseEffectWidget), findsOneWidget);
    expect(find.text('Кава'), findsOneWidget);

    await play(tester, const Duration(minutes: 1, seconds: 2));
    expect(find.byType(PauseEffectWidget), findsOneWidget);

    runtime.handle(_redemption('pause', id: 'clear', input: '0'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(PauseEffectWidget), findsNothing);
    await finish(tester);
  });

  testWidgets('crosshair appears and a sticker hits the screen', (
    tester,
  ) async {
    await pumpStage(tester);
    expect(find.byType(ScreenAttackGameWidget), findsOneWidget);
    runtime.handle(_redemption('crosshair'));
    await tester.pump();
    expect(find.byType(HuntCrosshair), findsOneWidget);

    runtime.handle(_redemption('sticker', id: 'spit'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await play(tester, const Duration(seconds: 2));
    expect(tester.takeException(), isNull);

    await play(tester, const Duration(seconds: 60));
    expect(find.byType(HuntCrosshair), findsNothing);
    await finish(tester);
  });

  testWidgets('chat cards carry highlighted and first messages', (
    tester,
  ) async {
    await pumpStage(tester);
    runtime.handle(_chat('first', chatter: 'newcomer'));
    runtime.handle(
      _chat('vip', chatter: 'regular', type: ChatEvent.highlightedType),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(ChatCardWidget), findsNWidgets(2));
    expect(find.text('Перше'), findsOneWidget);
    expect(find.text('Важливе'), findsOneWidget);

    await play(tester, const Duration(seconds: 10));
    expect(find.byType(ChatCardWidget), findsNothing);
    await finish(tester);
  });

  testWidgets('layers changing around the foreground keep its state', (
    tester,
  ) async {
    var created = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LayoutBuilder(
          builder:
              (context, constraints) => Stack(
                children: [
                  Positioned.fill(
                    child: EffectStage(
                      runtime: runtime,
                      constraints: constraints,
                      foreground: Positioned(
                        right: 0,
                        bottom: 0,
                        child: _Probe(onCreate: () => created++),
                      ),
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
    runtime.handle(_chat('card', chatter: 'viewer'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(ChatCardWidget), findsOneWidget);

    // The chat card below leaves in the frame the flashbang above appears.
    await tester.pump(const Duration(milliseconds: 9900));
    runtime.handle(_redemption('flashbang'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(ChatCardWidget), findsNothing);
    expect(find.byType(FlashbangWidget), findsOneWidget);
    expect(created, 1);

    await play(tester, Flashbang.duration);
    await finish(tester);
  });

  testWidgets('kill text is shown for its duration', (tester) async {
    await pumpStage(tester);
    runtime.handle(
      KillEvent(
        KillInfo(text: 'Ace', inMatch: 5, inMatchStreak: 5, totalStreak: 9),
      ),
    );
    await tester.pump();
    expect(find.byType(KillWidget), findsOneWidget);
    await play(tester, const Duration(seconds: 3));
    expect(find.byType(KillWidget), findsNothing);
    await finish(tester);
  });
}

UserInfo _user(String id) => UserInfo(id: id, login: id, name: id);

RedemptionEvent _redemption(
  String rewardId, {
  String id = 'redemption',
  String user = 'viewer',
  String? input,
}) => RedemptionEvent(
  id: '$rewardId-$id',
  rewardId: rewardId,
  rewardTitle: rewardId,
  cost: 100,
  user: _user(user),
  input: input,
);

ChatEvent _chat(String id, {required String chatter, String type = 'text'}) =>
    ChatEvent(
      messageId: id,
      chatter: _user(chatter),
      messageType: type,
      message: const WsChatMessage(
        text: 'Привіт',
        fragments: [
          WsChatMessageFragment(type: WsFragmentType.text, text: 'Привіт'),
        ],
      ),
    );

class _Probe extends StatefulWidget {
  final VoidCallback onCreate;

  const _Probe({required this.onCreate});

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.onCreate();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 10, height: 10);
}
