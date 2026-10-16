# Getting started with `onramper_flutter`

`onramper_flutter` is the official Flutter plugin for the Onramper crypto onramping platform. It wraps the native iOS `OnramperSDK.xcframework` and exposes an idiomatic Dart API for configuring the SDK, requesting a checkout, observing state, and embedding a self-contained checkout button.

> ℹ️ **iOS only.** Android is not supported in this release. The plugin renders an empty `SizedBox` on non-iOS targets — guard call sites with a platform check if your app targets Android.

---

## At a glance

Three calls and a native button:

```dart
final client = OnramperClient(
  configuration: const OnramperConfiguration(
    apiKey: 'pk_live_...',
    clientId: 'YOUR_CLIENT_ID',
    environment: OnramperEnvironment.production,
  ),
  sessionExpirationHandler: () async => await yourBackend.mintOnramperSession(),
);

await client.initialize(sessionId: pair.sessionId, sessionToken: pair.sessionToken);

final requirements = await client.getCheckoutRequirements(
  CheckoutIntentRequest(
    transactionData: OnramperTransactionData(
      source: 'usd', destination: 'btc', amount: 100,
      type: TransactionType.buy, paymentMethod: 'applepay',
      wallet: const WalletInfo(network: 'bitcoin', address: 'bc1q...'),
    ),
  ),
);

// Then in your widget tree:
OnramperCheckoutButton(requirements: requirements)
```

---

## Prerequisites

| Requirement | Notes |
|---|---|
| iOS 16.0+ | Plugin minimum. Set in Podfile and Xcode project. |
| Xcode 26+ | Required. The bundled xcframework is compiled with Swift 6.2 — Xcode 16 and earlier cannot link it. |
| Flutter 3.22+ / Dart 3.4+ | Plugin minimum. |
| Real iOS device | App Attest is unavailable on the iOS Simulator. |
| Apple Developer account | Required to sign with the App Attest capability. |
| Bundle ID registered with Onramper | Validated server-side; unregistered IDs fail with `attestationFailed`. |

For the full iOS build setup — entitlements, Podfile, and first-build tips — see iOS build setup.

---

## 1. Install

Add the plugin to `pubspec.yaml`:

```yaml
dependencies:
  onramper_flutter: ^1.3.1
```

Or pin a specific tag (useful for preview releases before they reach pub.dev):

```yaml
dependencies:
  onramper_flutter:
    git:
      url: https://github.com/onramper/onramper-flutter.git
      ref: v1.3.1
```

Fetch packages and install pods:

```bash
flutter pub get
cd ios && pod install
```

