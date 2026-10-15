# Type reference

Consolidated reference for every consumer-facing Dart type exported by `onramper_flutter`. Each type mirrors a Swift `OnramperSDK` model transported across the Pigeon bridge. Internal types (Pigeon DTOs, `*.g.dart`) are intentionally not exposed and not listed here.

> ℹ️ **iOS only.** The plugin is a no-op on Android; all methods throw if called on a non-iOS platform.

---

## Configuration

### `OnramperConfiguration`

Passed to `OnramperClient(configuration:)`.

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `apiKey` | `String` | Yes | — | Partner API key (`pk_live_…`). |
| `clientId` | `String` | Yes | — | Partner client ID (OnramperID OAuth client). |
| `environment` | `OnramperEnvironment` | Yes | — | `production` or `development` (staging). |
| `theme` | `OnramperTheme` | No | `system` | Visual theme applied to native checkout UI. |
| `logLevel` | `OnramperLogLevel` | No | `off` | Verbosity of SDK logging to the device console. |
| `logHandler` | `OnramperLogHandler?` | No | `null` | Receives structured `OnramperLogRecord`s at or above `logLevel`, in addition to Console output. Exceptions it throws are reported via `FlutterError.reportError` and don't interrupt checkout. |
| `isEventLoggingEnabled` | `bool` | No | `false` | Mirrors provider-lifecycle events to Onramper's backend telemetry. |
| `isEventConsoleLoggingEnabled` | `bool` | No | `false` | Emits provider-lifecycle events at `info` even when `logLevel` is lower, including `off`. |

### `OnramperEnvironment`

| Value | Description |
|---|---|
| `production` | Targets `api.onramper.com`. Use in App Store builds. |
| `development` | Targets `api-stg.onramper.com`. Use during integration and testing. |

### `OnramperTheme`

| Value | Description |
|---|---|
| `system` | Follows the device's light/dark mode preference. |
| `light` | Forces light mode on the native checkout surfaces. |
| `dark` | Forces dark mode on the native checkout surfaces. |

### `OnramperLogLevel`

| Value | Emits |
|---|---|
| `off` | Nothing. Use in production. |
| `error` | Failed requests only — non-2xx status and decoded error code. |
| `warning` | Degraded-path warnings in addition to errors. _(Collapsed to `error` on the Swift side — the native SDK has no distinct warning level.)_ |
| `info` | HTTP method, URL path, and status for every backend and security call. |
| `debug` | Low-level bridge and state machine detail. |
| `trace` | Maximum verbosity. _(Collapsed to `debug` on the Swift side.)_ |

### `OnramperLogRecord`

Delivered to `OnramperConfiguration.logHandler`. Structured and sanitized: URLs are reduced to hosts, HTTP paths to route templates, and values resembling emails, phone numbers, card numbers or tokens are redacted. Provider messages get best-effort redaction only, so treat exported logs as possibly containing personal data.

| Field | Type | Description |
|---|---|---|
| `timestamp` | `DateTime` | UTC time the record was emitted. |
| `level` | `OnramperLogLevel` | `off`, `error`, `info` or `debug` (the native levels). |
| `category` | `String` | Stable category, e.g. `Checkout`, `ProviderEvents`. |
| `event` | `String` | Stable event name, e.g. `checkout.finalized`. |
| `context` | `Map<String, String>` | Structured key/value context. |
| `message` | `String` | `"<event> k1=v1 k2=v2"`, keys sorted. |

`OnramperLogHandler` is `void Function(OnramperLogRecord record)`.

### `SessionCredentials`

Returned by `SessionExpirationHandler` and passed to `OnramperClient.initialize`.

| Field | Type | Description |
|---|---|---|
| `sessionId` | `String` | Session ID minted by your backend. |
| `sessionToken` | `String` | Session token minted by your backend. |

### `SessionExpirationHandler`

```dart
typedef SessionExpirationHandler = Future<SessionCredentials> Function();
```

