# Checkout flow

How a checkout flows through `onramper_sdk`. For the full integration walkthrough — install, usage, error handling — see Getting started.

---

## What the plugin handles for you

The plugin owns the parts of a checkout you'd otherwise have to build and maintain:

- **Abstracts away multiple headless providers** — integrate once instead of wiring up each onramp's API and quirks.
- **Fulfills every requirement each provider needs**, resolved per user and amount:
  - **Amount limits** — validates the order against each provider's min/max bounds.
  - **Terms of Service** — surfaces the right consent text and confirms acceptance.
  - **Dynamic KYC collection** — gathers the identity data the provider requires via the OnramperID sheet, only when needed.
- **Apple Pay and Revolut Pay support for US and EU** — works in both regions out of the box.
- **Token refresh** — refreshes both the Headless Wrapper session token and the OnramperID user token proactively and reactively. Your `sessionExpirationHandler` is only invoked if both refresh paths exhaust.
- **Token storage** — OIDC tokens live in the iOS keychain. Nothing to cache on the Dart side.
- **Unified API and event bridge** — one set of calls and events across all supported providers.
- **Payment surface** — picks the right view (Apple Pay, card webview, deep-link) from the provider's finalize response.

---

## How a checkout flows

```
Backend          Your app         Plugin (native iOS)
-------          --------         -------------------
mint session  →  initialize()  →  attestation + DPoP bootstrap
                 getCheckout   →  intent + quote + requirements
                 requirements     ↓
                 [embed button]
                                  user taps Buy
                               →  ToS acceptance recorded
                               →  OnramperID login (if needed)
                               →  finalize intent with BFF
                               →  present payment surface
                 observe events ← completed / failed
```

Step by step:

1. **Backend mints a session.** Your server calls `POST /v2/partners/{apiKey}/client-sessions` with your Ed25519 partner key and gets back a one-shot `{sessionId, sessionToken}` pair. It returns these to the app over your own authenticated channel.

2. **App constructs `OnramperClient`** with configuration and `sessionExpirationHandler`, then calls `initialize(sessionId:, sessionToken:)`. The native side runs App Attest and exchanges the bootstrap token for a DPoP-bound session. State becomes `ready`.

3. **App requests a checkout.** `getCheckoutRequirements(request)` creates a checkout intent, resolves what consent and KYC is needed for this user and amount, and returns `CheckoutRequirementsResult` with a quote and a native button handle.

4. **App embeds `OnramperCheckoutButton`.** The user sees the native Buy button and any Terms-of-Service text the plugin rendered for the selected provider.

5. **User taps Buy.** The button records ToS consent, presents the OnramperID login sheet if the provider needs user identity (and the same sheet handles phone re-verification), then finalizes the intent with the BFF.

6. **Plugin renders the payment surface.** Apple Pay, card webview, or other surface — chosen automatically from the provider's finalize response. State transitions through `finalizing` → `rendering`.

7. **Outcome.** `CheckoutEventKind.completed` (with `checkoutId`) or `CheckoutEventKind.failed` (with `OnramperError`). Call `client.reset()` to return to `ready` for another checkout.

---

## The state machine

`OnramperClient.state.kind` is the single source of truth for what the native SDK is doing at any moment.

| State | When | Payload |
|---|---|---|
| `idle` | Before `initialize()` resolves. | — |
| `initializing` | `initialize()` is in flight (attestation + DPoP bootstrap). | — |
| `ready` | Bootstrap complete; ready for `getCheckoutRequirements()`. | — |
| `checkoutPreparing` | `getCheckoutRequirements()` is in flight. | — |
| `requireLogin` | Intent created; the provider requires user identity or phone re-verification. The OnramperID sheet will present on Buy tap. | `requireLoginRequirements: List<CheckoutRequirement>` |
| `authenticating` | OnramperID login sheet is on screen. | — |
| `readyToCheckout` | All requirements satisfied; tapping Buy goes straight to finalize. | — |
| `finalizing` | BFF finalize call is in flight. | — |
| `rendering` | Payment surface is on screen. | `renderContext: RenderContext` |
| `completed` | Terminal success. | — |
| `failed` | Terminal failure. | `failedError: OnramperError` |

