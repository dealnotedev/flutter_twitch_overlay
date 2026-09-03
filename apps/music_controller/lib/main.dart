import 'dart:async';

import 'package:flutter/material.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/l10n/app_localizations.dart';
import 'package:obssource/music/control/music_control_protocol.dart';
import 'package:obssource/music/control/remote_music_requests.dart';
import 'package:obssource/music/music_player_visuals.dart';
import 'package:obssource/music/music_queue_overlay.dart';

void main(List<String> arguments) {
  WidgetsFlutterBinding.ensureInitialized();
  final port = _readPort(arguments);
  final requests = RemoteMusicRequests(
    endpoint: Uri.parse('http://127.0.0.1:$port'),
  );
  requests.start();
  runApp(MusicControllerApp(requests: requests));
}

int _readPort(List<String> arguments) {
  for (final argument in arguments) {
    if (!argument.startsWith('--port=')) continue;
    final value = int.tryParse(argument.substring('--port='.length));
    if (value != null && value > 0 && value <= 65535) return value;
  }
  return MusicControlProtocol.defaultPort;
}

class MusicControllerApp extends StatefulWidget {
  final RemoteMusicRequests requests;

  const MusicControllerApp({super.key, required this.requests});

  @override
  State<MusicControllerApp> createState() => _MusicControllerAppState();
}

class _MusicControllerAppState extends State<MusicControllerApp> {
  @override
  void dispose() {
    unawaited(widget.requests.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: MusicPlayerPalette.midnight,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('uk'),
      onGenerateTitle: (context) => context.localizations.music_control_title,
      theme: ThemeData(
        fontFamily: 'RobotoMono',
        useMaterial3: false,
        scaffoldBackgroundColor: MusicPlayerPalette.midnight,
        colorScheme: ColorScheme.fromSeed(
          seedColor: MusicPlayerPalette.neonPink,
          brightness: Brightness.dark,
        ),
      ),
      home: MusicControllerPage(requests: widget.requests),
    );
  }
}

class MusicControllerPage extends StatefulWidget {
  final RemoteMusicRequests requests;

  const MusicControllerPage({super.key, required this.requests});

  @override
  State<MusicControllerPage> createState() => _MusicControllerPageState();
}

class _MusicControllerPageState extends State<MusicControllerPage> {
  late MusicControlConnectionState _connection;
  late final StreamSubscription<MusicControlConnectionState> _subscription;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _connection = widget.requests.currentConnection;
    _subscription = widget.requests.connectionStates.listen((next) {
      if (!mounted) return;
      setState(() => _connection = next);
    });
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: MusicQueueOverlay(
              requests: widget.requests,
              alwaysExpanded: true,
              showWhenEmpty: true,
              maxVisibleQueueItems: null,
              presentation: MusicQueuePresentation.controllerCanvas,
              scrollController: _scrollController,
            ),
          ),
          const _PlayerStatusDivider(),
          _ConnectionStatus(
            state: _connection,
            endpoint: widget.requests.endpoint,
          ),
        ],
      ),
    );
  }
}

class _PlayerStatusDivider extends StatelessWidget {
  const _PlayerStatusDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      key: ValueKey('connection_status_divider'),
      height: 1,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0x003F4160),
              Color(0x993F4160),
              Color(0x003F4160),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  final MusicControlConnectionState state;
  final Uri endpoint;

  const _ConnectionStatus({required this.state, required this.endpoint});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (state.phase) {
      MusicControlConnectionPhase.connected => (
        Icons.link_rounded,
        const Color(0xFF51FD8B),
        context.localizations.music_control_connected,
      ),
      MusicControlConnectionPhase.connecting => (
        Icons.sync_rounded,
        const Color(0xFF53C9FF),
        context.localizations.music_control_connecting,
      ),
      MusicControlConnectionPhase.reconnecting => (
        Icons.sync_problem_rounded,
        const Color(0xFFFFC857),
        context.localizations.music_control_reconnecting(
          state.attempt,
          ((state.retryIn?.inMilliseconds ?? 0) / 1000).ceil(),
        ),
      ),
      MusicControlConnectionPhase.disconnected => (
        Icons.link_off_rounded,
        MusicPlayerPalette.error,
        context.localizations.music_control_disconnected,
      ),
      MusicControlConnectionPhase.incompatible => (
        Icons.error_outline_rounded,
        MusicPlayerPalette.error,
        context.localizations.music_control_incompatible,
      ),
      MusicControlConnectionPhase.closed => (
        Icons.power_settings_new_rounded,
        MusicPlayerPalette.textSecondary,
        context.localizations.music_control_closed,
      ),
    };

    return ColoredBox(
      key: const ValueKey('connection_status'),
      color: MusicPlayerPalette.voidBlack,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              key: const ValueKey('connection_status_icon'),
              color: color,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    key: const ValueKey('connection_status_label'),
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    endpoint.toString(),
                    style: const TextStyle(
                      color: MusicPlayerPalette.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                  if (state.lastError case final error?) ...[
                    const SizedBox(height: 4),
                    Text(
                      error,
                      key: const ValueKey('connection_last_error'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MusicPlayerPalette.error,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