Callback invoked when the SDK's silent refresh is exhausted and a fresh `{sessionId, sessionToken}` pair must be fetched from the partner backend. Throwing from this handler surfaces as `OnramperError(kind: userTokenRefreshFailed)` — the bridge calls `failRefreshedSession` which maps directly to that kind.

---

## Client

### `OnramperClient`

Primary entry point. Extends `ChangeNotifier` and implements the Pigeon `OnramperFlutterApi` callback interface. One instance per app session.

**Constructor:**

```dart
OnramperClient({
  required OnramperConfiguration configuration,
  SessionExpirationHandler? sessionExpirationHandler,
})
```

The constructor starts native configuration exactly once and stores the setup future. `initialize()` and other setup-dependent calls await it internally; no separate `configure()` call or delay is needed. A setup failure is retained and thrown by dependent methods, without an unhandled configuration future. Call and await `initialize()` once per client for normal startup, before requesting a checkout; awaiting setup does not initialize a session for you.

**Properties:**

| Property | Type | Description |
|---|---|---|
| `configuration` | `OnramperConfiguration` | Configuration this client was constructed with. |
| `state` | `OnramperState` | Latest known SDK state. Defaults to `idle`. |
| `stateStream` | `Stream<OnramperState>` | Broadcast stream of every state change. |
| `events` | `Stream<CheckoutEvent>` | Broadcast stream of domain events. |
| `lastError` | `OnramperError?` | Most recent native error callback, or `null`. Catch failures from public method futures separately. |
| `tosRequirements` | `List<TosRequirement>?` | Cached ToS requirements from the latest `getCheckoutRequirements` call. |
| `currentTransactionId` | `String?` | Onramper's durable transaction id. Set at finalize, cleared by a new checkout or `reset()`. Store it and quote it to support. Notifies listeners on change. |

**Static members:**

| Member | Type | Description |
|---|---|---|
| `wrapperVersion` | `String` (const) | Version of this Flutter plugin, e.g. `'1.3.1'`. |
| `sdkVersion()` | `Future<String>` | Version of the bundled native OnramperSDK, e.g. `'1.3.1'`. No client instance needed. |

**Methods:**

| Method | Returns | Description |
|---|---|---|
| `initialize({required String sessionId, required String sessionToken})` | `Future<void>` | Runs App Attest and exchanges the bootstrap token for a DPoP-bound session. Call once per client for normal startup; awaits stored setup internally. |
| `getCheckoutRequirements(CheckoutIntentRequest request, {OnramperUserPrefill? prefill, CheckoutButtonStyle? buttonStyle})` | `Future<CheckoutRequirementsResult>` | Creates a checkout intent, resolves requirements and quote, prepares the native button. A newer call (or `reset()` / `signOut()`) makes an in-flight call throw `intentInvalidated`. |
| `reset()` | `Future<void>` | Clears cached checkout state. Returns to `ready`. |
| `signOut()` | `Future<void>` | Wipes stored OnramperID OIDC tokens. Does not invalidate the partner session. |
| `cancelPreparedIntent(String buttonHandle)` | `Future<void>` | Drops a specific native button by handle. Call when navigating away from a prepared intent. |
| `dispose()` | `Future<void>` | Waits for pending setup; attempts native cleanup even after setup failure. Repeated calls share one future and its success or failure, with no duplicate cleanup. Initiates both stream closes without waiting for paused subscribers; `super.dispose()` always runs. Native cleanup platform failures throw `OnramperError`; subsequent setup-dependent methods throw `clientDisposed` and late callbacks are ignored. |

Operational SDK and platform-bridge failures from public calls throw `OnramperError`, including `OnramperClient.sdkVersion()` and `dispose()`. Programming errors propagate unchanged. SDK errors delivered as `OnramperErrorDto` retain their SDK kind and structured fields. For other bridge failures, the mapping is:

