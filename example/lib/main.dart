// Minimal example demonstrating the four-step onramper_sdk integration:
//
//   1. Create an OnramperClient with your API key, client ID, and a
//      sessionExpirationHandler that mints credentials from your backend.
//   2. Call client.initialize() with a fresh (sessionId, sessionToken) pair.
//   3. Call client.getCheckoutRequirements() to fetch the quote + requirements.
//   4. Embed OnramperCheckoutButton — it handles login, finalize, and payment.
//
// Credentials are injected at build time via --dart-define-from-file=.env.
// See the README for setup instructions.

import 'package:flutter/material.dart';
import 'package:onramper_sdk/onramper_sdk.dart';

import 'ios_diagnostics.dart';
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
  late final OnramperClient _client;
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
    _client = OnramperClient(
      configuration: const OnramperConfiguration(
        apiKey: _apiKey,
        clientId: _clientId,
        environment: OnramperEnvironment.development,
        logLevel: OnramperLogLevel.debug,
      ),
      sessionExpirationHandler: () =>
          SessionTokenService.fetch(authToken: _demoAuthToken),
    );
    _client.events.listen(_onEvent);
    _loadAppIdentifiers();
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
    _client.dispose();
    super.dispose();
  }

  void _onEvent(CheckoutEvent event) {
    setState(() => _statusMessage = 'event: ${event.kind.name}');
  }

  Future<void> _prepareCheckout() async {
    setState(() {
      _busy = true;
      _errorMessage = null;
      _statusMessage = 'minting session…';
    });
    try {
      final credentials =
          await SessionTokenService.fetch(authToken: _demoAuthToken);
      setState(() => _statusMessage = 'initializing…');
      await _client.initialize(
        sessionId: credentials.sessionId,
        sessionToken: credentials.sessionToken,
      );
      setState(() => _statusMessage = 'fetching checkout requirements…');
      final requirements = await _client.getCheckoutRequirements(
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
      );
      setState(() {
        _requirements = requirements;
        _statusMessage = 'ready — tap Buy';
      });
    } on OnramperError catch (e) {
      setState(() {
        _errorMessage = '${e.kind.name}: ${e.message}';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Onramper SDK example')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_appIdentifiers != null)
                _IdentifiersBanner(identifiers: _appIdentifiers!),
              if (_appIdentifiers != null) const SizedBox(height: 12),
              _buildHeader(),
              const SizedBox(height: 24),
              if (_requirements == null)
                ElevatedButton(
                  onPressed: _busy ? null : _prepareCheckout,
                  child: Text(_busy ? 'Preparing…' : 'Prepare checkout'),
                )
              else
                OnramperCheckoutButton(
                  requirements: _requirements!,
                ),
              const SizedBox(height: 24),
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
