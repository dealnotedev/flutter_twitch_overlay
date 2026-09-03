import 'dart:async';

import 'package:animated_reorderable_list/animated_reorderable_list.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:obssource/avatar_widget.dart';
import 'package:obssource/config/obs_config.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/data/events.dart';
import 'package:obssource/di/service_locator.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/follow/follow_widget.dart';
import 'package:obssource/generated/assets.dart';
import 'package:obssource/music/music_queue_overlay.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/obs_audio.dart';
import 'package:obssource/pixels/pixel_rain_animator.dart';
import 'package:obssource/pixels/pixel_rain_avatar.dart';
import 'package:obssource/secrets.dart';
import 'package:obssource/span_util.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/ws_event.dart';
import 'package:obssource/twitch/ws_manager.dart';

class LoggedWidget extends StatefulWidget {
  final ServiceLocator locator;
  final Future<img.Image?> Function(String url)? avatarLoader;
  final Future<UserDto?> Function(String id)? userLoader;

  const LoggedWidget({
    super.key,
    required this.locator,
    this.avatarLoader,
    this.userLoader,
  });

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<LoggedWidget> {
  static const _followDuration = Duration(seconds: 20);
  static const _rewardDuration = Duration(milliseconds: 7500);

  StreamSubscription<WsMessage>? _eventsSubscription;
  StreamSubscription<WsStateEvent>? _stateSubscription;
  StreamSubscription<Config>? _configSubscription;
  late Timer _rewardCleanupTimer;
  late Settings _settings;
  late ObsConfig _obsConfig;
  late WsState _wsState;
  late AvatarPixelRenderer _followRenderer;
  late int _followAvatarResolution;
  MusicRequests? _musicRequests;

  final _rewards = <UserRedeemedEvent>[];
  final _receivedEventIds = <String>{};
  final _follows = <UserFollowEvent>{};
  final _users = <String, UserDto>{};

  @override
  void initState() {
    super.initState();

    _settings = widget.locator.provide();
    _obsConfig = widget.locator.provide();
    _followRenderer = _readFollowRenderer();
    _followAvatarResolution = _readFollowAvatarResolution();
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
    _rewardCleanupTimer.cancel();
    _eventsSubscription?.cancel();
    _stateSubscription?.cancel();
    _configSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            ..._follows.map(
              (follow) => FollowWidget(
                event: follow,
                constraints: constraints,
                key: ValueKey(follow),
                renderer: _followRenderer,
                avatarResolution: _followAvatarResolution,
              ),
            ),
            _createRewardsWidget(),
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
                  child: MusicQueueOverlay(requests: musicRequests),
                ),
              ),
            _createConnectionIndicator(),
          ],
        );
      },
    );
  }

  Widget _createConnectionIndicator() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        key: const ValueKey('connection_indicator'),
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color:
              _wsState == WsState.connected
                  ? const Color(0xFF51FD0B)
                  : const Color(0xFFCD0017),
        ),
      ),
    );
  }

  void _handleWebsocketState(WsStateEvent event) {
    if (!mounted) return;

    setState(() {
      _wsState = event.current;
    });
  }

  AvatarPixelRenderer _readFollowRenderer() {
    final value = _obsConfig.getString(
      'follow_animation_renderer',
      fallback: 'optimized',
    );

    return value == 'legacy'
        ? AvatarPixelRenderer.legacyCanvas
        : AvatarPixelRenderer.rawAtlas;
  }

  int _readFollowAvatarResolution() {
    final resolution = _obsConfig.getInt(
      'follow_avatar_resolution',
      fallback: 48,
    );

    return resolution > 0 ? resolution : 48;
  }

  void _handleConfig(Config _) {
    final renderer = _readFollowRenderer();
    final avatarResolution = _readFollowAvatarResolution();
    if (!mounted ||
        (renderer == _followRenderer &&
            avatarResolution == _followAvatarResolution)) {
      return;
    }

    setState(() {
      _followRenderer = renderer;
      _followAvatarResolution = avatarResolution;
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
    final eventId = event?.id;

    if (eventId != null && !_receivedEventIds.add(eventId)) {
      return;
    }

    switch (message.payload.subscription?.type) {
      case 'channel.follow':
        if (event != null && _obsConfig.getBool('followers')) {
          await _handleUserFollow(event);
        }
        return;

      case 'channel.channel_points_custom_reward_redemption.add':
        await _handleRewardEvent(event);
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

    img.Image? avatar;
    final avatarUrl = user?.profileImageUrl;

    if (avatarUrl != null) {
      try {
        final loader = widget.avatarLoader ?? RainyAvatar.loadImageFromUrl;
        avatar = await loader(avatarUrl);
      } catch (_) {
        // The follow animation can still run without an avatar.
      }
    }

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
