import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:onramper_flutter/onramper_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'app/demo_controller.dart';
import 'app/session_token_service.dart';
import 'config/environments.dart';
import 'logging/log_file_store.dart';
import 'logging/log_settings.dart';
import 'logging/share_log_file.dart';
import 'platform/ios_diagnostics.dart';
import 'screens/buy_crypto_screen.dart';
import 'theme/demo_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final logSettings = await LogSettings.load();
  final logStore = LogFileStore(
    directory: () async =>
        Directory('${(await getApplicationSupportDirectory()).path}/Logs'),
    launchHeader: IosDiagnostics.launchHeader,
    excludeFromBackup: IosDiagnostics.excludeFromBackup,
    shareDirectory: getTemporaryDirectory,
  );
  runApp(ExampleApp(logSettings: logSettings, logStore: logStore));
}

OnramperClient defaultClientFactory(
  OnramperConfiguration configuration,
  SessionExpirationHandler onSessionExpired,
) =>
    OnramperClient(
      configuration: configuration,
      sessionExpirationHandler: onSessionExpired,
    );

Future<SessionCredentials> defaultMintSession(ResolvedEnvironment env) =>
    SessionTokenService.fetch(
      authToken: env.demoToken,
      endpoint: env.sessionEndpoint,
    );

class ExampleApp extends StatefulWidget {
  const ExampleApp({
    super.key,
    required this.logSettings,
    required this.logStore,
    this.clientFactory = defaultClientFactory,
    this.mintSession = defaultMintSession,
    this.defines = demoDefines,
    this.shareFile = shareLogFile,
  });

  final LogSettings logSettings;
  final LogFileStore logStore;
  final ClientFactory clientFactory;
  final SessionMinter mintSession;
  final Map<String, String> defines;
  final ShareLogFile shareFile;

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  late final DemoController _demo;
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _demo = DemoController(
      clientFactory: widget.clientFactory,
      mintSession: widget.mintSession,
      defines: widget.defines,
      onSdkLog: (record) {
        if (widget.logSettings.enabled) {
          unawaited(widget.logStore.append(record));
        }
      },
    );
    _isDark = _demo.isDark;
    _demo.addListener(_onDemoChanged);
  }

  /// Only the theme lives up here; the screen listens to everything else, so
  /// SDK state and events don't rebuild the MaterialApp.
  void _onDemoChanged() {
    if (_demo.isDark != _isDark) setState(() => _isDark = _demo.isDark);
  }

  @override
  void dispose() {
    _demo.removeListener(_onDemoChanged);
    _demo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = DemoPalette.of(_isDark);
    return DemoTheme(
      palette: palette,
      child: MaterialApp(
        title: 'Onramper Flutter Demo',
        debugShowCheckedModeBanner: false,
        theme: buildMaterialTheme(palette),
        home: BuyCryptoScreen(
          demo: _demo,
          logSettings: widget.logSettings,
          logStore: widget.logStore,
          shareFile: widget.shareFile,
        ),
      ),
    );
  }
}
