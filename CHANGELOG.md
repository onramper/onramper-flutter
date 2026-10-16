# Changelog

All notable changes to this project are documented in this file.
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
and the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.

## 1.3.1 — Parity with OnramperSDK for iOS 1.3.1

Bundles [OnramperSDK](https://github.com/onramper/onramper-ios) **v1.3.1**
(previously v1.1.1). Versions 1.2.x and 1.3.0 of this plugin were not
released separately; their changes are included here.

### Before you upgrade

- **Handle the new enum values.** `OnramperStateKind`, `CheckoutEventKind`
  and `OnramperErrorKind` gained values (below). An exhaustive `switch`
  without a `default` stops compiling until you handle them. Treat
  `paymentPending` as neither success nor failure.
- **Previously signed-in users sign in to OnramperID once more.** The native
  SDK now stores credentials per environment and removes the old shared
  entries on first launch.
- **Run `pod install` and rebuild.** A Dart-only update cannot replace the
  bundled iOS SDK.
- **Catch operational failures as `OnramperError`.** Migrate catches of
  `PlatformException` to `OnramperError` for SDK/bridge failures from
  `initialize`, `getCheckoutRequirements`, `reset`, `signOut`,
  `cancelPreparedIntent`, `sdkVersion` and `dispose`. SDK DTO errors keep
  their kinds. Native `not_configured`, `not_initialized` and
  `missing_response` map to `notConfigured`, `notInitialized` and
  `missingResponse`; other `PlatformException`s and `MissingPluginException`s
  map to `platformFailure`. `notConfigured`, `missingResponse` and
  `platformFailure` are new Dart-only enum cases: update exhaustive switches.
  Programming errors propagate unchanged. Public method signatures are unchanged.
- **Update manually constructed finalize responses.**
  `CheckoutFinalizeResponse(...)` now requires `onramperTransactionId`;
  supply it in application code and fixtures as well as the existing
  `headlessCheckoutId` and `headlessCheckoutData` arguments.

### Included from iOS SDK 1.2.0 – 1.3.1

- **1.2.0 — User-field prefill.** `getCheckoutRequirements(request, prefill:
  OnramperUserPrefill(...))` pre-populates OnramperID screens. It's
  best-effort and enabled per integration. Pass `email` only when you're sure
  it's the sign-in address: a mismatch drops the whole prefill.
- **1.2.1 — Transaction id.** `OnramperClient.currentTransactionId` (also on
  `CheckoutFinalizeResponse.onramperTransactionId`) is Onramper's durable id
  for the transaction. Store it and quote it to support; it's distinct from
  the per-attempt checkout id. It's cleared by a new checkout and by
  `reset()`.
- **1.2.2 — Session reliability.** Improved SDK session initialization and
  refresh. No API change.
- **1.3.0 — MoonPay Apple Pay.** The checkout button runs MoonPay's checkout
  (guest checkout or onboarding, 3-D Secure, required payment disclosures)
  with nothing to integrate. Disclosures can't be hidden.
- **1.3.0 — Pending payments.** An accepted but unsettled payment ends in
  `OnramperStateKind.paymentPending` / `CheckoutEventKind.paymentPending`
  instead of `completed`.
- **1.3.0 — Customer-facing errors.** `OnramperError.userMessage` (safe to
  show) and `supportCode` (safe to show next to it; matches logs). New kinds:
  - `paymentFailed`: the provider confirmed failure.
  - `providerFailed`: the outcome is unknown, so check before retrying.
  - `applePayNotConfigured`.

  The native failure screen's **Try Again** starts a fresh checkout.
- **1.3.0 — New events:** `challengeStarted`, `challengeCompleted` (3-D
  Secure) and `customerOnboardingRequired`. These report progress, not
  payment completion.
- **1.3.0 — Structured, sanitized logging.** `OnramperConfiguration.logHandler`
  receives `OnramperLogRecord`s (`timestamp`, `level`, `category`, `event`,
  `context`, `message`); Console output is kept. Provider messages get only
  best-effort redaction, so treat exported logs as possibly containing
  personal data. Logging is still off by default.
- **1.3.0 — Provider metadata.** `QuoteResponse.providerContext`
  (`ProviderJSONValue`) and `PaymentDisclosure` (`QuoteResponse.paymentDisclosures`).
  Most integrations can ignore them; don't log them.
- **1.3.0 — Credential isolation.** Credentials no longer carry over between
  environments.
- **1.3.1 — SDK version.** `await OnramperClient.sdkVersion()`.

### Flutter API additions

- `OnramperUserPrefill`; `getCheckoutRequirements(..., prefill:)`
- `OnramperClient.currentTransactionId` (notifies listeners)
- `OnramperClient.sdkVersion()` and `OnramperClient.wrapperVersion`
- `OnramperConfiguration.logHandler`, `isEventLoggingEnabled`,
  `isEventConsoleLoggingEnabled` (both default `false`)
- `OnramperLogRecord`, `OnramperLogHandler`, `ProviderJSONValue`,
  `PaymentDisclosure`
- `OnramperError.userMessage`, `OnramperError.supportCode`
- Nullable `OnramperError.cause` (`Object?`), `stackTrace` (`StackTrace?`) and
  `platformCode` (`String?`) diagnostics. The original exception (including
  native details) is retained via `cause`, and the original stack is preserved.
  `platformCode` is synthesized as `missing_plugin` for `MissingPluginException`;
  otherwise it retains the original platform exception code when available.
  These diagnostics are not safe end-user copy.

### Wrapper fixes

- **Awaitable setup.** Construction starts configuration exactly once.
  `initialize` and setup-dependent calls await the stored setup internally.
  Setup failures are retained and thrown by dependent methods without an
  unhandled configure future. Initialize once per client for normal startup.
- **Cleanup after failures.** `dispose()` waits for pending setup and attempts
  native cleanup even if setup failed. Repeated calls share one future and its
  success or failure, with no duplicate cleanup. Both stream closes are initiated
  without waiting for paused subscribers; `super.dispose()` always runs even if
  native cleanup fails. Platform failures are normalized to `OnramperError`.
- **Self-sizing checkout button.** The native button reports its content
  height (Buy button, ToS text, payment disclosures) and the platform view
  resizes to match. `OnramperNativeCheckoutButton.height` is deprecated and
  now acts only as a minimum. A new `buttonHandle` now creates a new native
  view instead of keeping the previous quote's button.
- **ToS text is rendered once, natively.** `OnramperCheckoutButton` no longer
  adds Dart ToS lines under the native button, which shows the consent
  sentence itself. `CheckoutButtonStyle.tosStyle` / `tosLinkStyle` and
  `OnramperCheckoutButton.onLinkTap` are deprecated and have no effect; the
  plugin no longer depends on `url_launcher`.
- **Superseded preparations are released.** A new `getCheckoutRequirements`,
  `reset()` or `signOut()` invalidates earlier unshown buttons. A superseded
  in-flight call throws `OnramperError` with kind `intentInvalidated`; ignore
  it when waiting for the latest quote. Expired (5 min) or invalidated
  handles render nothing.
- **Checkout button follows the configured theme.** With
  `OnramperTheme.light` or `.dark`, the embedded button (including its ToS
  text) renders in that theme even when the device appearance differs, so a
  light app on a dark-mode phone no longer shows white text on white.
  `OnramperTheme.system` still follows the device. Set the theme to match
  your app.
- **Safe after `dispose()`.** Setup-dependent methods throw `OnramperErrorKind.clientDisposed`;
  `reset()`, `signOut()` and `cancelPreparedIntent()` do nothing, and late
  native callbacks are ignored. Disposing an older client no longer detaches
  or tears down a client created after it.
- Podspec license corrected to Apache-2.0.

### Example app

- Pending payments are shown separately; errors show `userMessage` and the
  support code.
- Shows plugin and SDK versions and the current transaction id.
- **Prefill (optional)** form and automatic quotes. Purchase-form edits
  disable checkout immediately while text edits settle, then refresh the
  quote after a short typing debounce.
- Development / Production selector with separate credentials and demo
  session endpoints, missing-key feedback, and client rebuild on switching.
  Includes crypto, amount, wallet, fiat, country/state and onramp controls,
  plus a dark-mode switch that rebuilds the client with the selected theme.
- **Transaction complete** / **Payment processing** status panels with
  selectable transaction information. **Reset** clears the current checkout
  and requests a fresh quote; track pending payments before another payment.
- **Settings → Diagnostic logs** with a Save SDK logs switch, file previews,
  sharing, and deletion. The demo uses the SDK's debug log level.

## 1.1.2 — License correction

### Changed

- License updated from MIT to **Apache License 2.0** to match the
  React Native wrapper and the bundled `OnramperSDK` iOS framework.
- Added `NOTICE` file attributing `OnramperSDK` (Copyright 2026
  Onramper Technologies B.V.) per Apache 2.0 redistribution terms.

## 1.1.1 — Mandatory security update

Bumps the bundled [OnramperSDK](https://github.com/onramper/onramper-ios) to v1.1.1. The upstream release notes describe this as required for continued operation of existing partner integrations, following a security enhancement in the headless-service backend.

### Changed

- `ios/onramper_flutter.podspec` — pinned to OnramperSDK v1.1.1 (asset id `492870955`, sha256 `88235fa50561422ba3276f8008ff0a2229cff760f75f36f3f424ff5f26e2b2e2`).

### Plugin surface

Unchanged. The v1.1.1 SDK adds a new `EncryptedPayload` type carried on internal `CheckoutFinalizeRequest` / `CheckoutIntentResponse` structs — neither is constructed or read by the plugin bridge, so no consumer-visible API changes.

## 1.1.0 — Initial public release

First tagged release. Bundles [OnramperSDK](https://github.com/onramper/onramper-ios) v1.1.0.

### Added

- `OnramperClient` — configure → initialize → getCheckoutRequirements → observe, backed by both a `ChangeNotifier` and broadcast streams.
- `OnramperCheckoutButton` widget — embeds the native SwiftUI checkout button via a Flutter platform view. Handles OnramperID login, requirement completion, finalize, and payment presentation entirely inside the native SDK.
- `OnramperClient.getCheckoutRequirements(request, buttonStyle:)` — optional per-intent styling (`backgroundColor`, `foregroundColor`, `borderRadius`) forwarded to the native button.
- `OnramperClient.signOut()` — clears cached OnramperID tokens while preserving the partner session.
- `OnramperClient.cancelPreparedIntent(handle)` — drops a specific stored native button by handle.
- `CheckoutRequirementKind.reverification` — surfaces provider-driven email/phone re-verification requirements.
- Provider-lifecycle events: `checkoutCancelled`, `providerReady`, `paymentAuthorized`, `paymentProcessing`, `paymentCancelled`, `providerError` (with `providerReason` string).
- `CheckoutFinalizeResponse` payload on `checkoutFinalized` events for consumers that need the full finalize response (payment URL, render type, payment type, headless checkout id).
- `OnramperErrorKind.securityTrustFailed` with `host` payload — distinct from `unrecoverable` for cert-pinning failures.
- `AmountLimitRequirement.amountLimitSatisfied` — boolean signal for "no consumer action needed".
- Native SDK is fetched from a pinned release of `onramper/onramper-ios` at `pod install` time, sha256-verified. Removes the previously-vendored ~19 MB Git-LFS xcframework from the repo.

### Requirements

- Flutter 3.22+, Dart 3.4+
- iOS 16+ deployment target, App Attest capability, physical device for testing
- Export `ONRAMPER_IOS_READ_TOKEN` or `GITHUB_TOKEN` at `pod install` time to raise GitHub's anonymous rate limit from 60 to 5,000 requests/hour (optional)
