# Migration: bundled XCFramework → public download

When `onramper-sdk` ships public binary releases:

1. Replace `s.vendored_frameworks` in `ios/onramper_sdk.podspec` with a `prepare_command` that downloads the XCFramework zip from the matching `onramper-sdk` release tag.
2. `git rm -r ios/Frameworks/OnramperSDK.xcframework`.
3. Remove the `.gitattributes` entry for the XCFramework path.
4. Add `ios/Frameworks/` to `.gitignore`.
5. Bump plugin version; consumers see no API change.
