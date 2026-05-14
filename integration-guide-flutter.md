# OnramperSDK for Flutter — Integration Guide

A short, practical walkthrough for partners adding the Onramper Flutter plugin to an iOS app. For the underlying native reference (state machine, error catalogue, BFF contract), see the native iOS SDK's [`integration-guide.md`](https://github.com/onramper/onramper-ios/blob/master/integration-guide.md).

## Overview

`onramper_sdk` is the official Flutter plugin for the Onramper crypto onramping platform. It wraps the native iOS OnramperSDK and exposes an idiomatic Dart API for configuring the SDK, requesting a checkout, observing state, and embedding a self-contained checkout button. The plugin is **iOS-only** (Android is not supported in this release), requires Apple's **App Attest** capability, and ships the underlying iOS SDK as a **vendored XCFramework** so the package is fully self-contained — `pod install` pulls everything from the package itself, no extra source repositories required.

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
- **Run `git lfs install` and `git lfs pull` after cloning** if you are working on the plugin source locally. The vendored XCFramework is tracked with Git LFS — without LFS hydration, you will see pointer text files instead of the binary framework and `pod install` will fail.

## 2. Install

Add the plugin to your app's `pubspec.yaml`. The repository is private during integration; integrators are issued a deploy key and pull over SSH.

```yaml
dependencies:
  onramper_sdk:
    git:
      url: https://github.com/onramper/onramper-flutter.git
      ref: v1.0.0
```

While the repository remains private, use the SSH URL with your deploy key:

```yaml
dependencies:
  onramper_sdk:
    git:
      url: git@github.com:onramper/onramper-flutter.git
      ref: v1.0.0
```

Then fetch packages and pods:

```bash
flutter pub get
cd ios && pod install
```

The `pod install` step links the vendored XCFramework into the Runner project. If you see pointer-file errors, run `git lfs pull` in the plugin checkout before `pod install`.

## 3. Configure the client

Create one `OnramperClient` per app session. Pass an `OnramperConfiguration` and a `sessionExpirationHandler` that returns fresh `SessionCredentials` minted by your backend.

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

The handler is invoked from the native side via a Pigeon callback. If it throws, the native SDK surfaces the failure as an `OnramperError` with `kind == initializationFailed`.

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
      onramp: 'transak',
      source: 'usd',
      destination: 'btc',
      amount: 100,
      type: TransactionType.buy,
      paymentMethod: 'creditcard',
      country: 'us',
      subdivision: 'us-ca',
      wallet: const WalletInfo(
        network: 'bitcoin',
        address: 'bc1q...',
      ),
    ),
  ),
);

print('Quote: ${requirements.quote}');
print('Checkout id: ${requirements.headlessCheckoutId}');
print('Requirements: ${requirements.requirements.length}');
```

The returned `CheckoutRequirementsResult` carries:

- `quote` — the computed onramp quote (rate, fees, receive amount).
- `requirements` — tagged-union list of `tos`, `amountLimit`, and `userInfo` requirements to surface to the user.
- `headlessCheckoutId` — opaque id you can log alongside your own telemetry.

The convenience getter `requirements.tos` returns just the ToS entries for direct rendering.

## 6. Render the button

Embed `OnramperCheckoutButton` anywhere a regular Flutter widget would go. It rebuilds automatically as the client's state changes and renders the ToS sentence underneath itself.

```dart
OnramperCheckoutButton(
  client: client,
  requirements: requirements,
  style: const CheckoutButtonStyle(borderRadius: 8),
)
```

Tapping the button calls `client.presentCheckout()` natively, which presents a modal that handles:

1. The OnramperID OIDC login flow (in a `WKWebView`), if user authentication is required.
2. The payment surface — Apple Pay, card form, or provider-hosted page — chosen by the BFF based on the request and provider response.
3. Silent re-authentication if any token expires mid-flow.

Both `client` (a `ChangeNotifier`) and `client.events` (a `Stream<CheckoutEvent>`) emit updates throughout, so the rest of your UI can react in parallel.

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

`CheckoutButtonStyle` exposes the surface area needed to fit the button into your design system:

| Property | Type | Default |
|---|---|---|
| `backgroundColor` | `Color` | `Colors.black` |
| `foregroundColor` | `Color` | `Colors.white` |
| `borderRadius` | `double` | `12` |
| `labelStyle` | `TextStyle?` | `null` (theme default) |
| `tosStyle` | `TextStyle?` | `null` (theme default) |
| `tosLinkStyle` | `TextStyle?` | `null` (theme default, underlined) |

A custom-styled example:

```dart
OnramperCheckoutButton(
  client: client,
  requirements: requirements,
  style: CheckoutButtonStyle(
    backgroundColor: const Color(0xFF0050FF),
    foregroundColor: Colors.white,
    borderRadius: 24,
    labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    tosStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
    tosLinkStyle: const TextStyle(
      fontSize: 12,
      color: Color(0xFF0050FF),
      decoration: TextDecoration.underline,
    ),
  ),
)
```

The button also accepts a `label` (defaults to `'Buy'`) and an optional `onLinkTap` callback for routing ToS link taps through your own in-app browser.

## 10. Lifecycle: reset and dispose

- **`client.reset()`** clears cached checkout state on both sides of the bridge. Call it before starting a fresh `getCheckoutRequirements` with inputs that aren't a continuation of the previous flow (e.g., user navigated back and changed the amount). After reset the client returns to `OnramperStateKind.ready` and is immediately reusable.
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
| `pod install` fails with "framework not found" | Git LFS pointer file present instead of the real XCFramework | Run `git lfs install && git lfs pull` in the plugin checkout, then `pod install` again. |
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
