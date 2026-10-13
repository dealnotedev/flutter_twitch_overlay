import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:obssource/config/avatar_settings.dart';
import 'package:obssource/config/obs_config.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/di/app_service_locator.dart';
import 'package:obssource/di/service_locator.dart';
import 'package:obssource/effects/effect_runtime.dart';
import 'package:obssource/effects/effect_stage.dart';
import 'package:obssource/events/alert_event.dart';
import 'package:obssource/events/alert_event_mapper.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/music/music_player_visuals.dart';
import 'package:obssource/music/music_queue_overlay.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/pixels/pixel_rain_avatar.dart';
import 'package:obssource/secrets.dart';
import 'package:obssource/settings/overlay_settings_dialog.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/ws_event.dart';
import 'package:obssource/twitch/ws_manager.dart';

class LoggedWidget extends StatefulWidget {
  final ServiceLocator locator;
  final Future<img.Image?> Function(String url)? avatarLoader;
  final Future<UserDto?> Function(String id)? userLoader;
  final TwitchRewardCatalog? rewardCatalog;

  const LoggedWidget({
    super.key,
    required this.locator,
    this.avatarLoader,
    this.userLoader,
    this.rewardCatalog,
  });

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<LoggedWidget> {
  StreamSubscription<WsMessage>? _eventsSubscription;
  StreamSubscription<WsStateEvent>? _stateSubscription;
  StreamSubscription<AvatarSettings>? _avatarSettingsSubscription;
  StreamSubscription<void>? _playerSettingsSubscription;
  late Settings _settings;
  late ObsConfig _obsConfig;
  late WsState _wsState;
  late AvatarSettings _avatar;
  late EffectRuntime _runtime;
  late AlertEventMapper _mapper;
  MusicRequests? _musicRequests;
  final _musicOverlayController = MusicQueueOverlayController();
  bool _overlayControlsHovered = false;

  @override
  void initState() {
    super.initState();

    _settings = widget.locator.provide();
    _playerSettingsSubscription = _settings.playerPresentationChanges.listen((
      _,
    ) {
      if (mounted) setState(() {});
    });
    _obsConfig = widget.locator.provide();
    _avatar = _settings.avatar;
    try {
      _musicRequests = widget.locator.provide<MusicRequests>();
    } catch (_) {
      // Older test and debug locators may not provide music requests yet.
    }
    _avatarSettingsSubscription = _settings.avatarChanges.listen(
      _handleAvatarSettings,
    );

    _runtime = EffectRuntime(
      alerts: () => _settings.alerts,
      loadUser: _loadUser,
      loadAvatar: widget.avatarLoader ?? RainyAvatar.loadImageFromUrl,
    );
    _mapper = AlertEventMapper(
      broadcasterId: () => _settings.twitchAuth?.broadcasterId,
    );

    final ws = widget.locator.provide<WebSocketManager>();
    _wsState = ws.currentState;
    _eventsSubscription = ws.messages.listen(_handleWebsocketMessage);
    _stateSubscription = ws.state.listen(_handleWebsocketState);
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _stateSubscription?.cancel();
    _avatarSettingsSubscription?.cancel();
    _playerSettingsSubscription?.cancel();
    _runtime.dispose();
    _musicOverlayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            _createConfigInfo(context),
            Positioned.fill(
              child: EffectStage(
                runtime: _runtime,
                constraints: constraints,
                avatar: _avatar,
                foreground: _createMusicPlayer(constraints),
              ),
            ),
            _createOverlayControls(context),
          ],
        );
      },
    );
  }

  Widget? _createMusicPlayer(BoxConstraints constraints) {
    final musicRequests = _musicRequests;
    if (musicRequests == null) return null;

    return Positioned(
      right: 24,
      bottom: 24,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (constraints.maxWidth - 48).clamp(82.0, 520.0).toDouble(),
        ),
        child: MusicQueueOverlay(
          requests: musicRequests,
          controller: _musicOverlayController,
          collapseDelay: Duration(seconds: _settings.playerCollapseSeconds),
          alwaysExpanded: _settings.playerAlwaysExpanded,
        ),
      ),
    );
  }

  Widget _createOverlayControls(BuildContext context) {
    return Positioned(
      top: 6,
      right: 16,
      child: MouseRegion(
        opaque: true,
        onEnter: (_) => setState(() => _overlayControlsHovered = true),
        onExit: (_) => setState(() => _overlayControlsHovered = false),
        child: SizedBox(
          width: 56,
          height: 40,
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              Positioned(
                left: 0,
                child: IgnorePointer(
                  ignoring: !_overlayControlsHovered,
                  child: AnimatedOpacity(
                    key: const ValueKey('overlay_settings_button_reveal'),
                    opacity: _overlayControlsHovered ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: NeonMusicIconButton(
                      key: const ValueKey('overlay_settings_button'),
                      icon: Icons.settings_rounded,
                      onPressed: _showOverlaySettings,
                    ),
                  ),
                ),
              ),
              Container(
                key: const ValueKey('connection_indicator'),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color:
                      _wsState == WsState.connected
                          ? const Color(0xFF51FD0B)
                          : const Color(0xFFCD0017),
                  boxShadow: [
                    BoxShadow(
                      color: (_wsState == WsState.connected
                              ? const Color(0xFF51FD0B)
                              : const Color(0xFFCD0017))
                          .withValues(alpha: 0.55),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOverlaySettings() {
    final appLocator = widget.locator;
    final rewardCatalog =
        widget.rewardCatalog ??
        TwitchApiRewardCatalog(
          api: TwitchApi(settings: _settings, clientSecret: twitchClientSecret),
          settings: _settings,
        );
    showDialog<void>(
      context: context,
      barrierColor: MusicPlayerPalette.voidBlack.withValues(alpha: 0.82),
      builder:
          (_) => OverlaySettingsDialog(
            settings: _settings,
            rewardCatalog: rewardCatalog,
            musicServer:
                appLocator is AppServiceLocator
                    ? appLocator.musicControlServer
                    : null,
            musicRewardController:
                appLocator is AppServiceLocator
                    ? appLocator.musicRewardController
                    : null,
            youtubeConnection:
                appLocator is AppServiceLocator
                    ? appLocator.youtubeConnection
                    : null,
            musicRequests:
                appLocator is AppServiceLocator
                    ? appLocator.musicRequests
                    : null,
          ),
    );
  }

  Widget _createConfigInfo(BuildContext context) {
    return StreamBuilder<Config>(
      stream: _obsConfig.config.changes,
      initialData: _obsConfig.config.current,
      builder: (context, snapshot) {
        if (snapshot.requireData.valid) {
          return const SizedBox.shrink();
        }

        return Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            key: const ValueKey('invalid_obs_config_indicator'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.red,
            ),
            child: Text(
              context.localizations.config_invalid,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleWebsocketState(WsStateEvent event) {
    if (!mounted) return;

    setState(() {
      _wsState = event.current;
    });
  }

  void _handleAvatarSettings(AvatarSettings value) {
    if (!mounted ||
        (value.renderer == _avatar.renderer &&
            value.resolution == _avatar.resolution)) {
      return;
    }

    setState(() {
      _avatar = value;
    });
  }

  void _handleWebsocketMessage(WsMessage message) {
    final event = _mapper.map(message);
    if (event == null) return;

    if (event is ChatEvent && event.text.trim().toLowerCase() == '!music') {
      _musicOverlayController.expand();
    }
    _runtime.handle(event);
  }

  Future<UserDto?> _loadUser(String id) {
    final loader = widget.userLoader;
    if (loader != null) return loader(id);
    return TwitchApi(
      settings: _settings,
      clientSecret: twitchClientSecret,
    ).getUser(id: id);
  }
}
