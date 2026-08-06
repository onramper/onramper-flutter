# OnramperSDK for Flutter — Integration Guide

A short, practical walkthrough for partners adding the Onramper Flutter plugin to an iOS app. For the underlying native reference (state machine, error catalogue, BFF contract), see the native iOS SDK's [`integration-guide.md`](https://github.com/onramper/onramper-ios/blob/master/integration-guide.md).

## Overview

`onramper_flutter` is the official Flutter plugin for the Onramper crypto onramping platform. It wraps the native iOS OnramperSDK and exposes an idiomatic Dart API for configuring the SDK, requesting a checkout, observing state, and embedding a self-contained checkout button. The plugin is **iOS-only** (Android is not supported in this release) and requires Apple's **App Attest** capability. The bundled iOS SDK is downloaded from the public [`onramper/onramper-ios`](https://github.com/onramper/onramper-ios) release binaries at `pod install` time (sha256-pinned to a specific SDK version) — no authentication required.

## 1. iOS app prerequisites

Before writing any Dart code, the iOS Runner target must be configured for App Attest. Most integration issues trace back to one of the steps below.

- **Enable the App Attest capability** on the Runner target. In Xcode: select the `Runner` target → **Signing & Capabilities** → **+ Capability** → **App Attest**.
- **Add `Runner.entitlements`** with `com.apple.developer.devicecheck.appattest-environment` set to `development` (debug builds) or `production` (App Store / TestFlight). The example app ships a working file at `example/ios/Runner/Runner.entitlements`:

  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
      <key>com.apple.developer.devicecheck.appattest-environment</key>
      <string>development</string>
  </dict>
  </plist>
  ```

- **Set iOS deployment target to 16.0 or higher** in both `ios/Podfile` (`platform :ios, '16.0'`) and the Runner Xcode project (Build Settings → iOS Deployment Target).
- **Register your Flutter app's bundle identifier with Onramper** so the attestation service accepts it. Bundle IDs are validated server-side; an unregistered bundle ID is rejected with `OnramperErrorKind.attestationFailed`.
- **Run on a real device.** App Attest is unavailable on the iOS Simulator. Attempting to attest on a simulator surfaces as `OnramperError(kind: attestationUnavailable)` (mapped to `attestationFailed`); test on a physical device throughout integration.

## 2. Install

Add the plugin to your app's `pubspec.yaml`:

```yaml
dependencies:
  onramper_flutter: ^1.1.2
```

Or, to consume from git:

```yaml
dependencies:
  onramper_flutter:
    git:
      url: git@github.com:onramper/onramper-flutter.git
      ref: v1.1.2
```

Then fetch packages and pods:

```bash
flutter pub get
cd ios && pod install
```

The `pod install` step downloads the pinned OnramperSDK.xcframework from the public [`onramper/onramper-ios`](https://github.com/onramper/onramper-ios) release into `ios/Frameworks/` and links it into the Runner project. The download is sha256-verified against the checksum baked into the podspec, so a corrupted or unexpected binary fails install. No GitHub authentication is required for the anonymous download; if you hit rate limits (60/hour anonymous), export `ONRAMPER_IOS_READ_TOKEN` or `GITHUB_TOKEN` to bump the ceiling to 5000/hour.

## 3. Configure the client

Create one `OnramperClient` per app session. Pass an `OnramperConfiguration` and a `sessionExpirationHandler` that returns fresh `SessionCredentials` minted by your backend.

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
    // Called rarely — only when the native SDK's silent refresh has been
    // exhausted and a brand-new (sessionId, sessionToken) pair is required.
    // Call your backend; never embed long-lived secrets in the app.
    final pair = await yourBackend.mintOnramperSession();
    return SessionCredentials(
      sessionId: pair.sessionId,
      sessionToken: pair.sessionToken,
    );
  },
);
```

The handler is invoked from the native side via a Pigeon callback. If it throws, the native SDK surfaces the failure as `OnramperError(kind: userTokenRefreshFailed)` — the refresh is considered terminally failed and the SDK re-enters the login flow.

## 4. Initialize

Sessions are minted **server-side** by your backend calling `POST /v2/partners/{apiKey}/client-sessions` (signed with your partner key). The token is opaque, single-use, and time-bounded. Never embed a long-lived secret in your Flutter app — fetch a fresh pair from your own backend each app launch.

```dart
final pair = await yourBackend.mintOnramperSession();

await client.initialize(
  sessionId: pair.sessionId,
  sessionToken: pair.sessionToken,
);
```

