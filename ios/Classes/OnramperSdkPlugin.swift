import Flutter
import SwiftUI
import UIKit
import OnramperSDK

/// Errors produced inside the Flutter plugin glue (i.e. before the native
/// SDK has been engaged). Surfaced to Dart via `PigeonError`.
enum PluginError: Error {
    /// `configure(...)` was never called, or the client has been disposed.
    case notConfigured
    /// The native SDK has not been `initialize(...)`-d yet.
    case notInitialized
    /// The native SDK produced no usable response (e.g. swallowed a
    /// `CheckoutIntentResponse` we needed to assemble a DTO).
    case missingResponse(String)
    /// Maps to PigeonError so Dart receives a stable code/message pair
    /// instead of `String(describing:)` of the enum case.
    var asPigeonError: PigeonError {
        switch self {
        case .notConfigured:
            return PigeonError(code: "not_configured", message: "OnramperHostApi.configure has not been called", details: nil)
        case .notInitialized:
            return PigeonError(code: "not_initialized", message: "OnramperHostApi.initialize has not been called", details: nil)
        case .missingResponse(let detail):
            return PigeonError(code: "missing_response", message: "Native SDK produced no usable response", details: detail)
        }
    }
}

/// Single-flight bridge between the native SDK's
/// `sessionExpirationHandler` closure and the Dart side. When the SDK calls
/// the closure (i.e. its DPoP-bound SDK Session expired and a fresh
/// `SessionCredentials` pair must be sourced), this actor:
///
///   1. Sends `onSessionExpired()` to Dart via `OnramperFlutterApi`.
///   2. Suspends until Dart calls `provideRefreshedSession(...)` or
///      `failRefreshedSession(reason:)` via the HostApi.
///   3. Resumes the SDK's continuation with the new credentials, or throws.
///
/// Only one refresh round-trip is serviced at a time — the native SDK itself
/// already serialises refreshes, so concurrent callers should be impossible
/// in practice. If they ever do appear (e.g. test injection), additional
/// callers fail fast rather than queue.
actor SessionRefreshBridge {
    private var continuation: CheckedContinuation<SessionCredentials, Error>?

    func awaitRefresh(notifyDart: @Sendable () async -> Void) async throws -> SessionCredentials {
        // Send the notification BEFORE installing the continuation so concurrent
        // callers don't accidentally see a stale "in-flight" state due to
        // re-entrancy. The Dart-side notification has no causal ordering
        // requirement relative to suspension.
        if continuation != nil {
            throw OnramperError.userTokenRefreshFailed("refresh already in flight")
        }
        await notifyDart()
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<SessionCredentials, Error>) in
            // Re-check after the await above (concurrent installer race).
            if continuation != nil {
                cont.resume(throwing: OnramperError.userTokenRefreshFailed("refresh already in flight"))
                return
            }
            continuation = cont
        }
    }

    func resolve(_ credentials: SessionCredentials) {
        let cont = continuation
        continuation = nil
        cont?.resume(returning: credentials)
    }

    func fail(_ reason: String) {
        let cont = continuation
        continuation = nil
        cont?.resume(throwing: OnramperError.userTokenRefreshFailed(reason))
    }

    /// Test-only inspection: whether a refresh is currently pending.
    func isPending() -> Bool { continuation != nil }
}

/// Per-call collector for `getCheckoutRequirements`. The native SDK's public
/// `getCheckoutRequirements` returns only `(button, quote)` — it discards
/// both `headlessCheckoutId` and the requirements list. We rebuild the
/// missing fields from delegate callbacks fired during the call.
@MainActor
private final class CheckoutRequirementsCollector {
    var headlessCheckoutId: String?
    var requireLoginRequirements: [CheckoutRequirement]?
    var becameReadyToCheckout: Bool = false
}

/// Main Flutter plugin entry point. Owns the native `OnramperClient`, mirrors
/// SDK state/events back to Dart via `OnramperFlutterApi`, and brokers the
/// session-refresh round-trip.
///
/// `@MainActor` because the native `OnramperClient` is itself `@MainActor`-
/// isolated, and Flutter plugin message channels deliver on the main thread.
@MainActor
public final class OnramperSdkPlugin: NSObject, FlutterPlugin {

    // Native SDK instance — created lazily by `configure(...)`.
    var client: OnramperClient?

    // Flutter callback channel. `internal` rather than `private` so tests can
    // inject a stub via `testInjectFlutterApi`.
    var flutterApi: OnramperFlutterApiProtocol?

    let refreshBridge = SessionRefreshBridge()

    // Stores the per-call collector while `getCheckoutRequirements` is
    // in-flight. Reset to nil between calls.
    fileprivate var inFlightRequirements: CheckoutRequirementsCollector?

    // Bridges `client.events` (AsyncStream) to `flutterApi.onEvent`. Cancelled
    // on dispose / reconfigure.
    private var eventForwardingTask: Task<Void, Never>?

    // Handle of the most recent button stored in CheckoutButtonRegistry.
    // Cleared on reset / dispose so stale handles don't linger.
    private var lastButtonHandle: String?

