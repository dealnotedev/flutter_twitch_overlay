import 'dart:io';

import 'package:flutter/material.dart';
import 'package:obssource/config/obs_config.dart';
import 'package:obssource/di/app_service_locator.dart';
import 'package:obssource/di/service_locator.dart';
import 'package:obssource/l10n/app_localizations.dart';
import 'package:obssource/local_server.dart';
import 'package:obssource/logged_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final obsConfig = ObsConfig();
  await obsConfig.init();

  final localServer = LocalServer();
  localServer.run();

  final locator = AppServiceLocator.init(localServer);

  runApp(MyApp(locator: locator));

  print('APP STARTED ${Platform.resolvedExecutable}');
}

class MyApp extends StatelessWidget {
  final ServiceLocator locator;

  const MyApp({super.key, required this.locator});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.transparent,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en'), Locale('uk')],
      locale: Locale('uk'),
      theme: ThemeData(
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

  Widget _createRoot(BuildContext context) {
    return LoggedWidget(locator: widget.locator);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _createRoot(context),
    );
  }
}
