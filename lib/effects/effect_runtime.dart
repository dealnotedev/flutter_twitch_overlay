import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:obssource/config/alerts_settings.dart';
import 'package:obssource/data/events.dart';
import 'package:obssource/effects/alert_audio.dart';
import 'package:obssource/events/alert_event.dart';
import 'package:obssource/generated/assets.dart';
import 'package:obssource/raid/raid_audio.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/ws_subscription.dart';

typedef UserLoader = Future<UserDto?> Function(String id);
typedef AvatarLoader = Future<img.Image?> Function(String url);

/// Alert in the center of the overlay. Only one is shown at a time.
sealed class StageAlert {
  /// Hold time of the assembled pixel text, or the balloon flight time.
  final Duration hold;

  StageAlert({required this.hold});
}

final class FollowStageAlert extends StageAlert {
  final UserFollowEvent event;
  final FollowStyle style;

  FollowStageAlert({
    required this.event,
    required this.style,
    required super.hold,
  });
}

final class RaidStageAlert extends StageAlert {
  final UserRaidEvent event;

  RaidStageAlert({required this.event, required super.hold});
}

final class SubscriptionStageAlert extends StageAlert {
  final UserSubscriptionEvent event;

  SubscriptionStageAlert({required this.event, required super.hold});
}

/// Turns [AlertEvent]s into what the overlay shows and plays.
///
/// The same runtime drives the live overlay and the settings preview; only
/// the settings source, loaders and audio differ.
class EffectRuntime extends ChangeNotifier {
  /// Time a pixel alert needs besides its hold: fade-in, the heart and a
  /// short pause before the next alert.
  static const pixelAlertExtra = Duration(seconds: 10);

  final AlertsSettings Function() _alerts;
  final UserLoader _loadUser;
  final AvatarLoader _loadAvatar;
  final AlertAudio _audio;

  EffectRuntime({
    required AlertsSettings Function() alerts,
    required UserLoader loadUser,
    required AvatarLoader loadAvatar,
    AlertAudio audio = const ObsAlertAudio(),
  }) : _alerts = alerts,
       _loadUser = loadUser,
       _loadAvatar = loadAvatar,
       _audio = audio;

  final _users = <String, UserDto>{};
  final _timers = <Timer>{};
  bool _disposed = false;

  final _stageQueue = Queue<AlertEvent>();
  bool _stageBusy = false;
  StageAlert? _stage;

  final _rewardCards = <UserRedeemedEvent>[];

  StageAlert? get stage => _stage;

  List<UserRedeemedEvent> get rewardCards => List.unmodifiable(_rewardCards);

  void handle(AlertEvent event) {
    if (_disposed) return;
    switch (event) {
      case FollowEvent() || RaidEvent() || SubscriptionEvent():
        if (_stageEnabled(event)) {
          _stageQueue.addLast(event);
          unawaited(_runStage());
        }
      case RedemptionEvent():
        _handleRedemption(event);
      case ChatEvent() || KillEvent():
        break;
    }
  }

  /// Stops everything immediately; pending alerts are dropped.
  @override
  void dispose() {
    _disposed = true;
    _stageQueue.clear();
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    super.dispose();
  }

  bool _stageEnabled(AlertEvent event) {
    final alerts = _alerts();
    return switch (event) {
      FollowEvent() => alerts.follow.enabled,
      RaidEvent(:final viewers) =>
        alerts.raid.enabled && viewers >= alerts.raid.minViewers,
      SubscriptionEvent(:final subscription) => alerts.subscriptions.enabledFor(
        subscription.type,
      ),
      _ => false,
    };
  }

  Future<void> _runStage() async {
    if (_stageBusy) return;
    _stageBusy = true;
    try {
      while (!_disposed && _stageQueue.isNotEmpty) {
        final event = _stageQueue.removeFirst();
        // Settings may have changed while the alert was waiting.
        if (!_stageEnabled(event)) continue;
        try {
          await _showStage(event);
        } catch (error) {
          debugPrint('Could not show alert: $error');
        }
      }
    } finally {
      _stageBusy = false;
    }
  }

