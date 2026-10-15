// Example demonstrating the onramper_flutter integration:
//
//   1. Create an OnramperClient with your API key, client ID, and a
//      sessionExpirationHandler that mints credentials from your backend.
//   2. Call client.initialize() with a fresh (sessionId, sessionToken) pair.
//   3. Call client.getCheckoutRequirements() to fetch the quote + requirements
//      (optionally with prefill from the "Prefill (optional)" form).
//   4. Embed OnramperCheckoutButton — it handles login, finalize, and payment.
//
// Also shows: plugin/SDK versions and the current transaction id, a
// "New quote" button (re-quotes; superseded calls are ignored), and an SDK
// log viewer (app-bar icon) fed by OnramperConfiguration.logHandler.
//
// Credentials are injected at build time via --dart-define-from-file=.env.
// See the README for setup instructions.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onramper_flutter/onramper_flutter.dart';

import 'ios_diagnostics.dart';
import 'log_buffer.dart';
import 'log_viewer_sheet.dart';
import 'prefill_form.dart';
import 'session_token_service.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Onramper SDK example',
      home: ExampleHome(),
    );
  }
}

class ExampleHome extends StatefulWidget {
  const ExampleHome({super.key});

  @override
  State<ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<ExampleHome> {
  OnramperClient? _client;
  StreamSubscription<CheckoutEvent>? _eventSub;
  final LogBuffer _logs = LogBuffer();
  final PrefillController _prefill = PrefillController();
  OnramperLogLevel _logLevel = OnramperLogLevel.info;
  String? _sdkVersion;
  CheckoutRequirementsResult? _requirements;
  String? _statusMessage;
  String? _errorMessage;
  bool _busy = false;
  IosAppIdentifiers? _appIdentifiers;

  static const _apiKey = String.fromEnvironment(
    'ONRAMPER_API_KEY',
    defaultValue: '',
  );
  static const _clientId = String.fromEnvironment(
    'ONRAMPER_CLIENT_ID',
    defaultValue: '',
  );
  static const _demoAuthToken = String.fromEnvironment(
    'ONRAMPER_DEMO_AUTH_TOKEN',
    defaultValue: '',
  );
  static const _walletAddress = String.fromEnvironment(
    'ONRAMPER_WALLET_ADDRESS',
    defaultValue: 'Br2jjHYskB1JJikv3Qw2QcmWVQGfZvkJFng4ZEwiGSjv',
  );

  @override
  void initState() {
    super.initState();
    _client = _buildClient();
    _loadAppIdentifiers();
    _loadSdkVersion();
  }

  Future<void> _loadSdkVersion() async {
    try {
      final v = await OnramperClient.sdkVersion();
      if (mounted) setState(() => _sdkVersion = v);
    } catch (e) {
      debugPrint('sdkVersion failed: $e');
    }
  }

  OnramperClient _buildClient() {
    final client = OnramperClient(
      configuration: OnramperConfiguration(
        apiKey: _apiKey,
        clientId: _clientId,
        environment: OnramperEnvironment.development,
        logLevel: _logLevel,
        logHandler: _logs.add,
      ),
      sessionExpirationHandler: () =>
          SessionTokenService.fetch(authToken: _demoAuthToken),
    );
    _eventSub = client.events.listen(_onEvent);
    return client;
  }

  /// Log level is fixed at configure time, so changing it rebuilds the client
  /// and drops the current quote.
  Future<void> _changeLogLevel(OnramperLogLevel level) async {
    if (level == _logLevel) return;
    await _eventSub?.cancel();
    final old = _client;
    setState(() {
      _client = null;
      _requirements = null;
      _logLevel = level;
      _statusMessage = 'log level → ${level.name}; prepare a new quote';
    });
    await old?.dispose();
    if (mounted) setState(() => _client = _buildClient());
  }

  Future<void> _loadAppIdentifiers() async {
    try {
      final ids = await IosDiagnostics.readAppIdentifiers();
      debugPrint(
        'App launched with bundleId=${ids.bundleId} teamId=${ids.teamId}',
      );
      if (mounted) setState(() => _appIdentifiers = ids);
    } catch (e) {
      debugPrint('readAppIdentifiers failed: $e');
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _client?.dispose();
    _logs.dispose();
    _prefill.dispose();
    super.dispose();
  }

  void _onEvent(CheckoutEvent event) {
    final client = _client;
    setState(() {
      switch (event.kind) {
        case CheckoutEventKind.paymentPending:
          _statusMessage = 'payment processing — transaction '
              '${client?.currentTransactionId ?? '—'}';
        case CheckoutEventKind.completed:
          _statusMessage = 'completed — transaction '
              '${client?.currentTransactionId ?? '—'}';
        case CheckoutEventKind.failed:
          final e = event.error;
          _statusMessage = 'event: failed';
          if (e != null) _errorMessage = _describe(e);
        default:
          _statusMessage = 'event: ${event.kind.name}';
      }
    });
  }

  String _describe(OnramperError e) =>
      '${e.userMessage}\nError code: ${e.supportCode}';

  Future<void> _prepareCheckout() async {
    final client = _client;
    if (client == null) return;
    setState(() {
      _busy = true;
      // Hide the previous button: once a new preparation starts, the old one
      // no longer addresses the current checkout.
      _requirements = null;
      _errorMessage = null;
      _statusMessage = 'minting session…';
    });
    try {
      final credentials =
          await SessionTokenService.fetch(authToken: _demoAuthToken);
      setState(() => _statusMessage = 'initializing…');
      await client.initialize(
        sessionId: credentials.sessionId,
        sessionToken: credentials.sessionToken,
      );
      setState(() => _statusMessage = 'fetching checkout requirements…');
      final requirements = await client.getCheckoutRequirements(
        const CheckoutIntentRequest(
          transactionData: OnramperTransactionData(
            source: 'usd',
            destination: 'sol',
            amount: 100,
            type: TransactionType.buy,
            country: 'us',
            subdivision: 'us-ca',
            paymentMethod: 'applepay',
            wallet: WalletInfo(network: 'solana', address: _walletAddress),
          ),
        ),
        prefill: _prefill.build(),
      );
      setState(() {
        _requirements = requirements;
        _statusMessage = 'ready — tap Buy';
      });
    } on OnramperError catch (e) {
      // Superseded by a newer "New quote" tap; the newer call reports.
      if (e.kind == OnramperErrorKind.intentInvalidated) return;
      setState(() {
        _errorMessage = _describe(e);
        _statusMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _statusMessage = null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Onramper SDK example'),
        actions: [
          IconButton(
            tooltip: 'SDK logs',
            icon: const Icon(Icons.article_outlined),
            onPressed: () => showLogViewer(context, _logs),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_appIdentifiers != null)
                _IdentifiersBanner(identifiers: _appIdentifiers!),
              if (_appIdentifiers != null) const SizedBox(height: 4),
              _VersionsBanner(sdkVersion: _sdkVersion, client: client),
              const SizedBox(height: 12),
              _buildHeader(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'SDK log level (rebuilds client; needs a new quote)',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  DropdownButton<OnramperLogLevel>(
                    value: _logLevel,
                    onChanged: _busy
                        ? null
                        : (v) {
                            if (v != null) _changeLogLevel(v);
                          },
                    items: const [
                      OnramperLogLevel.off,
                      OnramperLogLevel.error,
                      OnramperLogLevel.info,
                      OnramperLogLevel.debug,
                    ]
                        .map((l) =>
                            DropdownMenuItem(value: l, child: Text(l.name)))
                        .toList(),
                  ),
                ],
              ),
              PrefillForm(controller: _prefill),
              const SizedBox(height: 16),
              if (_requirements == null)
                ElevatedButton(
                  onPressed: _busy || client == null ? null : _prepareCheckout,
                  child: Text(_busy ? 'Preparing…' : 'Prepare checkout'),
                )
              else ...[
                OnramperCheckoutButton(requirements: _requirements!),
                TextButton(
                  onPressed: _busy ? null : _prepareCheckout,
                  child: const Text('New quote'),
                ),
              ],
              const SizedBox(height: 16),
              if (_statusMessage != null) Text('Status: $_statusMessage'),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    if (_apiKey.isEmpty || _clientId.isEmpty || _demoAuthToken.isEmpty) {
      return const _MissingEnvBanner();
    }
    return const Text(
      'Buy 100 USD of SOL via Apple Pay (sandbox). Tap "Prepare checkout" to '
      'mint a demo session and fetch requirements.',
      style: TextStyle(fontSize: 14),
    );
  }
}

class _IdentifiersBanner extends StatelessWidget {
  const _IdentifiersBanner({required this.identifiers});

  final IosAppIdentifiers identifiers;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bundle: ${identifiers.bundleId}',
            style: const TextStyle(fontSize: 12, fontFamily: 'Courier'),
          ),
          Text(
            'Team:   ${identifiers.teamId}',
            style: const TextStyle(fontSize: 12, fontFamily: 'Courier'),
          ),
        ],
      ),
    );
  }
}

class _MissingEnvBanner extends StatelessWidget {
  const _MissingEnvBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Pass ONRAMPER_API_KEY, ONRAMPER_CLIENT_ID, and ONRAMPER_DEMO_AUTH_TOKEN '
        'via --dart-define before running. The demo auth token authorises the '
        'session-minting endpoint at demo-stg.onramper.dev.',
        style: TextStyle(fontSize: 12),
      ),
    );
  }
}

class _VersionsBanner extends StatelessWidget {
  const _VersionsBanner({required this.sdkVersion, required this.client});

  final String? sdkVersion;
  final OnramperClient? client;

  @override
  Widget build(BuildContext context) {
    const mono = TextStyle(fontSize: 12, fontFamily: 'Courier');
    final c = client;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Plugin: ${OnramperClient.wrapperVersion}', style: mono),
          Text('SDK:    ${sdkVersion ?? '…'}', style: mono),
          if (c != null)
            ListenableBuilder(
              listenable: c,
              builder: (_, __) => SelectableText(
                'Txn:    ${c.currentTransactionId ?? '—'}',
                style: mono,
              ),
            ),
        ],
      ),
    );
  }
}
