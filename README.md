# onramper_sdk

Flutter plugin wrapping the iOS OnramperSDK for crypto on-ramping. iOS only.

See `integration-guide-flutter.md` for setup.

## Local development

This repo bundles `OnramperSDK.xcframework` via Git LFS. After cloning:

```bash
git lfs install   # one-time, per machine
git lfs pull      # fetch the binary blobs
```

If `pod install` produces a build that crashes at runtime with "framework not found" or you see ~130-byte text files at `ios/Frameworks/OnramperSDK.xcframework/`, the LFS pull didn't run.

To bump the bundled SDK version: replace `ios/Frameworks/OnramperSDK.xcframework/` with the new build, update `ios/Frameworks/.version`, and bump `pubspec.yaml` + `ios/onramper_sdk.podspec`.
