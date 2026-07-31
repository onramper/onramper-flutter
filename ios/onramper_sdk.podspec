Pod::Spec.new do |s|
  s.name             = 'onramper_sdk'
  s.version          = '1.1.1'
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
  # onramper/onramper-ios repo at `pod install` time. The zip is verified
  # against a pinned sha256 so the podspec fully determines the binary
  # contents.
  #
  # onramper/onramper-ios is public, so no authentication is required for
  # anonymous downloads — a plain `pod install` on any machine works. A
  # GitHub token is used if present (raises the anonymous rate limit from
  # 60/hour to 5000/hour and remains compatible if the repo ever reverts
  # to internal). Sources for a token, in order: $ONRAMPER_IOS_READ_TOKEN,
  # $GITHUB_TOKEN, `gh auth token`.
  #
  # To bump the SDK version, update ONRAMPER_SDK_VERSION,
  # ONRAMPER_SDK_ASSET_ID (from
  # `gh api repos/onramper/onramper-ios/releases/tags/<tag>` -> assets[0].id),
  # and ONRAMPER_SDK_SHA256 (from the same response's assets[0].digest, minus
  # the `sha256:` prefix).
  s.prepare_command = <<~CMD
    set -euo pipefail
    ONRAMPER_SDK_VERSION="v1.1.1"
    ONRAMPER_SDK_ASSET_ID="492870955"
    ONRAMPER_SDK_SHA256="88235fa50561422ba3276f8008ff0a2229cff760f75f36f3f424ff5f26e2b2e2"
    FRAMEWORKS_DIR="Frameworks"
    XCFRAMEWORK_DIR="$FRAMEWORKS_DIR/OnramperSDK.xcframework"
    VERSION_STAMP="$FRAMEWORKS_DIR/.version"

    # Skip the download if we already have the right version on disk.
    if [ -d "$XCFRAMEWORK_DIR" ] && [ -f "$VERSION_STAMP" ] && [ "$(cat "$VERSION_STAMP")" = "$ONRAMPER_SDK_VERSION" ]; then
      exit 0
    fi

    # Token is optional — the download works anonymously for public repos.
    # If a token is available we send it (better rate limits, transparent
    # fallback if the repo is ever gated again).
    TOKEN="${ONRAMPER_IOS_READ_TOKEN:-${GITHUB_TOKEN:-}}"
    if [ -z "$TOKEN" ] && command -v gh >/dev/null 2>&1; then
      TOKEN="$(gh auth token 2>/dev/null || true)"
    fi

    mkdir -p "$FRAMEWORKS_DIR"
    ZIP="$(mktemp -t OnramperSDK).zip"
    trap 'rm -f "$ZIP"' EXIT

    AUTH_HEADER=()
    if [ -n "$TOKEN" ]; then
      AUTH_HEADER=(-H "Authorization: Bearer $TOKEN")
    fi

    if ! curl -sSLf \
      -H "Accept: application/octet-stream" \
      "${AUTH_HEADER[@]}" \
      -o "$ZIP" \
      "https://api.github.com/repos/onramper/onramper-ios/releases/assets/$ONRAMPER_SDK_ASSET_ID"; then
      echo "error: Failed to download OnramperSDK.xcframework." >&2
      echo "  If onramper/onramper-ios is temporarily gated, set" >&2
      echo "  ONRAMPER_IOS_READ_TOKEN to a GitHub PAT with Contents:read" >&2
      echo "  on onramper/onramper-ios and re-run pod install." >&2
      exit 1
    fi

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
