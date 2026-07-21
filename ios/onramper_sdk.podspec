Pod::Spec.new do |s|
  s.name             = 'onramper_sdk'
  s.version          = '1.0.0'
  s.summary          = 'Flutter plugin wrapping OnramperSDK (iOS).'
  s.description      = 'iOS-only Flutter plugin for the Onramper crypto on-ramp.'
  s.homepage         = 'https://github.com/onramper/onramper-flutter'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Onramper' => 'engineering@onramper.com' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '16.0'
  s.swift_version    = '5.9'

  s.source_files     = 'Classes/**/*.{swift,h,m}'
  s.dependency 'Flutter'

  s.vendored_frameworks = 'Frameworks/OnramperSDK.xcframework'

  # The OnramperSDK.xcframework is fetched from a pinned release of the
  # (currently internal) onramper/onramper-ios repo at `pod install` time.
  # Requires ONRAMPER_IOS_READ_TOKEN (falls back to GITHUB_TOKEN, or a locally-
  # authenticated `gh` CLI) with read access to onramper/onramper-ios. In CI
  # this is wired to the org-level RELEASE_REPO_TOKEN secret (see
  # .github/workflows/ios-tests.yml). The zip is verified against a pinned
  # sha256 so the podspec fully determines the binary contents.
  #
  # To bump the SDK version, update ONRAMPER_SDK_VERSION,
  # ONRAMPER_SDK_ASSET_ID (from
  # `gh api repos/onramper/onramper-ios/releases/tags/<tag>` -> assets[0].id),
  # and ONRAMPER_SDK_SHA256 (from the same response's assets[0].digest, minus
  # the `sha256:` prefix).
  s.prepare_command = <<~CMD
    set -euo pipefail
    ONRAMPER_SDK_VERSION="v1.1.0"
    ONRAMPER_SDK_ASSET_ID="461197092"
    ONRAMPER_SDK_SHA256="ff638a874587498611915af37ca05a26ebddd4a3be6c44af50edb40a348fc2b8"
    FRAMEWORKS_DIR="Frameworks"
    XCFRAMEWORK_DIR="$FRAMEWORKS_DIR/OnramperSDK.xcframework"
    VERSION_STAMP="$FRAMEWORKS_DIR/.version"

    # Skip the download if we already have the right version on disk.
    if [ -d "$XCFRAMEWORK_DIR" ] && [ -f "$VERSION_STAMP" ] && [ "$(cat "$VERSION_STAMP")" = "$ONRAMPER_SDK_VERSION" ]; then
      exit 0
    fi

    TOKEN="${ONRAMPER_IOS_READ_TOKEN:-${GITHUB_TOKEN:-}}"
    if [ -z "$TOKEN" ] && command -v gh >/dev/null 2>&1; then
      TOKEN="$(gh auth token 2>/dev/null || true)"
    fi
    if [ -z "$TOKEN" ]; then
      echo "error: OnramperSDK download requires ONRAMPER_IOS_READ_TOKEN (or GITHUB_TOKEN, or an authenticated gh CLI) with read access to onramper/onramper-ios" >&2
      exit 1
    fi

    mkdir -p "$FRAMEWORKS_DIR"
    ZIP="$(mktemp -t OnramperSDK).zip"
    trap 'rm -f "$ZIP"' EXIT

    curl -sSLf \
      -H "Accept: application/octet-stream" \
      -H "Authorization: Bearer $TOKEN" \
      -o "$ZIP" \
      "https://api.github.com/repos/onramper/onramper-ios/releases/assets/$ONRAMPER_SDK_ASSET_ID"

    ACTUAL_SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
    if [ "$ACTUAL_SHA" != "$ONRAMPER_SDK_SHA256" ]; then
      echo "error: OnramperSDK.xcframework.zip sha256 mismatch (expected $ONRAMPER_SDK_SHA256, got $ACTUAL_SHA)" >&2
      exit 1
    fi

    rm -rf "$XCFRAMEWORK_DIR"
    unzip -qo "$ZIP" -d "$FRAMEWORKS_DIR"
    echo "$ONRAMPER_SDK_VERSION" > "$VERSION_STAMP"
  CMD

  s.pod_target_xcconfig = {
    'DEFINES_MODULE'                       => 'YES',
    'ENABLE_BITCODE'                       => 'NO',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.swift'
    test_spec.frameworks   = 'XCTest'
  end
end
