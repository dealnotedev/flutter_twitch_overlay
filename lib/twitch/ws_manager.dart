import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/secrets.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/twitch_creds.dart';
import 'package:obssource/twitch/ws_event.dart';
import 'package:obssource/twitch/ws_subscription.dart';
import 'package:rxdart/rxdart.dart';
import 'package:web_socket_channel/io.dart';

class WebSocketManager {
  final String _url;
  final Settings _settings;
  final TwitchApi Function()? _apiFactory;
  StreamSubscription<TwitchCreds?>? _authSubscription;
  Timer? _reconnectTimer;
  bool _closed = false;

  final _registrations = <_Registration>{};

  final _messagesSubject = StreamController<WsMessage>.broadcast();
  final _stateSubject = StreamController<WsStateEvent>.broadcast();
  final _rewardsReadySubject = StreamController<bool>.broadcast();
  bool _rewardsReady = false;
  bool get rewardsReady => _rewardsReady;
  Stream<bool> get rewardsReadyChanges => _rewardsReadySubject.stream;
  Timer? _keepaliveTimer;

  void _setRewardsReady(bool value) {
    if (_rewardsReady == value) return;
    _rewardsReady = value;
    _rewardsReadySubject.add(value);
  }

  WsState _state = WsState.idle;

  DateTime? _lastDisconnectTime;

  bool _waitReconnect = false;

  _Channel? _channel;

  StreamSubscription<dynamic>? _subscription;

  Completer<void>? _registrationCompleter;

  WsState get currentState => _state;

  Stream<WsMessage> get messages => _messagesSubject.stream;

  WebSocketManager(
    this._url,
    this._settings, {
    TwitchApi Function()? apiFactory,
  }) : _apiFactory = apiFactory {
    _authSubscription = _settings.twitchAuthStream.listen(_handleAuth);
  }

  void _changeState(WsState state) {
    debugPrint('Ws state: $state');

    Duration? offlineDuration;

    switch (state) {
      case WsState.idle:
        _lastDisconnectTime = null;
        break;

      case WsState.disconnected:
        _lastDisconnectTime = DateTime.now();
        break;

      case WsState.connected:
        final lastDisconnect = _lastDisconnectTime;
        if (lastDisconnect != null) {
          offlineDuration = DateTime.now().difference(lastDisconnect);
        }
        break;
      default:
        // ignore
        break;
    }

    final stateBefore = _state;
    _state = state;

    _stateSubject.add(
      WsStateEvent(stateBefore, state, offlineDuration: offlineDuration),
    );
  }

  Stream<WsStateEvent> get state => Stream.value(
    WsStateEvent(_state, _state),
  ).concatWith([_stateSubject.stream]);

  Stream<WsState> get stateChanges =>
      _stateSubject.stream.map((event) => event.current);

  void _connectInternal() async {
    if (_closed || _settings.twitchAuth == null) return;
    switch (_state) {
      case WsState.connected:
      case WsState.initialConnecting:
      case WsState.reconnecting:
        return;

      case WsState.idle:
        _changeState(WsState.initialConnecting);
        break;

      case WsState.disconnected:
        _changeState(WsState.reconnecting);
        break;
    }

    final _Channel channel;

    try {
      final ws = await WebSocket.connect(_url);
      if (_closed) {
        await ws.close();
        return;
      }

      channel = _channel = _Channel(channel: IOWebSocketChannel(ws));
      _changeState(WsState.connected);
    } catch (e) {
      _onClosed();
      return;
    }

    _subscription = channel.channel.stream.listen(
      (dynamic event) {
        final json = jsonDecode(event);
        final messageType = json['metadata']?['message_type'];
        if (messageType == 'session_reconnect') {
          // Re-establish subscriptions before accepting new redemptions.
          _onClosed();
          return;
        }
        if (messageType == 'revocation') {
          final type =
              json['payload']?['subscription']?['type'] as String? ?? '';
          if (type.startsWith(
            'channel.channel_points_custom_reward_redemption.',
          )) {
            _setRewardsReady(false);
          }
          return;
        }
        if (messageType == 'session_welcome' ||
            messageType == 'session_keepalive' ||
            messageType == 'notification') {
          _keepaliveTimer?.cancel();
          _keepaliveTimer = Timer(const Duration(seconds: 35), _onClosed);
        }
        final sessionId = json['payload']?['session']?['id'] as String?;

        if (sessionId != null) {
          channel.sessionId = sessionId;

          _checkWsRegistration();
          return;
        }

        final encoded = jsonEncode(json);
        debugPrint('WEBSOCKET $encoded');

        final msg = WsMessage.fromJson(json);
        _messagesSubject.add(msg);
      },
      onDone: _onClosed,
      onError: (Object _) => _onClosed(),
    );
  }

  void write(String message) {
    _channel?.channel.sink.add(message);
  }

  void _destroyCurrentConnection(WsState state) {
    _setRewardsReady(false);
    _keepaliveTimer?.cancel();
    _subscription?.cancel();

    _channel?.channel.sink.close(1000);
    _channel = null;

    _changeState(state);
  }

