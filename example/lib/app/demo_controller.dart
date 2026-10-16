import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onramper_flutter/onramper_flutter.dart';

import '../config/environments.dart';
import '../logging/event_log.dart';
import '../utils/format.dart';

typedef ClientFactory = OnramperClient Function(
  OnramperConfiguration configuration,
  SessionExpirationHandler onSessionExpired,
);

typedef SessionMinter = Future<SessionCredentials> Function(
    ResolvedEnvironment environment);

enum InitStatus { initializing, ready, error }

/// Owns the [OnramperClient] — the Flutter port of the RN demo's
/// `useOnramper`. Any change of environment or theme (and [retry] /
/// [clearLocalSessions]) starts a new *run*: mint a demo session, build and
/// initialize a client, publish it. A superseded run never publishes its
/// client, and whatever it created is disposed.
///
/// Unlike RN, the plugin registers native callbacks globally, so a new client
/// is only constructed after the previous one has finished disposing.
class DemoController extends ChangeNotifier {
  DemoController({
    required ClientFactory clientFactory,
    required SessionMinter mintSession,
    required OnramperLogHandler onSdkLog,
    EventLog? eventLog,
    Map<String, String> defines = demoDefines,
    DemoEnvironment environment = DemoEnvironment.development,
    bool isDark = true,
  })  : _clientFactory = clientFactory,
        _mintSession = mintSession,
        _onSdkLog = onSdkLog,
        _defines = defines,
        _environment = environment,
        _isDark = isDark,
        eventLog = eventLog ?? EventLog() {
    _startRun();
  }

  final ClientFactory _clientFactory;
  final SessionMinter _mintSession;
  final OnramperLogHandler _onSdkLog;
  final Map<String, String> _defines;
  final EventLog eventLog;

  DemoEnvironment _environment;
  bool _isDark;
  InitStatus _status = InitStatus.initializing;
  String? _initError;
  OnramperStateKind _sdkState = OnramperStateKind.idle;
  bool _hasFinalizedCheckout = false;
  String? _transactionId;
  String? _completedCheckoutId;
  String? _lastFailure;
  DemoEnvironment? _settledEnvironment;
  DemoEnvironment? _switchTarget;

  int _run = 0;
  OnramperClient? _client;
  OnramperClient? _owned;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Future<void> _disposing = Future.value();
  bool _disposed = false;

  DemoEnvironment get environment => _environment;
  bool get isDark => _isDark;

  /// The ready client of the current run; `null` while (re)initializing.
  OnramperClient? get client => _client;
  InitStatus get status => _status;
  String? get initError => _initError;
  OnramperStateKind get sdkState => _sdkState;

  /// The current checkout reached finalization (independent of the retained
  /// transaction id).
  bool get hasFinalizedCheckout => _hasFinalizedCheckout;
  String? get transactionId => _transactionId;
  String? get completedCheckoutId => _completedCheckoutId;
  String? get lastFailure => _lastFailure;

  /// Environment of the last run that finished (ready or error).
  DemoEnvironment? get settledEnvironment => _settledEnvironment;
  bool get isSwitching => _switchTarget != null;

  void retry() => _startRun();

  void setDarkMode(bool value) {
    if (value == _isDark) return;
    _isDark = value;
    _startRun();
  }

  /// RN `App.tsx`: sign out, then re-initialize against [target]. The picker
  /// stays locked until a run for [target] settles.
  Future<void> switchEnvironment(DemoEnvironment target) async {
    if (target == _environment || _switchTarget != null) return;
    _switchTarget = target;
    _notify();
    final current = _client;
    if (current != null) {
      try {
        await current.signOut();
      } catch (e) {
        final d = describeError(e);
        _log(EventLevel.error, 'sign out failed: ${d.code} — ${d.message}');
      }
    }
    if (_disposed) return;
    _log(EventLevel.info, 'switching environment → ${target.name}');
    _environment = target;
    _startRun();
  }

  /// Signs out, resets, then re-initializes with a fresh demo session.
  Future<void> clearLocalSessions() async {
    final current = _client;
    if (current == null) throw StateError('The SDK is not initialized.');
    await current.signOut();
    await current.reset();
    _startRun();
  }

  /// Clears the last completed / failed outcome (not the SDK-driven state).
  void clearOutcome() {
    _completedCheckoutId = null;
    _lastFailure = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _releaseClient();
    super.dispose();
  }

  void _startRun() {
    final run = ++_run;
    _releaseClient();
    _status = InitStatus.initializing;
    _initError = null;
    _sdkState = OnramperStateKind.idle;
    _hasFinalizedCheckout = false;
    _transactionId = null;
    _completedCheckoutId = null;
    _lastFailure = null;
    _notify();
    unawaited(_execute(run));
  }

  bool _isCurrent(int run) => !_disposed && run == _run;

