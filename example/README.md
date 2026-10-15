# onramper_flutter — example app

A minimal Flutter app demonstrating the full `onramper_flutter` plugin integration:
configure → initialize → getCheckoutRequirements → OnramperCheckoutButton.

## Running the example

Prerequisites: real iOS device, Xcode 26+, bundle ID registered with Onramper.

```bash
cd example
flutter pub get
cd ios && pod install && cd ..
# Copy the env template and fill in your credentials:
cp .env.example .env
flutter run --release
```

Use `--release` (not `--debug`) — the Flutter debug overlay renders over the native
`WKWebView` and can obscure the payment sheet.

## What it covers

- Wiring `sessionExpirationHandler` to a demo session service
- Observing `client.events` in real time, with pending payments shown separately
  from completion and failures shown as `userMessage` + support code
- Rendering the self-sizing `OnramperCheckoutButton`
- **Crypto** selector (BTC / ETH / SOL) with predefined demo wallets, plus
  editable **amount** and **wallet** fields (switching crypto restores its
  demo wallet)
- **Dark mode** switch (starts from the device appearance): sets the app theme
  and passes an explicit `OnramperTheme.light`/`.dark` to the SDK (rebuilds
  the client)
- **Override country and state** (off by default — no `country`/`subdivision`
  is sent and the backend infers them); US/ES/NL/GR with a US state picker
- **Pay with** USD or EUR (choosing a country selects its default currency)
- **Onramp** filter: Any, MoonPay, Paybis or Coinbase Pay (`onlyOnramps`)
- **Reset** (`client.reset()`) and **Log out** (`client.signOut()`)
- **Prefill (optional):** email, first/last name and phone passed to
  `getCheckoutRequirements(prefill:)`. Email must match the OnramperID sign-in
  address, or the whole prefill is dropped.
- **New quote:** re-runs `getCheckoutRequirements`; superseded calls
  (`intentInvalidated`) are ignored
- **Versions banner:** plugin version, bundled SDK version and the current
  transaction id
- **SDK log viewer** (app-bar icon), fed by `OnramperConfiguration.logHandler`:
  pick a log level (rebuilds the client), browse records, Clear, Copy all
  (JSON lines). Exported logs may contain personal data.

`pubspec.yaml` points `onramper_flutter` at this checkout through
`dependency_overrides` (`path: ../`) so the app always runs the local plugin
code. The override is removed when a release is published.

For the full integration walkthrough, see the
[integration guide](https://github.com/onramper/onramper-flutter/blob/master/integration-guide-flutter.md).