  void _onClosed() {
    if (_closed) return;
    _destroyCurrentConnection(WsState.disconnected);

    if (_waitReconnect) {
      return;
    }

    _waitReconnect = true;

    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _waitReconnect = false;
      _connectInternal();
    });
  }

  void _handleAuth(TwitchCreds? auth) {
    if (_closed) return;
    if (auth == null) {
      _destroyCurrentConnection(WsState.idle);
      return;
    }

    switch (_state) {
      case WsState.connected:
        _checkWsRegistration();
        break;

      case WsState.disconnected:
      case WsState.initialConnecting:
      case WsState.reconnecting:
        break;

      case WsState.idle:
        _connectInternal();
        break;
    }
  }

  void _checkWsRegistration() async {
    final sessionId = _channel?.sessionId;
    final broadcasterId = _settings.twitchAuth?.broadcasterId;

    if (sessionId == null || broadcasterId == null) return;

    await _registrationCompleter?.future;

    final completer = _registrationCompleter = Completer<void>();

    final api =
        _apiFactory?.call() ??
        TwitchApi(settings: _settings, clientSecret: twitchClientSecret);

    try {
      final cleaned = await api.cleanupInactiveEventSubs();
      debugPrint('Deleting inactive subscription: $cleaned');
    } on DioException catch (e) {
      debugPrint(
        'Api Error ${e.response?.statusCode} with message ${e.message}',
      );
    } catch (_) {}

    try {
      await _registerInternal(
        api,
        _Registration(
          _RegistrationType.raid,
          sessionId: sessionId,
          broadcasterId: broadcasterId,
        ),
      );

      await _registerInternal(
        api,
        _Registration(
          _RegistrationType.rewards,
          sessionId: sessionId,
          broadcasterId: broadcasterId,
        ),
      );
      await _registerInternal(
        api,
        _Registration(
          _RegistrationType.rewardUpdates,
          sessionId: sessionId,
          broadcasterId: broadcasterId,
        ),
      );
      if (_channel?.sessionId == sessionId &&
          _settings.twitchAuth?.broadcasterId == broadcasterId) {
        _setRewardsReady(true);
      }

      await _registerInternal(
        api,
        _Registration(
          _RegistrationType.follow,
          sessionId: sessionId,
          broadcasterId: broadcasterId,
        ),
      );

      await _registerInternal(
        api,
        _Registration(
          _RegistrationType.chatMessages,
          sessionId: sessionId,
          broadcasterId: broadcasterId,
        ),
      );
      for (final type in [
        _RegistrationType.subscribe,
        _RegistrationType.resubscribe,
        _RegistrationType.subscriptionGift,
      ]) {
        await _registerInternal(
          api,
          _Registration(
            type,
            sessionId: sessionId,
            broadcasterId: broadcasterId,
          ),
        );
      }
    } on DioException catch (e) {
      debugPrint(
        'Api Error ${e.response?.statusCode} with message ${e.message}',
      );
    } finally {
      completer.complete();
    }
  }

  Future<void> _registerInternal(
    TwitchApi api,
    _Registration registration,
  ) async {
    if (_closed) return;
    if (_registrations.contains(registration)) return;

    switch (registration.type) {
      case _RegistrationType.subscribe:
      case _RegistrationType.resubscribe:
      case _RegistrationType.subscriptionGift:
        await api.subscribeSubscriptionEvents(
          type: switch (registration.type) {
            _RegistrationType.subscribe => SubscriptionEventType.subscribe,
            _RegistrationType.resubscribe => SubscriptionEventType.message,
            _ => SubscriptionEventType.gift,
          },
          broadcasterUserId: registration.broadcasterId,
          sessionId: registration.sessionId,
        );
        break;
      case _RegistrationType.rewards:
      case _RegistrationType.rewardUpdates:
        await api.subscribeCustomRewards(
          broadcasterUserId: registration.broadcasterId,
          sessionId: registration.sessionId,
          updates: registration.type == _RegistrationType.rewardUpdates,
        );
        break;

      case _RegistrationType.follow:
        await api.subscribeFollowEvents(
          broadcasterUserId: registration.broadcasterId,
          sessionId: registration.sessionId,
        );
        break;

      case _RegistrationType.raid:
        await api.subscribeRaidEvents(
          broadcasterUserId: registration.broadcasterId,
          sessionId: registration.sessionId,
        );
        break;

      case _RegistrationType.chatMessages:
        await api.subscribeChatMessages(
          broadcasterUserId: registration.broadcasterId,
          userId: registration.broadcasterId,
          sessionId: registration.sessionId,
        );
        break;
    }

    _registrations.add(registration);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _reconnectTimer?.cancel();
    await _authSubscription?.cancel();
    _destroyCurrentConnection(WsState.idle);
    await _messagesSubject.close();
    await _stateSubject.close();
    await _rewardsReadySubject.close();
  }
}

class _Channel {
  final IOWebSocketChannel channel;

  String? sessionId;

  _Channel({required this.channel});
}

enum _RegistrationType {
  rewards,
  rewardUpdates,
  follow,
  raid,
  chatMessages,
  subscribe,
  resubscribe,
  subscriptionGift,
}

class _Registration {
  final _RegistrationType type;

  final String sessionId;
  final String broadcasterId;

  _Registration(
    this.type, {
    required this.sessionId,
    required this.broadcasterId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Registration &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          sessionId == other.sessionId &&
          broadcasterId == other.broadcasterId;

  @override
  int get hashCode =>
      type.hashCode ^ sessionId.hashCode ^ broadcasterId.hashCode;
}

enum WsState { initialConnecting, connected, disconnected, reconnecting, idle }

class WsStateEvent {
  final WsState before;
  final WsState current;

  final Duration? offlineDuration;

  WsStateEvent(this.before, this.current, {this.offlineDuration});

  bool get changed => before != current;
}