`initialize` performs App Attest, exchanges the bootstrap token for a DPoP-bound session, and prepares all subsequent BFF calls. After it resolves, `client.state.kind` is `OnramperStateKind.ready`.

## 5. Prepare a checkout

Build a `CheckoutIntentRequest` describing what the user wants to buy and call `getCheckoutRequirements`. The SDK validates the request, computes a quote, and returns the requirements (Terms of Service, amount limits, user info) the integrator must reflect in the UI before the user can complete checkout.

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
    // Optional: restrict the checkout to a specific set of provider ids.
    // onlyOnramps: ['moonpay', 'paybis'],
  ),
  // Optional: style the native checkout button. Omit to use the SDK default.
  buttonStyle: const CheckoutButtonStyle(
    backgroundColor: Color(0xFF0050FF),
    foregroundColor: Colors.white,
    borderRadius: 24,
  ),
);

print('Quote: ${requirements.quote}');
print('Checkout id: ${requirements.headlessCheckoutId}');
print('Requirements: ${requirements.requirements.length}');
```

The returned `CheckoutRequirementsResult` carries:

- `quote` — the computed onramp quote (rate, fees, receive amount). Every field is non-null; a missing quote surfaces as `OnramperErrorKind.quoteUnavailable` instead.
- `requirements` — tagged-union list of `tos`, `amountLimit`, `userInfo`, and `reverification` requirements to surface to the user.
- `headlessCheckoutId` — opaque id you can log alongside your own telemetry.
- `buttonHandle` — opaque id addressing the native checkout button; `OnramperCheckoutButton` looks it up automatically, but if you need to embed the raw native button yourself you can pass this to `OnramperNativeCheckoutButton(buttonHandle: ...)`.

The convenience getter `requirements.tos` returns just the ToS entries for direct rendering.

## 6. Render the button

Embed `OnramperCheckoutButton` anywhere a regular Flutter widget would go. It renders the native SwiftUI checkout button (via a Flutter platform view) with any unsatisfied ToS lines above it.

```dart
OnramperCheckoutButton(
  requirements: requirements,
  // Optional: styling for the ToS text below the button.
  // The button's own colors / border radius are set via
  // getCheckoutRequirements(buttonStyle:) earlier — see §5.
  style: CheckoutButtonStyle(
    tosStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
  ),
)
```

Tapping the button drives the native checkout flow internally:

1. Records the ToS acceptance timestamp.
2. Presents the OnramperID login sheet (in a native `WKWebView`) if the provider requires identity — the same sheet also drives phone reverification.
3. Finalizes the intent with the BFF.
4. Presents the payment surface (Apple Pay, card webview, deep-link) chosen from the finalize response.
5. Silently re-authenticates if any token expires mid-flow.

The button owns the whole loop — no `presentCheckout()` call is needed. Both `client` (a `ChangeNotifier`) and `client.events` (a `Stream<CheckoutEvent>`) emit updates throughout, so the rest of your UI can react in parallel.

## 7. Observe state and events

The client exposes two complementary observation surfaces — pick the one that fits your state-management library.

```dart
// 1) ChangeNotifier — works with Provider, AnimatedBuilder, ValueListenableBuilder.
AnimatedBuilder(
  animation: client,
  builder: (_, __) => Text('State: ${client.state.kind.name}'),
)

// 2) Broadcast Stream — idiomatic for Riverpod / StreamBuilder / await for.
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

The terminal events you'll typically wire into analytics are:

- `CheckoutEventKind.completed` — happy path; `event.checkoutId` is populated.
- `CheckoutEventKind.failed` — `event.error` is populated with the typed `OnramperError`.

Provider-lifecycle events forwarded from the third-party checkout webview (not every provider emits every kind):

- `checkoutCancelled` — user dismissed the payment sheet before completing.
- `providerReady` — provider's page finished loading.
- `paymentAuthorized` — user authorized payment in the provider's native sheet (e.g. Apple Pay). Not terminal.
- `paymentProcessing` — provider is settling.
- `paymentCancelled` — provider reports the user cancelled (distinct from `checkoutCancelled`).
- `providerError` — provider reported a non-recoverable failure; `event.providerReason` carries a short human-readable string.

`checkoutFinalized` events additionally carry `event.finalizeResponse` — the full `CheckoutFinalizeResponse` including `headlessCheckoutData` (payment URL, render type, payment type) — if you need more than the `renderContext` summary.

## 8. Error handling

All errors thrown across the Flutter boundary are `OnramperError` instances. `kind` is the discriminator; the remaining fields carry context where it's known. The full enum from `lib/src/models/errors.dart`:

