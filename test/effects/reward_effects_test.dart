import 'dart:io';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:obssource/config/alerts_settings.dart';
import 'package:obssource/config/kills_settings.dart';
import 'package:obssource/config/reward_effects_settings.dart';
import 'package:obssource/data/events.dart';
import 'package:obssource/effects/alert_audio.dart';
import 'package:obssource/effects/effect_runtime.dart';
import 'package:obssource/effects/pause_effect.dart';
import 'package:obssource/effects/screen_attack_game.dart';
import 'package:obssource/events/alert_event.dart';
import 'package:obssource/kills/kill_server.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/ws_event.dart';

void main() {
  group('pause input', () {
    const max = Duration(minutes: 60);

    test('accepts minutes or m:ss followed by a message', () {
      final minutes = PauseRequest.parse('5', max: max)!;
      expect(minutes.duration, const Duration(minutes: 5));
      expect(minutes.message, isNull);

      final withMessage =
          PauseRequest.parse(' 1:30   Скоро   повернуся ', max: max)!;
      expect(withMessage.duration, const Duration(minutes: 1, seconds: 30));
      expect(withMessage.message, 'Скоро повернуся');
    });

    test('empty input and zero time remove the pause', () {
      expect(PauseRequest.parse(null, max: max)!.clears, isTrue);
      expect(PauseRequest.parse('   ', max: max)!.clears, isTrue);
      expect(PauseRequest.parse('0', max: max)!.clears, isTrue);
      expect(PauseRequest.parse('0:00 bye', max: max)!.clears, isTrue);
    });

    test('malformed time is ignored and long pauses are capped', () {
      expect(PauseRequest.parse('soon', max: max), isNull);
      expect(PauseRequest.parse('-5', max: max), isNull);
      expect(PauseRequest.parse('1:2:3', max: max), isNull);
      expect(PauseRequest.parse('600', max: max)!.duration, max);
    });
  });

  group('kill server', () {
    test('parses the query of the external tracker', () {
      final kill =
          KillServer.parse({
            'text': 'Double kill',
            'in_match': '2',
            'in_match_streak': '2',
            'total_streak': '7',
          })!;
      expect(kill.text, 'Double kill');
      expect(kill.inMatch, 2);
      expect(kill.totalStreak, 7);
      expect(KillServer.parse({'text': 'x', 'in_match': 'two'}), isNull);
    });

    test('accepts kills over HTTP only while enabled', () async {
      final server = KillServer();
      addTearDown(server.close);
      final kills = <KillInfo>[];
      final subscription = server.kills.listen(kills.add);
      addTearDown(subscription.cancel);

      await server.configure(enabled: true, address: '127.0.0.1', port: 0);
      final port = server.port!;
      final client = HttpClient();
      addTearDown(client.close);

      Future<int> get(String query) async {
        final request = await client.get('127.0.0.1', port, '/kill?$query');
        final response = await request.close();
        await response.drain<void>();
        return response.statusCode;
      }

      expect(
        await get('text=Kill&in_match=1&in_match_streak=1&total_streak=3'),
        HttpStatus.ok,
      );
      expect(await get('text=Broken'), HttpStatus.badRequest);
      await Future<void>.delayed(Duration.zero);
      expect(kills.single.text, 'Kill');

      await server.configure(enabled: false, address: '127.0.0.1', port: 0);
      expect(server.port, isNull);
    });
  });

  group('runtime', () {
    late RewardEffectsSettings effects;
    late AlertsSettings alerts;
    late _RecordingAudio audio;

    EffectRuntime create({Random? random}) => EffectRuntime(
      alerts: () => alerts,
      rewardEffects: () => effects,
      kills: () => const KillsSettings(seconds: 2),
      loadUser:
          (id) async => UserDto(
            id: id,
            login: id,
            displayName: id,
            profileImageUrl: 'https://example.test/$id.png',
          ),
      loadAvatar: (_) async => img.Image(width: 8, height: 8),
      loadPauseImage: () async => img.Image(width: 8, height: 8),
      audio: audio,
      random: random,
    );

    setUp(() {
      alerts = const AlertsSettings(
        rewardCard: RewardCardSettings(enabled: false),
      );
      effects = const RewardEffectsSettings();
      for (final action in RewardAction.values) {
        effects = effects.withBinding(
          action,
          RewardEffectBinding(rewardId: action.name),
        );
      }
      audio = _RecordingAudio();
    });

    test('flashbangs play one after another', () {
      fakeAsync((async) {
        effects = effects.copyWith(flashbangProChancePercent: 100);
        final runtime = create();
        runtime.handle(_redemption('flashbang', id: 'first'));
        runtime.handle(_redemption('flashbang', id: 'second'));
        async.flushMicrotasks();

        expect(runtime.flashbang?.id, 'first');
        expect(runtime.flashbang?.pro, isTrue);
        async.elapse(const Duration(seconds: 5));
        expect(runtime.flashbang?.id, 'second');
        async.elapse(const Duration(seconds: 5));
        expect(runtime.flashbang, isNull);

        runtime.playFlashbangSound();
        expect(audio.played, ['assets/wav_flashbang.wav']);
        runtime.dispose();
      });
    });

    test('a second CRT redemption extends the same session', () {
      fakeAsync((async) {
        effects = effects.copyWith(crtSeconds: 30);
        final runtime = create();
        runtime.handle(_redemption('crt', id: 'first', user: 'alice'));
        async.flushMicrotasks();
        final session = runtime.crt!.session;
        expect(runtime.crt!.userName, 'alice');
        expect(audio.played, ['assets/tv_off_sound.wav']);

        async.elapse(const Duration(seconds: 20));
        runtime.handle(_redemption('crt', id: 'second', user: 'bob'));
        async.flushMicrotasks();
        expect(runtime.crt!.session, session);
        expect(runtime.crt!.userName, 'bob');

        async.elapse(const Duration(seconds: 20));
        expect(runtime.crt, isNotNull);
        async.elapse(const Duration(seconds: 10));
        expect(runtime.crt, isNull);

        runtime.handle(_redemption('crt', id: 'third'));
        async.flushMicrotasks();
        expect(runtime.crt!.session, isNot(session));
        runtime.dispose();
      });
    });

    test('pause is replaced, ignored on bad input and removed by zero', () {
      fakeAsync((async) {
        final runtime = create();
        runtime.handle(_redemption('pause', id: '1', input: '2 Coffee'));
        async.flushMicrotasks();
        expect(runtime.pause!.duration, const Duration(minutes: 2));
        expect(runtime.pause!.message, 'Coffee');

        runtime.handle(_redemption('pause', id: '2', input: 'nonsense'));
        async.flushMicrotasks();
        expect(runtime.pause!.message, 'Coffee');

        // The picture stays after its duration until removed.
        async.elapse(const Duration(minutes: 5));
        expect(runtime.pause, isNotNull);

        runtime.handle(_redemption('pause', id: '3', input: '0'));
        async.flushMicrotasks();
        expect(runtime.pause, isNull);
        runtime.dispose();
      });
    });

    test('sticker and crosshair rewards command the sticker layer', () {
      fakeAsync((async) {
        effects = effects.copyWith(crosshairSeconds: 45);
        final runtime = create();
        final commands = <ScreenAttackCommand>[];
        runtime.screenAttack.commands.listen(commands.add);

        expect(runtime.screenAttackMounted, isTrue);
        runtime.handle(_redemption('sticker', id: '1'));
        runtime.handle(_redemption('crosshair', id: '2'));
        async.flushMicrotasks();

        expect(commands[0], isA<StickerCommand>());
        expect(
          (commands[1] as AimCommand).duration,
          const Duration(seconds: 45),
        );
        runtime.dispose();
      });
    });

    test('sticker layer is mounted only for active bindings', () {
      effects = const RewardEffectsSettings();
      final runtime = create();
      expect(runtime.screenAttackMounted, isFalse);
      effects = effects.withBinding(
        RewardAction.crosshair,
        const RewardEffectBinding(rewardId: 'aim', enabled: false),
      );
      expect(runtime.screenAttackMounted, isFalse);
      runtime.dispose();
    });

    test('unbound rewards only show the card', () {
      fakeAsync((async) {
        alerts = const AlertsSettings();
        final runtime = create();
        runtime.handle(_redemption('unbound', id: 'card'));
        async.flushMicrotasks();
        expect(runtime.rewardCards.single.id, 'card');
        expect(runtime.flashbang, isNull);
        expect(runtime.crt, isNull);
        expect(runtime.pause, isNull);
        runtime.dispose();
      });
    });

    test('highlighted and first messages respect their switches', () {
      fakeAsync((async) {
        alerts = alerts.copyWith(
          chat: const ChatAlertSettings(highlighted: true, seconds: 10),
        );
        final runtime = create(random: Random(1));
        runtime.handle(_chat('1', chatter: 'viewer'));
        runtime.handle(
          _chat('2', chatter: 'viewer', type: ChatEvent.highlightedType),
        );
        async.flushMicrotasks();
        expect(runtime.chatCards.single.id, '2');
        expect(runtime.chatCards.single.firstMessage, isFalse);
        expect(
          runtime.chatCards.single.avatarUrl,
          'https://example.test/viewer.png',
        );

        alerts = alerts.copyWith(
          chat: const ChatAlertSettings(firstMessage: true),
        );
        runtime.handle(_chat('3', chatter: 'viewer'));
        runtime.handle(_chat('4', chatter: 'newcomer'));
        async.flushMicrotasks();
        expect(runtime.chatCards.map((card) => card.id), ['2', '4']);
        expect(runtime.chatCards.last.firstMessage, isTrue);

        async.elapse(const Duration(seconds: 10));
        expect(runtime.chatCards, isEmpty);
        runtime.dispose();
      });
    });

    test('kills are shown one after another', () {
      fakeAsync((async) {
        final runtime = create();
        runtime.handle(KillEvent(_kill('First')));
        runtime.handle(KillEvent(_kill('Second')));
        async.flushMicrotasks();
        expect(runtime.kill?.text, 'First');
        async.elapse(const Duration(seconds: 2));
        expect(runtime.kill?.text, 'Second');
        async.elapse(const Duration(seconds: 2));
        expect(runtime.kill, isNull);
        runtime.dispose();
      });
    });

    test('balloons fly for the hold time', () {
      fakeAsync((async) {
        alerts = alerts.copyWith(
          follow: const FollowAlertSettings(
            style: FollowStyle.balloons,
            sound: FollowSound.classic,
            holdSeconds: 10,
          ),
        );
        final runtime = create();
        runtime.handle(FollowEvent(user: _user('follower')));
        async.flushMicrotasks();
        final alert = runtime.stage! as FollowStageAlert;
        expect(alert.style, FollowStyle.balloons);
        expect(alert.event.avatar, isNull);
        expect(alert.event.user?.profileImageUrl, isNotNull);
        expect(audio.played, ['assets/follow_classic.mp3']);

        async.elapse(const Duration(seconds: 10));
        expect(runtime.stage, isNull);
        runtime.dispose();
      });
    });

    test('the classic raid ends when its animation reports done', () {
      fakeAsync((async) {
        alerts = alerts.copyWith(
          raid: const RaidAlertSettings(
            style: RaidStyle.classic,
            sound: RaidSound.classic,
            maxAnimals: 2,
          ),
        );
        final runtime = create();
        runtime.handle(RaidEvent(from: _user('raider'), viewers: 500));
        runtime.handle(FollowEvent(user: _user('follower')));
        async.flushMicrotasks();

        final raid = runtime.stage! as RaidStageAlert;
        expect(raid.style, RaidStyle.classic);
        expect(raid.maxAnimals, 2);
        expect(raid.from.displayName, 'raider');
        expect(audio.played, ['assets/raid.mp3']);

        async.elapse(const Duration(seconds: 3));
        runtime.completeStage(raid);
        async.flushMicrotasks();
        expect(runtime.stage, isA<FollowStageAlert>());
        runtime.dispose();
      });
    });

    test('the classic raid has a safety timeout', () {
      fakeAsync((async) {
        alerts = alerts.copyWith(
          raid: const RaidAlertSettings(
            style: RaidStyle.classic,
            maxAnimals: 4,
          ),
        );
        final runtime = create();
        runtime.handle(RaidEvent(from: _user('raider'), viewers: 50));
        async.flushMicrotasks();
        expect(runtime.stage, isA<RaidStageAlert>());

        // 1 s delay + 4 × 0.75 s + 6 s run + 5 s tail + 10 s margin.
        async.elapse(const Duration(seconds: 24));
        expect(runtime.stage, isNotNull);
        async.elapse(const Duration(seconds: 1));
        expect(runtime.stage, isNull);
        runtime.dispose();
      });
    });
  });
}

UserInfo _user(String id) => UserInfo(id: id, login: id, name: id);

RedemptionEvent _redemption(
  String rewardId, {
  required String id,
  String user = 'viewer',
  String? input,
}) => RedemptionEvent(
  id: id,
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
        text: 'hello',
        fragments: [
          WsChatMessageFragment(type: WsFragmentType.text, text: 'hello'),
        ],
      ),
    );

KillInfo _kill(String text) =>
    KillInfo(text: text, inMatch: 1, inMatchStreak: 1, totalStreak: 1);

class _RecordingAudio implements AlertAudio {
  final played = <String>[];

  @override
  Future<void> play(String asset, {int volumePercent = 100}) async {
    played.add(asset);
  }
}
