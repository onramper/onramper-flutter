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

import 'buy_form.dart';
import 'demo_environment.dart';
import 'ios_diagnostics.dart';
import 'log_buffer.dart';
import 'log_viewer_sheet.dart';
import 'prefill_form.dart';
import 'session_initializer.dart';
import 'session_token_service.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  // Starts from the device appearance; the in-app switch owns it afterwards
  // and is passed to the SDK as an explicit light/dark theme.
  late final ValueNotifier<bool> _dark = ValueNotifier(
    WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark,
  );

  @override
  void dispose() {
    _dark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _dark,
      builder: (context, dark, _) => MaterialApp(
        title: 'Onramper SDK example',
        theme: ThemeData(brightness: Brightness.light),
        darkTheme: ThemeData(brightness: Brightness.dark),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: ExampleHome(darkMode: _dark),
      ),
    );
  }
}

class ExampleHome extends StatefulWidget {
  const ExampleHome({
    super.key,
    required this.darkMode,
    this.sessionCredentialsProvider,
  });

  /// App-wide dark mode; drives both the Flutter theme and `OnramperTheme`.
  final ValueNotifier<bool> darkMode;

  /// Optional backend integration for obtaining fresh session credentials.
  final SessionExpirationHandler? sessionCredentialsProvider;

