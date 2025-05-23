import 'dart:async';
import 'dart:convert';

import 'package:animated_reorderable_list/animated_reorderable_list.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:obssource/avatar_widget.dart';
import 'package:obssource/di/service_locator.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/generated/assets.dart';
import 'package:obssource/screen_attack_game.dart';
import 'package:obssource/secrets.dart';
import 'package:obssource/settings.dart';
import 'package:obssource/span_util.dart';
import 'package:obssource/srt_off.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/twitch_creds.dart';
import 'package:obssource/twitch/ws_manager.dart';

class LoggedWidget extends StatefulWidget {
  final ServiceLocator locator;
  final TwitchCreds creds;

  const LoggedWidget({super.key, required this.locator, required this.creds});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<LoggedWidget> {
  StreamSubscription<dynamic>? _eventsSubscription;
  StreamSubscription<WsStateEvent>? _stateSubscription;

  late WsState _state;
  late Timer _timer;
  late Settings _settings;

  @override
  void initState() {
    _settings = widget.locator.provide();

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

    return Stack(
      children: [
        ScreenAttackGameWidget(locator: widget.locator),
        _createConnectionIndicator(),
        if (_off) ...[CRTOffAnimation(onEnd: _handleCrtOff)],
        if (_off && _crtOffFinished) ...[
          Center(
            child: Image.asset(Assets.assetsIcDulya, width: 200, height: 200),
          ),
          if (offTv != null) ...[_createOffTvByWidget(offTv)],
        ],
        _createRewardsWidget(context),
      ],
    );
  }

  Widget _createOffTvByWidget(_UserRedeemedEvent offTv) {
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

  final _rewards = <_UserRedeemedEvent>[];

  final _receivedEventIds = <String>{};

  _UserRedeemedEvent? _offTv;

  static const _offTvDuration = Duration(seconds: 30);

  bool get _off {
    final off = _offTv;
    return off != null && off.time.add(_offTvDuration).isAfter(DateTime.now());
  }

  Future<void> _handleReward(_UserRedeemedEvent reward) async {
    if ('Дуля (30с)' == reward.reward) {
      if (!_off) {
        _crtOffFinished = false;
      }

      setState(() {
        _offTv = reward;
      });

      await Future.delayed(_offTvDuration);

      setState(() {});
    }
  }

  void _handleWebsocketMessage(dynamic event) async {
    final json = jsonEncode(event);
    print('EVENT $json');

    final eventId = event['payload']?['event']?['id'] as String?;

    if (eventId != null && !_receivedEventIds.add(eventId)) {
      // Remove duplicates
      return;
    }

    final userId = event['payload']?['event']?['user_id'] as String?;
    final userName = event['payload']?['event']?['user_name'] as String?;

    final reward = event['payload']?['event']?['reward']?['title'] as String?;
    final cost = event['payload']?['event']?['reward']?['cost'] as int?;

    if (eventId != null &&
        userId != null &&
        userName != null &&
        reward != null) {
      final UserDto user;

      final UserDto? cached = _users[userId];
      if (cached != null) {
        user = cached;
      } else {
        final api = TwitchApi(
          settings: _settings,
          clientSecret: twitchClientSecret,
        );
        user = await api.getUser(id: userId);
        _users[userId] = user;
      }

      final event = _UserRedeemedEvent(
        eventId,
        time: DateTime.now(),
        user: userName,
        reward: reward,
        avatar: user.profileImageUrl,
        cost: cost ?? 0,
      );

      _handleReward(event);

      setState(() {
        _rewards.add(event);
      });
    }
  }

  void _handleTimerTick(_) {
    setState(() {
      _rewards.removeWhere(
        (e) => DateTime.now().difference(e.time) > Duration(milliseconds: 7500),
      );
    });
  }

  final _users = <String, UserDto>{};

  bool _crtOffFinished = false;

  void _handleCrtOff() {
    setState(() {
      _crtOffFinished = true;
    });
  }
}

class _RewardWidget extends StatelessWidget {
  final _UserRedeemedEvent event;

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
          color: Color(0xFF3C3C3C).withValues(alpha: 0.8),
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

class _UserRedeemedEvent {
  final String id;
  final DateTime time;
  final String user;
  final String reward;
  final String? avatar;
  final int cost;

  _UserRedeemedEvent(
    this.id, {
    required this.user,
    required this.reward,
    required this.avatar,
    required this.cost,
    required this.time,
  });
}
