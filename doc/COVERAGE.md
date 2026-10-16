# Coverage

What `onramper_flutter` supports in this release — regions, payment methods, providers, and platform requirements. For the full integration walkthrough, see Getting started.

---

## Platform

| Platform | Supported | Notes |
|---|---|---|
| iOS 16.0+ | Yes | Minimum deployment target required by the plugin. |
| Android | No | Not supported in this release. The plugin renders an empty `SizedBox` on Android. |

| Toolchain | Minimum |
|---|---|
| Flutter | 3.22 |
| Dart | 3.4 |
| Xcode | 26+ (required — earlier versions cannot link the Swift 6.2 xcframework) |

> ℹ️ **iOS only.** Android support is not part of this release. Guard call sites with a platform check if your app targets Android.

---

## Supported regions

| Region | Supported |
|---|---|
| United States (US) | Yes |
| European Union (EU) | Yes |

---

## Supported payment methods

| Payment method | Supported |
|---|---|
| Apple Pay | Yes |

---

## Supported providers

| Provider | Notes |
|---|---|
| Coinbase | Available in supported regions subject to partner configuration. |
| Paybis | Available in supported regions subject to partner configuration. |
| MoonPay | Apple Pay. The checkout button runs MoonPay's checkout inside the payment sheet: guest checkout or MoonPay account onboarding when required, 3-D Secure verification, and MoonPay's required payment disclosures shown next to the Apple Pay button (they can't be hidden). Nothing extra to integrate. |

Other providers may appear based on region, requested amount, and payment method. The set of eligible providers is resolved at `getCheckoutRequirements` time from Onramper's backend — the list above reflects providers available in this release, not an exhaustive list of what any single request returns. Use `onlyOnramps` in `CheckoutIntentRequest` to restrict to a specific subset.
