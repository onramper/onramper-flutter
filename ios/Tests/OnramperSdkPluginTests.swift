import XCTest
@testable import onramper_flutter
import OnramperSDK

/// Captures every callback the plugin sends Dart-side so tests can assert on
/// call counts and arguments without instantiating Flutter's engine.
final class MockOnramperFlutterApi: OnramperFlutterApiProtocol {
    var states: [OnramperStateDto] = []
    var events: [CheckoutEventDto] = []
    var errors: [OnramperErrorDto] = []
    var sessionExpiredCallCount = 0

    func onStateChanged(state stateArg: OnramperStateDto, completion: @escaping (Result<Void, PigeonError>) -> Void) {
        states.append(stateArg)
        completion(.success(()))
    }

    func onEvent(event eventArg: CheckoutEventDto, completion: @escaping (Result<Void, PigeonError>) -> Void) {
        events.append(eventArg)
        completion(.success(()))
    }

    func onError(error errorArg: OnramperErrorDto, completion: @escaping (Result<Void, PigeonError>) -> Void) {
        errors.append(errorArg)
        completion(.success(()))
    }

    func onSessionExpired(completion: @escaping (Result<Void, PigeonError>) -> Void) {
        sessionExpiredCallCount += 1
        completion(.success(()))
    }

    var logs: [LogRecordDto] = []

    func onLog(record recordArg: LogRecordDto, completion: @escaping (Result<Void, PigeonError>) -> Void) {
        logs.append(recordArg)
        completion(.success(()))
    }

    var transactionIds: [String?] = []

    func onTransactionIdChanged(transactionId transactionIdArg: String?, completion: @escaping (Result<Void, PigeonError>) -> Void) {
        transactionIds.append(transactionIdArg)
        completion(.success(()))
    }
}

@MainActor
final class OnramperSdkPluginTests: XCTestCase {

    var plugin: OnramperSdkPlugin!
    var mockApi: MockOnramperFlutterApi!

    override func setUp() async throws {
        try await super.setUp()
        plugin = OnramperSdkPlugin()
        mockApi = MockOnramperFlutterApi()
        plugin.testInjectFlutterApi(mockApi)
    }

    override func tearDown() async throws {
        plugin = nil
        mockApi = nil
        try await super.tearDown()
    }

    // MARK: - log forwarding

