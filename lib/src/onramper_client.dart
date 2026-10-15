import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;

import 'models/configuration.dart';
import 'models/errors.dart';
import 'models/events.dart';
import 'models/log_record.dart';
import 'models/prefill.dart';
import 'models/requirements.dart';
import 'models/state.dart';
import 'platform/pigeon.g.dart';
import 'widget/checkout_button_style.dart';

/// Callback invoked by the SDK when the native session token has expired and
/// a fresh [SessionCredentials] pair must be fetched from the partner backend.
///
/// Implementations should perform whatever auth-handshake the integrator's
/// backend requires and return the new credentials. Throwing from this handler
/// is treated as a terminal failure and results in `failRefreshedSession`
/// being called on the host platform.
typedef SessionExpirationHandler = Future<SessionCredentials> Function();

/// Primary, consumer-facing entry point to the Onramper Flutter plugin.
///
/// Bridges Dart code to the native iOS SDK via the Pigeon-generated
/// [OnramperHostApi] (Dart → Swift) and implements the Pigeon-generated
/// [OnramperFlutterApi] (Swift → Dart) for state/event/error/sessionExpired
/// callbacks.
///
/// Exposes two complementary observation surfaces so consumers can pick the
/// pattern that best fits their state-management library:
///
/// 1. **[ChangeNotifier]** — works with `Provider`, `AnimatedBuilder`, and
///    `ValueListenableBuilder`. Listeners are notified on every state change
///    and every error update.
/// 2. **Broadcast [Stream]s** — [stateStream], [events]. Idiomatic for
///    Riverpod, `StreamBuilder`, and `await for` consumers.
///
/// The client is created with an [OnramperConfiguration] which is forwarded to
/// the native side once during construction (fire-and-forget). Call
/// [initialize] with [SessionCredentials] before starting a checkout flow.
///
/// After [dispose], methods throw [OnramperError] with kind `clientDisposed`,
/// and late native callbacks are ignored. Create a new client to start over.
class OnramperClient extends ChangeNotifier implements OnramperFlutterApi {
  /// Creates a client wired to the real native HostApi.
  OnramperClient({
    required OnramperConfiguration configuration,
    SessionExpirationHandler? sessionExpirationHandler,
  }) : this._(
          configuration: configuration,
          hostApi: OnramperHostApi(),
          sessionExpirationHandler: sessionExpirationHandler,
        );

  /// Test-only factory that injects a fake [OnramperHostApi].
  @visibleForTesting
  factory OnramperClient.forTesting({
    required OnramperConfiguration configuration,
    required OnramperHostApi hostApi,
    SessionExpirationHandler? sessionExpirationHandler,
  }) =>
      OnramperClient._(
        configuration: configuration,
        hostApi: hostApi,
        sessionExpirationHandler: sessionExpirationHandler,
      );

  /// Version of this Flutter plugin. `X.Y.Z` bundles native OnramperSDK
  /// `X.Y.Z`.
  static const String wrapperVersion = '1.3.1';

  /// Version of the bundled native OnramperSDK (e.g. "1.3.1"). Works without a
  /// client instance. Useful for diagnostics and support screens.
  static Future<String> sdkVersion() => OnramperHostApi().sdkVersion();

  /// Required by `dartPluginClass: OnramperClient` in `pubspec.yaml`.
  ///
  /// Flutter's generated `dart_plugin_registrant` calls this on app start.
  /// The SDK uses Pigeon-generated channels that wire themselves up on first
  /// use, so there's nothing to register here — this entry point exists
  /// solely to satisfy the Flutter plugin contract.
  static void registerWith() {
    // No-op: Pigeon channels are configured per-client in `_OnramperClient._`.
  }

  OnramperClient._({
    required OnramperConfiguration configuration,
    required OnramperHostApi hostApi,
    SessionExpirationHandler? sessionExpirationHandler,
  })  : _config = configuration,
        _host = hostApi,
        _sessionExpirationHandler = sessionExpirationHandler {
    OnramperFlutterApi.setUp(this);
    // Fire-and-forget — Pigeon's configure is async on iOS, but the contract
    // is "called exactly once at construction; configuration errors surface
    // as later state/error callbacks". Errors here become listener
    // notifications via [onError].
    unawaited(_host.configure(_config.toDto()));
  }

  final OnramperConfiguration _config;
  final OnramperHostApi _host;
  final SessionExpirationHandler? _sessionExpirationHandler;

