import 'package:dio/dio.dart';
import 'package:obssource/twitch/loopback_oauth_callback.dart';
import 'package:obssource/twitch/twitch_creds.dart';
import 'package:open_url/open_url.dart';

class TwitchAuthenticator {
  final String clientId;
  final String clientSecret;
  final String oauthRedirectUrl;
  final LoopbackOAuthCallback _callback;

  static const _scope =
      'channel:manage:redemptions moderator:read:followers user:read:chat channel:read:subscriptions';
  TwitchAuthenticator({
    required this.clientId,
    required this.clientSecret,
    required this.oauthRedirectUrl,
  }) : _callback = LoopbackOAuthCallback(
         openBrowser: (uri) async {
           await openUrl(uri.toString());
         },
       );

  Future<TwitchCreds?> login() async {
    final authorizationCode = await _startOauth();

    if (authorizationCode == null) return null;

    final body = <String, String>{
      'redirect_uri': oauthRedirectUrl,
      'scope': _scope,
      'client_id': clientId,
      'client_secret': clientSecret,
      'grant_type': 'authorization_code',
      'code': authorizationCode,
    };

    final dio = Dio();

    final response = await dio.post(
      'https://id.twitch.tv/oauth2/token',
      data: FormData.fromMap(body),
      options: Options(contentType: "application/x-www-form-urlencoded"),
    );
    final json = response.data;
    final accessToken = json['access_token'] as String;

    final userId = await dio
        .get(
          'https://api.twitch.tv/helix/users',
          options: Options(
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Client-Id': clientId,
            },
          ),
        )
        .then((value) => value.data['data'] as List<dynamic>)
        .then((array) => array[0]['id']);

    return TwitchCreds(
      refreshToken: json['refresh_token'] as String,
      accessToken: accessToken,
      clientId: clientId,
      broadcasterId: userId,
    );
  }

  Future<String?> _startOauth() => _callback.request(
    Uri.https('id.twitch.tv', '/oauth2/authorize', {
      'client_id': clientId,
      'redirect_uri': _callback.callback.toString(),
      'response_type': 'code',
      'scope': _scope,
    }),
  );

  Future<void> close() => _callback.close();
}