  Future<void> _execute(int run) async {
    final env = _environment;
    try {
      final resolved = env.resolve(_defines);
      if (!resolved.isComplete) {
        throw StateError('.env is missing ${resolved.missing.join(', ')}');
      }
      Future<SessionCredentials> mint() => _mintSession(resolved);
      _log(EventLevel.info, '[${env.name}] minting demo session…');
      final session = await mint();
      if (!_isCurrent(run)) return;
      _log(EventLevel.info, 'demo session minted');
      await _disposing;
      if (!_isCurrent(run)) return;
      final client = _clientFactory(
        OnramperConfiguration(
          apiKey: resolved.apiKey,
          clientId: resolved.clientId,
          environment: resolved.sdkEnvironment,
          theme: _isDark ? OnramperTheme.dark : OnramperTheme.light,
          logLevel: OnramperLogLevel.debug,
          logHandler: _onSdkLog,
        ),
        () async {
          _log(EventLevel.info, 'session expired — minting a new one');
          return mint();
        },
      );
      _owned = client;
      _listen(client);
      await client.initialize(
          sessionId: session.sessionId, sessionToken: session.sessionToken);
      if (!_isCurrent(run)) return;
      _client = client;
      _status = InitStatus.ready;
      _settledEnvironment = env;
      _log(EventLevel.info, '[${env.name}] SDK initialized');
      _finishSwitch();
      _notify();
    } catch (error) {
      if (!_isCurrent(run)) return;
      final d = describeError(error);
      _releaseClient();
      _status = InitStatus.error;
      _settledEnvironment = env;
      _initError = '${d.code} — ${d.message}';
      _log(EventLevel.error, 'init failed: ${d.code} — ${d.message}');
      _finishSwitch();
      _notify();
    }
  }

  void _listen(OnramperClient client) {
    client.addListener(_onClientChanged);
    _subscriptions
      ..add(client.stateStream.listen(_onState))
      ..add(client.events.listen(_onEvent));
  }

  void _releaseClient() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _subscriptions.clear();
    final owned = _owned;
    _owned = null;
    _client = null;
    if (owned == null) return;
    owned.removeListener(_onClientChanged);
    _disposing = _disposing
        .then((_) => owned.dispose())
        .catchError((Object e) => debugPrint('OnramperClient.dispose: $e'));
  }

  void _finishSwitch() {
    if (_switchTarget != null && _settledEnvironment == _switchTarget) {
      _switchTarget = null;
    }
  }

  void _onClientChanged() {
    final id = _owned?.currentTransactionId;
    if (id == _transactionId) return;
    _transactionId = id;
    _notify();
  }

  void _onState(OnramperState s) {
    _sdkState = s.kind;
    if (s.kind == OnramperStateKind.checkoutPreparing ||
        s.kind == OnramperStateKind.ready) {
      _hasFinalizedCheckout = false;
    }
    if (s.kind == OnramperStateKind.failed) {
      _log(EventLevel.error,
          'state → failed: ${s.failedError?.kind.name ?? 'unknown'}');
    } else {
      _log(EventLevel.event, 'state → ${s.kind.name}');
    }
    _notify();
  }

  void _onEvent(CheckoutEvent e) {
    switch (e.kind) {
      case CheckoutEventKind.renderingStarted:
        _log(EventLevel.event,
            'rendering started (${e.renderContext?.renderType.name})');
      case CheckoutEventKind.checkoutFinalized:
        _hasFinalizedCheckout = true;
        _log(EventLevel.event,
            'finalized — transaction ${e.finalizeResponse?.onramperTransactionId}');
      case CheckoutEventKind.completed:
        _completedCheckoutId = e.checkoutId;
        _lastFailure = null;
        _log(EventLevel.event, 'completed ${e.checkoutId}');
      case CheckoutEventKind.failed:
        _completedCheckoutId = null;
        final error = e.error;
        final d = describeError(error ?? 'unknown');
        _lastFailure = '${d.code} — ${d.message}';
        _log(EventLevel.error,
            'failed ${error?.kind.name} — ${error?.message}');
      case CheckoutEventKind.checkoutCancelled:
        _log(EventLevel.event, 'checkout cancelled');
      case CheckoutEventKind.checkoutStarted:
        _completedCheckoutId = null;
        _lastFailure = null;
      case CheckoutEventKind.paymentPending:
        _completedCheckoutId = null;
        _lastFailure = null;
        _log(EventLevel.event,
            'Payment processing — track the transaction before starting another payment.');
      case CheckoutEventKind.providerError:
        _log(EventLevel.error, 'provider error: ${e.providerReason}');
      case CheckoutEventKind.providerReady ||
            CheckoutEventKind.paymentAuthorized ||
            CheckoutEventKind.paymentProcessing ||
            CheckoutEventKind.paymentCancelled ||
            CheckoutEventKind.challengeStarted ||
            CheckoutEventKind.challengeCompleted ||
            CheckoutEventKind.customerOnboardingRequired:
        _log(EventLevel.event, e.kind.name);
      case CheckoutEventKind.stateChanged ||
            CheckoutEventKind.loginRequired ||
            CheckoutEventKind.readyToCheckout ||
            CheckoutEventKind.requirementSatisfied:
        return;
    }
    _notify();
  }

  void _log(EventLevel level, String line) {
    if (!_disposed) eventLog.add(level, line);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