| Native exception / code | `OnramperErrorKind` |
|---|---|
| `PlatformException`: `not_configured` | `notConfigured` (Dart-only) |
| `PlatformException`: `not_initialized` | `notInitialized` (existing kind) |
| `PlatformException`: `missing_response` | `missingResponse` (Dart-only) |
| Any other `PlatformException`, or `MissingPluginException` | `platformFailure` (Dart-only) |

The original error stack is preserved. Nullable diagnostics `cause` (`Object?`), `stackTrace` (`StackTrace?`) and `platformCode` (`String?`) retain the original exception, stack and platform code where available. Native `PlatformException.details` remains accessible through `cause`; `platformCode` is distinct from the numeric backend `code`; for `MissingPluginException`, it is synthesized as `missing_plugin` rather than copied from an original exception code. These diagnostics are not safe end-user copy: show `userMessage` and `supportCode` instead. Catch `OnramperError` rather than `PlatformException` for operational failures, and update exhaustive switches for the three new Dart-only enum cases. Existing public method signatures are unchanged.

### `OnramperUserPrefill`

Optional `prefill:` for `getCheckoutRequirements`. Pre-populates OnramperID sign-in and additional-info screens. Best-effort; blank fields are ignored; enabled per integration.

| Field | Type | Description |
|---|---|---|
| `email` | `String?` | Pass only when you're confident it's the sign-in address. A mismatch drops the whole prefill. |
| `firstName` | `String?` | |
| `lastName` | `String?` | |
| `phoneNumber` | `String?` | E.164, e.g. `+3712345678`. The user still verifies it. |

---

## State

### `OnramperState`

Snapshot of the SDK state. At most one payload field is non-null per instance, matching the active `kind`.

| Field | Type | Description |
|---|---|---|
| `kind` | `OnramperStateKind` | Discriminator. |
| `requireLoginRequirements` | `List<CheckoutRequirement>?` | Populated when `kind == requireLogin`. Requirements the OnramperID sheet will resolve. |
| `renderContext` | `RenderContext?` | Populated when `kind == rendering`. Payment surface URL and render type. |
| `failedError` | `OnramperError?` | Populated when `kind == failed`. |

### `OnramperStateKind`

| Value | When |
|---|---|
| `idle` | Before `initialize()` resolves. |
| `initializing` | `initialize()` is in flight. |
| `ready` | Bootstrap complete; ready for `getCheckoutRequirements()`. |
| `checkoutPreparing` | `getCheckoutRequirements()` is in flight. |
| `requireLogin` | Provider requires user identity or phone re-verification. OnramperID sheet will present on Buy tap. |
| `authenticating` | OnramperID login sheet is on screen. |
| `readyToCheckout` | All requirements satisfied; Buy goes straight to finalize. |
| `finalizing` | backend finalize call is in flight. |
| `rendering` | Payment surface is on screen. |
| `paymentPending` | Payment accepted, settlement pending. Neither success nor failure; track with `currentTransactionId`. |
| `completed` | Terminal success. |
| `failed` | Terminal failure. |

### `RenderContext`

Render payload attached to `OnramperStateKind.rendering` and the `renderingStarted` / `checkoutFinalized` events.

| Field | Type | Description |
|---|---|---|
| `url` | `String` | Payment surface URL. |
| `renderType` | `RenderType` | How the URL is displayed. |
| `paymentType` | `CheckoutPaymentType?` | Null on the initial `renderingStarted` event; non-null once the state reaches `rendering` or `checkoutFinalized`. |

### `RenderType`

| Value | Description |
|---|---|
| `webview` | URL is presented in a native `WKWebView`. |
| `deeplink` | URL is opened via a deep-link (redirects to a payment app or external browser). |

### `CheckoutPaymentType`

| Value | Description |
|---|---|
| `applePay` | Apple Pay native sheet. |
| `revolutPay` | Revolut Pay webview. |

---

## Events

### `CheckoutEvent`

Domain event observed from the native SDK. Inspect `kind` to decide which payload field is populated — other fields are null.

