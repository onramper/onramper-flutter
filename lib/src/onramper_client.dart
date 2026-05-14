import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models/configuration.dart';
import 'models/errors.dart';
import 'models/events.dart';
import 'models/requirements.dart';
import 'models/state.dart';
import 'platform/pigeon.g.dart';

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

  // ---- Public API (Dart -> native) -----------------------------------------

  /// Hands the bootstrap [SessionCredentials] to the native SDK so it can
  /// perform attestation and stand up a DPoP-bound session.
  Future<void> initialize({
    required String sessionId,
    required String sessionToken,
  }) {
    return _host.initialize(
      SessionCredentialsDto(sessionId: sessionId, sessionToken: sessionToken),
    );
  }

  /// Requests a checkout intent from the BFF.
  ///
  /// Returns the mapped [CheckoutRequirementsResult] and caches its
  /// [CheckoutRequirementsResult.tos] under [tosRequirements] for downstream
  /// UI to render.
  Future<CheckoutRequirementsResult> getCheckoutRequirements(
    CheckoutIntentRequest request,
  ) async {
    final dto = await _host.getCheckoutRequirements(request.toDto());
    final result = CheckoutRequirementsResult.fromDto(dto);
    _tosRequirements = result.tos;
    notifyListeners();
    return result;
  }

  /// Asks the native side to render the checkout webview on top of the
  /// Flutter view hierarchy.
  Future<void> presentCheckout() => _host.presentCheckout();

  /// Resets the native SDK and clears cached requirements / errors.
  Future<void> reset() async {
    _tosRequirements = null;
    _lastError = null;
    await _host.reset();
    notifyListeners();
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

  // ---- OnramperFlutterApi conformance (native -> Dart) ---------------------

  @override
  void onStateChanged(OnramperStateDto state) {
    _state = OnramperState.fromDto(state);
    if (!_stateController.isClosed) _stateController.add(_state);
    notifyListeners();
  }

  @override
  void onEvent(CheckoutEventDto event) {
    if (!_eventController.isClosed) {
      _eventController.add(CheckoutEvent.fromDto(event));
    }
  }

  @override
  void onError(OnramperErrorDto error) {
    _lastError = OnramperError.fromDto(error);
    notifyListeners();
  }

  @override
  void onSessionExpired() {
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
