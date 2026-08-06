# Getting started with `onramper_sdk`

`onramper_sdk` is the official Flutter plugin for the Onramper crypto onramping platform. It wraps the native iOS `OnramperSDK.xcframework` and exposes an idiomatic Dart API for configuring the SDK, requesting a checkout, observing state, and embedding a self-contained checkout button.

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
  onramper_sdk: ^1.1.1
```

While the repository remains private, use a git dependency:

```yaml
dependencies:
  onramper_sdk:
    git:
      url: git@github.com:onramper/onramper-flutter.git
      ref: v1.1.1
```

Fetch packages and install pods:

```bash
flutter pub get
cd ios && pod install
```

The `pod install` step downloads the pinned `OnramperSDK.xcframework` from the public [`onramper/onramper-ios`](https://github.com/onramper/onramper-ios) release into `ios/Frameworks/` and links it into the Runner project. The download is sha256-verified against the checksum baked into the podspec — a corrupted or mismatched binary fails install. No GitHub authentication is required. If you hit rate limits (60/hour anonymous), export `ONRAMPER_IOS_READ_TOKEN` or `GITHUB_TOKEN` to raise the ceiling to 5,000/hour.

---

## 2. iOS build setup

The iOS prerequisites — App Attest capability, entitlements plist, deployment target, and Podfile configuration — are covered in a dedicated guide.

➡️ **See iOS build setup**

Complete that guide before your first build, then return here for usage.

---

## 3. Configure the client

Create one `OnramperClient` per app session. Pass an `OnramperConfiguration` and a `sessionExpirationHandler` that returns fresh credentials minted by your backend.

```dart
import 'package:onramper_sdk/onramper_sdk.dart';

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

`initialize` performs App Attest, exchanges the bootstrap token for a DPoP-bound session, and prepares all subsequent BFF calls. After it resolves, `client.state.kind` is `OnramperStateKind.ready`.

➡️ **See Backend session endpoint** for the upstream API contract and a reference implementation.

---

## 5. Prepare a checkout

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

---

## 6. Render the button

Embed `OnramperCheckoutButton` anywhere a regular Flutter widget would go. It renders the native SwiftUI checkout button via a Flutter `UiKitView` (platform view), with any unsatisfied ToS lines above it.

```dart
OnramperCheckoutButton(
  requirements: requirements,
  // Optional: ToS text styling. The button's colors / border radius are set
  // via getCheckoutRequirements(buttonStyle:) — see §5.
  style: CheckoutButtonStyle(
    tosStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
  ),
)
```

Tapping the button drives the native checkout flow internally:

1. Records the ToS acceptance timestamp.
2. Presents the OnramperID login sheet (a native `WKWebView`) if the provider requires identity. The same sheet also handles phone re-verification.
3. Finalizes the intent with the BFF.
4. Presents the payment surface (Apple Pay, card webview, deep-link) chosen from the finalize response.
5. Silently re-authenticates if any token expires mid-flow.

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

`checkoutFinalized` events additionally carry `event.finalizeResponse` — the full `CheckoutFinalizeResponse` including `headlessCheckoutData` (payment URL, render type, payment type).

---

## 8. Error handling

All errors thrown across the Flutter boundary are `OnramperError` instances. `kind` is the discriminator.

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

The numeric BFF error code is preserved on `OnramperError.code` when one was present. Switch on `kind`, not the numeric code.

---

## 9. Theming

`CheckoutButtonStyle` fields split between two places:

**Native button appearance** — passed to `getCheckoutRequirements(buttonStyle:)`:

| Property | Type | Default |
|---|---|---|
| `backgroundColor` | `Color?` | SDK default (system blue) |
| `foregroundColor` | `Color?` | SDK default (white) |
| `borderRadius` | `double` | `12` |

**ToS line text styling** — passed to `OnramperCheckoutButton(style:)`:

| Property | Type | Default |
|---|---|---|
| `tosStyle` | `TextStyle?` | `TextStyle(fontSize: 12)` |
| `tosLinkStyle` | `TextStyle?` | Inherits from `tosStyle` with underline + blue |

```dart
final requirements = await client.getCheckoutRequirements(
  request,
  buttonStyle: const CheckoutButtonStyle(
    backgroundColor: Color(0xFF0050FF),
    foregroundColor: Colors.white,
    borderRadius: 24,
  ),
);

OnramperCheckoutButton(
  requirements: requirements,
  style: CheckoutButtonStyle(
    tosStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
    tosLinkStyle: const TextStyle(
      fontSize: 12,
      color: Color(0xFF0050FF),
      decoration: TextDecoration.underline,
    ),
  ),
  // Optional: route ToS link taps through your own in-app browser.
  onLinkTap: (uri) => YourInAppBrowser.open(uri),
)
```

The button label ("Buy") is fixed by the SDK and not overridable from Dart.

---

## 10. Lifecycle

- **`client.reset()`** — clears cached checkout state on both sides of the bridge. Call before starting a fresh `getCheckoutRequirements` when the user changes amount, currency, or wallet. After reset, `client.state.kind` returns to `OnramperStateKind.ready`.
- **`client.signOut()`** — wipes cached OnramperID (OIDC) tokens. The partner session (DPoP key + session token) is preserved, but the next checkout that requires identity re-prompts the login sheet.
- **`client.cancelPreparedIntent(buttonHandle)`** — drops a specific stored native checkout button by handle without tearing down the client. Call this on `requirements.buttonHandle` when your UI navigates away from a prepared intent without ever showing the button.
- **`client.dispose()`** — shuts the plugin down, detaches Pigeon callbacks, and closes the broadcast streams. Call it from the widget's `State.dispose()`. Idempotent.

```dart
@override
void dispose() {
  client.dispose();
  super.dispose();
}
```

---

## 11. Before going live

- Production `apiKey` and `clientId` configured per build flavour (no staging credentials in release builds).
- App Attest entitlement set to `production` in your release provisioning profile.
- Backend session-mint endpoint deployed and reachable from the production app; returns both `sessionId` and `sessionToken`.
- `sessionExpirationHandler` wired and tested end-to-end.
- `logLevel: OnramperLogLevel.off` in production builds.
- Tested on a real device — attestation path verified.
- Error UI covers at minimum `amountOutOfRange`, `quoteUnavailable`, `checkoutForbidden`, `temporaryFailure`, `networkError`, `deviceBlocked`, `configurationError`, and `unrecoverable`.
- Analytics hooked into `client.events` or `client.stateStream`.
- `client.dispose()` called on widget unmount.