The `pod install` step downloads the pinned `OnramperSDK.xcframework` from the public [`onramper/onramper-ios`](https://github.com/onramper/onramper-ios) release into `ios/Frameworks/` and links it into the Runner project. The download is sha256-verified against the checksum baked into the podspec — a corrupted or mismatched binary fails install. No GitHub authentication is required. If you hit rate limits (60/hour anonymous), export `ONRAMPER_IOS_READ_TOKEN` or `GITHUB_TOKEN` to raise the ceiling to 5,000/hour.

---

After upgrading the package, always run `pod install` and rebuild — a Dart-only update doesn't replace the bundled iOS SDK. To check what's installed at runtime:

```dart
debugPrint('onramper_flutter ${OnramperClient.wrapperVersion}, '
    'OnramperSDK ${await OnramperClient.sdkVersion()}');
```

## 2. iOS build setup

The iOS prerequisites — App Attest capability, entitlements plist, deployment target, and Podfile configuration — are covered in a dedicated guide.

➡️ **See [iOS build setup](IOS_BUILD_SETUP.md)**

Complete that guide before your first build, then return here for usage.

---

## 3. Configure the client

Create one `OnramperClient` per app session. Pass an `OnramperConfiguration` and a `sessionExpirationHandler` that returns fresh credentials minted by your backend.

```dart
import 'package:onramper_flutter/onramper_flutter.dart';

final client = OnramperClient(
  configuration: const OnramperConfiguration(
    apiKey: 'pk_live_...',
    clientId: 'YOUR_ONRAMPER_ID_CLIENT_ID',
    environment: OnramperEnvironment.production, // .development during integration
    theme: OnramperTheme.system,
    logLevel: OnramperLogLevel.off,              // .info during integration
  ),
  sessionExpirationHandler: () async {
    // Called rarely — only when the SDK's silent refresh has been exhausted
    // and a brand-new (sessionId, sessionToken) pair is required.
    // Call your backend; never embed long-lived secrets in the app.
    final pair = await yourBackend.mintOnramperSession();
    return SessionCredentials(
      sessionId: pair.sessionId,
      sessionToken: pair.sessionToken,
    );
  },
);
```

The handler is invoked via a Pigeon callback from the native side. If it throws, the native bridge surfaces the failure as `OnramperError(kind: userTokenRefreshFailed)` — the refresh is considered terminally failed and the SDK re-enters the login flow.

### Capturing SDK logs (optional)

Logging is off by default. To capture structured, sanitized SDK logs (for example for an in-app diagnostics screen), set `logLevel` and pass a `logHandler`. Console output is kept either way.

```dart
OnramperConfiguration(
  apiKey: 'pk_live_...',
  clientId: 'YOUR_ONRAMPER_ID_CLIENT_ID',
  logLevel: OnramperLogLevel.info,
  logHandler: (record) => diagnostics.add(
    '${record.timestamp.toIso8601String()} ${record.level.name} '
    '${record.category} ${record.message}',
  ),
)
```

Each `OnramperLogRecord` carries `timestamp`, `level`, `category`, `event`, `context` and `message`. The handler runs on the UI isolate, so keep it fast; if it throws, the error is reported through `FlutterError.reportError` and checkout continues. Provider messages get only best-effort redaction, so treat exported logs as possibly containing personal data. `isEventLoggingEnabled` and `isEventConsoleLoggingEnabled` (both `false` by default) enable provider-event telemetry and provider-event console logging respectively.

Do not instantiate a new `OnramperClient` for each checkout intent. One client per app session is the intended lifecycle; `reset()` exists so you don't have to recreate it.

---

## 4. Initialize

Sessions are minted server-side by your backend calling `POST /v2/partners/{apiKey}/client-sessions` (signed with your Ed25519 partner key). The token is opaque, single-use for the initial bind, and time-bounded. Never embed a long-lived secret in the Flutter bundle — fetch a fresh pair from your own backend each app launch.

```dart
final pair = await yourBackend.mintOnramperSession();

await client.initialize(
  sessionId: pair.sessionId,
  sessionToken: pair.sessionToken,
);
// client.state.kind == OnramperStateKind.ready
```

The constructor starts native configuration exactly once and stores the setup future. `initialize()` and other setup-dependent calls await it internally; no separate `configure()` call or delay is needed. A setup failure is retained and thrown by dependent methods, without an unhandled configuration future. Call and await `initialize()` once per client for normal startup, before requesting a checkout; awaiting setup does not initialize a session for you.

`initialize` performs App Attest, exchanges the bootstrap token for a DPoP-bound session, and prepares all subsequent backend calls. After it resolves, `client.state.kind` is `OnramperStateKind.ready`.

➡️ **See [Backend session endpoint](BACKEND_SESSION_ENDPOINT.md)** for the upstream API contract and a reference implementation.

---

## 5. Get a quote and prepare checkout

Build a `CheckoutIntentRequest` and call `getCheckoutRequirements`. The SDK validates the request, computes a quote, and returns the requirements (Terms of Service, amount limits, user info) that must be reflected in the UI before the user can complete checkout.

```dart
final requirements = await client.getCheckoutRequirements(
  CheckoutIntentRequest(
    transactionData: OnramperTransactionData(
      source: 'usd',
      destination: 'btc',
      amount: 100,
      type: TransactionType.buy,
      paymentMethod: 'applepay',
      country: 'us',
      subdivision: 'us-ca',
      wallet: const WalletInfo(
        network: 'bitcoin',
        address: 'bc1q...',
      ),
    ),
    // Optional: restrict to a specific set of provider IDs.
    // onlyOnramps: ['coinbase', 'paybis'],
  ),
  // Optional: style the native checkout button. Omit to use the SDK default.
  buttonStyle: const CheckoutButtonStyle(
    backgroundColor: Color(0xFF0050FF),
    foregroundColor: Colors.white,
    borderRadius: 24,
  ),
);

print('Quote: ${requirements.quote.payout} ${requirements.quote.ramp}');
print('Checkout id: ${requirements.headlessCheckoutId}');
```

The returned `CheckoutRequirementsResult` carries:

| Field | Description |
|---|---|
| `quote` | Computed onramp quote (rate, fees, receive amount). All fields non-null. A missing quote surfaces as `OnramperErrorKind.quoteUnavailable` instead. |
| `requirements` | Tagged-union list of `tos`, `amountLimit`, `userInfo`, and `reverification` requirements. |
| `headlessCheckoutId` | Opaque id you can log alongside your own telemetry. |
| `buttonHandle` | Opaque id addressing the native checkout button. `OnramperCheckoutButton` looks it up automatically. |

The convenience getter `requirements.tos` returns just the ToS entries for direct rendering.

### Prefill (optional)

If you already know some user details, pass them as `prefill:` so the OnramperID sign-in and additional-info screens arrive pre-populated:

```dart
final requirements = await client.getCheckoutRequirements(
  request,
  prefill: const OnramperUserPrefill(
    firstName: 'Ada',
    lastName: 'Lovelace',
    phoneNumber: '+3712345678', // E.164
  ),
);
```

Prefill is best-effort and never blocks sign-in. Blank fields are ignored. A prefilled phone number is a candidate the user still verifies. **Pass `email` only when you're confident it's the address the user will sign in with:** if it doesn't match, the whole prefill is dropped, which is worse than omitting `email`. Prefill is enabled per integration; talk to your Onramper representative before relying on it.

### Re-quoting

Calling `getCheckoutRequirements` again (or `reset()` / `signOut()`) supersedes an earlier call that's still in flight. The earlier call throws `OnramperError` with kind `intentInvalidated`; ignore it while you wait for the latest quote. Buttons from earlier calls that weren't shown yet are released and render nothing. Prepared buttons expire after 5 minutes. A button that's already on screen can't be recalled, so hide it while you re-quote and show the new `requirements` when the call returns.

---

## 6. Render the button

Embed `OnramperCheckoutButton` anywhere a regular Flutter widget would go. It renders the native SwiftUI checkout button via a Flutter `UiKitView` (platform view), including the ToS consent sentence below Buy, and sizes itself to its content.

```dart
// The button's colors / border radius are set via
// getCheckoutRequirements(buttonStyle:) — see §5.
OnramperCheckoutButton(requirements: requirements)
```

Tapping the button drives the native checkout flow internally:

1. Records the ToS acceptance timestamp.
2. Presents the OnramperID login sheet (a native `WKWebView`) if the provider requires identity. The same sheet also handles phone re-verification.
3. Finalizes the intent with Onramper's backend.
4. Presents the payment surface (Apple Pay, card webview, deep-link) chosen from the finalize response.
5. Silently re-authenticates if any token expires mid-flow.

The button sizes itself to its native content — the Buy button plus any Terms of Service text and provider payment disclosures (for example MoonPay's, shown next to the Apple Pay button and not hideable). Don't wrap it in a fixed-height container.

The button owns the whole loop — no separate `presentCheckout()` call is needed.

---

## 7. Observe state and events

The client exposes two complementary observation surfaces.

```dart
// ChangeNotifier — works with Provider, AnimatedBuilder, ValueListenableBuilder.
AnimatedBuilder(
  animation: client,
  builder: (_, __) => Text('State: ${client.state.kind.name}'),
)

// Broadcast Stream — idiomatic for Riverpod, StreamBuilder, await for.
StreamBuilder<CheckoutEvent>(
  stream: client.events,
  builder: (_, snapshot) {
    final event = snapshot.data;
    if (event == null) return const SizedBox.shrink();
    return Text('Event: ${event.kind.name}');
  },
)
```

Both surfaces see the same events. State changes also fan out via `client.stateStream` if you prefer streams to `ChangeNotifier`.

Terminal events to wire into analytics:

| Event | Payload |
|---|---|
| `CheckoutEventKind.completed` | `event.checkoutId` |
| `CheckoutEventKind.failed` | `event.error` (`OnramperError`) |

Provider-lifecycle events forwarded from the third-party checkout webview (not every provider emits every kind):

| Event | Description |
|---|---|
| `checkoutCancelled` | User dismissed the payment sheet before completing. |
| `providerReady` | Provider page finished loading. |
| `paymentAuthorized` | User authorized payment (e.g. Apple Pay). Not terminal. |
| `paymentProcessing` | Provider is settling. |
| `paymentCancelled` | Provider reports the user cancelled (distinct from `checkoutCancelled`). |
| `providerError` | Provider reported non-recoverable failure; `event.providerReason` carries a human-readable string. |

### Outcomes and the transaction id

| Event | Meaning |
|---|---|
| `completed` | Payment completed. `event.checkoutId` is populated. |
| `paymentPending` | Payment accepted but not yet settled. Neither success nor failure: show a "processing" state and track the transaction through your backend and webhooks. Don't start another payment because one is pending. |
| `failed` | `event.error` carries the typed `OnramperError`. Show `error.userMessage` and `error.supportCode`. |

```dart
client.events.listen((event) {
  switch (event.kind) {
    case CheckoutEventKind.completed:
      showSuccess(client.currentTransactionId);
    case CheckoutEventKind.paymentPending:
      showProcessing(client.currentTransactionId);
    case CheckoutEventKind.failed:
      final e = event.error!;
      showError('${e.userMessage}\nError code: ${e.supportCode}');
    default:
      break;
  }
});
```

`client.currentTransactionId` is Onramper's durable id for the transaction. It's set when the checkout is finalized (before the payment surface appears), notifies listeners, and is cleared by a new checkout or `reset()`. **Store it and quote it to Onramper support.** It's distinct from the checkout id on `checkoutStarted` / `completed`, which identifies one attempt; a journey can have several checkout ids but at most one transaction id. The same value is on `event.finalizeResponse.onramperTransactionId`.

Additional provider events in this release: `challengeStarted` / `challengeCompleted` (3-D Secure) and `customerOnboardingRequired` (MoonPay guest checkout unavailable; the SDK opens MoonPay onboarding). These report progress, not payment completion.

`checkoutFinalized` events additionally carry `event.finalizeResponse` — the full `CheckoutFinalizeResponse` including `headlessCheckoutData` (payment URL, render type, payment type).

---

## 8. Error handling

Operational SDK and platform-bridge failures from public calls throw `OnramperError`, including `OnramperClient.sdkVersion()` and `dispose()`. Programming errors propagate unchanged. SDK errors delivered as `OnramperErrorDto` retain their SDK kind and structured fields. For other bridge failures, the mapping is:

| Native exception / code | `OnramperErrorKind` |
|---|---|
| `PlatformException`: `not_configured` | `notConfigured` (Dart-only) |
| `PlatformException`: `not_initialized` | `notInitialized` (existing kind) |
| `PlatformException`: `missing_response` | `missingResponse` (Dart-only) |
| Any other `PlatformException`, or `MissingPluginException` | `platformFailure` (Dart-only) |

The original error stack is preserved. Nullable diagnostics `cause` (`Object?`), `stackTrace` (`StackTrace?`) and `platformCode` (`String?`) retain the original exception, stack and platform code where available. Native `PlatformException.details` remains accessible through `cause`; `platformCode` is distinct from the numeric backend `code`; for `MissingPluginException`, it is synthesized as `missing_plugin` rather than copied from an original exception code. These diagnostics are not safe end-user copy: show `userMessage` and `supportCode` instead. Catch `OnramperError` rather than `PlatformException` for operational failures, and update exhaustive switches for the three new Dart-only enum cases. Existing public method signatures are unchanged.

Operational failures from calls throw `OnramperError`, and `failed` events carry one. Every error has `userMessage` — plain copy that's safe to show users — and `supportCode`, a short stable code that's safe to show next to it and matches what the SDK logs:

```dart
showError('${error.userMessage}\nError code: ${error.supportCode}');
```

```dart
try {
  final result = await client.getCheckoutRequirements(request);
  setState(() => requirements = result);
} on OnramperError catch (error) {
  switch (error.kind) {
    case OnramperErrorKind.amountOutOfRange:
      showAmountPrompt(min: error.minAmount, max: error.maxAmount);
    case OnramperErrorKind.quoteUnavailable:
      showMessage('No quote available — try a different amount.');
    case OnramperErrorKind.checkoutForbidden:
      showMessage('Checkout is not available for your region.');
    case OnramperErrorKind.temporaryFailure:
      showRetry(after: error.retryAfterSeconds ?? 5);
    case OnramperErrorKind.deviceBlocked:
    case OnramperErrorKind.attestationFailed:
      showTerminalMessage('Unable to continue on this device.');
    case OnramperErrorKind.notConfigured:
    case OnramperErrorKind.missingResponse:
    case OnramperErrorKind.platformFailure:
      // Inspect diagnostics; do not automatically retry bridge failures.
      showMessage('${error.userMessage}\nError code: ${error.supportCode}');
    case OnramperErrorKind.unrecoverable:
      await client.reset();
      showRetry();
    default:
      showRetry();
  }
}
```

| `OnramperErrorKind` | `recoverable` | Suggested action |
|---|---|---|
| `notInitialized` | false | Await `initialize()` before calling other methods. |
| `initializationFailed` | true | Show a retry affordance; re-call `initialize()` with a fresh credential pair. |
| `attestationFailed` | false | Show a "device unsupported" screen; do not retry. |
| `invalidStateTransition` | false | Log to crash reporting — this is a bug in the integration. |
| `invalidState` | false | Check `client.state.kind` before calling and gate UI accordingly. |
| `networkError` | true | Show retry with a "check your connection" message. |
| `decodingError` | false | Log `debugInfo`; surface as a generic failure. |
| `timeout` | true | Offer a retry; the network may be slow. |
| `requirementNotSatisfied` | true | Re-call `getCheckoutRequirements` and surface the outstanding requirement. |
| `amountOutOfRange` | true | Prompt user to enter a new amount; display `minAmount`/`maxAmount`. |
| `oidcFlowCancelled` | true | Tapping Buy again retries; usually no UI action needed. |
| `oidcTokenExchangeFailed` | true | Offer retry; verify `clientId` if it persists. |
| `oidcFlowFailed` | true | Offer retry; log `debugInfo`. |
| `userTokenInvalid` | true | SDK will re-present login automatically. |
| `userTokenRefreshFailed` | true | Button re-presents the login sheet; usually no action needed. |
| `webviewLoadFailed` | true | Offer retry; check connectivity. |
| `deepLinkFailed` | true | Offer retry. |
| `invalidRequest` | true | Fix the offending parameter (`error.field`) and retry. |
| `quoteUnavailable` | true | Suggest a different amount, currency, or payment method. |
| `checkoutForbidden` | false | Show a "not available for this configuration" message. |
| `temporaryFailure` | true | Show retry; respect `retryAfterSeconds` if present. |
| `unrecoverable` | false | Call `reset()`, then re-`initialize()`; show retry. |
| `configurationError` | false | Not user-actionable; surface as a developer/support issue. |
| `deviceBlocked` | false | Show a "unable to continue on this device" message. |
| `securityStorageFailed` | false | Rare; log `debugInfo` and surface a generic error. |
| `securityTrustFailed` | false | Rare; log `error.host` and surface a generic error. |
| `paymentFailed` | true | Show `userMessage`; let the user try another payment method. |
| `providerFailed` | false | Show `userMessage`; check the transaction status before offering another payment. |
| `applePayNotConfigured` | false | Ask the user to add a card in Wallet, or offer another payment method. |
| `intentInvalidated` | true | Ignore it; use the latest `getCheckoutRequirements` result. |
| `clientDisposed` | false | Create a new `OnramperClient`. |
| `notConfigured` | false | _Dart-only._ Native plugin has no configured client; inspect setup failure and lifecycle diagnostics. |
| `missingResponse` | false | _Dart-only._ Required native response missing. Do not automatically retry; inspect diagnostics and report the bridge failure. |
| `platformFailure` | false | _Dart-only._ Do not automatically retry; check platform support, plugin registration and native build. |

The numeric backend error code is preserved on `OnramperError.code` when one was present. Switch on `kind`, not the numeric code.

---

## 9. Theming

`CheckoutButtonStyle` styles the native checkout button.

**Native button appearance** — passed to `getCheckoutRequirements(buttonStyle:)`:

| Property | Type | Default |
|---|---|---|
| `backgroundColor` | `Color?` | SDK default (system blue) |
| `foregroundColor` | `Color?` | SDK default (white) |
| `borderRadius` | `double` | `12` |

```dart
final requirements = await client.getCheckoutRequirements(
  request,
  buttonStyle: const CheckoutButtonStyle(
    backgroundColor: Color(0xFF0050FF),
    foregroundColor: Colors.white,
    borderRadius: 24,
  ),
);

OnramperCheckoutButton(requirements: requirements)
```

The native button renders the Terms of Service consent sentence (with its links) below Buy and opens the links itself. `CheckoutButtonStyle.tosStyle` / `tosLinkStyle` and `OnramperCheckoutButton.onLinkTap` are deprecated and have no effect.

The button label ("Buy") is fixed by the SDK and not overridable from Dart.

---

## 10. Lifecycle

- **`client.reset()`** — clears cached checkout state on both sides of the bridge, including `currentTransactionId` (read it first). Call before starting a fresh `getCheckoutRequirements` when the user changes amount, currency, or wallet. After reset, `client.state.kind` returns to `OnramperStateKind.ready`.
- **`client.signOut()`** — wipes cached OnramperID (OIDC) tokens. The partner session (DPoP key + session token) is preserved, but the next checkout that requires identity re-prompts the login sheet.
- **`client.cancelPreparedIntent(buttonHandle)`** — drops a specific stored native checkout button by handle without tearing down the client. Call this on `requirements.buttonHandle` when your UI navigates away from a prepared intent without ever showing the button.
- **`client.dispose()`** — waits for pending setup and attempts native cleanup even if setup failed. Repeated calls return the same future and share its success or failure; cleanup runs once. Both stream closes are initiated without waiting for paused subscribers, and `super.dispose()` always runs, even if native cleanup fails. Native cleanup platform failures throw `OnramperError`. Callbacks are detached and late callbacks ignored; if a newer client has been created since, its callbacks and native client are left in place. Subsequent setup-dependent methods throw `clientDisposed`; `reset()`, `signOut()` and `cancelPreparedIntent()` do nothing. Await disposal when possible; Flutter's synchronous `State.dispose()` must attach an error handler to the returned future.

```dart
@override
void dispose() {
  client.dispose().catchError((Object error, StackTrace stack) {
    // Report to your diagnostics; do not show raw exception details to users.
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      context: ErrorDescription('while disposing OnramperClient'),
    ));
  });
  super.dispose();
}
```

---

## 11. Before going live

- Production `apiKey` and `clientId` configured per build flavour (no staging credentials in release builds).
- App Attest entitlement set to `production` in your release provisioning profile.
- Backend session-mint endpoint deployed and reachable from the production app; returns both `sessionId` and `sessionToken`.
- `sessionExpirationHandler` wired and tested end-to-end.
- Tested on a real device — attestation path verified.
- Error UI covers at minimum `amountOutOfRange`, `quoteUnavailable`, `checkoutForbidden`, `temporaryFailure`, `networkError`, `deviceBlocked`, `configurationError`, and `unrecoverable`.
- Analytics hooked into `client.events` or `client.stateStream`.
- `client.dispose()` called on widget unmount.