  @override
  State<ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<ExampleHome> {
  OnramperClient? _client;
  StreamSubscription<CheckoutEvent>? _eventSub;
  final LogBuffer _logs = LogBuffer();
  final PrefillController _prefill = PrefillController();
  OnramperLogLevel _logLevel = OnramperLogLevel.info;
  BuyForm _form = const BuyForm(wallet: _walletAddress);
  SessionInitializer _session = SessionInitializer();
  int _prepareGeneration = 0;
  String? _sdkVersion;
  CheckoutRequirementsResult? _requirements;
  String? _statusMessage;
  String? _errorMessage;
  bool _busy = false;
  IosAppIdentifiers? _appIdentifiers;

  DemoEnvironment _environment = DemoEnvironment.development;

  /// Selected environment with its `.env` secrets.
  ResolvedEnvironment get _env => _environment.resolve(demoDefines);

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
        apiKey: _env.apiKey,
        clientId: _env.clientId,
        environment: _env.sdkEnvironment,
        theme: widget.darkMode.value ? OnramperTheme.dark : OnramperTheme.light,
        logLevel: _logLevel,
        logHandler: _logs.add,
      ),
      sessionExpirationHandler: _fetchSessionCredentials,
    );
    _eventSub = client.events.listen(_onEvent);
    _session = SessionInitializer();
    return client;
  }

  Future<SessionCredentials> _fetchSessionCredentials() =>
      widget.sessionCredentialsProvider?.call() ??
      SessionTokenService.fetch(
        authToken: _env.demoToken,
        endpoint: _env.sessionEndpoint,
      );

  /// Log level and theme are fixed at configure time, so changing either
  /// rebuilds the client and drops the current quote.
  Future<void> _rebuildClient(String reason, VoidCallback apply) async {
    // Block other actions (including another rebuild) until the old client
    // is disposed and the new one exists; overlapping rebuilds would create
    // two native clients sharing the plugin's global channels.
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _eventSub?.cancel();
      final old = _client;
      _update(() {
        _client = null;
        _requirements = null;
        apply();
        _statusMessage = '$reason; prepare a new quote';
      });
      // Dispose the old client before creating the new one: the plugin's
      // callback registration is global.
      await old?.dispose();
      if (mounted) setState(() => _client = _buildClient());
    } finally {
      _update(() => _busy = false);
    }
  }

  Future<void> _changeLogLevel(OnramperLogLevel level) async {
    if (level == _logLevel) return;
    await _rebuildClient('log level → ${level.name}', () => _logLevel = level);
  }

  Future<void> _changeEnvironment(DemoEnvironment environment) async {
    if (environment == _environment) return;
    await _rebuildClient(
        'environment → ${environment.label}', () => _environment = environment);
  }

  Future<void> _changeDarkMode(bool dark) async {
    if (dark == widget.darkMode.value) return;
    await _rebuildClient('theme → ${dark ? 'dark' : 'light'}',
        () => widget.darkMode.value = dark);
  }

  /// Runs Reset / Log out and reports the outcome like other calls.
  Future<void> _runAction(
      String label, Future<void> Function(OnramperClient) action) async {
    final client = _client;
    if (client == null) return;
    setState(() {
      _busy = true;
      _requirements = null;
      _errorMessage = null;
    });
    try {
      await action(client);
      _update(() => _statusMessage = '$label OK');
    } on OnramperError catch (e) {
      _update(() => _errorMessage = _describe(e));
    } catch (e) {
      _update(() => _errorMessage = e.toString());
    } finally {
      _update(() => _busy = false);
    }
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
    _update(() {
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

  /// setState for async callbacks: the screen may be gone by the time an
  /// SDK call returns.
  void _update(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<void> _prepareCheckout() async {
    final client = _client;
    final request = _form.toRequest();
    if (client == null || request == null) return;
    final generation = ++_prepareGeneration;
    setState(() {
      _busy = true;
      // Hide the previous button: once a new preparation starts, the old one
      // no longer addresses the current checkout.
      _requirements = null;
      _errorMessage = null;
      _statusMessage = 'preparing…';
    });
    try {
      // Initialize once per client; reset/signOut keep the native session.
      await _session.ensureInitialized(() async {
        final credentials = await _fetchSessionCredentials();
        _update(() => _statusMessage = 'initializing…');
        await client.initialize(
          sessionId: credentials.sessionId,
          sessionToken: credentials.sessionToken,
        );
      });
      _update(() => _statusMessage = 'fetching checkout requirements…');
      final requirements = await client.getCheckoutRequirements(
        request,
        prefill: _prefill.build(),
      );
      _update(() {
        _requirements = requirements;
        _statusMessage = 'ready — tap Buy';
      });
    } on OnramperError catch (e) {
      // Superseded by a newer "New quote" tap; the newer call reports.
      if (e.kind == OnramperErrorKind.intentInvalidated) return;
      _update(() {
        _errorMessage = _describe(e);
        _statusMessage = null;
      });
    } catch (e) {
      _update(() {
        _errorMessage = e.toString();
        _statusMessage = null;
      });
    } finally {
      // A superseded prepare must not clear the busy state of a newer one.
      if (generation == _prepareGeneration) _update(() => _busy = false);
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
                  const Expanded(child: Text('Environment')),
                  SegmentedButton<DemoEnvironment>(
                    segments: [
                      for (final e in DemoEnvironment.values)
                        ButtonSegment(value: e, label: Text(e.label)),
                    ],
                    selected: {_environment},
                    onSelectionChanged:
                        _busy ? null : (s) => _changeEnvironment(s.first),
                  ),
                ],
              ),
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dark mode'),
                subtitle: const Text('Rebuilds the client with this theme',
                    style: TextStyle(fontSize: 12)),
                value: widget.darkMode.value,
                onChanged: _busy ? null : _changeDarkMode,
              ),
              _BuyFormFields(
                form: _form,
                enabled: !_busy,
                onChanged: (f) => setState(() {
                  _form = f;
                  // The prepared button still targets the previous purchase.
                  // Require a new quote before allowing checkout again.
                  _requirements = null;
                  _statusMessage = null;
                  _errorMessage = null;
                }),
              ),
              PrefillForm(controller: _prefill),
              const SizedBox(height: 16),
              if (_requirements == null)
                ElevatedButton(
                  onPressed:
                      _busy || client == null || _form.toRequest() == null
                          ? null
                          : _prepareCheckout,
                  child: Text(_busy ? 'Preparing…' : 'Prepare checkout'),
                )
              else ...[
                OnramperCheckoutButton(requirements: _requirements!),
                TextButton(
                  onPressed: _busy ? null : _prepareCheckout,
                  child: const Text('New quote'),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy || client == null
                          ? null
                          : () => _runAction('reset', (c) => c.reset()),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy || client == null
                          ? null
                          : () => _runAction('log out', (c) => c.signOut()),
                      child: const Text('Log out'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_statusMessage != null) Text('Status: $_statusMessage'),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(_errorMessage!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final env = _env;
    if (!env.isComplete) return _MissingEnvBanner(env: env);
    return Text(
      'Buy ${_form.amount.trim()} ${_form.fiat.label} of '
      '${_form.crypto.symbol} via Apple Pay (${_environment.label}). Tap '
      '"Prepare checkout" '
      'to mint a demo session and fetch requirements.',
      style: const TextStyle(fontSize: 14),
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
  const _MissingEnvBanner({required this.env});

  final ResolvedEnvironment env;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${env.environment.label} is missing ${env.missing.join(', ')}. Add '
        'them to example/.env (see .env.example) and run with '
        '--dart-define-from-file=.env. The demo auth token authorises '
        '${Uri.parse(env.sessionEndpoint).host}.',
        style: const TextStyle(fontSize: 12),
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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

/// Crypto, amount, wallet, country override, fiat and onramp filter — same
/// approach as the RN demo.
class _BuyFormFields extends StatefulWidget {
  const _BuyFormFields({
    required this.form,
    required this.enabled,
    required this.onChanged,
  });

  final BuyForm form;
  final bool enabled;
  final ValueChanged<BuyForm> onChanged;

  @override
  State<_BuyFormFields> createState() => _BuyFormFieldsState();
}

class _BuyFormFieldsState extends State<_BuyFormFields> {
  late final _amount = TextEditingController(text: widget.form.amount);
  late final _wallet = TextEditingController(text: widget.form.wallet);

  @override
  void didUpdateWidget(_BuyFormFields old) {
    super.didUpdateWidget(old);
    // Switching crypto replaces the wallet; keep the field in sync.
    if (_wallet.text != widget.form.wallet) _wallet.text = widget.form.wallet;
  }

  @override
  void dispose() {
    _amount.dispose();
    _wallet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    final enabled = widget.enabled;
    final onChanged = widget.onChanged;
    final amountValid = parseAmount(form.amount) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<DemoCrypto>(
          segments: [
            for (final c in DemoCrypto.values)
              ButtonSegment(value: c, label: Text(c.symbol)),
          ],
          selected: {form.crypto},
          onSelectionChanged:
              enabled ? (s) => onChanged(form.withCrypto(s.first)) : null,
        ),
        TextField(
          controller: _amount,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount (${form.fiat.label})',
            errorText: amountValid ? null : 'Enter a number greater than 0',
          ),
          onChanged: (v) => onChanged(form.copyWith(amount: v)),
        ),
        TextField(
          controller: _wallet,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: '${form.crypto.symbol} wallet (${form.crypto.network})',
            errorText:
                form.wallet.trim().isEmpty ? 'Enter a wallet address' : null,
          ),
          style: const TextStyle(fontSize: 13),
          onChanged: (v) => onChanged(form.copyWith(wallet: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Override country and state'),
          subtitle: const Text('Off: the backend infers the user\'s country',
              style: TextStyle(fontSize: 12)),
          value: form.countryOverride,
          onChanged: enabled
              ? (v) => onChanged(form.copyWith(countryOverride: v))
              : null,
        ),
        if (form.countryOverride) ...[
          SegmentedButton<DemoCountry>(
            segments: [
              for (final c in DemoCountry.values)
                ButtonSegment(value: c, label: Text(c.label)),
            ],
            selected: {form.country},
            onSelectionChanged:
                enabled ? (s) => onChanged(form.withCountry(s.first)) : null,
          ),
          if (form.country == DemoCountry.us)
            _LabeledDropdown<String>(
              label: 'US state',
              value: form.usState,
              items: [
                for (final st in usStates)
                  DropdownMenuItem(value: st.code, child: Text(st.name)),
              ],
              onChanged: enabled
                  ? (v) {
                      if (v != null) onChanged(form.copyWith(usState: v));
                    }
                  : null,
            ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(child: Text('Pay with')),
            SegmentedButton<DemoFiat>(
              segments: [
                for (final f in DemoFiat.values)
                  ButtonSegment(value: f, label: Text(f.label)),
              ],
              selected: {form.fiat},
              onSelectionChanged: enabled
                  ? (s) => onChanged(form.copyWith(fiat: s.first))
                  : null,
            ),
          ],
        ),
        _LabeledDropdown<String?>(
          label: 'Onramp',
          value: form.onramp,
          items: [
            for (final (id, label) in onrampOptions)
              DropdownMenuItem(value: id, child: Text(label)),
          ],
          onChanged:
              enabled ? (v) => onChanged(form.copyWith(onramp: () => v)) : null,
        ),
      ],
    );
  }
}

class _LabeledDropdown<T> extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        DropdownButton<T>(value: value, items: items, onChanged: onChanged),
      ],
    );
  }
}
