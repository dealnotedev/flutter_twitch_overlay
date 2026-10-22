import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:obssource/config/obs_config.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/di/app_service_locator.dart';
import 'package:obssource/di/service_locator.dart';
import 'package:obssource/l10n/app_localizations.dart';
import 'package:obssource/logged_widget.dart';
import 'package:obssource/music/music_queue_overlay.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/music/music_settings.dart';
import 'package:obssource/music/turntable_music_player.dart';
import 'package:obssource/secrets.dart';
import 'package:obssource/settings/overlay_settings_dialog.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/twitch_login_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = Settings();
  await settings.init();

  final obsConfig = ObsConfig();
  await obsConfig.init();

  final locator = AppServiceLocator.init(settings, obsConfig);

  runApp(MyApp(locator: locator));
}

class MyApp extends StatelessWidget {
  final ServiceLocator locator;

  const MyApp({super.key, required this.locator});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.transparent,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en'), Locale('uk')],
      locale: Locale('uk'),
      theme: ThemeData(
        fontFamily: 'RobotoMono',
        useMaterial3: false,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
        ).copyWith(surface: Colors.transparent),
      ),
      home: MyHomePage(locator: locator),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final ServiceLocator locator;

  const MyHomePage({super.key, required this.locator});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final Settings _settings;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    _settings = widget.locator.provide();
    final locator = widget.locator;
    if (locator is AppServiceLocator) {
      _lifecycle = AppLifecycleListener(
        onExitRequested: () async {
          await locator.close();
          return AppExitResponse.exit;
        },
        onDetach: () => unawaited(locator.close()),
      );
    }
    super.initState();
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  Widget _createRoot(BuildContext context) {
    return StreamBuilder(
      stream: _settings.twitchAuthChanges,
      initialData: _settings.twitchAuth,
      builder: (cntx, snapshot) {
        final data = snapshot.data;
        if (data != null) {
          return LoggedWidget(locator: widget.locator);
        } else {
          return Stack(
            children: [
              if (_settings.music.source == MusicSourceKind.local)
                Center(child: TwitchLoginWidget(settings: _settings))
              else
                _ExternalPlayerView(
                  settings: _settings,
                  requests: widget.locator.provide<MusicRequests>(),
                ),
              Positioned(
                top: 8,
                right: 16,
                child: IconButton(
                  key: const ValueKey('unauthenticated_settings'),
                  icon: const Icon(Icons.settings_rounded, color: Colors.white),
                  onPressed: () {
                    final locator = widget.locator;
                    showDialog<void>(
                      context: context,
                      builder:
                          (_) => OverlaySettingsDialog(
                            settings: _settings,
                            configureRewards: false,
                            musicSource:
                                locator is AppServiceLocator
                                    ? locator.musicSource
                                    : null,
                            rewardCatalog: TwitchApiRewardCatalog(
                              api: TwitchApi(
                                settings: _settings,
                                clientSecret: twitchClientSecret,
                              ),
                              settings: _settings,
                            ),
                          ),
                    );
                  },
                ),
              ),
            ],
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder(
        stream: _settings.musicChanges,
        builder: (context, _) => _createRoot(context),
      ),
    );
  }
}

/// Music remains available without a Twitch session in the OBS process.
class _ExternalPlayerView extends StatelessWidget {
  final Settings settings;
  final MusicRequests requests;
  const _ExternalPlayerView({required this.settings, required this.requests});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final turntable =
          settings.music.playerStyle == MusicPlayerStyle.turntable;
      return Stack(
        children: [
          Positioned(
            right: turntable ? 0 : 24,
            bottom: 24,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (constraints.maxWidth - (turntable ? 24 : 48)).clamp(
                  82.0,
                  520.0,
                ),
              ),
              child:
                  turntable
                      ? TurntableMusicPlayer(requests: requests)
                      : MusicQueueOverlay(
                        requests: requests,
                        collapseDelay: Duration(
                          seconds: settings.playerCollapseSeconds,
                        ),
                        alwaysExpanded: settings.playerAlwaysExpanded,
                      ),
            ),
          ),
        ],
      );
    },
  );
}