| `OnramperErrorKind` | Description | `recoverable` default | Suggested action |
|---|---|---|---|
| `notInitialized` | A method requiring an initialized session was called before `initialize()` resolved. | false | Await `initialize()` before calling other methods. |
| `initializationFailed` | `initialize()` could not stand up a session (attestation, network, or backend rejection). | true | Show a retry affordance; re-call `initialize()` with a fresh credential pair. |
| `attestationFailed` | App Attest is unavailable or the device was rejected (simulator, jailbreak, unregistered bundle ID). | false | Show a "device unsupported" screen; do not retry. |
| `invalidStateTransition` | The native state machine rejected a transition (developer error). `fromState`/`toState` are populated. | false | Log to crash reporting; this indicates a bug in the integration. |
| `invalidState` | A method was called from an inappropriate state. `expectedState`/`actualState` are populated. | false | Check `client.state.kind` before calling and gate UI accordingly. |
| `networkError` | Transport-level failure (DNS, TLS, offline). `code` may carry the HTTP status. | true | Show a retry affordance with a "check your connection" message. |
| `decodingError` | The BFF returned a payload the SDK could not decode. | false | Log `debugInfo`; surface as a generic failure. |
| `timeout` | A BFF call exceeded its timeout. | true | Offer a retry; the network may be slow. |
| `requirementNotSatisfied` | Checkout was attempted while a requirement (ToS, user info, amount) was still unsatisfied. | true | Re-call `getCheckoutRequirements` and surface the outstanding requirement. |
| `amountOutOfRange` | Amount falls outside the provider's bounds. `minAmount` and `maxAmount` are populated. | true | Prompt the user to enter a new amount; display `minAmount`/`maxAmount` from the error. |
| `oidcFlowCancelled` | User dismissed the OnramperID login sheet. | true | Tapping Buy again retries; usually no UI action needed. |
| `oidcTokenExchangeFailed` | The OIDC authorization code → token exchange failed. | true | Offer a retry; verify `clientId` configuration if it persists. |
| `oidcFlowFailed` | The OIDC webview hit a terminal error (load failure, invalid response). | true | Offer a retry; log `debugInfo`. |
| `userTokenInvalid` | The OnramperID user token was rejected by the BFF and could not be refreshed. | true | The SDK will re-present login automatically; surface only if you want to log. |
| `userTokenRefreshFailed` | OnramperID refresh token terminally rejected. SDK has already re-entered the login flow. | true | Usually no action; the button re-presents the login sheet. |
| `webviewLoadFailed` | The payment webview failed to load. | true | Offer a retry; check connectivity. |
| `deepLinkFailed` | A deep-link return from the payment surface failed. | true | Offer a retry. |
| `invalidRequest` | A 4xx validation error from the BFF. `field` names the offending input where known. | true | Fix the offending parameter (e.g., `amount`, `wallet.address`) and retry. |
| `quoteUnavailable` | No provider returned a usable quote for this request. | true | Suggest a different amount, currency, or payment method. |
| `checkoutForbidden` | Region, KYC tier, or partner policy blocks this checkout. | false | Show a "not available for this configuration" message. |
| `temporaryFailure` | Server-side 5xx. `retryAfterSeconds` may be populated. | true | Show a retry affordance; respect `retryAfterSeconds` if present. |
| `unrecoverable` | Internal recovery (refresh + re-bootstrap) was exhausted. | false | Show an error, call `reset()`, then re-`initialize()`. |
| `configurationError` | Partner setup error (bad API key, missing scope). | false | Not user-actionable; surface as a developer/support issue. |
| `deviceBlocked` | The BFF terminally rejected the device. | false | Show a "unable to continue on this device" message. |
| `securityStorageFailed` | Keychain read/write on the native side failed. | false | Rare; log `debugInfo` and surface a generic error. |
| `securityTrustFailed` | Certificate pinning check failed for a host. `host` names the affected server. | false | Rare; log `host` and surface as a generic error. |

Catch `OnramperError` directly when you need to branch on `kind`:

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

The native SDK preserves the BFF's numeric error code on `OnramperError.code` when one was present. See the headless-service catalogue at [`headless-service/src/errors/index.ts`](https://github.com/onramper/onramper-services/blob/master/headless-service/src/errors/index.ts) for the canonical mapping (the SDK translates these to typed `OnramperErrorKind`s — you should not switch on the numeric code directly).

## 9. Theming

`CheckoutButtonStyle` splits its fields between two places:

**Native button appearance** — passed to `getCheckoutRequirements(buttonStyle:)` (see §5) and rendered inside the SwiftUI checkout button:

