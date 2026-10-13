import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:obssource/config/alerts_settings.dart';
import 'package:obssource/config/kills_settings.dart';
import 'package:obssource/config/reward_effects_settings.dart';
import 'package:obssource/data/events.dart';
import 'package:obssource/effects/alert_audio.dart';
import 'package:obssource/effects/chat_card.dart';
import 'package:obssource/effects/crt_off.dart';
import 'package:obssource/effects/flashbang.dart';
import 'package:obssource/effects/pause_effect.dart';
import 'package:obssource/effects/screen_attack_game.dart';
import 'package:obssource/events/alert_event.dart';
import 'package:obssource/generated/assets.dart';
import 'package:obssource/pixels/pixel_rain_avatar.dart';
import 'package:obssource/raid/classic_raid_widget.dart';
import 'package:obssource/raid/raid_audio.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/ws_subscription.dart';

typedef UserLoader = Future<UserDto?> Function(String id);
typedef AvatarLoader = Future<img.Image?> Function(String url);

/// Alert in the center of the overlay. Only one is shown at a time.
sealed class StageAlert {
  /// Hold time of the assembled pixel text, or the balloon flight time.
  final Duration hold;
  final _finished = Completer<void>();

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
  final RaidStyle style;

  /// Raiding channel; built from the event when the profile is unavailable.
  final UserDto from;
  final int maxAnimals;

  RaidStageAlert({
    required this.event,
    required this.style,
    required this.from,
    required this.maxAnimals,
    required super.hold,
  });
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

  /// Margin after the expected end of a self-timed effect.
  static const _selfTimedMargin = Duration(seconds: 10);

  final AlertsSettings Function() _alerts;
  final RewardEffectsSettings Function() _rewardEffects;
  final KillsSettings Function() _kills;
  final UserLoader _loadUser;
  final AvatarLoader _loadAvatar;
  final Future<img.Image?> Function() _loadPauseImage;
  final AlertAudio _audio;
  final Random _random;

  /// Keeps the sticker layer mounted even without bound rewards (preview).
  final bool keepScreenAttackMounted;

  final screenAttack = ScreenAttackController();

  EffectRuntime({
    required AlertsSettings Function() alerts,
    RewardEffectsSettings Function()? rewardEffects,
    KillsSettings Function()? kills,
    required UserLoader loadUser,
    required AvatarLoader loadAvatar,
    Future<img.Image?> Function()? loadPauseImage,
    AlertAudio audio = const ObsAlertAudio(),
    Random? random,
    this.keepScreenAttackMounted = false,
  }) : _alerts = alerts,
       _rewardEffects = rewardEffects ?? (() => const RewardEffectsSettings()),
       _kills = kills ?? (() => const KillsSettings()),
       _loadUser = loadUser,
       _loadAvatar = loadAvatar,
       _loadPauseImage =
           loadPauseImage ??
           (() => RainyAvatar.loadImageFromAssets(Assets.assetsImgPause1)),
       _audio = audio,
       _random = random ?? Random();

  final _users = <String, UserDto>{};
  final _timers = <Timer>{};
  bool _disposed = false;

  final _stageQueue = Queue<AlertEvent>();
  bool _stageBusy = false;
  StageAlert? _stage;

  final _rewardCards = <UserRedeemedEvent>[];
  final _chatCards = <ChatCard>[];
  final _chatters = <String>{};

  final _flashbangQueue = Queue<Flashbang>();
  bool _flashbangBusy = false;
  Flashbang? _flashbang;

  CrtEffect? _crt;
  int _crtSessions = 0;
  PauseEffect? _pause;

  final _killQueue = Queue<KillInfo>();
  bool _killBusy = false;
  KillInfo? _kill;

  StageAlert? get stage => _stage;
  List<UserRedeemedEvent> get rewardCards => List.unmodifiable(_rewardCards);
  List<ChatCard> get chatCards => List.unmodifiable(_chatCards);
  Flashbang? get flashbang => _flashbang;
  CrtEffect? get crt => _crt;
  PauseEffect? get pause => _pause;
  KillInfo? get kill => _kill;

