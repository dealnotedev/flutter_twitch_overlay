import 'package:flutter/material.dart';
import 'package:obssource/config/obs_config.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/di/app_service_locator.dart';
import 'package:obssource/di/service_locator.dart';
import 'package:obssource/l10n/app_localizations.dart';
import 'package:obssource/local_server.dart';
import 'package:obssource/logged_widget.dart';
import 'package:obssource/twitch/twitch_login_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = Settings();
  await settings.init();

  final obsConfig = ObsConfig();
  await obsConfig.init();

  final localServer = LocalServer();
  localServer.run();

  final locator = AppServiceLocator.init(settings, obsConfig, localServer);

  runApp(MyApp(locator: locator));
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

  @override
  void initState() {
    _settings = widget.locator.provide();
    super.initState();
  }

  Widget _createRoot(BuildContext context) {
    return StreamBuilder(
      stream: _settings.twitchAuthChanges,
      initialData: _settings.twitchAuth,
      builder: (cntx, snapshot) {
        final data = snapshot.data;
        if (data != null) {
          return LoggedWidget(creds: data, locator: widget.locator);
        } else {
          return Center(child: TwitchLoginWidget(settings: _settings));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _createRoot(context),
    );
  }
}
