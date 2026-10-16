import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The "Save SDK logs" switch — the only setting that survives a restart
/// (RN keeps it in NSUserDefaults under the same key).
class LogSettings extends ChangeNotifier {
  LogSettings._(this._prefs, this._enabled);

  static const prefsKey = 'onramperDiagnosticLogging';

  static Future<LogSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return LogSettings._(prefs, prefs.getBool(prefsKey) ?? true);
  }

  final SharedPreferences _prefs;
  bool _enabled;

  bool get enabled => _enabled;

  Future<void> setEnabled(bool value) async {
    if (value == _enabled) return;
    await _prefs.setBool(prefsKey, value);
    _enabled = value;
    notifyListeners();
  }
}