    // `FlutterPlugin.register(with:)` is invoked on the main thread by
    // Flutter's plugin registry. It's declared `nonisolated` because the
    // `FlutterPlugin` protocol comes from an `@objc` header without actor
    // isolation; we `assumeIsolated` inside to satisfy MainActor.
    public nonisolated static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        MainActor.assumeIsolated {
            let plugin = OnramperSdkPlugin()
            OnramperHostApiSetup.setUp(binaryMessenger: messenger, api: plugin)
            plugin.flutterApi = OnramperFlutterApi(binaryMessenger: messenger)
            registerOnramperCheckoutButtonFactory(registrar: registrar)
            registrar.publish(plugin)
        }
    }

    // MARK: Test seams (not exposed in production code paths)

    func testInjectFlutterApi(_ api: OnramperFlutterApiProtocol) {
        self.flutterApi = api
    }

    func testClient() -> OnramperClient? { client }

    func testRefreshBridge() -> SessionRefreshBridge { refreshBridge }

    // MARK: Internal helpers

    /// Cancels the event-forwarding task. Called on dispose / reconfigure.
    private func tearDownObservers() {
        eventForwardingTask?.cancel(); eventForwardingTask = nil
    }

}

// MARK: - OnramperHostApi conformance
//
// `OnramperHostApi` is generated `internal`, so conforming methods stay
// `internal` too (no `public` keyword). They are still discoverable from
// Pigeon-generated code because that code lives in the same module.
//
// The extension is `@MainActor` because the class is @MainActor and Swift 6
// requires the isolation to be spelled out on the extension too when
// conforming to a non-isolated protocol like `OnramperHostApi` (pigeon
// generates that protocol without any actor annotation).
@MainActor
extension OnramperSdkPlugin: OnramperHostApi {

    func configure(config: ConfigurationDto) throws {
        // Capture the bridge and a weak self for the closure the SDK retains.
        let bridge = self.refreshBridge
        let nativeConfig = BridgeMappers.toNative(config) { [weak self] in
            try await bridge.awaitRefresh { @Sendable in
                // The notification runs on the main actor so the
                // `OnramperFlutterApi` can be touched without crossing isolation.
                await MainActor.run {
                    self?.flutterApi?.onSessionExpired { _ in /* fire-and-forget */ }
                }
            }
        }

        tearDownObservers()
        let newClient = OnramperClient(configuration: nativeConfig)
        newClient.delegate = self
        client = newClient

        // Forward CheckoutEvents to Dart.
        let api = self.flutterApi
        eventForwardingTask = Task { @MainActor [weak self] in
            for await event in newClient.events {
                let dto = BridgeMappers.fromNative(event)
                api?.onEvent(event: dto) { _ in /* fire-and-forget */ }
                self?.observeEventForRequirementsCollector(event)
            }
        }
    }

    /// Side-channel for the per-call requirements collector. The delegate
    /// path is the primary source of truth, but `loginRequired` and
    /// `checkoutStarted` events arrive at the same time and double-record
    /// here as a belt-and-braces fallback in case the delegate fires later.
    fileprivate func observeEventForRequirementsCollector(_ event: CheckoutEvent) {
        guard let collector = inFlightRequirements else { return }
        switch event {
        case .checkoutStarted(let id):
            if collector.headlessCheckoutId == nil { collector.headlessCheckoutId = id }
        case .loginRequired(let reqs):
            if collector.requireLoginRequirements == nil { collector.requireLoginRequirements = reqs }
        case .readyToCheckout:
            collector.becameReadyToCheckout = true
        default:
            break
        }
    }

