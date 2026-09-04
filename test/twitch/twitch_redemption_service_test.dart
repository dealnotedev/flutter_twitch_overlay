import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/twitch_creds.dart';
import 'package:obssource/twitch/twitch_redemption.dart';
import 'package:obssource/twitch/twitch_redemption_service.dart';

void main() {
  late Settings settings;
  late TwitchApi api;

  setUp(() {
    settings = Settings();
    settings.twitchAuth = TwitchCreds(
      accessToken: 'token',
      refreshToken: 'refresh',
      broadcasterId: 'broadcaster-1',
      clientId: 'client-1',
    );
    api = TwitchApi(settings: settings, clientSecret: 'unused');
    api.dio.interceptors.clear();
  });

  test('sends a terminal status directly to Twitch', () async {
    RequestOptions? capturedRequest;
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          capturedRequest = options;
          handler.resolve(
            Response<void>(requestOptions: options, statusCode: 200),
          );
        },
      ),
    );
    final service = TwitchApiRedemptionService(api: api, settings: settings);

    await service.settle(
      rewardId: 'reward-1',
      redemptionId: 'redemption-1',
      status: TwitchRedemptionStatus.fulfilled,
    );

    expect(capturedRequest?.queryParameters, {
      'broadcaster_id': 'broadcaster-1',
      'reward_id': 'reward-1',
      'id': 'redemption-1',
    });
    expect(capturedRequest?.data, {'status': 'FULFILLED'});
  });

  test('propagates a failed status update after one attempt', () async {
    var requestCount = 0;
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestCount++;
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response<void>(
                requestOptions: options,
                statusCode: 500,
              ),
            ),
          );
        },
      ),
    );
    final service = TwitchApiRedemptionService(api: api, settings: settings);

    await expectLater(
      service.settle(
        rewardId: 'reward-1',
        redemptionId: 'redemption-1',
        status: TwitchRedemptionStatus.canceled,
      ),
      throwsA(isA<DioException>()),
    );

    expect(requestCount, 1);
  });

  test('rejects a non-terminal status', () async {
    final service = TwitchApiRedemptionService(api: api, settings: settings);

    await expectLater(
      service.settle(
        rewardId: 'reward-1',
        redemptionId: 'redemption-1',
        status: TwitchRedemptionStatus.unfulfilled,
      ),
      throwsArgumentError,
    );
  });
}