  Future<void> _showStage(AlertEvent event) async {
    switch (event) {
      case FollowEvent(:final user):
        final settings = _alerts().follow;
        final profile = await _user(user.id);
        final avatar =
            settings.style == FollowStyle.pixel ? await _avatar(profile) : null;
        if (_disposed) return;
        final hold = Duration(seconds: settings.holdSeconds);
        final lifetime =
            settings.style == FollowStyle.pixel ? hold + pixelAlertExtra : hold;
        final now = DateTime.now();
        await _present(
          FollowStageAlert(
            event: UserFollowEvent(
              userName: user.name,
              user: profile,
              avatar: avatar,
              time: now,
              end: now.add(lifetime),
            ),
            style: settings.style,
            hold: hold,
          ),
          lifetime: lifetime,
          sound: followSound(settings.sound),
          volumePercent: settings.volumePercent,
        );

      case RaidEvent(:final from, :final viewers):
        final settings = _alerts().raid;
        final profile = await _user(from.id);
        final avatar = await _avatar(profile);
        if (_disposed) return;
        final hold = Duration(seconds: settings.holdSeconds);
        await _present(
          RaidStageAlert(
            event: UserRaidEvent(
              userName: from.name,
              viewers: viewers,
              avatar: avatar,
            ),
            hold: hold,
          ),
          lifetime: hold + pixelAlertExtra,
          sound: raidSound(settings.sound, viewers),
          volumePercent: settings.volumePercent,
        );

      case SubscriptionEvent(:final subscription, :final user):
        final settings = _alerts().subscriptions;
        final profile = user != null ? await _user(user.id) : null;
        final avatar = settings.showAvatar ? await _avatar(profile) : null;
        if (_disposed) return;
        final hold = Duration(seconds: settings.holdSeconds);
        await _present(
          SubscriptionStageAlert(
            event: UserSubscriptionEvent(
              userName: user?.name,
              subscription: subscription,
              avatar: avatar,
            ),
            hold: hold,
          ),
          lifetime: hold + pixelAlertExtra,
          sound: subscriptionSound(settings.sound, subscription.type),
          volumePercent: settings.volumePercent,
        );

      case RedemptionEvent() || ChatEvent() || KillEvent():
        break;
    }
  }

  Future<void> _present(
    StageAlert alert, {
    required Duration lifetime,
    required String? sound,
    required int volumePercent,
  }) async {
    _stage = alert;
    _changed();
    if (sound != null) {
      unawaited(_audio.play(sound, volumePercent: volumePercent));
    }
    await _sleep(lifetime);
    if (identical(_stage, alert)) {
      _stage = null;
      _changed();
    }
  }

  void _handleRedemption(RedemptionEvent event) {
    final card = _alerts().rewardCard;
    if (card.enabled) unawaited(_showRewardCard(event, card));
  }

  Future<void> _showRewardCard(
    RedemptionEvent event,
    RewardCardSettings settings,
  ) async {
    final profile = await _user(event.user.id);
    if (_disposed) return;
    final card = UserRedeemedEvent(
      event.id,
      time: DateTime.now(),
      user: event.user.name,
      reward: event.rewardTitle,
      avatar: profile?.profileImageUrl,
      cost: event.cost,
    );
    _rewardCards.add(card);
    _changed();
    await _sleep(Duration(seconds: settings.seconds));
    _rewardCards.remove(card);
    _changed();
  }

  static String? followSound(FollowSound sound) => switch (sound) {
    FollowSound.modern => Assets.assetsFollowSound,
    FollowSound.classic => Assets.assetsFollowClassic,
    FollowSound.none => null,
  };

  static String? raidSound(RaidSound sound, int viewers) => switch (sound) {
    RaidSound.voice => RaidAudio.assetForViewers(viewers),
    RaidSound.classic => Assets.assetsRaid,
    RaidSound.none => null,
  };

  static String? subscriptionSound(
    SubscriptionSound sound,
    SubscriptionEventType type,
  ) => switch (sound) {
    SubscriptionSound.distinct => switch (type) {
      SubscriptionEventType.subscribe =>
        Assets.subscriptionsSubscriptionPurchase,
      SubscriptionEventType.message => Assets.subscriptionsSubscriptionRenewal,
      SubscriptionEventType.gift => Assets.subscriptionsSubscriptionGift,
    },
    SubscriptionSound.classic => Assets.assetsSub,
    SubscriptionSound.none => null,
  };

  /// Profile of [id]; a failed lookup must not suppress the alert.
  Future<UserDto?> _user(String id) async {
    final cached = _users[id];
    if (cached != null) return cached;
    try {
      final user = await _loadUser(id);
      if (user != null) _users[id] = user;
      return user;
    } catch (error) {
      debugPrint('Could not load profile $id: $error');
      return null;
    }
  }

  /// Avatar pixels; alerts still run without them.
  Future<img.Image?> _avatar(UserDto? user) async {
    final url = user?.profileImageUrl;
    if (url == null) return null;
    try {
      return await _loadAvatar(url);
    } catch (error) {
      debugPrint('Could not load avatar: $error');
      return null;
    }
  }

  /// Delay that is canceled together with the runtime.
  Future<void> _sleep(Duration duration) {
    final completer = Completer<void>();
    late final Timer timer;
    timer = Timer(duration, () {
      _timers.remove(timer);
      completer.complete();
    });
    _timers.add(timer);
    return completer.future;
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }
}