| Field | Type | Description |
|---|---|---|
| `kind` | `CheckoutEventKind` | Discriminator. |
| `state` | `OnramperState?` | Populated on `stateChanged`. |
| `checkoutId` | `String?` | Populated on `completed`. |
| `loginRequirements` | `List<CheckoutRequirement>?` | Populated on `loginRequired`. |
| `requirementType` | `CheckoutRequirementKind?` | Populated on `requirementSatisfied`. |
| `renderContext` | `RenderContext?` | Populated on `renderingStarted` and `checkoutFinalized`. |
| `finalizeResponse` | `CheckoutFinalizeResponse?` | Populated on `checkoutFinalized`. Full finalize response including provider metadata. |
| `providerReason` | `String?` | Populated on `providerError`. Short human-readable reason from the provider. |
| `error` | `OnramperError?` | Populated on `failed`. |

### `CheckoutEventKind`

| Value | Fires when | Key payload |
|---|---|---|
| `stateChanged` | Any state transition. | `state` |
| `checkoutStarted` | Intent created. | — |
| `loginRequired` | Provider requires user identity or re-verification. | `loginRequirements` |
| `readyToCheckout` | All requirements satisfied. | — |
| `requirementSatisfied` | One requirement type passed (tos, amountLimit, userInfo, reverification). | `requirementType` |
| `checkoutFinalized` | backend finalized; payment surface about to render. | `renderContext`, `finalizeResponse` |
| `renderingStarted` | Payment surface on screen. | `renderContext` |
| `completed` | Terminal success. | `checkoutId` |
| `failed` | Terminal failure. | `error` |
| `checkoutCancelled` | User dismissed the payment sheet before completing. | — |
| `providerReady` | Provider checkout page finished loading. | — |
| `paymentAuthorized` | User authorized payment (e.g. Apple Pay). Not terminal. | — |
| `paymentProcessing` | Provider accepted payment and is settling. | — |
| `paymentCancelled` | Provider reports user cancelled (e.g. dismissed Apple Pay sheet). | — |
| `providerError` | Provider reported non-recoverable failure. | `providerReason` |
| `paymentPending` | Payment accepted but not yet settled. | — |
| `challengeStarted` | 3-D Secure verification started. | — |
| `challengeCompleted` | 3-D Secure verification finished. | — |
| `customerOnboardingRequired` | MoonPay guest checkout unavailable; the SDK opens MoonPay onboarding. | — |

The events from `checkoutCancelled` onwards are forwarded from the payment surface; not every provider emits every kind. They report progress, not payment completion.

### `CheckoutFinalizeResponse`

Carried by the `checkoutFinalized` event. **Upgrade note:** direct construction now requires the named `onramperTransactionId` argument as well as `headlessCheckoutId` and `headlessCheckoutData`; update manually constructed responses and fixtures.

| Field | Type | Description |
|---|---|---|
| `headlessCheckoutId` | `String` | Finalized checkout ID. |
| `onramperTransactionId` | `String` | Onramper's durable transaction id; same as `OnramperClient.currentTransactionId`. |
| `headlessCheckoutData` | `HeadlessCheckoutData` | Payment surface info. |

### `HeadlessCheckoutData`

| Field | Type | Description |
|---|---|---|
| `url` | `String` | Payment surface URL. |
| `renderType` | `RenderType` | `webview` or `deeplink`. |
| `checkoutPaymentType` | `CheckoutPaymentType` | `applePay` or `revolutPay`. |

---

## Requirements

### `CheckoutIntentRequest`

Passed to `OnramperClient.getCheckoutRequirements`.

| Field | Type | Required | Description |
|---|---|---|---|
| `transactionData` | `OnramperTransactionData` | Yes | Transaction parameters. |
| `onlyOnramps` | `List<String>?` | No | Allowlist of provider IDs. Omit for all eligible providers. |

### `OnramperTransactionData`

