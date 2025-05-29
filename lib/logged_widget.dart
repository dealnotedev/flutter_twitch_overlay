import 'dart:async';

import 'package:animated_reorderable_list/animated_reorderable_list.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:obssource/animated_mover.dart';
import 'package:obssource/avatar_widget.dart';
import 'package:obssource/config/obs_config.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/data/events.dart';
import 'package:obssource/di/service_locator.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/generated/assets.dart';
import 'package:obssource/obs_audio.dart';
import 'package:obssource/screen_attack_game.dart';
import 'package:obssource/secrets.dart';
import 'package:obssource/span_util.dart';
import 'package:obssource/srt_off.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/twitch_creds.dart';
import 'package:obssource/twitch/ws_event.dart';
import 'package:obssource/twitch/ws_manager.dart';

class LoggedWidget extends StatefulWidget {
  final ServiceLocator locator;
  final TwitchCreds creds;

  const LoggedWidget({super.key, required this.locator, required this.creds});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<LoggedWidget> {
  StreamSubscription<WsMessage>? _eventsSubscription;
  StreamSubscription<WsStateEvent>? _stateSubscription;

  late WsState _state;
  late Timer _timer;
  late Settings _settings;
  late ObsConfig _obsConfig;

  @override
  void initState() {
    _settings = widget.locator.provide();
    _obsConfig = widget.locator.provide();

    final ws = widget.locator.provide<WebSocketManager>();
    _state = ws.currentState;

    _eventsSubscription = ws.messages.listen(_handleWebsocketMessage);
    _stateSubscription = ws.state.listen(_handleWebsocketState);

    _timer = Timer.periodic(Duration(seconds: 1), _handleTimerTick);
    super.initState();
  }

  void _handleWebsocketState(WsStateEvent event) {
    setState(() {
      _state = event.current;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _stateSubscription?.cancel();
    _eventsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offTv = _offTv;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            if (_obsConfig.getBool('screen_attack_game')) ...[
              ScreenAttackGameWidget(locator: widget.locator),
            ],
            _createConnectionIndicator(),
            if (_off) ...[CRTOffAnimation(onEnd: _handleCrtOff)],
            if (_off && _crtOffFinished) ...[
              Center(
                child: Image.asset(
                  Assets.assetsIcDulya,
                  width: 200,
                  height: 200,
                ),
              ),
              if (offTv != null) ...[_createOffTvByWidget(offTv)],
            ],
            _createRewardsWidget(context),
            ..._follows.map((f) {
              return _FollowBallonsWidget(
                event: f,
                constraints: constraints,
                duration: _followDuration,
                key: ValueKey(f),
              );
            }),
            ..._roosters.map((r) {
              return _RoosterWidget(
                constraints: constraints,
                key: ValueKey(r.id),
                event: r,
                duration: _roosterDuration,
              );
            }),
            _createConfigInfo(context),
          ],
        );
      },
    );
  }

  Widget _createConfigInfo(BuildContext context) {
    return StreamBuilder(
      stream: _obsConfig.config.changes,
      initialData: _obsConfig.config.current,
      builder: (cntx, config) {
        final valid = config.requireData.valid;
        if (valid) {
          return SizedBox.shrink();
        }
        return Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.red,
            ),
            child: Text(
              context.localizations.config_invalid,
              style: TextStyle(
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

  Widget _createOffTvByWidget(UserRedeemedEvent offTv) {
    final avatarPlaceholder = '{user_avatar}';
    return Positioned(
      bottom: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 20, color: Colors.white),
            children: SpanUtil.createSpansAdvanced(
              context.localizations.by_user(avatarPlaceholder, offTv.user),
              [avatarPlaceholder, offTv.user],
              (t) {
                if (t == avatarPlaceholder) {
                  return WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Avatar(size: 24, url: offTv.avatar),
                  );
                }
                return TextSpan(
                  text: t,
                  style: TextStyle(fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _createConnectionIndicator() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color:
              _state == WsState.connected
                  ? Color(0xFF51FD0B)
                  : Color(0xFFCD0017),
        ),
      ),
    );
  }

  Widget _createRewardsWidget(BuildContext context) {
    return AnimatedListView(
      padding: EdgeInsets.symmetric(vertical: 8),
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

  final _rewards = <UserRedeemedEvent>[];

  final _receivedEventIds = <String>{};

  UserRedeemedEvent? _offTv;

  static const _offTvDuration = Duration(seconds: 30);

  bool get _off {
    final off = _offTv;
    return off != null && off.time.add(_offTvDuration).isAfter(DateTime.now());
  }

  Future<void> _handleReward(UserRedeemedEvent reward) async {
    if ('Дуля (30с)' == reward.reward) {
      ObsAudio.loadAsset(Assets.assetsTvOffSound).then((id) {
        ObsAudio.play(id);
      });

      if (!_off) {
        _crtOffFinished = false;
      }

      setState(() {
        _offTv = reward;
      });

      await Future.delayed(_offTvDuration);

      setState(() {});
      return;
    }
  }

  static const _roosterDuration = Duration(seconds: 10);
  static const _followDuration = Duration(seconds: 10);

  final _roosters = <_Rooster>{};
  final _follows = <UserFollowEvent>{};

  void _handleUserFollow(WsMessageEvent event) async {
    final user = await _getUser(event.userId);
    final userName = event.userName;

    if (userName != null) {
      final follow = UserFollowEvent(
        time: DateTime.now(),
        end: DateTime.now().add(_followDuration),
        userName: userName,
        user: user,
      );

      setState(() {
        _follows.add(follow);
      });

      ObsAudio.loadAsset(Assets.assetsFollowSound).then((id) {
        ObsAudio.play(id);
      });

      await Future.delayed(_followDuration);

      setState(() {
        _follows.remove(follow);
      });
    }
  }

  void _handleWebsocketMessage(WsMessage message) async {
    final event = message.payload.event;

    final eventId = event?.id;
    if (eventId != null && !_receivedEventIds.add(eventId)) {
      // Remove duplicates
      return;
    }

    if (event != null &&
        message.payload.subscription?.type == 'channel.follow' &&
        _obsConfig.getBool('followers')) {
      _handleUserFollow(event);
      return;
    }

    final msg = event?.message;
    if (msg != null) {
      _handleChatMessage(message, msg);
      return;
    }

    final userId = event?.userId;
    final userName = event?.userName;

    final reward = event?.reward?.title;
    final cost = event?.reward?.cost;

    if (eventId != null &&
        userId != null &&
        userName != null &&
        reward != null) {
      final UserDto? user = await _getUser(userId);

      final event = UserRedeemedEvent(
        eventId,
        time: DateTime.now(),
        user: userName,
        reward: reward,
        avatar: user?.profileImageUrl,
        cost: cost ?? 0,
      );

      _handleReward(event);

      setState(() {
        _rewards.add(event);
      });
    }
  }

  Future<UserDto?> _getUser(String? userId) async {
    if (userId != null) {
      final UserDto? cached = _users[userId];
      if (cached != null) {
        return cached;
      }
      final api = TwitchApi(
        settings: _settings,
        clientSecret: twitchClientSecret,
      );
      final user = await api.getUser(id: userId);
      _users[userId] = user;
      return user;
    } else {
      return null;
    }
  }

  void _handleTimerTick(_) {
    final sizeBefore = _rewards.length;

    _rewards.removeWhere(
      (e) => DateTime.now().difference(e.time) > Duration(milliseconds: 7500),
    );

    if (_rewards.length != sizeBefore) {
      setState(() {});
    }
  }

  final _users = <String, UserDto>{};

  bool _crtOffFinished = false;

  void _handleCrtOff() {
    setState(() {
      _crtOffFinished = true;
    });
  }

  final _firstChatSenders = <String>{};

  Future<void> _handleChatMessage(WsMessage event, WsChatMessage msg) async {
    final senderId = event.payload.event?.chatterUserId;

    if (senderId == null) return;

    final user = await _getUser(senderId);
    final name = event.payload.event?.chatterUserName;
    final id = event.payload.event?.messageId;

    final String title;
    final Color color;

    if (!mounted) return;

    final firstMessage = _firstChatSenders.add(senderId);

    if ('channel_points_highlighted' == event.payload.event?.messageType) {
      title = context.localizations.chat_message_highlighted;
      color = Color(0xFFFF6905);
    } else if (_obsConfig.getBool('first_chat_message') && firstMessage) {
      title = context.localizations.chat_message_first;
      color = Color(0xFF8829FF);
    } else {
      return;
    }

    if (name != null && id != null) {
      final spans = msg.fragments.map<InlineSpan>((f) {
        switch (f.type) {
          case WsFragmentType.text:
          case WsFragmentType.mention:
          case WsFragmentType.unknown:
            return TextSpan(text: f.text);

          case WsFragmentType.emote:
            final format =
                (f.emote?.format.contains('animated') ?? false)
                    ? 'animated'
                    : 'static';
            final url =
                'https://static-cdn.jtvnw.net/emoticons/v2/${f.emote?.id}/$format/dark/2.0';
            return WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: CachedNetworkImage(
                filterQuality: FilterQuality.high,
                imageUrl: url,
                width: 24,
                height: 24,
              ),
            );
        }
      });

      final rooster = _Rooster(
        color: color,
        title: title,
        id: id,
        text: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Avatar(size: 24, url: user?.profileImageUrl),
          ),
          TextSpan(text: ' '),
          TextSpan(text: ' '),
          TextSpan(
            text: '$name: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ...spans,
        ],
      );

      setState(() {
        _roosters.add(rooster);
      });

      await Future.delayed(_roosterDuration);

      setState(() {
        _roosters.remove(rooster);
      });
    }
  }
}

class _RewardWidget extends StatelessWidget {
  final UserRedeemedEvent event;

  const _RewardWidget({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final cost = NumberFormat('###,###').format(event.cost);
    final currencyPlaceholder = '{:currency_icon}';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 448),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: Color(0xFF3C3C3C).withValues(alpha: 0.9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(url: event.avatar, size: 48),
            Gap(16),
            Flexible(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.white, fontSize: 18),
                  children: SpanUtil.createSpansAdvanced(
                    context.localizations.user_redeemed_reward_title(
                      event.user,
                      event.reward,
                      currencyPlaceholder,
                      cost,
                    ),
                    [event.user, event.reward, currencyPlaceholder],
                    (t) {
                      if (t == currencyPlaceholder) {
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
                        text: t,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
              ),
            ),
            Gap(8),
          ],
        ),
      ),
    );
  }
}

class _Rooster {
  final Color color;
  final String title;
  final String id;
  final List<InlineSpan> text;

  _Rooster({
    required this.id,
    required this.text,
    required this.title,
    required this.color,
  });
}

class _RoosterWidget extends StatelessWidget {
  final Duration duration;
  final _Rooster event;
  final BoxConstraints constraints;

  const _RoosterWidget({
    super.key,
    required this.event,
    required this.duration,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedHorizontalMover(
      alreadyInsideStack: true,
      constraints: constraints,
      duration: duration,
      size: Size(400, 320),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          LottieBuilder.asset(
            Assets.assetsRooster,
            width: 400,
            height: 320,
            fit: BoxFit.cover,
            frameRate: FrameRate(60),
          ),
          Positioned(
            left: 256,
            bottom: 200,
            child: Transform.rotate(
              angle: -0.25,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    constraints: BoxConstraints(maxWidth: 448),
                    decoration: BoxDecoration(
                      color: Color(0xFF3C3C3C).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 12,
                      top: 12,
                    ),
                    child: RichText(
                      textWidthBasis: TextWidthBasis.longestLine,
                      text: TextSpan(
                        style: TextStyle(fontSize: 16, color: Colors.white),
                        children: event.text,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 24,
                    top: -16,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: event.color,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        event.title,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowBallonsWidget extends StatelessWidget {
  static const _avatarPlaceholder = '{avatart_placeholder}';

  final UserFollowEvent event;
  final Duration duration;
  final BoxConstraints constraints;

  const _FollowBallonsWidget({
    super.key,
    required this.event,
    required this.duration,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedVerticalMover(
      duration: duration,
      size: Size(280, 280),
      constraints: constraints,
      alreadyInsideStack: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          LottieBuilder.asset(
            Assets.assetsBallons,
            width: 280,
            height: 280,
            fit: BoxFit.cover,
            frameRate: FrameRate(60),
          ),
          Positioned(
            top: 48,
            left: 160,
            child: Transform.rotate(
              angle: -0.15,
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xFF3C3C3C).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(32),
                ),
                padding: EdgeInsets.all(16),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(fontSize: 24),
                    children: SpanUtil.createSpansAdvanced(
                      context.localizations.user_now_following_title(
                        _avatarPlaceholder,
                        event.userName,
                      ),
                      [_avatarPlaceholder, event.userName],
                      (t) {
                        if (t == _avatarPlaceholder) {
                          return WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Avatar(
                              size: 24,
                              url: event.user?.profileImageUrl,
                            ),
                          );
                        }
                        return TextSpan(
                          text: t,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
