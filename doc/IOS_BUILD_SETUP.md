# iOS build setup for `onramper_sdk`

Build-time configuration for embedding the Onramper iOS SDK in a Flutter app: deployment target, App Attest capability, entitlements, Podfile, and first-build tips. For the full integration walkthrough — install, usage, error handling, API reference — see Getting started.

---

## 1. iOS deployment target

The plugin requires **iOS 16.0 or higher**. Set this in two places:

**`ios/Podfile`** — the first line of the file:

```ruby
platform :ios, '16.0'
```

**Xcode project** — Runner target → Build Settings → Deployment → iOS Deployment Target → `16.0`.

If the Podfile and the Xcode project are out of sync, `pod install` will warn and builds may fail with deployment-target conflicts.

---

## 2. App Attest capability

The Onramper iOS SDK attests every session via Apple's `DCAppAttestService`. Without the entitlement, the first call to `initialize()` returns `OnramperError(kind: attestationFailed)`.

### 2.1 Enable the capability

In Xcode: select the **Runner** target → **Signing & Capabilities** → **+ Capability** → **App Attest**.

Xcode writes the entitlement into `Runner.entitlements` (creating the file if it doesn't exist). Confirm the file contains:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.devicecheck.appattest-environment</key>
    <string>development</string>
</dict>
</plist>
```

Use `development` for debug and ad hoc builds. For App Store and TestFlight builds, change the value to `production` (or configure it per build configuration in Xcode's build settings).

### 2.2 Bundle ID registration

Your Flutter app's bundle identifier must be registered with Onramper before attestation will succeed. Bundle IDs are validated server-side; an unregistered ID is rejected with `OnramperError(kind: attestationFailed)`. Contact Onramper support to register your bundle ID.

> ℹ️ **iOS only** — App Attest is unavailable on the iOS Simulator. Attempting to attest on a simulator surfaces as `OnramperError(kind: attestationFailed)`. Run on a physical device throughout integration.

---

## 3. Podfile setup

Your `ios/Podfile` must set the deployment target at the top. No additional changes to the target block or post-install hook are required for this plugin.

```ruby
platform :ios, '16.0'

# ... Flutter-generated target block ...
```

A minimal working Podfile (Flutter default):

```ruby
platform :ios, '16.0'

ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug'   => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(
    File.join('..', 'Flutter', 'Generated.xcconfig'),
    __FILE__,
  )
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. " \
          "If you're running pod install manually, " \
          "make sure flutter pub get is executed first"
  end
  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. " \
        "Try deleting Generated.xcconfig and running flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'),
                         flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end
```

---

## 4. Pod install

```bash
flutter pub get
cd ios && pod install
```

`pod install` downloads the pinned `OnramperSDK.xcframework` from the public [`onramper/onramper-ios`](https://github.com/onramper/onramper-ios) release into `ios/Frameworks/` and links it into the Runner project. The download is sha256-verified against the checksum baked into the podspec.

**Rate limits.** CocoaPods fetches the release asset via GitHub's anonymous API (60 requests/hour). If `pod install` fails with:

```
curl: (22) The requested URL returned error: 403
```

Export a token to raise the ceiling to 5,000/hour, then re-run:

```bash
export ONRAMPER_IOS_READ_TOKEN=ghp_...   # preferred — scoped read-only
# OR
export GITHUB_TOKEN=ghp_...
cd ios && pod install
```

---

## 5. First build tips

- **Build on device, not the simulator.** App Attest is unavailable on simulators. `flutter run` without `--simulator` will prompt you to select a connected device.
- **Use `--release` or `--profile` for end-to-end testing.** The Flutter debug overlay renders on top of the native `WKWebView` and can obstruct the payment sheet. Pass `--release` when testing the full checkout flow.
- **Xcode 26+ is required.** The bundled xcframework is compiled with Swift 6.2. Xcode 16 and earlier cannot link it — both report effective-5.10 ABI but the Swift module is incompatible.
- **Signing team must be set.** Xcode → Runner target → Signing & Capabilities → Team. The bundle ID must match what you registered with Onramper.
- If the build fails with `module map file ... not found` for a Swift pod, ensure Xcode is 26+ and that `SWIFT_ENABLE_EXPLICIT_MODULES` has not been set to `YES` by another Podfile hook in your project.

---

## 6. Verifying the setup

After a successful build on a real device, call `client.initialize(...)` with valid credentials. The state machine should progress through `initializing` → `ready`.

If you see `failed: attestationFailed`, check:

1. Running on a real device (not simulator).
2. `Runner.entitlements` contains `com.apple.developer.devicecheck.appattest-environment`.
3. Bundle ID is registered with Onramper.
4. The entitlement value (`development` vs `production`) matches the build type.

If you see `failed: networkError`, the device cannot reach the Onramper backend — check connectivity and confirm no proxy or firewall is blocking `api.onramper.com` (production) or `api-stg.onramper.com` (staging).
