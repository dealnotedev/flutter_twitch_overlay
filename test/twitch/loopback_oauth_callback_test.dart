import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/twitch/loopback_oauth_callback.dart';

void main() {
  late int port;
  late HttpClient client;
  late List<LoopbackOAuthCallback> callbacks;
  late Map<Completer<void>, Uri> authorizations;
  setUp(() async {
    final reservation = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = reservation.port;
    await reservation.close(force: true);
    client = HttpClient()..findProxy = (_) => 'DIRECT';
    callbacks = [];
    authorizations = {};
  });
  tearDown(() async {
    client.close(force: true);
    for (final callback in callbacks) {
      await callback.close();
    }
  });
  LoopbackOAuthCallback create(
    Completer<void> opened, {
    Duration timeout = const Duration(seconds: 2),
  }) {
    final callback = LoopbackOAuthCallback(
      callback: Uri.parse('http://127.0.0.1:$port'),
      openBrowser: (uri) async {
        authorizations[opened] = uri;
        opened.complete();
      },
      retryDelay: const Duration(milliseconds: 5),
      timeout: timeout,
    );
    callbacks.add(callback);
    return callback;
  }

  Future<int> deliver(String path, {Completer<void>? forLogin}) async {
    var uri = Uri.parse('http://127.0.0.1:$port$path');
    if (forLogin != null) {
      uri = uri.replace(
        queryParameters: {
          ...uri.queryParameters,
          'state': authorizations[forLogin]!.queryParameters['state']!,
        },
      );
    }
    final request = await client.getUrl(uri);
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  }

  test(
    'two sources authorize in order without racing for the callback port',
    () async {
      final openedA = Completer<void>();
      final openedB = Completer<void>();
      final a = create(openedA);
      final b = create(openedB);
      final resultA = a.request(Uri.parse('https://example.invalid/a'));
      await openedA.future;
      final resultB = b.request(Uri.parse('https://example.invalid/b'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(openedB.isCompleted, isFalse);
      expect(await deliver('/favicon.ico'), HttpStatus.notFound);
      expect(
        await deliver('/?code=stale&state=wrong-source'),
        HttpStatus.badRequest,
      );
      await deliver('/?code=first', forLogin: openedA);
      expect(await resultA, 'first');
      await openedB.future.timeout(const Duration(seconds: 2));
      await deliver('/?code=second', forLogin: openedB);
      expect(await resultB, 'second');
    },
  );

  test('separate source isolates share the callback port in turn', () async {
    final mailbox = ReceivePort();
    final opened = {'a': Completer<String>(), 'b': Completer<String>()};
    final results = {'a': Completer<String?>(), 'b': Completer<String?>()};
    final subscription = mailbox.listen((dynamic message) {
      final data = message as List<dynamic>;
      if (data[0] == 'opened') opened[data[1]]!.complete(data[2] as String);
      if (data[0] == 'result') results[data[1]]!.complete(data[2] as String?);
    });
    final isolates = <Isolate>[];
    addTearDown(() async {
      for (final isolate in isolates) {
        isolate.kill(priority: Isolate.immediate);
      }
      await subscription.cancel();
      mailbox.close();
    });
    isolates.add(
      await Isolate.spawn(_authorizeInIsolate, (mailbox.sendPort, port, 'a')),
    );
    final stateA = await opened['a']!.future.timeout(
      const Duration(seconds: 3),
    );
    isolates.add(
      await Isolate.spawn(_authorizeInIsolate, (mailbox.sendPort, port, 'b')),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(opened['b']!.isCompleted, isFalse);
    await deliver('/?code=a&state=$stateA');
    expect(await results['a']!.future, 'a');
    final stateB = await opened['b']!.future.timeout(
      const Duration(seconds: 3),
    );
    expect(stateB, isNot(stateA));
    expect(await deliver('/?code=stale&state=$stateA'), HttpStatus.badRequest);
    await deliver('/?code=b&state=$stateB');
    expect(await results['b']!.future, 'b');
  });

  test('disposing a queued source never opens a stale browser login', () async {
    final openedA = Completer<void>();
    final first = create(openedA);
    final opened = Completer<void>();
    final resultA = first.request(Uri.parse('https://example.invalid/a'));
    await openedA.future;
    final second = create(opened);
    final resultB = second.request(Uri.parse('https://example.invalid/b'));
    await second.close();
    expect(await resultB, isNull);
    expect(opened.isCompleted, isFalse);
    await first.close();
    expect(await resultA, isNull);
  });

  test(
    'an occupied callback port has a bounded wait and can be retried',
    () async {
      final occupied = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      final opened = Completer<void>();
      final callback = create(
        opened,
        timeout: const Duration(milliseconds: 40),
      );
      await expectLater(
        callback.request(Uri.parse('https://example.invalid')),
        throwsA(isA<TimeoutException>()),
      );
      expect(opened.isCompleted, isFalse);
      await occupied.close(force: true);
      final retry = callback.request(Uri.parse('https://example.invalid'));
      await opened.future;
      await deliver('/?error=access_denied', forLogin: opened);
      expect(await retry, isNull);
    },
  );
}

Future<void> _authorizeInIsolate((SendPort, int, String) args) async {
  final (reply, port, name) = args;
  final callback = LoopbackOAuthCallback(
    callback: Uri.parse('http://127.0.0.1:$port'),
    retryDelay: const Duration(milliseconds: 5),
    openBrowser:
        (uri) async =>
            reply.send(['opened', name, uri.queryParameters['state']!]),
  );
  final code = await callback.request(Uri.parse('https://example.invalid'));
  await callback.close();
  reply.send(['result', name, code]);
}