| Field | Type | Required | Description |
|---|---|---|---|
| `source` | `String` | Yes | Source (fiat) asset, e.g. `'usd'`. |
| `destination` | `String` | Yes | Destination (crypto) asset, e.g. `'btc'`. Required since v1.1.0. |
| `amount` | `double` | Yes | Amount in the `source` currency. |
| `type` | `TransactionType` | Yes | `buy` or `sell`. |
| `paymentMethod` | `String` | Yes | Payment method ID, e.g. `'applepay'`. |
| `wallet` | `WalletInfo` | Yes | Destination wallet. |
| `country` | `String?` | No | ISO 3166-1 alpha-2 (e.g. `'us'`). Derived from request IP when omitted. |
| `subdivision` | `String?` | No | ISO 3166-2 (e.g. `'us-ca'`). Recommended for US. |

### `TransactionType`

| Value | Description |
|---|---|
| `buy` | User spends fiat and receives crypto. |
| `sell` | User spends crypto and receives fiat. |

### `WalletInfo`

| Field | Type | Required | Description |
|---|---|---|---|
| `network` | `String` | Yes | Wallet network, e.g. `'bitcoin'`, `'solana'`. |
| `address` | `String` | Yes | Destination wallet address. |
| `memo` | `String?` | No | Destination tag / memo when the network requires one. |

### `CheckoutRequirementsResult`

Returned by `getCheckoutRequirements`.

| Field | Type | Description |
|---|---|---|
| `headlessCheckoutId` | `String` | Opaque checkout ID for telemetry. |
| `requirements` | `List<CheckoutRequirement>` | Tagged-union list of requirements. |
| `quote` | `QuoteResponse` | Priced quote. All fields non-null. |
| `buttonHandle` | `String` | Opaque ID addressing the native button. Passed automatically by `OnramperCheckoutButton`. |
| `tos` | `List<TosRequirement>` | Convenience getter — only the ToS requirements. |

### `CheckoutRequirement`

Tagged union. Inspect `kind` then read the matching payload field.

| Field | Type | Description |
|---|---|---|
| `kind` | `CheckoutRequirementKind` | Discriminator. |
| `tos` | `TosRequirement?` | Non-null when `kind == tos`. |
| `amountLimit` | `AmountLimitRequirement?` | Non-null when `kind == amountLimit`. |
| `userInfo` | `UserInfoRequirement?` | Non-null when `kind == userInfo`. |
| `reverification` | `ReverificationRequirement?` | Non-null when `kind == reverification`. |

### `CheckoutRequirementKind`

| Value | Description |
|---|---|
| `tos` | Terms of Service / Privacy Policy / User Agreement acceptance. |
| `amountLimit` | Min/max amount bounds for the provider. |
| `userInfo` | KYC identity fields required by the provider. |
| `reverification` | Previously-collected identity field must be re-confirmed. |

### `TosRequirement`

| Field | Type | Description |
|---|---|---|
| `providerId` | `String` | Provider this ToS belongs to. |
| `items` | `List<TosItem>` | Documents the user must acknowledge. |

### `TosItem`

| Field | Type | Description |
|---|---|---|
| `type` | `TosItemType` | Document kind. |
| `required` | `bool` | Whether acknowledgement is required. |
| `satisfied` | `bool` | Whether already acknowledged. |
| `url` | `String?` | Link to the document, when provided. |
| `content` | `String?` | Inline content, when provided. |

### `TosItemType`

| Value | `displayName` | Description |
|---|---|---|
| `tos` | `'Terms of Service'` | Provider terms of service. |
| `privacyPolicy` | `'Privacy Policy'` | Provider privacy policy. |
| `userAgreement` | `'User Agreement'` | Provider user agreement. |

`TosItemType` has an extension `TosItemTypeDisplayName` that exposes `displayName` — the same wording used by the iOS SDK, suitable for direct rendering.

### `AmountLimitRequirement`

| Field | Type | Description |
|---|---|---|
| `providerId` | `String` | Provider these limits apply to. |
| `amountLimitSatisfied` | `bool` | `true` if the requested amount already falls within bounds. |
| `minAmountLimit` | `double?` | Minimum accepted amount for this provider. |
| `maxAmountLimit` | `double?` | Maximum accepted amount for this provider. |