State transitions are emitted as `CheckoutEventKind.stateChanged` on `client.events` and trigger `notifyListeners()` on the `ChangeNotifier`. Both observation surfaces stay in sync.

---

## Requirements flow

`getCheckoutRequirements` returns a list of `CheckoutRequirement` items describing what the provider needs before a checkout can proceed. The plugin and button handle most of these automatically — you surface them to the user only when the plugin cannot resolve them on its own.

| Requirement kind | What it means | How it's resolved |
|---|---|---|
| `tos` | The user must acknowledge the provider's Terms of Service, Privacy Policy, or User Agreement. | Rendered automatically below the button by `OnramperCheckoutButton`. Acceptance is recorded when the user taps Buy. |
| `amountLimit` | The requested amount must fall within the provider's min/max bounds. | `amountLimitSatisfied: true` means the current amount already passes. If `false`, prompt the user to enter an amount within `minAmountLimit`/`maxAmountLimit`. |
| `userInfo` | The provider needs identity fields (name, email, phone, SSN last 4, address). | Resolved via the OnramperID login sheet, which is presented automatically on Buy tap. State transitions to `requireLogin` then `authenticating`. |
| `reverification` | A previously-collected field (email or phone) is older than the provider's recency policy. | Resolved via the same OnramperID sheet; the user re-verifies their existing number. `lastVerifiedAt` carries the ISO-8601 timestamp of the last verification. |

---

## What OnramperID is

OnramperID is Onramper's hosted OIDC identity layer. It collects whatever KYC data the chosen provider requires (email, name, contact info) so partners don't host a login UI or hold user PII themselves.

- The plugin presents OnramperID as a native sheet on Buy tap, **only when** the checkout's requirements include `userInfo` or `reverification`.
- Redirect is a hosted HTTPS callback intercepted inside the webview — no custom URL scheme, universal link, or `Info.plist` registration is required for OnramperID.
- Token refresh, re-authentication, and re-presenting the login sheet on a terminal refresh failure are all handled internally. Partners never read, write, or inspect OnramperID tokens.

---

## Provider-lifecycle events

Provider checkout webviews forward the following events over the bridge. Not every provider emits every kind. Wire them into analytics or logging; they are not required for checkout flow control.

| `CheckoutEventKind` | Fires when |
|---|---|
| `providerReady` | Provider's checkout page finished loading. |
| `paymentAuthorized` | User authorized payment in the provider's native sheet (e.g. Apple Pay). Not terminal — settling follows. |
| `paymentProcessing` | Provider accepted the payment and is settling it. |
| `paymentCancelled` | Provider reports the user cancelled (e.g. dismissed the Apple Pay sheet). |
| `checkoutCancelled` | User dismissed the payment webview before completing. |
| `providerError` | Provider reported a non-recoverable failure. `event.providerReason` carries a short human-readable string from the provider. |

---

## Token management

The plugin manages two independent token hierarchies silently:

**Partner (Headless Wrapper) session:**
- The bootstrap `sessionToken` is exchanged for a DPoP-bound session during `initialize()`.
- The session token is refreshed proactively (before expiry) and reactively (on 401).
- If both refresh paths exhaust, the plugin calls `sessionExpirationHandler` for a fresh `{sessionId, sessionToken}` pair. Your handler should call your backend and return new credentials; the plugin re-runs the bootstrap transparently.

**OnramperID user token (OIDC):**
- Obtained from the OnramperID login sheet and stored in the iOS keychain.
- Access and refresh tokens are managed automatically.
- If the refresh token is terminally rejected, the plugin re-presents the login sheet. Your code only sees `CheckoutEventKind.loginRequired` — no error is emitted for this path.

You never read, write, or cache either token class in Dart.