    func test_logHandler_forwardsRecordsToDartOnMain() async {
        let handler = plugin.makeLogHandler()
        let record = OnramperLogRecord(level: .info, category: "Checkout", event: "checkout.finalized", context: [:])
        DispatchQueue.global().async { handler(record) }   // native calls from arbitrary threads
        let delivered = expectation(description: "delivered")
        func poll() {
            if mockApi.logs.count == 1 { delivered.fulfill(); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { MainActor.assumeIsolated { poll() } }
        }
        poll()
        await fulfillment(of: [delivered], timeout: 2)
        XCTAssertEqual(mockApi.logs.first?.event, "checkout.finalized")
    }

    func test_configure_installsLogHandlerOnlyWhenDartHasOne() throws {
        var withHandler = makeConfig()
        withHandler.hasLogHandler = true
        try plugin.configure(config: withHandler)
        XCTAssertNotNil(plugin.testClient()?.configuration.logHandler)

        try plugin.configure(config: makeConfig())
        XCTAssertNil(plugin.testClient()?.configuration.logHandler)
    }

    // MARK: - sdkVersion

    func test_sdkVersion_returnsNativeVersion() throws {
        XCTAssertEqual(try plugin.sdkVersion(), OnramperClient.sdkVersion)
        XCTAssertEqual(try plugin.sdkVersion(), "1.3.1")
    }

    // MARK: - configure

    func test_configure_createsNativeClient() throws {
        let dto = makeConfig()
        try plugin.configure(config: dto)
        XCTAssertNotNil(plugin.testClient(), "expected native OnramperClient to be created")
    }

    func test_configure_secondCall_replacesClient() throws {
        try plugin.configure(config: makeConfig())
        let first = plugin.testClient()
        XCTAssertNotNil(first)

        try plugin.configure(config: makeConfig(apiKey: "pk_test_two"))
        let second = plugin.testClient()
        XCTAssertNotNil(second)
        // Identity check: a second configure must rebuild the client so the
        // refreshed configuration (different apiKey) is wired into the SDK.
        XCTAssertFalse(first === second, "expected configure(...) to replace the existing client")
    }

    // MARK: - reset / dispose (no-op safety when not configured)

    func test_reset_withoutConfigure_succeeds() async throws {
        try await callExpectingSuccess { completion in
            plugin.reset(completion: completion)
        }
    }

    func test_dispose_clearsClient() async throws {
        try plugin.configure(config: makeConfig())
        XCTAssertNotNil(plugin.testClient())

        try await callExpectingSuccess { completion in
            plugin.dispose(completion: completion)
        }
        XCTAssertNil(plugin.testClient(), "expected dispose to release the native client")
    }

    // MARK: - initialize before configure

    func test_initialize_withoutConfigure_failsWithNotConfigured() async throws {
        let creds = SessionCredentialsDto(sessionId: "sid", sessionToken: "tok")
        let error = await callExpectingFailure { completion in
            plugin.initialize(credentials: creds, completion: completion)
        }
        let pigeon = try XCTUnwrap(error as? PigeonError)
        XCTAssertEqual(pigeon.code, "not_configured")
    }

    // MARK: - Session-refresh bridge: resolve path

    func test_sessionRefresh_resolve_returnsCredentialsToCaller() async throws {
        let bridge = plugin.testRefreshBridge()
        let creds = SessionCredentials(sessionId: "fresh_sid", sessionToken: "fresh_tok")
        let mockApi = self.mockApi!

        // Kick off the refresh in a task, then resolve from outside.
        async let result: SessionCredentials = bridge.awaitRefresh {
            // Same callback the plugin installs in production.
            await MainActor.run {
                mockApi.onSessionExpired { _ in }
            }
        }

        // Wait until the bridge has recorded the pending continuation.
        try await waitUntil { await bridge.isPending() }

        // Dart-side has been notified via `onSessionExpired`.
        XCTAssertEqual(mockApi.sessionExpiredCallCount, 1)

        // Simulate Dart returning fresh credentials via the HostApi.
        try plugin.provideRefreshedSession(credentials: SessionCredentialsDto(
            sessionId: creds.sessionId, sessionToken: creds.sessionToken
        ))

        let received = try await result
        XCTAssertEqual(received.sessionId, "fresh_sid")
        XCTAssertEqual(received.sessionToken, "fresh_tok")
    }

    // MARK: - Session-refresh bridge: fail path

    func test_sessionRefresh_fail_throwsUserTokenRefreshFailed() async throws {
        let bridge = plugin.testRefreshBridge()
        let mockApi = self.mockApi!

        async let result: SessionCredentials = bridge.awaitRefresh {
            await MainActor.run { mockApi.onSessionExpired { _ in } }
        }
        try await waitUntil { await bridge.isPending() }

        try plugin.failRefreshedSession(reason: "user signed out")

        do {
            _ = try await result
            XCTFail("expected awaitRefresh to throw")
        } catch let error as OnramperError {
            switch error {
            case .userTokenRefreshFailed(let reason):
                XCTAssertEqual(reason, "user signed out")
            default:
                XCTFail("expected userTokenRefreshFailed, got \(error)")
            }
        }
    }

    // MARK: - Session-refresh bridge: concurrent callers

    func test_sessionRefresh_concurrentCaller_failsFast() async throws {
        let bridge = plugin.testRefreshBridge()
        let mockApi = self.mockApi!
        let notify: @Sendable () async -> Void = {
            await MainActor.run { mockApi.onSessionExpired { _ in } }
        }

        async let first: SessionCredentials = bridge.awaitRefresh(notifyDart: notify)
        try await waitUntil { await bridge.isPending() }

        // Second caller should fail immediately rather than enqueue.
        do {
            _ = try await bridge.awaitRefresh(notifyDart: notify)
            XCTFail("expected concurrent refresh to fail")
        } catch let error as OnramperError {
            switch error {
            case .userTokenRefreshFailed(let reason):
                XCTAssertTrue(reason.contains("already in flight"), "got reason: \(reason)")
            default:
                XCTFail("expected userTokenRefreshFailed, got \(error)")
            }
        }

        // Resolve the first to leave the bridge clean for teardown.
        try plugin.provideRefreshedSession(credentials: SessionCredentialsDto(sessionId: "s", sessionToken: "t"))
        _ = try await first
    }

    // MARK: - Helpers

    private func makeConfig(apiKey: String = "pk_test_x") -> ConfigurationDto {
        ConfigurationDto(
            apiKey: apiKey,
            clientId: "01HPLUGINTEST",
            environment: .development,
            theme: .system,
            logLevel: .off,
            hasLogHandler: false,
            isEventLoggingEnabled: false,
            isEventConsoleLoggingEnabled: false
        )
    }

    /// Bridges Pigeon's `(Result<Value, Error>) -> Void` completion-style
    /// HostApi method into an `async throws -> Value` for ergonomic
    /// assertions.
    private func callExpectingSuccess(_ call: (@escaping (Result<Void, Error>) -> Void) -> Void) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            call { result in
                switch result {
                case .success: cont.resume(returning: ())
                case .failure(let e): cont.resume(throwing: e)
                }
            }
        }
    }

    private func callExpectingFailure(_ call: (@escaping (Result<Void, Error>) -> Void) -> Void) async -> Error {
        await withCheckedContinuation { (cont: CheckedContinuation<Error, Never>) in
            call { result in
                switch result {
                case .success: cont.resume(returning: NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "expected failure but got success"]))
                case .failure(let e): cont.resume(returning: e)
                }
            }
        }
    }

    /// Polls a condition with a brief sleep until it becomes true or the
    /// timeout elapses.
    private func waitUntil(timeout: TimeInterval = 1.0, _ condition: @escaping () async -> Bool) async throws {
        let start = Date()
        while !(await condition()) {
            if Date().timeIntervalSince(start) > timeout {
                throw NSError(domain: "test.waitUntil", code: 1, userInfo: [NSLocalizedDescriptionKey: "condition not met within \(timeout)s"])
            }
            try await Task.sleep(nanoseconds: 5_000_000) // 5ms
        }
    }
}