  OnramperState _state = const OnramperState(kind: OnramperStateKind.idle);
  final StreamController<OnramperState> _stateController =
      StreamController<OnramperState>.broadcast();
  final StreamController<CheckoutEvent> _eventController =
      StreamController<CheckoutEvent>.broadcast();
  OnramperError? _lastError;
  List<TosRequirement>? _tosRequirements;
  String? _currentTransactionId;
  bool _disposed = false;

  /// Configuration this client was constructed with.
  OnramperConfiguration get configuration => _config;

  /// Latest known state of the native SDK. Defaults to
  /// [OnramperStateKind.idle] until the first callback arrives.
  OnramperState get state => _state;

  /// Broadcast stream of every state change reported by the native SDK.
  ///
  /// Mirrors [state] / [notifyListeners] — listeners that prefer streams
  /// (Riverpod, `StreamBuilder`, `await for`) should listen here.
  Stream<OnramperState> get stateStream => _stateController.stream;

  /// Broadcast stream of domain [CheckoutEvent]s emitted by the native SDK.
  Stream<CheckoutEvent> get events => _eventController.stream;

  /// Most recent error reported by the native SDK, or `null` if none yet.
  OnramperError? get lastError => _lastError;

  /// Cached Terms-of-Service requirements from the latest
  /// [getCheckoutRequirements] response (or `null` if none requested yet).
  List<TosRequirement>? get tosRequirements => _tosRequirements;

  /// Onramper's durable id for the current transaction, or `null`.
  ///
  /// Set when the checkout is finalized, before the payment surface renders.
  /// Cleared when a new checkout starts or on [reset]. **Store this id and
  /// quote it to Onramper support.** It's distinct from the per-attempt
  /// checkout id on `checkoutStarted` / `completed` events. Read it before
  /// calling [reset].
  String? get currentTransactionId => _currentTransactionId;

  // ---- Public API (Dart -> native) -----------------------------------------

  /// Hands the bootstrap [SessionCredentials] to the native SDK so it can
  /// perform attestation and stand up a DPoP-bound session.
  ///
  /// Throws [OnramperError] on SDK failure.
  Future<void> initialize({
    required String sessionId,
    required String sessionToken,
  }) {
    return _guard(() => _host.initialize(
          SessionCredentialsDto(
              sessionId: sessionId, sessionToken: sessionToken),
        ));
  }

  /// Requests a checkout intent from the BFF.
  ///
  /// [prefill] optionally pre-populates OnramperID screens; see
  /// [OnramperUserPrefill] for the email caveat. [buttonStyle] optionally
  /// overrides the appearance of the native checkout button embedded via
  /// [OnramperCheckoutButton]. Only the visual fields (background/foreground
  /// color, border radius) are forwarded — text/font styling for the
  /// Dart-side ToS lines lives on the widget.
  ///
  /// Returns the mapped [CheckoutRequirementsResult] and caches its
  /// [CheckoutRequirementsResult.tos] under [tosRequirements] for downstream
  /// UI to render.
  ///
  /// Calling it again (or [reset] / [signOut]) supersedes an earlier call
  /// still in flight; the earlier future fails with
  /// `OnramperErrorKind.intentInvalidated`, which you can ignore when waiting
  /// for the latest quote. Buttons from earlier calls that weren't yet shown
  /// are released and render nothing.
  ///
  /// Throws [OnramperError] on SDK failure.
  Future<CheckoutRequirementsResult> getCheckoutRequirements(
    CheckoutIntentRequest request, {
    OnramperUserPrefill? prefill,
    CheckoutButtonStyle? buttonStyle,
  }) async {
    final dto = await _guard(() => _host.getCheckoutRequirements(
          request.toDto(),
          prefill?.toDto(),
          buttonStyle?.toNativeDto(),
        ));
    final result = CheckoutRequirementsResult.fromDto(dto);
    if (_disposed) return result;
    _tosRequirements = result.tos;
    notifyListeners();
    return result;
  }

  /// Resets the native SDK and clears cached requirements / errors.
  Future<void> reset() async {
    _tosRequirements = null;
    _lastError = null;
    _currentTransactionId = null;
    await _guard(_host.reset);
    if (!_disposed) notifyListeners();
  }

