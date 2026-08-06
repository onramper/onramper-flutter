# onramper_flutter

[![CI](https://github.com/onramper/onramper-flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/onramper/onramper-flutter/actions/workflows/ci.yml)
[![iOS tests](https://github.com/onramper/onramper-flutter/actions/workflows/ios-tests.yml/badge.svg)](https://github.com/onramper/onramper-flutter/actions/workflows/ios-tests.yml)

Official Flutter plugin for the [Onramper](https://onramper.com) crypto on-ramp. Wire up three calls — `configure`, `initialize`, `getCheckoutRequirements` — and render a native checkout button. No PII, no checkout UI, no auth plumbing to maintain.

**iOS-only**, requires iOS 16+ and Apple's App Attest capability. Android throws `SizedBox.shrink` from the native button (no-op fallback); requests from Android throw at the platform boundary.

## Contents

- [Versioning](#versioning)
- [Requirements](#requirements)
- [Install](#install)
- [Quick start](#quick-start)
- [Events + errors](#events--errors)
- [Documentation](#documentation)

## Versioning

`onramper_flutter` X.Y.Z bundles `OnramperSDK` X.Y.Z. Wrapper-only patch releases ship as `X.Y.Z+N` where `N` is the patch counter.

## Requirements

- Flutter 3.22+, Dart 3.4+.
- iOS 16+ deployment target.
- **App Attest capability** enabled on the Runner target with a `Runner.entitlements` file setting `com.apple.developer.devicecheck.appattest-environment` to `development` (debug) or `production` (release).
- **Real device** for testing. App Attest is not available on the iOS Simulator; attempting to initialize on a simulator surfaces as `OnramperError(kind: attestationFailed)`.
- Your app's **bundle identifier registered with Onramper**. Unregistered bundles are rejected server-side with `attestationFailed`.

## Install

```yaml
dependencies:
  onramper_flutter: ^1.1.1
```

Or, while consuming from git:

```yaml
dependencies:
  onramper_flutter:
    git:
      url: git@github.com:onramper/onramper-flutter.git
      ref: v1.1.1
```

Then:

```bash
flutter pub get
cd ios && pod install
```

The `pod install` step downloads the pinned `OnramperSDK.xcframework` from the [`onramper/onramper-ios`](https://github.com/onramper/onramper-ios) release into `ios/Frameworks/` and links it into the Runner project. The download is sha256-verified against the checksum baked into the podspec, so a corrupted or unexpected binary fails install.

`onramper-ios` is a public repository — no GitHub authentication is required. If you're behind a corporate proxy or hit anonymous rate limits (60/hour), export `ONRAMPER_IOS_READ_TOKEN` (or `GITHUB_TOKEN`, or run `gh auth login`) — the podspec will pick any of them up transparently.

## Quick start

```dart
import 'package:onramper_flutter/onramper_flutter.dart';

// 1) Create one client per app session.
final client = OnramperClient(
  configuration: const OnramperConfiguration(
    apiKey: 'pk_live_...',
    clientId: 'YOUR_ONRAMPER_ID_CLIENT_ID',
    environment: OnramperEnvironment.production,
  ),
  // Called when the native SDK's silent refresh has been exhausted and a
  // brand-new (sessionId, sessionToken) pair is required. Call your backend;
  // never embed long-lived secrets in the app.
  sessionExpirationHandler: () async {
    final pair = await yourBackend.mintOnramperSession();
    return SessionCredentials(
      sessionId: pair.sessionId,
      sessionToken: pair.sessionToken,
    );
  },
);

// 2) Bootstrap (App Attest + DPoP handshake).
final pair = await yourBackend.mintOnramperSession();
await client.initialize(
  sessionId: pair.sessionId,
  sessionToken: pair.sessionToken,
);

// 3) Prepare a checkout intent.
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
      wallet: WalletInfo(network: 'bitcoin', address: 'bc1q...'),
    ),
  ),
  // Optional: style the native button. Omit to use the SDK default.
  buttonStyle: const CheckoutButtonStyle(
    backgroundColor: Color(0xFF0050FF),
    borderRadius: 24,
  ),
);

// 4) Render the button. Tap → login → finalize → payment webview — all native.
OnramperCheckoutButton(requirements: requirements)
```

See [`example/`](https://github.com/onramper/onramper-flutter/tree/master/example) for a runnable app that wires all four steps end-to-end.

## Events + errors

Observe events via `client.events`, state via `client.state` / `client.stateStream`, and errors via `client.lastError`. All are `ChangeNotifier`-backed too — `AnimatedBuilder(animation: client, ...)` works.

Terminal events:
- `CheckoutEventKind.completed` — happy path; `event.checkoutId` populated.
- `CheckoutEventKind.failed` — `event.error` carries a typed `OnramperError`.

Provider-lifecycle events (`checkoutCancelled`, `providerReady`, `paymentAuthorized`, `paymentProcessing`, `paymentCancelled`, `providerError`) surface everything the underlying provider emits — not every provider emits every one.

Errors are typed by `OnramperErrorKind` (25 kinds) with structured payloads (`minAmount`, `maxAmount`, `retryAfterSeconds`, `field`, `host`, `debugInfo`, etc.). See the [full error table in the integration guide](https://github.com/onramper/onramper-flutter/blob/master/integration-guide-flutter.md#8-error-handling).

## Documentation

- [Integration guide](https://github.com/onramper/onramper-flutter/blob/master/integration-guide-flutter.md) — end-to-end walkthrough including App Attest setup, error handling, theming, and troubleshooting.
- [Backend session endpoint](https://github.com/onramper/onramper-flutter/blob/master/doc/BACKEND_SESSION_ENDPOINT.md) — reference implementation of the server-side call that mints `(sessionId, sessionToken)` pairs for `initialize` and `sessionExpirationHandler`.
- [CHANGELOG](https://github.com/onramper/onramper-flutter/blob/master/CHANGELOG.md) — release notes.

## License

Apache 2.0. See [`LICENSE`](LICENSE).
