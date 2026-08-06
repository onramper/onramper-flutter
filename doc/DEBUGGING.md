# Debugging your integration

Known limitations and gotchas when integrating `onramper_flutter`. For the full integration walkthrough — install, usage, error handling — see Getting started.

---

## App Attest in the simulator

Always returns `OnramperError(kind: attestationFailed)`. Apple's `DCAppAttestService` only works on physical iOS devices. There is no workaround for simulator testing of the full attestation path — use a real device for any end-to-end test.

To confirm the error is simulator-specific, look for `attestationUnavailable` in the native SDK logs (set `logLevel: OnramperLogLevel.debug` on the client). The Dart layer maps this to `attestationFailed`.

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

This error indicates a version skew between the Flutter plugin and the Onramper BFF. SDK v1.1.1 added a required `encryption: EncryptedPayload` field to `CheckoutIntentResponse`. If the BFF has not yet been deployed with that field, the SDK's `Codable` decoder throws `keyNotFound` and the plugin surfaces it as `decodingError`.

Check that:

1. You are on `onramper_flutter` v1.1.1 or later in `pubspec.yaml`.
2. The BFF environment you are targeting (staging or production) has been deployed with the `encryption` field on `CheckoutIntentResponse`. Staging is typically deployed ahead of production — if staging works but production does not, the production BFF deployment is pending.
3. You are not mixing staging credentials with the production BFF or vice versa — set `OnramperEnvironment.development` for staging and `OnramperEnvironment.production` for production.

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

## Reading the event log in the demo app

The `example/` app ships an event log widget that surfaces every `CheckoutEvent` and `OnramperState` transition in real time. To use it for debugging your own integration:

1. Clone the repository and open `example/`.
2. Run with verbose logging enabled:

```bash
cd example
flutter pub get
cd ios && pod install && cd ..
flutter run --debug
```

3. In `main.dart`, set `logLevel: OnramperLogLevel.debug` on the `OnramperConfiguration`. This emits HTTP method, URL path, and status for every BFF and security call to the device console.

4. Observe the event stream. Every state transition, event, and error emitted by the native SDK is printed to the on-screen log, alongside the raw `OnramperError` fields (`kind`, `code`, `message`, `debugInfo`) when an error is present.

For native-side logs, open the Xcode console (⌘ + Shift + C) while the app is running. The native SDK logs with the subsystem `com.onramper.sdk`.

---

## Quick reference

| Symptom | Likely cause | Fix |
|---|---|---|
| `attestationFailed` on first call | Simulator, or missing/wrong entitlement, or unregistered bundle ID | Run on real device; check `Runner.entitlements`; confirm bundle ID with Onramper. |
| `pod install` 403 | GitHub anonymous rate limit | Export `ONRAMPER_IOS_READ_TOKEN` or `GITHUB_TOKEN`. |
| `pod install` 404 | Release asset removed or version too old | Bump `onramper_flutter` to latest. |
| `pod install` deployment target error | iOS target < 16.0 in Podfile or Xcode | Set `platform :ios, '16.0'` in Podfile; update Runner target in Xcode. |
| App crashes on launch with attestation error | Missing entitlement | Add `com.apple.developer.devicecheck.appattest-environment` to `Runner.entitlements`. |
| `decodingError: encryption key not found` | Plugin/BFF version skew | Upgrade to `onramper_flutter` v1.1.1+; confirm BFF environment matches `OnramperEnvironment`. |
| `networkError` (code 403) on `getCheckoutRequirements` | Session token missing `checkout:write` scope | Add `checkout:write` to the scope list in your backend session-mint call. |
| `unrecoverable` mid-flow | Recovery chain exhausted | Call `reset()`, fetch fresh credentials, call `initialize()`. |
| Build fails — Swift module not found | Xcode < 26 | Update to Xcode 26+. |
| Payment sheet obscured by Flutter debug overlay | Running in debug mode | Use `flutter run --release` or `--profile` for checkout testing. |
