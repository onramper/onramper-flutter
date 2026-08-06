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

- Wiring `sessionExpirationHandler` to a local mock session service
- Observing `client.events` and `client.stateStream` in real time
- Rendering `OnramperCheckoutButton` with custom `CheckoutButtonStyle`
- Handling `OnramperError` kinds in the UI

For the full integration walkthrough, see the
[integration guide](https://github.com/onramper/onramper-flutter/blob/master/integration-guide-flutter.md).
