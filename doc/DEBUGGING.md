# Debugging your integration

Known limitations and gotchas when integrating `onramper_flutter`. For the full integration walkthrough — install, usage, error handling — see Getting started.

---

## App Attest in the simulator

Always returns `OnramperError(kind: attestationFailed)`. Apple's `DCAppAttestService` only works on physical iOS devices. There is no workaround for simulator testing of the full attestation path — use a real device for any end-to-end test.

To confirm the error is simulator-specific, look for `attestationUnavailable` in the native SDK logs — set `logLevel: OnramperLogLevel.debug` in your `OnramperConfiguration` to enable them. The Dart layer maps this to `attestationFailed`.

---

## Xcode 26+ required for Swift 6.2 xcframework

The bundled `OnramperSDK.xcframework` is compiled with Swift 6.2, which requires **Xcode 26 or later**. Xcode 16 and earlier report the same effective-5.10 ABI version but cannot load the module — the build fails with a Swift compiler version mismatch error. This affects both local builds and CI runners: `macos-15` runners (Xcode 16.4) fail; `macos-26` runners (Xcode 26) succeed.

If you see a linker error like:

```
ld: symbol(s) not found for architecture arm64
```

or a Swift module compatibility error mentioning a compiler version mismatch, verify your Xcode version:

```bash
xcodebuild -version
```

