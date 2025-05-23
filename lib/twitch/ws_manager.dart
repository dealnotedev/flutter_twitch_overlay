import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:obssource/secrets.dart';
import 'package:obssource/settings.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/twitch_creds.dart';
import 'package:rxdart/rxdart.dart';
import 'package:web_socket_channel/io.dart';

class WebSocketManager {
  final _subject = StreamController<dynamic>.broadcast();

  final String _url;
  final Settings _settings;
  final _stateSubject = StreamController<WsStateEvent>.broadcast();

  WsState currentState = WsState.idle;

  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  WebSocketManager(this._url, Settings settings) : _settings = settings {
    _settings.twitchAuthStream.listen(_handleAuth);
  }

  DateTime? _lastDisconnectTime;

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

    final stateBefore = currentState;
    currentState = state;
    _stateSubject.add(
      WsStateEvent(stateBefore, state, offlineDuration: offlineDuration),
    );
  }

  Stream<WsStateEvent> get state => Stream.value(
    WsStateEvent(currentState, currentState),
  ).concatWith([_stateSubject.stream]);

  Stream<WsState> get stateShanges =>
      _stateSubject.stream.map((event) => event.current);

  void _connectInternal({TwitchCreds? auth}) async {
    final actualAuth = auth ?? _settings.twitchAuth;

    if (actualAuth == null) {
      return;
    }

    if (currentState == WsState.disconnected) {
      _changeState(WsState.reconnecting);
    } else {
      _changeState(WsState.initialConnecting);
    }

    try {
      final ws = await WebSocket.connect(_url);
      ws.pingInterval = const Duration(seconds: 10);

      _channel = IOWebSocketChannel(ws);
      _changeState(WsState.connected);
    } catch (e) {
      _onClosed();
      return;
    }

    _subscription = _channel?.stream.listen((dynamic event) {
      final json = jsonDecode(event);
      final sessionId = json['payload']?['session']?['id'] as String?;

      if (sessionId != null && !_registeredSessionIds.contains(sessionId)) {
        _registerWsSession(sessionId);
        return;
      }

      _subject.add(json);
    }, onDone: _onClosed);
  }

  void write(String message) {
    _channel?.sink.add(message);
  }

  void _destroyCurrentConnection(WsState state) {
    _subscription?.cancel();
    _channel?.sink.close(1000);

    _changeState(state);
  }

  Stream<dynamic> get messages => _subject.stream;

  bool _waitReconnect = false;

  void _onClosed() {
    _destroyCurrentConnection(WsState.disconnected);

    if (_waitReconnect) {
      return;
    }

    _waitReconnect = true;

    Future.delayed(const Duration(seconds: 5), () {
      _waitReconnect = false;
      _connectInternal();
    });
  }

  void _handleAuth(TwitchCreds? auth) {
    if (auth == null) {
      _destroyCurrentConnection(WsState.idle);
      return;
    }

    _connectInternal(auth: auth);
  }

  final _registeredSessionIds = <String>{};

  void _registerWsSession(String sessionId) async {
    final api = TwitchApi(
      settings: _settings,
      clientSecret: twitchClientSecret,
    );

    try {
      await api.subscribeCustomRewards(
        broadcasterUserId: _settings.twitchAuth?.broadcasterId,
        sessionId: sessionId,
      );

      _registeredSessionIds.add(sessionId);
    } on DioException catch (e) {
      print('Api Error ${e.response?.statusCode} with message ${e.message}');
    }
  }
}

enum WsState { initialConnecting, connected, disconnected, reconnecting, idle }

class WsStateEvent {
  final WsState before;
  final WsState current;

  final Duration? offlineDuration;

  WsStateEvent(this.before, this.current, {this.offlineDuration});

  bool get changed => before != current;
}