| Property | Type | Default | Bridged as |
|---|---|---|---|
| `backgroundColor` | `Color?` | SDK default (system blue) | Hex string `#RRGGBBAA` |
| `foregroundColor` | `Color?` | SDK default (white) | Hex string `#RRGGBBAA` |
| `borderRadius` | `double` | `12` | Points |

**ToS-line text styling** — passed to `OnramperCheckoutButton(style:)` for the Dart-drawn text above the button:

| Property | Type | Default |
|---|---|---|
| `tosStyle` | `TextStyle?` | `TextStyle(fontSize: 12)` |
| `tosLinkStyle` | `TextStyle?` | inherits from `tosStyle` with underline + blue color |

A custom-styled example:

```dart
// Native button appearance goes to getCheckoutRequirements.
final requirements = await client.getCheckoutRequirements(
  request,
  buttonStyle: const CheckoutButtonStyle(
    backgroundColor: Color(0xFF0050FF),
    foregroundColor: Colors.white,
    borderRadius: 24,
  ),
);

// ToS text styling goes to the widget.
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

The native button's label text ("Buy") is fixed by the SDK and not currently overridable from Dart.

## 10. Lifecycle: reset, signOut, cancelPreparedIntent, dispose

- **`client.reset()`** clears cached checkout state on both sides of the bridge. Call it before starting a fresh `getCheckoutRequirements` with inputs that aren't a continuation of the previous flow (e.g., user navigated back and changed the amount). After reset the client returns to `OnramperStateKind.ready` and is immediately reusable.
- **`client.signOut()`** wipes cached OnramperID (OIDC) tokens. Distinct from `reset()`: the partner session (DPoP key + session token) is preserved, but the next checkout that requires identity re-prompts the login sheet. Call this from an "Sign out" button in your app.
- **`client.cancelPreparedIntent(buttonHandle)`** drops a specific stored native checkout button by handle without tearing down the client. Useful when your UI navigates away from a prepared intent without ever showing the button — call this on the previous `requirements.buttonHandle` so the native resources are released promptly.
- **`client.dispose()`** shuts the plugin down, detaches Pigeon callbacks, and closes the broadcast streams. Call it from the consumer widget's `State.dispose()`. The method is idempotent.
- **Do not** instantiate a new `OnramperClient` for each checkout intent. One client per app session is the intended lifecycle; `reset()` exists precisely so you don't have to recreate it.

```dart
@override
void dispose() {
  client.dispose();
  super.dispose();
}
```

See `example/lib/main.dart` for a full working example that wires `initialize`, `getCheckoutRequirements`, and the button into a single screen with proper disposal.

## 11. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `OnramperError(kind: attestationFailed)` on first call | Running on iOS Simulator, or bundle ID not registered with Onramper | Run on a real device; confirm bundle ID is registered. |
| `pod install` fails with deployment target error | `ios/Podfile` and Runner project still on iOS < 16 | Set `platform :ios, '16.0'` in `Podfile` and bump Runner's deployment target to match. |
| `pod install` fails with `curl: (22) 403 rate limit exceeded` | Hit GitHub's 60/hour anonymous request cap | Export `ONRAMPER_IOS_READ_TOKEN` or `GITHUB_TOKEN` to authenticate the request (5000/hour cap), then re-run. |
| `pod install` fails with `curl: (22) 404` | `onramper/onramper-ios` release asset id in the podspec doesn't exist upstream | Bump `onramper_flutter` to a version whose bundled SDK release is still published, or open an issue on this repo. |
| App crashes immediately on launch with attestation error | Missing or wrong `Runner.entitlements` | Add the `com.apple.developer.devicecheck.appattest-environment` entitlement; match `development` to debug builds, `production` to release. |
| `OnramperError(kind: unrecoverable)` mid-flow | Both token refresh paths exhausted (rare) | Call `client.reset()`, then `client.initialize(...)` with fresh credentials. |
| Want to map a specific BFF error code | `OnramperError.code` carries the numeric BFF code when present | Cross-reference [`headless-service/src/errors/index.ts`](https://github.com/onramper/onramper-services/blob/master/headless-service/src/errors/index.ts); the SDK preserves `bffErrorCode` on `OnramperError.code`. |

## 12. Reference: example app

The `example/` directory contains a complete runnable Flutter app demonstrating every section of this guide. Start there if a snippet above doesn't compile in your project — it will reveal which prerequisite step was missed.

```bash
cd example
flutter pub get
cd ios && pod install && cd ..
flutter run --release   # release build avoids the Flutter debug overlay over the WKWebView
```
