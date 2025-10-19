import 'dart:async';

import 'package:flutter/material.dart';
import 'package:obssource/data/events.dart';
import 'package:obssource/di/service_locator.dart';
import 'package:obssource/kill_widget.dart';
import 'package:obssource/local_server.dart';

class LoggedWidget extends StatefulWidget {
  final ServiceLocator locator;

  const LoggedWidget({super.key, required this.locator});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<LoggedWidget> {

  StreamSubscription<KillInfo>? _killsSubscription;

  late LocalServer _localServer;

  @override
  void initState() {
    _localServer = widget.locator.provide();
    _killsSubscription = _localServer.kills.listen(_handleKill);
    super.initState();
  }

  @override
  void dispose() {
    _killsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kill = _kill;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            if (kill != null) ...[
              _createKillWidget(context, kill: kill, constraints: constraints),
            ],
          ],
        );
      },
    );
  }

  Widget _createKillWidget(BuildContext context, {
    required KillInfo kill,
    required BoxConstraints constraints,
  }) {
    return KillWidget(text: kill.text,
        constraints: constraints,
        key: ValueKey(kill),
        streak: kill.inMatch);
  }

  KillInfo? _kill;

  Completer<KillInfo>? _killCompleter;

  void _handleKill(KillInfo kill) async {
    await _killCompleter?.future;

    _killCompleter = Completer();

    setState(() {
      _kill = kill;
    });

    await Future.delayed(Duration(seconds: 3));

    setState(() {
      _kill = null;
    });

    _killCompleter?.complete(kill);
  }
}