  /// Signs out of OnramperID. Distinct from [reset]: the partner session
  /// (DPoP key + session token) is preserved so a subsequent checkout can
  /// re-use the same native client, but any cached OIDC tokens are wiped and
  /// the user will be re-prompted to log in on the next checkout that
  /// requires identity.
  Future<void> signOut() async {
    _tosRequirements = null;
    _lastError = null;
    _currentTransactionId = null;
    await _guard(_host.signOut);
    if (!_disposed) notifyListeners();
  }

  /// Drops the native checkout button identified by [buttonHandle] without
  /// tearing down the SDK client. Useful when a screen showing a prepared
  /// intent is being replaced by another checkout screen — call this on the
  /// old handle so its native resources are released promptly rather than
  /// waiting for the next [reset] or [dispose].
  Future<void> cancelPreparedIntent(String buttonHandle) {
    return _guard(() => _host.cancelPreparedIntent(buttonHandle));
  }

  /// Tears down the client, releases native resources, and closes both
  /// broadcast streams. Idempotent.
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    // Detach our FlutterApi handlers so late callbacks don't hit a disposed
    // client.
    OnramperFlutterApi.setUp(null);
    await _host.dispose();
    await _stateController.close();
    await _eventController.close();
    super.dispose();
  }

  /// Runs a host call, converting a native `OnramperError` (delivered as a
  /// PlatformException whose `details` is an [OnramperErrorDto]) into a typed
  /// [OnramperError]. Other exceptions propagate unchanged.
  Future<T> _guard<T>(Future<T> Function() call) async {
    if (_disposed) throw const OnramperError.clientDisposed();
    try {
      return await call();
    } on PlatformException catch (e) {
      final details = e.details;
      if (details is OnramperErrorDto) throw OnramperError.fromDto(details);
      rethrow;
    }
  }

  // ---- OnramperFlutterApi conformance (native -> Dart) ---------------------

  @override
  void onStateChanged(OnramperStateDto state) {
    if (_disposed) return;
    _state = OnramperState.fromDto(state);
    if (!_stateController.isClosed) _stateController.add(_state);
    notifyListeners();
  }

  @override
  void onEvent(CheckoutEventDto event) {
    if (_disposed) return;
    if (!_eventController.isClosed) {
      _eventController.add(CheckoutEvent.fromDto(event));
    }
  }

  @override
  void onError(OnramperErrorDto error) {
    if (_disposed) return;
    _lastError = OnramperError.fromDto(error);
    notifyListeners();
  }

  @override
  void onTransactionIdChanged(String? transactionId) {
    if (_disposed) return;
    if (transactionId == _currentTransactionId) return;
    _currentTransactionId = transactionId;
    notifyListeners();
  }

  @override
  void onLog(LogRecordDto record) {
    if (_disposed) return;
    final handler = _config.logHandler;
    if (handler == null) return;
    try {
      handler(OnramperLogRecord.fromDto(record));
    } catch (e, st) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: st,
        library: 'onramper_flutter',
        context:
            ErrorDescription('while calling OnramperConfiguration.logHandler'),
      ));
    }
  }

  @override
  void onSessionExpired() {
    if (_disposed) return;
    // The Pigeon callback is synchronous; dispatch the async refresh.
    unawaited(_handleSessionExpired());
  }

  Future<void> _handleSessionExpired() async {
    final handler = _sessionExpirationHandler;
    if (handler == null) {
      await _host.failRefreshedSession(
        'No sessionExpirationHandler configured on OnramperClient.',
      );
      return;
    }
    try {
      final fresh = await handler();
      await _host.provideRefreshedSession(
        SessionCredentialsDto(
          sessionId: fresh.sessionId,
          sessionToken: fresh.sessionToken,
        ),
      );
    } catch (e) {
      await _host.failRefreshedSession(e.toString());
    }
  }

  // ---- @visibleForTesting hooks --------------------------------------------

  @visibleForTesting
  void debugDispatchStateChanged(OnramperStateDto dto) => onStateChanged(dto);

  @visibleForTesting
  void debugDispatchEvent(CheckoutEventDto dto) => onEvent(dto);

  @visibleForTesting
  void debugDispatchError(OnramperErrorDto dto) => onError(dto);

  @visibleForTesting
  Future<void> debugDispatchSessionExpired() async {
    onSessionExpired();
    // Drain microtasks so the spawned _handleSessionExpired future completes
    // before the caller asserts on host-api side effects.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }
}
