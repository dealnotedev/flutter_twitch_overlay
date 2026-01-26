import 'dart:async';
import 'dart:math';

import 'package:animated_reorderable_list/animated_reorderable_list.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:obssource/avatar_widget.dart';
import 'package:obssource/config/obs_config.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/data/events.dart';
import 'package:obssource/di/service_locator.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/flashbang.dart';
import 'package:obssource/follow/follow_ballons.dart';
import 'package:obssource/generated/assets.dart';
import 'package:obssource/highlighed/highlighted_message.dart';
import 'package:obssource/kill_widget.dart';
import 'package:obssource/local_server.dart';
import 'package:obssource/obs_audio.dart';
import 'package:obssource/pixels/pixel_rain_avatar.dart';
import 'package:obssource/raid.dart';
import 'package:obssource/screen_attack_game.dart';
import 'package:obssource/secrets.dart';
import 'package:obssource/span_util.dart';
import 'package:obssource/srt_off.dart';
import 'package:obssource/subs/subs_widget.dart';
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
  StreamSubscription<KillInfo>? _killsSubscription;

  late WsState _state;
  late Timer _timer;
  late Settings _settings;
  late ObsConfig _obsConfig;
  late LocalServer _localServer;

  @override
  void initState() {
    _settings = widget.locator.provide();
    _obsConfig = widget.locator.provide();
    _localServer = widget.locator.provide();

    final ws = widget.locator.provide<WebSocketManager>();
    _state = ws.currentState;

    _eventsSubscription = ws.messages.listen(_handleWebsocketMessage);
    _stateSubscription = ws.state.listen(_handleWebsocketState);

    _timer = Timer.periodic(Duration(seconds: 1), _handleTimerTick);

    //_simulateRaid(raiders: 20);

    /*WidgetsBinding.instance.addPostFrameCallback((_) {
      _pushSubscription(
        _Sub(who: 'dealnotedev',
            text: context.localizations.subscription_gift_description('1', 5)),
      );
    });*/

    _killsSubscription = _localServer.kills.listen(_handleKill);
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
    _killsSubscription?.cancel();
    super.dispose();
  }

  Flashbang? _flashbang;

  @override
  Widget build(BuildContext context) {
    final offTv = _offTv;
    final pause = _pause;
    final pauseMsg = pause?.message;
    final raid = _raid;
    final sub = _sub;
    final kill = _kill;
    final flashbang = _flashbang;

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
            if (pause != null) ...[
              Stack(
                key: ValueKey(pause),
                children: [
                  RainyAvatar(
                    pixelSize: 12,
                    verticalOffset: pauseMsg != null ? -64 : 0,
                    fallDuration: pause.fallDuration,
                    duration: pause.duration,
                    image: pause.image,
                    constraints: constraints,
                  ),
                  if (pauseMsg != null) ...[
                    Positioned(
                      left: 320,
                      right: 320,
                      bottom: 48,
                      child: Text(
                        pauseMsg,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            ..._follows.map((f) {
              return FollowBallonsWidget(
                event: f,
                constraints: constraints,
                duration: _followDuration,
                key: ValueKey(f),
              );
            }),
            ..._highlightedMessages.map((r) {
              return HighlightedMessageWidget(
                constraints: constraints,
                key: ValueKey(r.id),
                event: r,
                duration: _highlightedMessageDuration,
              );
            }),
            _createConfigInfo(context),
            //_createPixeledName(constraints, 'bilosnizhka_ua'),
            _createRewardsWidget(context),
            if (raid != null) ...[
              RaidWidget(
                constraints: constraints,
                raid: raid,
                onDone: _handleRaidAnimationDone,
              ),
            ],
            if (sub != null) ...[_createSubsWidget(sub, constraints)],
            if (kill != null) ...[
              _createKillWidget(context, kill: kill, constraints: constraints),
            ],
            if (flashbang != null) ...[
              FlashbangWidget(
                constraints: constraints,
                flashbang: flashbang,
                key: ValueKey(flashbang.id),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _createKillWidget(
    BuildContext context, {
    required KillInfo kill,
    required BoxConstraints constraints,
  }) {
    return KillWidget(
      text: kill.text,
      constraints: constraints,
      key: ValueKey(kill),
      streak: kill.inMatch,
    );
  }

  Widget _createSubsWidget(_Sub sub, BoxConstraints constraints) {
    return SubsWidget(
      who: sub.who,
      constraints: constraints,
      description: sub.text,
    );
  }

  void _handleSubscriptionMessage(WsMessage message) {
    final who = message.payload.event?.user?.name;
    final tier = _subTierOf(message.payload.event?.tier);

    final months = message.payload.event?.cumulativeMonths;

    if (who != null && months != null) {
      _pushSubscription(
        _Sub(
          who: who,
          text: context.localizations.subscription_message_description(
            tier,
            months,
          ),
        ),
      );
    }
  }

  void _handleSubscriptionGift(WsMessage message) {
    final tier = _subTierOf(message.payload.event?.tier);
    final anonymous = message.payload.event?.anonymous ?? false;
    final count = message.payload.event?.total ?? 0;

    final String? who;

    if (anonymous) {
      who = context.localizations.subscription_anonymous;
    } else {
      who = message.payload.event?.user?.name;
    }

    if (who != null) {
      _pushSubscription(
        _Sub(
          who: who,
          text: context.localizations.subscription_gift_description(
            tier,
            count,
          ),
        ),
      );
    }
  }

  static String _subTierOf(String? value) {
    switch (value) {
      case "1000":
        return "1";
      case "2000":
        return "2";
      case "3000":
        return "3";
      default:
        return "?";
    }
  }

  void _handleSubscription(WsMessage message) async {
    final tier = _subTierOf(message.payload.event?.tier);
    final who = message.payload.event?.user?.name;
    final gift = message.payload.event?.gift ?? false;

    if (who == null || gift) return;

    _pushSubscription(
      _Sub(
        who: who,
        text: context.localizations.subscription_subscribe_description(tier),
      ),
    );
  }

  KillInfo? _kill;

  Completer<KillInfo>? _killCompleter;

  void _handleKill(KillInfo kill) async {
    await _killCompleter?.future;

    _killCompleter = Completer();

    setState(() {
      _kill = kill;
    });

    await Future.delayed(Duration(seconds: 3));

    setState(() {
      _kill = null;
    });

    _killCompleter?.complete(kill);
  }

  void _pushSubscription(_Sub sub) async {
    final previous = _subCompleter;
    final completer = _subCompleter = Completer<void>();

    await previous?.future;

    ObsAudio.loadAsset(Assets.assetsSub).then((id) {
      ObsAudio.play(id);
    });

    setState(() {
      _sub = sub;
    });

    await Future.delayed(Duration(seconds: 20));

    setState(() {
      _sub = null;
    });

    completer.complete();
  }

  _Sub? _sub;
  Completer<void>? _subCompleter;

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

  Future<void> _handleFlashbang(UserRedeemedEvent reward) async {
    final flashbang = Flashbang(id: reward.id, pro: Random().nextBool());
    setState(() {
      _flashbang = flashbang;
    });

    await Future.delayed(Duration(seconds: 5));

    if (_flashbang != flashbang) return;

    setState(() {
      _flashbang = null;
    });
  }

  Future<void> _handleReward(UserRedeemedEvent reward) async {
    if ('Флешбенг' == reward.reward) {
      _handleFlashbang(reward);
      return;
    }

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

    if ('Пауза' == reward.reward) {
      final args = (reward.input?.trim() ?? '').split(' ');

      final int seconds;

      if (args.isNotEmpty && args.first.isNotEmpty) {
        final time = args.first;

        if (time.contains(':')) {
          final ms = time.split(':');

          final m = int.tryParse(ms[0]) ?? 0;
          final s = ms.length > 1 ? int.tryParse(ms[1]) ?? 0 : 0;

          seconds = m * 60 + s;
        } else {
          final minutes = int.tryParse(time) ?? 0;
          seconds = minutes * 60;
        }
      } else {
        seconds = 0;
      }

      final message = args.length > 1 ? args.sublist(1).join(' ') : null;

      if (seconds == 0) {
        setState(() {
          _pause = null;
        });
        return;
      }

      final image = await RainyAvatar.loadImageFromAssets(
        Assets.assetsImgPause1,
      );
      setState(() {
        _pause = Pause(
          message: message,
          image: image!,
          duration: Duration(seconds: seconds),
          fallDuration: Duration(milliseconds: 1500),
        );
      });
    }
  }

  static const _highlightedMessageDuration = Duration(seconds: 10);
  static const _followDuration = Duration(seconds: 10);

  Pause? _pause;

  final _highlightedMessages = <HighlightedMessage>{};
  final _follows = <UserFollowEvent>{};

  void _handleUserFollow(WsMessageEvent event) async {
    final user = await _getUser(event.user?.id);
    final userName = event.user?.name;

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

    if (message.payload.subscription?.type == 'channel.subscription.gift' &&
        _obsConfig.getBool('subscriptions')) {
      _handleSubscriptionGift(message);
      return;
    }

    if (message.payload.subscription?.type == 'channel.subscription.message' &&
        _obsConfig.getBool('subscriptions')) {
      _handleSubscriptionMessage(message);
      return;
    }

    if (message.payload.subscription?.type == 'channel.subscribe' &&
        _obsConfig.getBool('subscriptions')) {
      _handleSubscription(message);
      return;
    }

    if (message.payload.subscription?.type == 'channel.raid' &&
        _obsConfig.getBool('raids')) {
      _handleRaid(message);
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

    final userId = event?.user?.id;
    final userName = event?.user?.name;

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
        input: message.payload.event?.userInput,
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
    final senderId = event.payload.event?.chatter?.id;

    if (senderId == null) return;

    final user = await _getUser(senderId);
    final name = event.payload.event?.chatter?.name;
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

      final config = HighlightedMessageConfig.get();

      final highlightedMessage = HighlightedMessage(
        config: config,
        firstMessage: firstMessage,
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
        _highlightedMessages.add(highlightedMessage);
      });

      await Future.delayed(_highlightedMessageDuration);

      setState(() {
        _highlightedMessages.remove(highlightedMessage);
      });
    }
  }

  Raid? _raid;

  void _simulateRaid({int raiders = 5}) async {
    _playRaidAudio();

    final from = UserDto.dealnotedev;
    final avatarUrl = from.profileImageUrl;

    final avatar =
        avatarUrl != null
            ? await RainyAvatar.loadImageFromUrl(avatarUrl)
            : null;

    setState(() {
      _raid = Raid(who: from, avatar: avatar, raiders: raiders, id: from.id);
    });
  }

  static void _playRaidAudio() {
    ObsAudio.loadAsset(Assets.assetsRaid).then((id) {
      ObsAudio.play(id);
    });
  }

  void _handleRaid(WsMessage message) async {
    final fromId = message.payload.event?.fromBroadcaster?.id;
    final from = fromId != null ? await _getUser(fromId) : null;

    if (fromId != null && from != null) {
      _playRaidAudio();

      final avatarUrl = from.profileImageUrl;
      final avatar =
          avatarUrl != null
              ? await RainyAvatar.loadImageFromUrl(avatarUrl)
              : null;

      setState(() {
        _raid = Raid(
          who: from,
          avatar: avatar,
          raiders: message.payload.event?.viewers ?? 0,
          id: fromId,
        );
      });
    }
  }

  void _handleRaidAnimationDone(Raid raid) {
    if (_raid != raid) return;

    setState(() {
      _raid = null;
    });
  }
}

class _Sub {
  final String who;
  final String text;

  _Sub({required this.who, required this.text});
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