### `UserInfoRequirement`

| Field | Type | Description |
|---|---|---|
| `providerId` | `String` | Provider requesting the identity fields. |
| `fields` | `List<UserInfoField>` | Individual KYC fields. |

### `UserInfoField`

| Field | Type | Description |
|---|---|---|
| `type` | `UserInfoFieldType` | Which profile field. |
| `required` | `bool` | Whether collection is required. |
| `satisfied` | `bool` | Whether already collected. |

### `UserInfoFieldType`

| Value | Description |
|---|---|
| `firstName` | Given name. |
| `lastName` | Family name. |
| `email` | Email address. |
| `emailVerification` | Email address verification. |
| `phoneNumber` | Phone number. |
| `phoneVerification` | Phone number verification. |
| `ssnLastFour` | Last four digits of SSN (US only). |
| `address` | Residential address. |

### `ReverificationRequirement`

| Field | Type | Description |
|---|---|---|
| `providerId` | `String` | Provider requesting re-verification. |
| `field` | `ReverificationField` | Which field to re-verify. |
| `requiredRecencyDays` | `int` | How recent the last verification must be (in days). |
| `lastVerifiedAt` | `String?` | ISO-8601 timestamp of the last verification, or `null` if never verified. |

### `ReverificationField`

| Value | Description |
|---|---|
| `email` | Email address re-verification. |
| `phone` | Phone number re-verification (driven by the OnramperID login sheet). |

---

## Quote

### `QuoteResponse`

Returned inside `CheckoutRequirementsResult.quote`. All core fields are non-null — a request that cannot be priced rejects with `OnramperError(kind: quoteUnavailable)` rather than returning a partial quote.

| Field | Type | Description |
|---|---|---|
| `quoteId` | `String` | Unique ID for this quote. |
| `ramp` | `String` | Provider (onramp) ID that priced the trade, e.g. `'coinbase'`. |
| `rate` | `double` | Exchange rate applied to the trade. |
| `networkFee` | `double` | Network/processing fee for the trade. |
| `transactionFee` | `double` | Provider transaction fee. |
| `payout` | `double` | Amount of the destination asset the user receives. |
| `paymentMethod` | `String` | Payment method the quote was priced for. |
| `recommendations` | `List<String>?` | Optional provider recommendation metadata. |
| `providerContext` | `Map<String, ProviderJSONValue>?` | Provider-specific data (executable flags, limits, disclosures). Most integrations can ignore it. May contain tokens; don't log it. |
| `paymentDisclosures` | `List<PaymentDisclosure>` (getter) | Disclosures listed under `providerContext['paymentDisclosures']`. The native button already shows them. |

### `ProviderJSONValue`

Sealed JSON value: `ProviderJSONString(String value)`, `ProviderJSONNumber(double value)`, `ProviderJSONBool(bool value)`, `ProviderJSONNull()`, `ProviderJSONArray(List<ProviderJSONValue> value)`, `ProviderJSONObject(Map<String, ProviderJSONValue> value)`. `stringValue` returns the string payload or `null`.

### `PaymentDisclosure`

| Field | Type |
|---|---|
| `code` | `String` |
| `version` | `String` |
| `contentMarkdown` | `String` |
| `contentHtml` | `String` |

`PaymentDisclosure.tryParse(ProviderJSONValue)` returns `null` unless all four fields are strings.

---

## Errors

### `OnramperError`

Implements `Exception`. Thrown across `async` boundaries; catch with `on OnramperError`.

