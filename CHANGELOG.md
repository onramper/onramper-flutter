# Changelog

All notable changes to this project are documented in this file.
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
and the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.

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
- `ONRAMPER_IOS_READ_TOKEN` / `GITHUB_TOKEN` / `gh auth login` at `pod install` time while `onramper/onramper-ios` remains internal
