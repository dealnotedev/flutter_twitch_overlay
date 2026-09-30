import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/ws_manager.dart';

import 'tts_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'reward readiness requires add/update subscriptions and drops on revocation',
    () async {
      final settings = configuredTtsSettings();
      final subscriptions = <String>[];
      final updateAccepted = Completer<void>();
      final api = TwitchApi(settings: settings, clientSecret: 'unused');
      api.dio.interceptors
        ..clear()
        ..add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              if (options.method == 'GET') {
                handler.resolve(
                  Response(requestOptions: options, data: {'data': []}),
                );
                return;
              }
              final type = (options.data as Map)['type'] as String;
              subscriptions.add(type);
              if (type.endsWith('redemption.update')) {
                await updateAccepted.future;
              }
              handler.resolve(
                Response(requestOptions: options, statusCode: 202),
              );
            },
          ),
        );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final socketReady = Completer<WebSocket>();
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socketReady.complete(socket);
        socket.add(
          jsonEncode({
            'metadata': {'message_type': 'session_welcome'},
            'payload': {
              'session': {'id': 'test-session'},
            },
          }),
        );
      });
      final manager = WebSocketManager(
        'ws://127.0.0.1:${server.port}',
        settings,
        apiFactory: () => api,
      );
      addTearDown(() async {
        await manager.close();
        await (await socketReady.future).close();
        await server.close(force: true);
      });
      await eventually(
        () => subscriptions.any((s) => s.endsWith('redemption.update')),
      );
      expect(manager.rewardsReady, isFalse);
      updateAccepted.complete();
      await eventually(() => manager.rewardsReady);
      expect(
        subscriptions,
        containsAll([
          'channel.channel_points_custom_reward_redemption.add',
          'channel.channel_points_custom_reward_redemption.update',
        ]),
      );
      (await socketReady.future).add(
        jsonEncode({
          'metadata': {'message_type': 'revocation'},
          'payload': {
            'subscription': {
              'type': 'channel.channel_points_custom_reward_redemption.add',
            },
          },
        }),
      );
      await eventually(() => !manager.rewardsReady);
    },
  );
}
