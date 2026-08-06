import Flutter
import Security
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.pluginRegistry.registrar(forPlugin: "ios_diagnostics")!.messenger()
    let channel = FlutterMethodChannel(
      name: "onramper_flutter_example/diagnostics",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getAppIdentifiers":
        result([
          "bundleId": Bundle.main.bundleIdentifier ?? "unknown",
          "teamId": Self.readTeamId() ?? "unknown",
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Reads the app's Team ID by inspecting the access group of a transient
  /// keychain item — the access group is prefixed with `<TeamID>.`. Works
  /// regardless of signing source (free Apple ID, enterprise, App Store).
  private static func readTeamId() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: "OnramperSDKExample.teamIdProbe",
      kSecAttrService as String: "OnramperSDKExample.teamIdProbe",
      kSecReturnAttributes as String: true,
    ]
    var result: AnyObject?
    var status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
      status = SecItemAdd(query as CFDictionary, &result)
    }
    guard status == errSecSuccess,
          let dict = result as? [String: Any],
          let accessGroup = dict[kSecAttrAccessGroup as String] as? String,
          let teamId = accessGroup.split(separator: ".").first
    else { return nil }
    return String(teamId)
  }
}
