import 'dart:async';
import 'package:obssource/di/app_service_locator.dart';
import 'package:obssource/tts/tts_controller.dart';
import 'package:obssource/tts/tts_twitch.dart';
import 'dart:collection';

import 'package:animated_reorderable_list/animated_reorderable_list.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:obssource/alerts/user_alert_widget.dart';
import 'package:obssource/avatar_widget.dart';
import 'package:obssource/config/obs_config.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/data/events.dart';
import 'package:obssource/di/service_locator.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/follow/follow_widget.dart';
import 'package:obssource/generated/assets.dart';
import 'package:obssource/music/music_player_visuals.dart';
import 'package:obssource/music/music_queue_overlay.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/obs_audio.dart';
import 'package:obssource/pixels/pixel_rain_animator.dart';
import 'package:obssource/pixels/pixel_rain_avatar.dart';
import 'package:obssource/raid/raid_audio.dart';
import 'package:obssource/raid/raid_widget.dart';
import 'package:obssource/secrets.dart';
import 'package:obssource/settings/overlay_settings_dialog.dart';
import 'package:obssource/span_util.dart';
import 'package:obssource/subs/subscription_text.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/ws_event.dart';
import 'package:obssource/twitch/ws_manager.dart';
import 'package:obssource/twitch/ws_subscription.dart';

class LoggedWidget extends StatefulWidget {
  final ServiceLocator locator;
  final Future<img.Image?> Function(String url)? avatarLoader;
  final Future<UserDto?> Function(String id)? userLoader;
  final TwitchRewardCatalog? rewardCatalog;

