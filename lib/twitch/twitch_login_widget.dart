import 'dart:async';

import 'package:flutter/material.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/secrets.dart';
import 'package:obssource/twitch/twitch_authenticator.dart';

class TwitchLoginWidget extends StatefulWidget {
  final Settings settings;

  const TwitchLoginWidget({super.key, required this.settings});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<TwitchLoginWidget> {
  bool _loggingIn = false;
  bool _failed = false;
  final _authenticator = TwitchAuthenticator(
    clientId: twitchClientId,
    clientSecret: twitchClientSecret,
    oauthRedirectUrl: twitchOauthRedirectUrl,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_login2Twitch());
  }

  @override
  void dispose() {
    unawaited(_authenticator.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _failed
                  ? context.localizations.twitch_login_failed
                  : 'Please, Login to Twitch via browser',
              style: const TextStyle(color: Colors.white),
            ),
            if (!_loggingIn)
              TextButton(
                onPressed: () => unawaited(_login2Twitch()),
                child: Text(context.localizations.music_settings_retry),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _login2Twitch() async {
    if (_loggingIn) return;
    setState(() {
      _loggingIn = true;
      _failed = false;
    });
    try {
      final creds = await _authenticator.login();
      if (!mounted) return;
      if (creds == null) {
        _failed = true;
      } else {
        await widget.settings.saveTwitchAuth(creds);
      }
    } catch (_) {
      if (mounted) _failed = true;
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }
}