| Field | Type | Description |
|---|---|---|
| `kind` | `OnramperErrorKind` | Discriminator — always set. |
| `message` | `String` | Developer-facing description (English, non-localized). |
| `userMessage` | `String` | Plain end-user copy, safe to show users. |
| `supportCode` | `String` | Short stable code, safe to show next to `userMessage`; matches SDK logs. Plugin-originated errors use `FLUTTER-…` codes. |
| `recoverable` | `bool` | SDK's assessment of whether a retry is worthwhile. |
| `code` | `int?` | Numeric backend error code when one was present. Do not switch on this; use `kind`. |
| `minAmount` | `double?` | Populated for `amountOutOfRange`. |
| `maxAmount` | `double?` | Populated for `amountOutOfRange`. |
| `retryAfterSeconds` | `double?` | Populated for `temporaryFailure` when the server specified a retry delay. |
| `field` | `String?` | Populated for `invalidRequest` — names the offending request field. |
| `debugInfo` | `String?` | Opaque diagnostic string. Log to your crash reporter; do not switch on its content. |
| `fromState` | `String?` | Populated for `invalidStateTransition` — the state the machine was in. |
| `toState` | `String?` | Populated for `invalidStateTransition` — the state the machine was asked to enter. |
| `expectedState` | `String?` | Populated for `invalidState`. |
| `actualState` | `String?` | Populated for `invalidState`. |
| `host` | `String?` | Populated for `securityTrustFailed` — the host whose certificate pinning check failed. |
| `cause` | `Object?` | Original exception, including native details when available. Diagnostic only; not safe end-user copy. |
| `stackTrace` | `StackTrace?` | Original failure stack when available; preserved when rethrowing. |
| `platformCode` | `String?` | Original platform exception code when available; synthesized as `missing_plugin` for `MissingPluginException`. Separate from numeric backend `code`. |

### `OnramperErrorKind`

The Dart-only additions `notConfigured`, `missingResponse` and `platformFailure` use the bridge mapping above. They do not add native DTO enum values. Update exhaustive switches when upgrading. The table below lists SDK and plugin kinds.

| Value | `recoverable` default | Suggested action |
|---|---|---|
| `notInitialized` | false | Await `initialize()` before calling other methods. |
| `initializationFailed` | true | Show retry; re-call `initialize()` with a fresh credential pair. |
| `attestationFailed` | false | Show a "device unsupported" screen; do not retry. |
| `invalidStateTransition` | false | Log to crash reporting — integration bug. |
| `invalidState` | false | Check `client.state.kind` before calling; gate UI accordingly. |
| `networkError` | true | Show retry with a "check your connection" message. |
| `decodingError` | false | Log `debugInfo`; surface as a generic failure. |
| `timeout` | true | Offer retry; the network may be slow. |
| `requirementNotSatisfied` | true | Re-call `getCheckoutRequirements`; surface outstanding requirement. |
| `amountOutOfRange` | true | Prompt user to adjust amount; display `minAmount`/`maxAmount`. |
| `oidcFlowCancelled` | true | Tapping Buy again retries; usually no UI action needed. |
| `oidcTokenExchangeFailed` | true | Offer retry; verify `clientId` if it persists. |
| `oidcFlowFailed` | true | Offer retry; log `debugInfo`. |
| `userTokenInvalid` | true | SDK re-presents login automatically. |
| `userTokenRefreshFailed` | true | Button re-presents login sheet; usually no action needed. |
| `webviewLoadFailed` | true | Offer retry; check connectivity. |
| `deepLinkFailed` | true | Offer retry. |
| `invalidRequest` | true | Fix the offending parameter (`error.field`) and retry. |
| `quoteUnavailable` | true | Suggest different amount, currency, or payment method. |
| `checkoutForbidden` | false | Show a "not available for this configuration" message. |
| `temporaryFailure` | true | Show retry; respect `retryAfterSeconds` if present. |
| `unrecoverable` | false | Call `reset()`, then re-`initialize()`; show retry. |
| `configurationError` | false | Not user-actionable; log and surface as a developer/support issue. |
| `deviceBlocked` | false | Show a "unable to continue on this device" message. |
| `securityStorageFailed` | false | Rare; log `debugInfo` and surface a generic error. |
| `securityTrustFailed` | false | Rare; log `error.host` and surface a generic error. |
| `paymentFailed` | true | Provider confirmed failure (e.g. card declined). Show `userMessage`; offer another payment method. |
| `providerFailed` | false | Outcome unknown — the payment may have gone through. Check status before offering another payment. |
| `applePayNotConfigured` | false | No Apple Pay card in Wallet. Ask the user to add one or pick another method. |
| `intentInvalidated` | true | _Plugin-originated._ Superseded by a newer `getCheckoutRequirements`, `reset()` or `signOut()`. Ignore. |
| `clientDisposed` | false | _Plugin-originated._ Method called after `dispose()`. Create a new client. |
| `notConfigured` | false | _Dart-only._ Native plugin has no configured client; inspect setup failure and lifecycle diagnostics. |
| `missingResponse` | false | _Dart-only._ Required native response missing. Do not automatically retry; inspect diagnostics and report the bridge failure. |
| `platformFailure` | false | _Dart-only._ Do not automatically retry; check platform support, plugin registration and native build. |

