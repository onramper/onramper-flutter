import 'package:flutter/material.dart';
import 'package:onramper_sdk/onramper_sdk.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Onramper SDK example',
      home: const ExampleHome(),
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

  static const _apiKey = String.fromEnvironment('ONRAMPER_API_KEY', defaultValue: '');
  static const _clientId = String.fromEnvironment('ONRAMPER_CLIENT_ID', defaultValue: '');
  static const _sessionId = String.fromEnvironment('ONRAMPER_SESSION_ID', defaultValue: '');
  static const _sessionToken = String.fromEnvironment('ONRAMPER_SESSION_TOKEN', defaultValue: '');
  static const _walletAddress = String.fromEnvironment(
    'ONRAMPER_WALLET_ADDRESS',
    defaultValue: 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
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
      sessionExpirationHandler: () async => const SessionCredentials(
        sessionId: _sessionId,
        sessionToken: _sessionToken,
      ),
    );
    _client.events.listen(_onEvent);
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
      _statusMessage = 'initializing…';
    });
    try {
      await _client.initialize(sessionId: _sessionId, sessionToken: _sessionToken);
      setState(() => _statusMessage = 'fetching checkout requirements…');
      final requirements = await _client.getCheckoutRequirements(
        const CheckoutIntentRequest(
          transactionData: OnramperTransactionData(
            onramp: 'transak',
            source: 'usd',
            destination: 'btc',
            amount: 100,
            type: TransactionType.buy,
            country: 'us',
            paymentMethod: 'credit_debit_card',
            wallet: WalletInfo(network: 'bitcoin', address: _walletAddress),
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
              _buildHeader(),
              const SizedBox(height: 24),
              if (_requirements == null)
                ElevatedButton(
                  onPressed: _busy ? null : _prepareCheckout,
                  child: Text(_busy ? 'Preparing…' : 'Prepare checkout'),
                )
              else
                OnramperCheckoutButton(
                  client: _client,
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
    if (_apiKey.isEmpty || _clientId.isEmpty || _sessionId.isEmpty || _sessionToken.isEmpty) {
      return const _MissingEnvBanner();
    }
    return const Text(
      'Buy 100 USD of BTC via Transak (sandbox).',
      style: TextStyle(fontSize: 14),
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
        'Set ONRAMPER_API_KEY, ONRAMPER_CLIENT_ID, ONRAMPER_SESSION_ID, '
        'ONRAMPER_SESSION_TOKEN via --dart-define before running.',
        style: TextStyle(fontSize: 12),
      ),
    );
  }
}