  const LoggedWidget({
    super.key,
    required this.locator,
    this.avatarLoader,
    this.userLoader,
    this.rewardCatalog,
  });

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<LoggedWidget> {
  static const _followDuration = Duration(seconds: 20);
  static const _raidDuration = Duration(seconds: 20);
  static const _subscriptionDuration = Duration(seconds: 20);
  static const _rewardDuration = Duration(milliseconds: 7500);

  StreamSubscription<WsMessage>? _eventsSubscription;
  StreamSubscription<WsStateEvent>? _stateSubscription;
  StreamSubscription<Config>? _configSubscription;
  StreamSubscription<void>? _playerSettingsSubscription;
  late Timer _rewardCleanupTimer;
  late Settings _settings;
  late ObsConfig _obsConfig;
  late WsState _wsState;
  late AvatarPixelRenderer _alertRenderer;
  late int _alertAvatarResolution;
  MusicRequests? _musicRequests;
  final _musicOverlayController = MusicQueueOverlayController();
  bool _overlayControlsHovered = false;

  final _rewards = <UserRedeemedEvent>[];
  final _receivedEventIds = <String>{};
  final _follows = <UserFollowEvent>{};
  final _raids = <UserRaidEvent>{};
  UserSubscriptionEvent? _currentSubscription;
  final _subscriptionQueue = Queue<WsMessageEvent>();
  bool _processingSubscriptions = false;
  final _users = <String, UserDto>{};

  @override
  void initState() {
    super.initState();

    _settings = widget.locator.provide();
    _playerSettingsSubscription = _settings.playerPresentationChanges.listen((
      _,
    ) {
      if (mounted) setState(() {});
    });
    _obsConfig = widget.locator.provide();
    _alertRenderer = _readAlertRenderer();
    _alertAvatarResolution = _readAlertAvatarResolution();
    try {
      _musicRequests = widget.locator.provide<MusicRequests>();
    } catch (_) {
      // Older test and debug locators may not provide music requests yet.
    }
    _configSubscription = _obsConfig.config.changes.listen(_handleConfig);

    final ws = widget.locator.provide<WebSocketManager>();
    _wsState = ws.currentState;
    _eventsSubscription = ws.messages.listen(_handleWebsocketMessage);
    _stateSubscription = ws.state.listen(_handleWebsocketState);
    _rewardCleanupTimer = Timer.periodic(
      const Duration(seconds: 1),
      _handleTimerTick,
    );
  }

  @override
  void dispose() {
    _subscriptionQueue.clear();
    _rewardCleanupTimer.cancel();
    _eventsSubscription?.cancel();
    _stateSubscription?.cancel();
    _configSubscription?.cancel();
    _playerSettingsSubscription?.cancel();
    _musicOverlayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            _createConfigInfo(context),
            ..._follows.map(
              (follow) => FollowWidget(
                event: follow,
                constraints: constraints,
                key: ValueKey(follow),
                renderer: _alertRenderer,
                avatarResolution: _alertAvatarResolution,
              ),
            ),
            ..._raids.map(
              (raid) => RaidWidget(
                key: ValueKey(raid),
                event: raid,
                constraints: constraints,
                renderer: _alertRenderer,
                avatarResolution: _alertAvatarResolution,
              ),
            ),
            _createRewardsWidget(),
            if (_currentSubscription case final subscription?)
              UserAlertWidget(
                key: ValueKey(subscription),
                userName:
                    subscription.subscription.isAnonymous
                        ? context.localizations.subscription_anonymous
                        : subscription.userName!,
                description: subscription.subscription.description(
                  context.localizations,
                ),
                avatar: subscription.avatar,
                constraints: constraints,
                renderer: _alertRenderer,
                avatarResolution: _alertAvatarResolution,
              ),
            if (_musicRequests case final musicRequests?)
              Positioned(
                right: 24,
                bottom: 24,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth:
                        (constraints.maxWidth - 48)
                            .clamp(82.0, 520.0)
                            .toDouble(),
                  ),
                  child: MusicQueueOverlay(
                    requests: musicRequests,
                    controller: _musicOverlayController,
                    collapseDelay: Duration(
                      seconds: _settings.playerCollapseSeconds,
                    ),
                    alwaysExpanded: _settings.playerAlwaysExpanded,
                  ),
                ),
              ),
            _createOverlayControls(context),
          ],
        );
      },
    );
  }

  Widget _createOverlayControls(BuildContext context) {
    return Positioned(
      top: 6,
      right: 16,
      child: MouseRegion(
        opaque: true,
        onEnter: (_) => setState(() => _overlayControlsHovered = true),
        onExit: (_) => setState(() => _overlayControlsHovered = false),
        child: SizedBox(
          width: 56,
          height: 40,
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              Positioned(
                left: 0,
                child: IgnorePointer(
                  ignoring: !_overlayControlsHovered,
                  child: AnimatedOpacity(
                    key: const ValueKey('overlay_settings_button_reveal'),
                    opacity: _overlayControlsHovered ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: NeonMusicIconButton(
                      key: const ValueKey('overlay_settings_button'),
                      icon: Icons.settings_rounded,
                      onPressed: _showOverlaySettings,
                    ),
                  ),
                ),
              ),
              Container(
                key: const ValueKey('connection_indicator'),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color:
                      _wsState == WsState.connected
                          ? const Color(0xFF51FD0B)
                          : const Color(0xFFCD0017),
                  boxShadow: [
                    BoxShadow(
                      color: (_wsState == WsState.connected
                              ? const Color(0xFF51FD0B)
                              : const Color(0xFFCD0017))
                          .withValues(alpha: 0.55),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOverlaySettings() {
    final appLocator = widget.locator;
    final rewardCatalog =
        widget.rewardCatalog ??
        TwitchApiRewardCatalog(
          api: TwitchApi(settings: _settings, clientSecret: twitchClientSecret),
          settings: _settings,
        );
    showDialog<void>(
      context: context,
      barrierColor: MusicPlayerPalette.voidBlack.withValues(alpha: 0.82),
      builder:
          (_) => OverlaySettingsDialog(
            settings: _settings,
            rewardCatalog: rewardCatalog,
            ttsController:
                appLocator is AppServiceLocator
                    ? appLocator.provide<TtsController>()
                    : null,
            ttsRewardCatalog:
                appLocator is AppServiceLocator
                    ? appLocator.provide<TtsRewardCatalog>()
                    : null,
          ),
    );
  }

  Widget _createConfigInfo(BuildContext context) {
    return StreamBuilder<Config>(
      stream: _obsConfig.config.changes,
      initialData: _obsConfig.config.current,
      builder: (context, snapshot) {
        if (snapshot.requireData.valid) {
          return const SizedBox.shrink();
        }

        return Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            key: const ValueKey('invalid_obs_config_indicator'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.red,
            ),
            child: Text(
              context.localizations.config_invalid,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleWebsocketState(WsStateEvent event) {
    if (!mounted) return;

    setState(() {
      _wsState = event.current;
    });
  }

  AvatarPixelRenderer _readAlertRenderer() {
    final value = _obsConfig.getString(
      'alert_animation_renderer',
      fallback: 'optimized',
    );

    return value == 'legacy'
        ? AvatarPixelRenderer.legacyCanvas
        : AvatarPixelRenderer.rawAtlas;
  }

  int _readAlertAvatarResolution() {
    final resolution = _obsConfig.getInt(
      'alert_avatar_resolution',
      fallback: 48,
    );

    return resolution > 0 ? resolution : 48;
  }

  void _handleConfig(Config _) {
    final renderer = _readAlertRenderer();
    final avatarResolution = _readAlertAvatarResolution();
    if (!mounted ||
        (renderer == _alertRenderer &&
            avatarResolution == _alertAvatarResolution)) {
      return;
    }

    setState(() {
      _alertRenderer = renderer;
      _alertAvatarResolution = avatarResolution;
    });
  }

  Widget _createRewardsWidget() {
    return AnimatedListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      items: _rewards,
      itemBuilder: (context, index) {
        final reward = _rewards[index];
        return _RewardWidget(event: reward, key: ValueKey(reward.id));
      },
      enterTransition: [SlideInLeft()],
      exitTransition: [SlideInLeft()],
      isSameItem: (a, b) => a.id == b.id,
    );
  }

  Future<void> _handleWebsocketMessage(WsMessage message) async {
    final event = message.payload.event;
    final eventId = event?.id ?? message.messageId;

    if (eventId != null && !_receivedEventIds.add(eventId)) {
      return;
    }

    switch (message.payload.subscription?.type) {
      case 'channel.subscribe':
      case 'channel.subscription.message':
      case 'channel.subscription.gift':
        if (event?.subscription != null &&
            _obsConfig.getBool('subscriptions', fallback: true)) {
          await _handleUserSubscription(event!);
        }
        return;
      case 'channel.raid':
        final raid = event?.raid;
        if (raid != null && _obsConfig.getBool('raids', fallback: true)) {
          await _handleUserRaid(raid);
        }
        return;

      case 'channel.follow':
        if (event != null && _obsConfig.getBool('followers')) {
          await _handleUserFollow(event);
        }
        return;

      case 'channel.channel_points_custom_reward_redemption.add':
        await _handleRewardEvent(event);
        return;

      case 'channel.chat.message':
        if (event?.messageText?.trim().toLowerCase() == '!music') {
          _musicOverlayController.expand();
        }
        return;
    }
  }

  Future<void> _handleRewardEvent(WsMessageEvent? event) async {
    final eventId = event?.id;
    final userId = event?.user?.id;
    final userName = event?.user?.name;
    final reward = event?.reward;

    if (eventId == null ||
        userId == null ||
        userName == null ||
        reward == null) {
      return;
    }

    final user = await _getUser(userId);
    if (!mounted) return;

    setState(() {
      _rewards.add(
        UserRedeemedEvent(
          eventId,
          time: DateTime.now(),
          user: userName,
          reward: reward.title,
          avatar: user?.profileImageUrl,
          cost: reward.cost,
        ),
      );
    });
  }

  Future<void> _handleUserSubscription(WsMessageEvent event) async {
    _subscriptionQueue.addLast(event);
    if (_processingSubscriptions) return;
    _processingSubscriptions = true;
    try {
      while (mounted && _subscriptionQueue.isNotEmpty) {
        final next = _subscriptionQueue.removeFirst();
        try {
          await _showUserSubscription(next);
        } catch (error) {
          debugPrint('Could not show subscription alert: $error');
        }
      }
    } finally {
      _processingSubscriptions = false;
    }
  }

  Future<void> _showUserSubscription(WsMessageEvent event) async {
    final subscription = event.subscription!;
    final name = event.user?.name;
    if (!subscription.isAnonymous && (name == null || name.isEmpty)) return;

    UserDto? user;
    if (!subscription.isAnonymous) {
      try {
        user = await _getUser(event.user?.id);
      } catch (_) {
        // A failed profile lookup must not suppress the notification.
      }
    }

    if (!mounted) return;

    final avatar = await _loadAlertAvatar(user);

    if (!mounted) return;

    final alert = UserSubscriptionEvent(
      userName: name,
      subscription: subscription,
      avatar: avatar,
    );

    setState(() {
      _currentSubscription = alert;
    });

    unawaited(_playSubscriptionSound(subscription.type));

    await Future<void>.delayed(_subscriptionDuration);

    if (!mounted) return;

    setState(() {
      _currentSubscription = null;
    });
  }

  Future<void> _playSubscriptionSound(SubscriptionEventType type) async {
    try {
      final asset = switch (type) {
        SubscriptionEventType.subscribe =>
          Assets.subscriptionsSubscriptionPurchase,
        SubscriptionEventType.message =>
          Assets.subscriptionsSubscriptionRenewal,
        SubscriptionEventType.gift => Assets.subscriptionsSubscriptionGift,
      };
      final sound = await ObsAudio.loadAsset(asset);
      if (mounted) await ObsAudio.play(sound);
    } catch (error) {
      debugPrint('Could not play subscription audio: $error');
    }
  }

  Future<void> _handleUserRaid(WsRaid event) async {
    final broadcasterId = _settings.twitchAuth?.broadcasterId;
    if (broadcasterId != null && event.toBroadcasterId != broadcasterId) return;

    UserDto? user;
    try {
      user = await _getUser(event.fromBroadcaster.id);
    } catch (_) {
      // A profile lookup failure must not suppress the raid notification.
    }
    if (!mounted) return;
    final avatar = await _loadAlertAvatar(user);
    if (!mounted) return;

    final raid = UserRaidEvent(
      userName: event.fromBroadcaster.name,
      viewers: event.viewers,
      avatar: avatar,
    );
    setState(() => _raids.add(raid));
    unawaited(_playRaidSound(event.viewers));

    await Future<void>.delayed(_raidDuration);
    if (!mounted) return;
    setState(() => _raids.remove(raid));
  }

  Future<void> _playRaidSound(int viewers) async {
    try {
      final sound = await ObsAudio.loadAsset(
        RaidAudio.assetForViewers(viewers),
      );
      if (mounted) await ObsAudio.play(sound);
    } catch (error) {
      debugPrint('Could not play raid audio: $error');
    }
  }

  Future<img.Image?> _loadAlertAvatar(UserDto? user) async {
    final url = user?.profileImageUrl;
    if (url == null) return null;
    try {
      final loader = widget.avatarLoader ?? RainyAvatar.loadImageFromUrl;
      return await loader(url);
    } catch (_) {
      // Alerts can still run without an avatar.
      return null;
    }
  }

  Future<void> _handleUserFollow(WsMessageEvent event) async {
    final userName = event.user?.name;
    if (userName == null) return;

    final user = await _getUser(event.user?.id);
    await _showUserFollow(userName: userName, user: user);
  }

  Future<void> _showUserFollow({
    required String userName,
    required UserDto? user,
  }) async {
    if (!mounted) return;

    final avatar = await _loadAlertAvatar(user);

    if (!mounted) return;

    final now = DateTime.now();
    final follow = UserFollowEvent(
      time: now,
      end: now.add(_followDuration),
      userName: userName,
      user: user,
      avatar: avatar,
    );

    setState(() {
      _follows.add(follow);
    });

    ObsAudio.loadAsset(Assets.assetsFollowSound).then(ObsAudio.play);

    await Future<void>.delayed(_followDuration);
    if (!mounted) return;

    setState(() {
      _follows.remove(follow);
    });
  }

  Future<UserDto?> _getUser(String? userId) async {
    if (userId == null) return null;

    final cached = _users[userId];
    if (cached != null) return cached;

    final loader = widget.userLoader;
    final user =
        loader != null
            ? await loader(userId)
            : await TwitchApi(
              settings: _settings,
              clientSecret: twitchClientSecret,
            ).getUser(id: userId);

    if (user != null) {
      _users[userId] = user;
    }

    return user;
  }

  void _handleTimerTick(Timer _) {
    final sizeBefore = _rewards.length;
    _rewards.removeWhere(
      (event) => DateTime.now().difference(event.time) > _rewardDuration,
    );

    if (mounted && _rewards.length != sizeBefore) {
      setState(() {});
    }
  }
}

class _RewardWidget extends StatelessWidget {
  final UserRedeemedEvent event;

  const _RewardWidget({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final cost = NumberFormat('###,###').format(event.cost);
    const currencyPlaceholder = '{:currency_icon}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 448),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: const Color(0xFF3C3C3C).withValues(alpha: 0.9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(url: event.avatar, size: 48),
            const Gap(16),
            Flexible(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  children: SpanUtil.createSpansAdvanced(
                    context.localizations.user_redeemed_reward_title(
                      event.user,
                      event.reward,
                      currencyPlaceholder,
                      cost,
                    ),
                    [event.user, event.reward, currencyPlaceholder],
                    (text) {
                      if (text == currencyPlaceholder) {
                        return WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Image.asset(
                            Assets.assetsIcTwitchChannelPosints32dp,
                            width: 18,
                            height: 18,
                          ),
                        );
                      }
                      return TextSpan(
                        text: text,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
              ),
            ),
            const Gap(8),
          ],
        ),
      ),
    );
  }
}