---

## Widgets

### `OnramperCheckoutButton`

Consumer-facing wrapper that renders any unsatisfied ToS items above the native `OnramperNativeCheckoutButton`. The native button handles the full checkout flow (OIDC login, finalize, payment surface) internally.

```dart
const OnramperCheckoutButton({
  Key? key,
  required CheckoutRequirementsResult requirements,
  CheckoutButtonStyle style = const CheckoutButtonStyle(),
  Future<bool> Function(Uri)? onLinkTap,
})
```

| Parameter | Type | Description |
|---|---|---|
| `requirements` | `CheckoutRequirementsResult` | Result from `getCheckoutRequirements`. |
| `style` | `CheckoutButtonStyle` | ToS text styling (see below). Button colors are set via `getCheckoutRequirements(buttonStyle:)`. |
| `onLinkTap` | `Future<bool> Function(Uri)?` | Override for ToS link taps. When null, links open in an external browser via `url_launcher`. |

### `CheckoutButtonStyle`

Styling for `OnramperCheckoutButton`. Fields split between native button appearance (forwarded via `getCheckoutRequirements`) and Dart-drawn ToS text.

| Field | Type | Default | Used by |
|---|---|---|---|
| `backgroundColor` | `Color?` | SDK default (system blue) | Native button — pass to `getCheckoutRequirements(buttonStyle:)`. |
| `foregroundColor` | `Color?` | SDK default (white) | Native button — pass to `getCheckoutRequirements(buttonStyle:)`. |
| `borderRadius` | `double` | `12` | Native button — pass to `getCheckoutRequirements(buttonStyle:)`. |
| `tosStyle` | `TextStyle?` | `TextStyle(fontSize: 12)` | Dart ToS lines — pass to `OnramperCheckoutButton(style:)`. |
| `tosLinkStyle` | `TextStyle?` | Inherits from `tosStyle` with underline + blue | Dart ToS link lines — pass to `OnramperCheckoutButton(style:)`. |

Colors are serialized as `#RRGGBBAA` hex strings across the bridge. The button label ("Buy") is fixed by the SDK and not overridable from Dart.

### `OnramperNativeCheckoutButton`

Low-level wrapper. Embeds the native SwiftUI button directly via `UiKitView`. Use `OnramperCheckoutButton` unless you need to manage ToS rendering yourself.

```dart
const OnramperNativeCheckoutButton({
  Key? key,
  required String buttonHandle,
  @Deprecated('The button sizes itself.') double? height,
})
```

| Parameter | Type | Description |
|---|---|---|
| `buttonHandle` | `String` | Handle from `CheckoutRequirementsResult.buttonHandle`. |
| `height` | `double?` | **Deprecated.** The button sizes itself to its native content; if set, acts as a minimum height. |

Starts at 56 logical pixels until the native view reports its content height. Renders nothing (height 0) for an expired or superseded handle. Renders an empty `SizedBox` on non-iOS platforms.
