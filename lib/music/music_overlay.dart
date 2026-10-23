import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/di/app_service_locator.dart';
import 'package:obssource/di/service_locator.dart';
import 'package:obssource/music/music_player_visuals.dart';
import 'package:obssource/music/music_queue_overlay.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/music/music_settings.dart';
import 'package:obssource/music/turntable_music_player.dart';
import 'package:obssource/secrets.dart';
import 'package:obssource/settings/overlay_settings_dialog.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/ws_event.dart';
import 'package:obssource/twitch/ws_manager.dart';

/// Adds music and its settings without coupling them to overlay effects.
class MusicOverlay extends StatefulWidget {
  final ServiceLocator locator;
  final Widget child;

  const MusicOverlay({super.key, required this.locator, required this.child});

  @override
  State<MusicOverlay> createState() => _MusicOverlayState();
}

class _MusicOverlayState extends State<MusicOverlay> {
  late final Settings _settings;
  late final MusicRequests _requests;
  final _controller = MusicQueueOverlayController();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  bool _hovered = false;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    _settings = widget.locator.provide();
    _requests = widget.locator.provide();
    _subscriptions.addAll([
      _settings.musicChanges.listen(_changed),
      _settings.playerPresentationChanges.listen(_changed),
      _settings.twitchAuthChanges.listen(_changed),
    ]);
    final locator = widget.locator;
    if (locator is AppServiceLocator) {
      _lifecycle = AppLifecycleListener(
        onExitRequested: () async {
          await locator.close();
          return AppExitResponse.exit;
        },
        onDetach: () => unawaited(locator.close()),
      );
      _subscriptions.add(
        locator.provide<WebSocketManager>().messages.listen(_handleMessage),
      );
    }
  }

  void _changed(dynamic _) {
    if (mounted) setState(() {});
  }

  void _handleMessage(WsMessage message) {
    if (message.payload.subscription?.type == 'channel.chat.message' &&
        message.payload.event?.message?.text?.trim().toLowerCase() ==
            '!music') {
      _controller.expand();
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _lifecycle?.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _showSettings() {
    final locator = widget.locator;
    showDialog<void>(
      context: context,
      barrierColor: MusicPlayerPalette.voidBlack.withValues(alpha: 0.82),
      builder:
          (_) => OverlaySettingsDialog(
            settings: _settings,
            configureRewards: _settings.twitchAuth != null,
            musicSource:
                locator is AppServiceLocator ? locator.musicSource : null,
            rewardCatalog: TwitchApiRewardCatalog(
              api: TwitchApi(
                settings: _settings,
                clientSecret: twitchClientSecret,
              ),
              settings: _settings,
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authenticated = _settings.twitchAuth != null;
    final external = _settings.music.source == MusicSourceKind.external;
    final turntable = _settings.music.playerStyle == MusicPlayerStyle.turntable;
    return LayoutBuilder(
      builder:
          (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              if (authenticated || !external) widget.child,
              if (authenticated || external)
                Positioned(
                  right: turntable ? 0 : 24,
                  bottom: 24,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          (constraints.maxWidth - (turntable ? 24 : 48))
                              .clamp(82.0, 520.0)
                              .toDouble(),
                    ),
                    child:
                        turntable
                            ? TurntableMusicPlayer(
                              requests: _requests,
                              loadVuProfile:
                                  widget.locator is AppServiceLocator
                                      ? (widget.locator as AppServiceLocator)
                                          .musicSource
                                          .vuProfileFor
                                      : null,
                            )
                            : MusicQueueOverlay(
                              requests: _requests,
                              controller: _controller,
                              collapseDelay: Duration(
                                seconds: _settings.playerCollapseSeconds,
                              ),
                              alwaysExpanded: _settings.playerAlwaysExpanded,
                            ),
                  ),
                ),
              Positioned(
                top: 6,
                right: 16,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _hovered = true),
                  onExit: (_) => setState(() => _hovered = false),
                  child: SizedBox(
                    width: 56,
                    height: 40,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IgnorePointer(
                        ignoring: authenticated && !_hovered,
                        child: AnimatedOpacity(
                          opacity: !authenticated || _hovered ? 1 : 0,
                          duration: const Duration(milliseconds: 160),
                          child: NeonMusicIconButton(
                            key: ValueKey(
                              authenticated
                                  ? 'overlay_settings_button'
                                  : 'unauthenticated_settings',
                            ),
                            icon: Icons.settings_rounded,
                            onPressed: _showSettings,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
    );
  }
}
