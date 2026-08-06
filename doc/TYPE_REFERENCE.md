# Type reference

Consolidated reference for every consumer-facing Dart type exported by `onramper_sdk`. Each type mirrors a Swift `OnramperSDK` model transported across the Pigeon bridge. Internal types (Pigeon DTOs, `*.g.dart`) are intentionally not exposed and not listed here.

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
| `info` | HTTP method, URL path, and status for every BFF and security call. |
| `debug` | Low-level bridge and state machine detail. |
| `trace` | Maximum verbosity. _(Collapsed to `debug` on the Swift side.)_ |

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

**Properties:**

| Property | Type | Description |
|---|---|---|
| `configuration` | `OnramperConfiguration` | Configuration this client was constructed with. |
| `state` | `OnramperState` | Latest known SDK state. Defaults to `idle`. |
| `stateStream` | `Stream<OnramperState>` | Broadcast stream of every state change. |
| `events` | `Stream<CheckoutEvent>` | Broadcast stream of domain events. |
| `lastError` | `OnramperError?` | Most recent error, or `null`. |
| `tosRequirements` | `List<TosRequirement>?` | Cached ToS requirements from the latest `getCheckoutRequirements` call. |

**Methods:**

| Method | Returns | Description |
|---|---|---|
| `initialize({required String sessionId, required String sessionToken})` | `Future<void>` | Runs App Attest and exchanges the bootstrap token for a DPoP-bound session. Call once per app launch. |
| `getCheckoutRequirements(CheckoutIntentRequest request, {CheckoutButtonStyle? buttonStyle})` | `Future<CheckoutRequirementsResult>` | Creates a checkout intent, resolves requirements and quote, prepares the native button. |
| `reset()` | `Future<void>` | Clears cached checkout state. Returns to `ready`. |
| `signOut()` | `Future<void>` | Wipes stored OnramperID OIDC tokens. Does not invalidate the partner session. |
| `cancelPreparedIntent(String buttonHandle)` | `Future<void>` | Drops a specific native button by handle. Call when navigating away from a prepared intent. |
| `dispose()` | `Future<void>` | Tears down the client, closes streams, detaches Pigeon callbacks. Idempotent. |

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
| `finalizing` | BFF finalize call is in flight. |
| `rendering` | Payment surface is on screen. |
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
| `checkoutFinalized` | BFF finalized; payment surface about to render. | `renderContext`, `finalizeResponse` |
| `renderingStarted` | Payment surface on screen. | `renderContext` |
| `completed` | Terminal success. | `checkoutId` |
| `failed` | Terminal failure. | `error` |
| `checkoutCancelled` | User dismissed the payment sheet before completing. | — |
| `providerReady` | Provider checkout page finished loading. | — |
| `paymentAuthorized` | User authorized payment (e.g. Apple Pay). Not terminal. | — |
| `paymentProcessing` | Provider accepted payment and is settling. | — |
| `paymentCancelled` | Provider reports user cancelled (e.g. dismissed Apple Pay sheet). | — |
| `providerError` | Provider reported non-recoverable failure. | `providerReason` |

The `checkoutCancelled` through `providerError` events are forwarded from third-party checkout webviews; not every provider emits every kind.

### `CheckoutFinalizeResponse`

Carried by the `checkoutFinalized` event.

| Field | Type | Description |
|---|---|---|
| `headlessCheckoutId` | `String` | Finalized checkout ID. |
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

---

## Errors

### `OnramperError`

Implements `Exception`. Thrown across `async` boundaries; catch with `on OnramperError`.

| Field | Type | Description |
|---|---|---|
| `kind` | `OnramperErrorKind` | Discriminator — always set. |
| `message` | `String` | Human-readable description (English, non-localized). |
| `recoverable` | `bool` | SDK's assessment of whether a retry is worthwhile. |
| `code` | `int?` | Numeric BFF error code when one was present. Do not switch on this; use `kind`. |
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

### `OnramperErrorKind`

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
  double height = 56.0,
})
```

| Parameter | Type | Description |
|---|---|---|
| `buttonHandle` | `String` | Handle from `CheckoutRequirementsResult.buttonHandle`. |
| `height` | `double` | Height in logical pixels. Default `56`. |

Renders an empty `SizedBox` on non-iOS platforms.