    func initialize(
        credentials: SessionCredentialsDto,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let client else {
            completion(.failure(PluginError.notConfigured.asPigeonError))
            return
        }
        Task { @MainActor in
            do {
                try await client.initialize(
                    sessionId: credentials.sessionId,
                    sessionToken: credentials.sessionToken
                )
                completion(.success(()))
            } catch let onramperError as OnramperError {
                // Forward through the existing error mapper so Dart sees a
                // typed DTO via `OnramperFlutterApi.onError` AND a PigeonError
                // on the call result.
                let dto = BridgeMappers.fromNative(onramperError)
                self.flutterApi?.onError(error: dto) { _ in }
                completion(.failure(PigeonError(code: "onramper_error", message: dto.message, details: nil)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func getCheckoutRequirements(
        request: CheckoutIntentRequestDto,
        prefill: UserPrefillDto?,
        buttonStyle: CheckoutButtonStyleDto?,
        completion: @escaping (Result<CheckoutRequirementsResultDto, Error>) -> Void
    ) {
        guard let client else {
            completion(.failure(PluginError.notConfigured.asPigeonError))
            return
        }
        let nativeRequest = BridgeMappers.toNative(request)
        let nativePrefill = BridgeMappers.toNative(prefill)
        let nativeStyle = BridgeMappers.toNative(buttonStyle)
        let collector = CheckoutRequirementsCollector()
        self.inFlightRequirements = collector

        Task { @MainActor in
            defer { self.inFlightRequirements = nil }
            do {
                // `getCheckoutRequirements` is UIKit-gated and returns a
                // SwiftUI button + quote. The button's appearance comes from
                // `nativeStyle`, defaulting to the SDK's system-blue if the
                // consumer didn't override.
                let result = try await client.getCheckoutRequirements(
                    nativeRequest,
                    prefill: nativePrefill,
                    buttonStyle: nativeStyle
                )

                // Store the button in the registry and hand the handle to Dart so
                // OnramperNativeCheckoutButton can look it up via the platform view.
                if let prev = self.lastButtonHandle {
                    await CheckoutButtonRegistry.shared.drop(prev)
                }
                let handle = await CheckoutButtonRegistry.shared.store(result.button)
                self.lastButtonHandle = handle

                guard let headlessId = collector.headlessCheckoutId else {
                    completion(.failure(
                        PluginError.missingResponse("delegate.didStartCheckout was not invoked")
                            .asPigeonError
                    ))
                    return
                }

                let nativeReqs = collector.requireLoginRequirements ?? []
                let dto = CheckoutRequirementsResultDto(
                    headlessCheckoutId: headlessId,
                    requirements: nativeReqs.map(BridgeMappers.fromNative),
                    quote: BridgeMappers.fromNative(result.quote),
                    buttonHandle: handle
                )
                completion(.success(dto))
            } catch let onramperError as OnramperError {
                let errDto = BridgeMappers.fromNative(onramperError)
                self.flutterApi?.onError(error: errDto) { _ in }
                completion(.failure(PigeonError(code: "onramper_error", message: errDto.message, details: nil)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func reset(completion: @escaping (Result<Void, Error>) -> Void) {
        let client = self.client
        let handle = self.lastButtonHandle
        Task { @MainActor in
            await client?.reset()
            if let h = handle { await CheckoutButtonRegistry.shared.drop(h) }
            self.lastButtonHandle = nil
            completion(.success(()))
        }
    }

    func signOut(completion: @escaping (Result<Void, Error>) -> Void) {
        let client = self.client
        let handle = self.lastButtonHandle
        Task { @MainActor in
            await client?.signOut()
            // Drop the current button too — the intent it addressed was tied
            // to the now-cleared OIDC identity.
            if let h = handle { await CheckoutButtonRegistry.shared.drop(h) }
            self.lastButtonHandle = nil
            completion(.success(()))
        }
    }

    func cancelPreparedIntent(buttonHandle: String) throws {
        // Fire-and-forget — the registry actor serialises access. If the
        // handle refers to the currently-tracked button, also clear our
        // reference so a subsequent reset() doesn't try to drop a stale id.
        Task { await CheckoutButtonRegistry.shared.drop(buttonHandle) }
        if lastButtonHandle == buttonHandle { lastButtonHandle = nil }
    }

    func dispose(completion: @escaping (Result<Void, Error>) -> Void) {
        let client = self.client
        Task { @MainActor in
            await client?.reset()
            self.tearDownObservers()
            await CheckoutButtonRegistry.shared.dropAll()
            self.client = nil
            self.inFlightRequirements = nil
            self.lastButtonHandle = nil
            completion(.success(()))
        }
    }

    func provideRefreshedSession(credentials: SessionCredentialsDto) throws {
        // Pigeon's HostApi method is sync; fanning out into a Task is fine
        // because the actor handles ordering and `resolve(...)` is
        // idempotent (no-op if no continuation is pending).
        let creds = SessionCredentials(
            sessionId: credentials.sessionId,
            sessionToken: credentials.sessionToken
        )
        Task { await refreshBridge.resolve(creds) }
    }

    func failRefreshedSession(reason: String) throws {
        Task { await refreshBridge.fail(reason) }
    }
}

// MARK: - OnramperDelegate conformance
//
// All callbacks run on the main actor (per the SDK protocol). We forward
// state changes to Dart via `onStateChanged` and feed the in-flight
// requirements collector when a `getCheckoutRequirements` call is mid-flight.
@MainActor
extension OnramperSdkPlugin: OnramperDelegate {

    public func onramperClient(_ client: OnramperClient, didChangeState state: OnramperState) {
        flutterApi?.onStateChanged(state: BridgeMappers.fromNative(state)) { _ in }
    }

    public func onramperClient(_ client: OnramperClient, didStartCheckout checkoutId: String) {
        inFlightRequirements?.headlessCheckoutId = checkoutId
    }

    public func onramperClient(_ client: OnramperClient, didRequireLogin requirements: [CheckoutRequirement]) {
        inFlightRequirements?.requireLoginRequirements = requirements
    }

    public func onramperClient(_ client: OnramperClient, didBecomeReadyToCheckout checkoutId: String) {
        inFlightRequirements?.becameReadyToCheckout = true
    }

    public func onramperClient(_ client: OnramperClient, didCompleteCheckout checkoutId: String) {
        // The event-forwarding task already mirrors `.completed` to Dart.
    }

    public func onramperClient(_ client: OnramperClient, didFailWithError error: OnramperError) {
        flutterApi?.onError(error: BridgeMappers.fromNative(error)) { _ in }
    }
}