  /// Nothing is shown or waiting, except a pause, which stays until removed.
  bool get idle =>
      !_stageBusy &&
      _stage == null &&
      _stageQueue.isEmpty &&
      _rewardCards.isEmpty &&
      _chatCards.isEmpty &&
      _flashbang == null &&
      _flashbangQueue.isEmpty &&
      _crt == null &&
      _kill == null &&
      _killQueue.isEmpty;

  bool get screenAttackMounted {
    if (keepScreenAttackMounted) return true;
    final effects = _rewardEffects();
    return effects.binding(RewardAction.sticker).isActive ||
        effects.binding(RewardAction.crosshair).isActive;
  }

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
      case ChatEvent():
        _handleChat(event);
      case KillEvent(:final kill):
        _killQueue.addLast(kill);
        unawaited(_runKills());
    }
  }

  /// Ends a self-timed stage alert such as the classic raid.
  void completeStage(StageAlert alert) {
    if (!alert._finished.isCompleted) alert._finished.complete();
  }

  /// Plays the bang in sync with the grenade animation.
  void playFlashbangSound() {
    final binding = _rewardEffects().binding(RewardAction.flashbang);
    unawaited(
      _audio.play(
        Assets.assetsWavFlashbang,
        volumePercent: binding.volumePercent,
      ),
    );
  }

  /// Stops everything immediately; pending alerts are dropped.
  @override
  void dispose() {
    _disposed = true;
    _stageQueue.clear();
    _flashbangQueue.clear();
    _killQueue.clear();
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    unawaited(screenAttack.close());
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
        final pixel = settings.style == FollowStyle.pixel;
        final avatar = pixel ? await _avatar(profile) : null;
        if (_disposed) return;
        final hold = Duration(seconds: settings.holdSeconds);
        final lifetime = pixel ? hold + pixelAlertExtra : hold;
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
        final lifetime = switch (settings.style) {
          RaidStyle.pixel => hold + pixelAlertExtra,
          RaidStyle.classic =>
            ClassicRaidWidget.durationFor(min(viewers, settings.maxAnimals)) +
                _selfTimedMargin,
        };
        await _present(
          RaidStageAlert(
            event: UserRaidEvent(
              userName: from.name,
              viewers: viewers,
              avatar: avatar,
            ),
            style: settings.style,
            from:
                profile ??
                UserDto(
                  id: from.id,
                  login: from.login,
                  displayName: from.name,
                  profileImageUrl: null,
                ),
            maxAnimals: settings.maxAnimals,
            hold: hold,
          ),
          lifetime: lifetime,
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
    await _wait(lifetime, alert._finished.future);
    if (identical(_stage, alert)) {
      _stage = null;
      _changed();
    }
  }

  void _handleRedemption(RedemptionEvent event) {
    final card = _alerts().rewardCard;
    if (card.enabled) unawaited(_showRewardCard(event, card));

    final effects = _rewardEffects();
    for (final action in effects.actionsFor(event.rewardId)) {
      switch (action) {
        case RewardAction.flashbang:
          final pro = _random.nextInt(100) < effects.flashbangProChancePercent;
          _flashbangQueue.addLast(Flashbang(id: event.id, pro: pro));
          unawaited(_runFlashbangs());
        case RewardAction.crt:
          unawaited(_showCrt(event, effects));
        case RewardAction.pause:
          unawaited(_showPause(event.input, effects));
        case RewardAction.sticker:
          screenAttack.sticker();
        case RewardAction.crosshair:
          screenAttack.aim(Duration(seconds: effects.crosshairSeconds));
      }
    }
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
    await _wait(Duration(seconds: settings.seconds));
    _rewardCards.remove(card);
    _changed();
  }

  Future<void> _runFlashbangs() async {
    if (_flashbangBusy) return;
    _flashbangBusy = true;
    try {
      while (!_disposed && _flashbangQueue.isNotEmpty) {
        _flashbang = _flashbangQueue.removeFirst();
        _changed();
        await _wait(Flashbang.duration);
        _flashbang = null;
        _changed();
      }
    } finally {
      _flashbangBusy = false;
    }
  }

  Future<void> _showCrt(
    RedemptionEvent event,
    RewardEffectsSettings effects,
  ) async {
    final binding = effects.binding(RewardAction.crt);
    unawaited(
      _audio.play(
        Assets.assetsTvOffSound,
        volumePercent: binding.volumePercent,
      ),
    );
    final profile = await _user(event.user.id);
    if (_disposed) return;

    // A redemption during the effect extends it without replaying the
    // switch-off animation.
    final crt = CrtEffect(
      session: _crt?.session ?? ++_crtSessions,
      userName: event.user.name,
      avatarUrl: profile?.profileImageUrl,
    );
    _crt = crt;
    _changed();
    await _wait(Duration(seconds: effects.crtSeconds));
    if (identical(_crt, crt)) {
      _crt = null;
      _changed();
    }
  }

  Future<void> _showPause(String? input, RewardEffectsSettings effects) async {
    final request = PauseRequest.parse(
      input,
      max: Duration(minutes: effects.pauseMaxMinutes),
    );
    if (request == null) return;
    if (request.clears) {
      _pause = null;
      _changed();
      return;
    }

    final img.Image? image;
    try {
      image = await _loadPauseImage();
    } catch (error) {
      debugPrint('Could not load the pause picture: $error');
      return;
    }
    if (_disposed || image == null) return;

    // The picture stays until a new pause replaces it or `0` removes it.
    _pause = PauseEffect(
      image: image,
      duration: request.duration,
      message: request.message,
    );
    _changed();
  }

  void _handleChat(ChatEvent event) {
    final chatter = event.chatter;
    if (chatter == null) return;

    final first = _chatters.add(chatter.id);
    final settings = _alerts().chat;
    final bool firstMessage;
    if (event.highlighted && settings.highlighted) {
      firstMessage = false;
    } else if (first && settings.firstMessage) {
      firstMessage = true;
    } else {
      return;
    }
    unawaited(_showChatCard(event, firstMessage, settings));
  }

  Future<void> _showChatCard(
    ChatEvent event,
    bool firstMessage,
    ChatAlertSettings settings,
  ) async {
    final chatter = event.chatter!;
    final profile = await _user(chatter.id);
    if (_disposed) return;

    final duration = Duration(seconds: settings.seconds);
    final card = ChatCard(
      id: event.messageId,
      firstMessage: firstMessage,
      userName: chatter.name,
      avatarUrl: profile?.profileImageUrl,
      fragments: event.message.fragments,
      animal: ChatAnimal.values[_random.nextInt(ChatAnimal.values.length)],
      duration: duration,
    );
    _chatCards.add(card);
    _changed();
    await _wait(duration);
    _chatCards.remove(card);
    _changed();
  }

  Future<void> _runKills() async {
    if (_killBusy) return;
    _killBusy = true;
    try {
      while (!_disposed && _killQueue.isNotEmpty) {
        _kill = _killQueue.removeFirst();
        _changed();
        await _wait(Duration(seconds: _kills().seconds));
        _kill = null;
        _changed();
      }
    } finally {
      _killBusy = false;
    }
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

  /// Waits for [duration] or until [until] completes; canceled together with
  /// the runtime.
  Future<void> _wait(Duration duration, [Future<void>? until]) {
    final completer = Completer<void>();
    late final Timer timer;
    void finish() {
      if (completer.isCompleted) return;
      timer.cancel();
      _timers.remove(timer);
      completer.complete();
    }

    timer = Timer(duration, finish);
    _timers.add(timer);
    until?.then((_) {
      if (!_disposed) finish();
    });
    return completer.future;
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }
}
