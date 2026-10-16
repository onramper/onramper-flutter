# onramper_flutter — example app

A minimal Flutter app demonstrating the full `onramper_flutter` plugin integration:
construct client (configuration starts automatically) → await initialize →
getCheckoutRequirements → OnramperCheckoutButton. Initialize once per client;
setup is awaited internally.

## Running the example

Prerequisites: real iOS device, Xcode 26+, bundle ID registered with Onramper.

```bash
cd example
flutter pub get
cd ios && pod install && cd ..
# Copy the env template and fill in your credentials:
cp .env.example .env
flutter run --dart-define-from-file=.env --release
```

Use `--release` (not `--debug`) — the Flutter debug overlay renders over the native
`WKWebView` and can obscure the payment sheet.

## What it covers

- Wiring `sessionExpirationHandler` to a demo session service
- Observing `client.events` in real time, with pending payments shown separately
  from completion and failures shown as `userMessage` + support code
- Rendering the self-sizing `OnramperCheckoutButton`
- Layout and behaviour match the React Native example app
  (`onramper-react-native/example`): one **Buy Crypto** screen plus a
  **Settings** sheet (⚙︎ in the header)
- **Live quotes:** any change to the form re-runs `getCheckoutRequirements`
  (400 ms after typing stops); a response for older inputs is dropped. If the
  SDK fails before checkout is finalized, **Get a new quote** replaces the
  checkout button
- **Crypto** tiles (BTC / ETH / SOL) with predefined demo wallets, editable
  **wallet** and **amount**, **USD / EUR / GBP**, **Apple Pay / Revolut Pay**,
  and an **Onramp** filter (Any, MoonPay, Paybis, Coinbase Pay → `onlyOnramps`)
- **Override country and state** (off by default — the backend infers them);
  US/ES/NL/GR, with a US state picker
- **Prefill** (collapsed, off by default): first/last name, phone, and an
  optional email; the header shows which fields are sent
- **Reset** (`client.reset()`) and **Log out** (`client.signOut()`)
- Status boxes for **Payment processing**, **Transaction complete**, the
  **Onramper transaction ID**, and errors (initialization, quote, action,
  checkout)
- **Settings → Environment** (Development / Production, default Development):
  signs out, then re-initializes against the selected environment. Each uses
  its own `.env` keys (`ONRAMPER_DEV_*` / `ONRAMPER_PROD_*`, see
  `.env.example`); missing keys show as an initialization error. Legacy
  unprefixed `ONRAMPER_API_KEY`, `ONRAMPER_CLIENT_ID` and
  `ONRAMPER_DEMO_AUTH_TOKEN` are fallback values for Development only
- **Settings → Clear local sessions:** sign out, reset, and re-initialize
  with a fresh demo session
- **Settings → Dark mode** (on by default): app theme plus
  `OnramperTheme.dark`/`.light` for the SDK (re-initializes)
- **Settings → Diagnostic logs:** SDK records (`logLevel: debug`) are written
  to daily UTC files `onramper-sdk-YYYY-MM-DD.log` in Application Support
  (excluded from backup), kept for 7 days / 5 MB. Turn **Save SDK logs** off to
  stop writing (remembered across launches). Preview, share (system share
  sheet) or delete all. Logs may contain personal information
- **Settings → SDK events:** in-memory list of what the demo did and saw
  (init steps, state changes, quotes, checkout events)
- **Settings → About:** plugin and SDK versions, environment, bundle ID and
  team ID (useful for App Attest allowlist checks)

`pubspec.yaml` points `onramper_flutter` at this checkout through
`dependency_overrides` (`path: ../`) so the app always runs the local plugin
code. The override is removed when a release is published.

For the full integration walkthrough, see the
[integration guide](https://github.com/onramper/onramper-flutter/blob/master/integration-guide-flutter.md).
