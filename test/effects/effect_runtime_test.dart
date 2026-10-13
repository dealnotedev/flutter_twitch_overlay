import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:obssource/config/alerts_settings.dart';
import 'package:obssource/effects/alert_audio.dart';
import 'package:obssource/effects/effect_runtime.dart';
import 'package:obssource/events/alert_event.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/ws_event.dart';
import 'package:obssource/twitch/ws_subscription.dart';

void main() {
  late AlertsSettings alerts;
  late _RecordingAudio audio;
  late List<String> lookups;

  EffectRuntime create() => EffectRuntime(
    alerts: () => alerts,
    loadUser: (id) async {
      lookups.add(id);
      return UserDto(
        id: id,
        login: id,
        displayName: id,
        profileImageUrl: 'https://example.test/$id.png',
      );
    },
    loadAvatar: (_) async => img.Image(width: 8, height: 8),
    audio: audio,
  );

  setUp(() {
    alerts = const AlertsSettings();
    audio = _RecordingAudio();
    lookups = [];
  });

  test('follows, raids and subscriptions share one queue', () {
    fakeAsync((async) {
      final runtime = create();
      runtime.handle(_follow('follower'));
      runtime.handle(_raid('raider', viewers: 3));
      runtime.handle(_subscription('subscriber'));
      async.flushMicrotasks();

      expect(runtime.stage, isA<FollowStageAlert>());
      expect(audio.played, ['assets/follow_sound.mp3']);

      async.elapse(const Duration(seconds: 20));
      expect(runtime.stage, isA<RaidStageAlert>());
      expect((runtime.stage! as RaidStageAlert).event.userName, 'raider');
      expect(audio.played.last, 'assets/raid/raid_003.wav');

      async.elapse(const Duration(seconds: 20));
      expect(runtime.stage, isA<SubscriptionStageAlert>());

      async.elapse(const Duration(seconds: 20));
      expect(runtime.stage, isNull);
      runtime.dispose();
    });
  });

  test('hold time extends the pixel alert lifetime', () {
    fakeAsync((async) {
      alerts = alerts.copyWith(follow: alerts.follow.copyWith(holdSeconds: 15));
      final runtime = create();
      runtime.handle(_follow('follower'));
      async.flushMicrotasks();

      expect(runtime.stage?.hold, const Duration(seconds: 15));
      async.elapse(const Duration(seconds: 24));
      expect(runtime.stage, isNotNull);
      async.elapse(const Duration(seconds: 1));
      expect(runtime.stage, isNull);
      runtime.dispose();
    });
  });

  test('small raids below the minimum are ignored', () {
    fakeAsync((async) {
      alerts = alerts.copyWith(raid: alerts.raid.copyWith(minViewers: 5));
      final runtime = create();
      runtime.handle(_raid('small', viewers: 4));
      async.flushMicrotasks();
      expect(runtime.stage, isNull);

      runtime.handle(_raid('big', viewers: 5));
      async.flushMicrotasks();
      expect(runtime.stage, isA<RaidStageAlert>());
      runtime.dispose();
    });
  });

  test('sound choice and volume follow the settings', () {
    fakeAsync((async) {
      alerts = alerts.copyWith(
        follow: alerts.follow.copyWith(
          sound: FollowSound.classic,
          volumePercent: 40,
        ),
        raid: alerts.raid.copyWith(sound: RaidSound.none),
        subscriptions: alerts.subscriptions.copyWith(
          sound: SubscriptionSound.classic,
        ),
      );
      final runtime = create();
      runtime.handle(_follow('follower'));
      runtime.handle(_raid('raider', viewers: 2));
      runtime.handle(_subscription('subscriber'));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 60));

      expect(audio.played, ['assets/follow_classic.mp3', 'assets/sub.mp3']);
      expect(audio.volumes.first, 40);
      runtime.dispose();
    });
  });

  test('alerts disabled while waiting in the queue are skipped', () {
    fakeAsync((async) {
      final runtime = create();
      runtime.handle(_follow('follower'));
      runtime.handle(_subscription('subscriber'));
      async.flushMicrotasks();

      alerts = alerts.copyWith(
        subscriptions: const SubscriptionAlertSettings(
          subscribe: false,
          resubscribe: false,
          gift: false,
        ),
      );
      async.elapse(const Duration(seconds: 20));

      expect(runtime.stage, isNull);
      expect(lookups, ['follower']);
      runtime.dispose();
    });
  });

  test('subscription avatars can be turned off', () {
    fakeAsync((async) {
      alerts = alerts.copyWith(
        subscriptions: alerts.subscriptions.copyWith(showAvatar: false),
      );
      final runtime = create();
      runtime.handle(_subscription('subscriber'));
      async.flushMicrotasks();

      final alert = runtime.stage! as SubscriptionStageAlert;
      expect(alert.event.userName, 'subscriber');
      expect(alert.event.avatar, isNull);
      runtime.dispose();
    });
  });

  test('reward cards disappear after their duration', () {
    fakeAsync((async) {
      alerts = alerts.copyWith(
        rewardCard: const RewardCardSettings(seconds: 5),
      );
      final runtime = create();
      runtime.handle(_redemption('redemption-1'));
      async.flushMicrotasks();
      expect(runtime.rewardCards.single.id, 'redemption-1');
      expect(
        runtime.rewardCards.single.avatar,
        'https://example.test/viewer.png',
      );

      async.elapse(const Duration(seconds: 5));
      expect(runtime.rewardCards, isEmpty);

      alerts = alerts.copyWith(
        rewardCard: const RewardCardSettings(enabled: false),
      );
      runtime.handle(_redemption('redemption-2'));
      async.flushMicrotasks();
      expect(runtime.rewardCards, isEmpty);
      runtime.dispose();
    });
  });

  test('disposal cancels pending alerts and timers', () {
    fakeAsync((async) {
      final runtime = create();
      runtime.handle(_follow('follower'));
      runtime.handle(_follow('second'));
      async.flushMicrotasks();
      runtime.dispose();

      expect(async.pendingTimers, isEmpty);
      async.elapse(const Duration(minutes: 1));
      expect(lookups, ['follower']);
    });
  });
}

UserInfo _user(String id) => UserInfo(id: id, login: id, name: id);

FollowEvent _follow(String id) => FollowEvent(user: _user(id));

RaidEvent _raid(String id, {required int viewers}) =>
    RaidEvent(from: _user(id), viewers: viewers);

SubscriptionEvent _subscription(String id) => SubscriptionEvent(
  subscription: const WsSubscription(
    type: SubscriptionEventType.subscribe,
    tier: 1,
  ),
  user: _user(id),
);

RedemptionEvent _redemption(String id) => RedemptionEvent(
  id: id,
  rewardId: 'reward',
  rewardTitle: 'Reward',
  cost: 100,
  user: _user('viewer'),
);

class _RecordingAudio implements AlertAudio {
  final played = <String>[];
  final volumes = <int>[];

  @override
  Future<void> play(String asset, {int volumePercent = 100}) async {
    played.add(asset);
    volumes.add(volumePercent);
  }
}
