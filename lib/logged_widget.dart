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
import 'package:obssource/secrets.dart';
import 'package:obssource/settings.dart';
import 'package:obssource/span_util.dart';
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
    return Stack(
      children: [
        /*Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: const AnimatedWave(
            height: 128,
            speed: 3,
            color: Colors.orange,
            alpha: 96,
          ),
        ),*/
        _createRewardsWidget(context),
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _state == WsState.connected ? Colors.green : Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  Widget _createRewardsWidget(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AnimatedListView(
            padding: EdgeInsets.symmetric(vertical: 8),
            items: _rewards,
            itemBuilder: (context, index) {
              final reward = _rewards[index];
              return _RewardWidget(event: reward, key: ValueKey(reward.id));
            },
            enterTransition: [SlideInLeft()],
            exitTransition: [SlideInLeft()],
            isSameItem: (a, b) => a.id == b.id,
          ),
        ),
        Expanded(child: SizedBox.shrink()),
      ],
    );
  }

  final _rewards = <_UserRedeemedEvent>[];

  final _receivedEventIds = <String>{};

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
        constraints: BoxConstraints(maxWidth: 512),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: Color(0x80202020).withValues(alpha: 0.8),
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