Update via the Mac App Store or the [Apple Developer downloads page](https://developer.apple.com/download/all/).

---

## Bundle ID not registered → `attestationFailed`

`initialize()` fails with `OnramperError(kind: attestationFailed)` when:

1. The app's bundle ID has not been registered with Onramper, **or**
2. The app is running on an iOS Simulator (see above), **or**
3. The `com.apple.developer.devicecheck.appattest-environment` entitlement is missing from `Runner.entitlements`.

Check `Runner.entitlements` in Xcode (Project Navigator → `ios/Runner/Runner.entitlements`). It must contain:

```xml
<key>com.apple.developer.devicecheck.appattest-environment</key>
<string>development</string>
```

Use `development` for debug and ad hoc builds; use `production` for App Store and TestFlight builds. A mismatch (e.g., `production` in a debug build signed with a development provisioning profile) causes attestation to fail.

If the entitlement is present and the build type is correct, contact Onramper support to confirm your bundle ID is registered.

---

## `pod install` failures

### Rate limit — 403

```
curl: (22) The requested URL returned error: 403
```

The CocoaPods podspec downloads the xcframework from the GitHub releases API. GitHub's anonymous API rate limit is 60 requests/hour. Export a token and re-run:

```bash
export ONRAMPER_IOS_READ_TOKEN=ghp_...   # preferred — scoped read-only token
# OR
export GITHUB_TOKEN=ghp_...
cd ios && pod install
```

### Missing release asset — 404

```
curl: (22) The requested URL returned error: 404
```

The release asset referenced by the podspec's checksum does not exist in the upstream [`onramper/onramper-ios`](https://github.com/onramper/onramper-ios) repository. This can happen if:

- The pin in the podspec references an asset that has since been removed, **or**
- You are using an older version of `onramper_flutter` whose bundled iOS SDK release is no longer published.

Bump `onramper_flutter` to the latest version in `pubspec.yaml`, run `flutter pub get`, then re-run `pod install`. If the problem persists on the latest version, open an issue on the Flutter plugin repository.

### Deployment target error

```
The iOS deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to X.Y,
but the range of supported deployment target versions is 16.0 to ...
```

Both `ios/Podfile` and the Runner Xcode project must have their iOS deployment target set to `16.0` or higher. Set `platform :ios, '16.0'` as the first line of `Podfile`, and update Runner → Build Settings → iOS Deployment Target in Xcode.

---

## `decodingError`: encryption key not found

```
OnramperError(kind: decodingError): encryption key not found
```

This error indicates a version skew between the Flutter plugin and Onramper's backend. SDK v1.1.1 added a required `encryption: EncryptedPayload` field to `CheckoutIntentResponse`. If Onramper's backend has not yet been deployed with that field, the SDK's `Codable` decoder throws `keyNotFound` and the plugin surfaces it as `decodingError`.

Check that:

1. You are on `onramper_flutter` v1.1.1 or later in `pubspec.yaml`.
2. The backend environment you are targeting (staging or production) has been deployed with the `encryption` field on `CheckoutIntentResponse`. Staging is typically deployed ahead of production — if staging works but production does not, the production backend deployment is pending.
3. You are not mixing staging credentials with the production backend or vice versa — set `OnramperEnvironment.development` for staging and `OnramperEnvironment.production` for production.

If the error persists after updating both the plugin and confirming the environment, contact Onramper support with the `debugInfo` string from the error.

---

## Session token missing scope → 403 on `getCheckoutRequirements`

`getCheckoutRequirements` fails with `OnramperError(kind: networkError)` with `code: 403` when the backend session token was minted without the required scopes.

The session must include both scopes:

```json
{ "scope": ["quotes:read", "checkout:write"] }
```

Verify your backend's session-mint call includes both values. A token minted with only `quotes:read` succeeds for quotes but fails when the plugin attempts to create a checkout intent.

See Backend session endpoint for the full request body and signing details.

---

## `unrecoverable` mid-flow

```
OnramperError(kind: unrecoverable)
```

Emitted when the SDK's internal recovery chain — session token refresh, DPoP re-binding, re-bootstrap via `sessionExpirationHandler` — was exhausted without successfully recovering.

Recovery steps:

1. Call `client.reset()` to clear cached state on both sides of the bridge.
2. Fetch fresh credentials from your backend.
3. Call `client.initialize(sessionId:, sessionToken:)` with the new credentials.
4. Resume the checkout flow from `getCheckoutRequirements`.

This error is rare in steady state. If it occurs frequently, check that your `sessionExpirationHandler` is correctly wired and returns valid credentials — a handler that always throws will cause every refresh attempt to surface as `unrecoverable`.

---

## Capturing SDK logs

Pass a `logHandler` to receive structured, sanitized log records in Dart (Console output is kept):

```dart
final records = <OnramperLogRecord>[];

OnramperConfiguration(
  apiKey: 'pk_test_...',
  clientId: '...',
  environment: OnramperEnvironment.development,
  logLevel: OnramperLogLevel.debug,
  logHandler: records.add,
)
```

Each record carries `timestamp`, `level`, `category`, `event`, `context` and `message`. URLs are reduced to hosts, HTTP paths to route templates, and values resembling emails, phone numbers, card numbers or tokens are redacted. **Provider messages get only best-effort redaction, so treat exported logs as possibly containing personal data** and choose retention and sharing accordingly.

Two flags, both `false` by default:

- `isEventLoggingEnabled` mirrors provider-lifecycle events to Onramper's backend telemetry.
- `isEventConsoleLoggingEnabled` logs provider-lifecycle events at `info` even when `logLevel` is lower, including `off`.

For native-side logs, open the Xcode console (⌘ + Shift + C) while the app is running. The native SDK logs with the subsystem `com.onramper.sdk`.

---

## Support codes

Every `OnramperError` has a `supportCode`: a short, stable code that's safe to show users next to `userMessage` (e.g. "Error code: …") and matches what the SDK logs. Ask users to quote it, together with `client.currentTransactionId` when there is one, when they contact support. Codes starting with `FLUTTER-` come from the Flutter plugin itself (`FLUTTER-INTENT-INVALIDATED`, `FLUTTER-CLIENT-DISPOSED`).

---

## Versions

```dart
final plugin = OnramperClient.wrapperVersion;   // e.g. '1.3.1'
final sdk = await OnramperClient.sdkVersion();  // bundled native SDK, e.g. '1.3.1'
```

Include both in bug reports. After upgrading the package, run `pod install` and rebuild: a Dart-only update doesn't replace the bundled iOS SDK.

---

## Using the example app for debugging

The `example/` app shows plugin and SDK versions and the current transaction id, and includes an SDK log viewer:

1. Clone the repository and open `example/`.
2. Run it:

```bash
cd example
flutter pub get
cd ios && pod install && cd ..
flutter run --dart-define-from-file=.env --debug
```

3. Pick a log level in the app (changing it rebuilds the client, so request a new quote afterwards).
4. Tap the log icon in the app bar to browse records, expand their context, **Clear** them, or **Copy all** as JSON lines.

---

## Quick reference

| Symptom | Likely cause | Fix |
|---|---|---|
| `attestationFailed` on first call | Simulator, or missing/wrong entitlement, or unregistered bundle ID | Run on real device; check `Runner.entitlements`; confirm bundle ID with Onramper. |
| `pod install` 403 | GitHub anonymous rate limit | Export `ONRAMPER_IOS_READ_TOKEN` or `GITHUB_TOKEN`. |
| `pod install` 404 | Release asset removed or version too old | Bump `onramper_flutter` to latest. |
| `pod install` deployment target error | iOS target < 16.0 in Podfile or Xcode | Set `platform :ios, '16.0'` in Podfile; update Runner target in Xcode. |
| App crashes on launch with attestation error | Missing entitlement | Add `com.apple.developer.devicecheck.appattest-environment` to `Runner.entitlements`. |
| `decodingError: encryption key not found` | Plugin/backend version skew | Upgrade to `onramper_flutter` v1.1.1+; confirm backend environment matches `OnramperEnvironment`. |
| `networkError` (code 403) on `getCheckoutRequirements` | Session token missing `checkout:write` scope | Add `checkout:write` to the scope list in your backend session-mint call. |
| `unrecoverable` mid-flow | Recovery chain exhausted | Call `reset()`, fetch fresh credentials, call `initialize()`. |
| `intentInvalidated` thrown from `getCheckoutRequirements` | A newer call, `reset()` or `signOut()` superseded it | Expected when re-quoting; ignore it and use the latest result. |
| `clientDisposed` | Method called after `dispose()` | Create a new `OnramperClient`. |
| Previously signed-in users see the OnramperID login again after upgrading | Credentials are now stored per environment (SDK 1.3.0) | Expected once per user; no action needed. |
| Checkout button shows nothing | Prepared button expired (5 min) or was superseded | Request a new quote. |
| Build fails — Swift module not found | Xcode < 26 | Update to Xcode 26+. |
| Payment sheet obscured by Flutter debug overlay | Running in debug mode | Use `flutter run --release` or `--profile` for checkout testing. |
