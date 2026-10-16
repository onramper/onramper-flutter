import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../platform/pigeon.g.dart';

/// Tracks the native checkout button's content height reported over
/// [CheckoutButtonFlutterApi].
class CheckoutButtonHeightController extends ChangeNotifier
    implements CheckoutButtonFlutterApi {
  CheckoutButtonHeightController({double minHeight = 0})
      : _minHeight = minHeight;

  /// Used until the native view reports its first height.
  static const double fallbackHeight = 56;

  double _minHeight;

  /// Floor for [height] (from the deprecated widget `height` parameter).
  double get minHeight => _minHeight;
  set minHeight(double value) {
    if (value == _minHeight) return;
    _minHeight = value;
    notifyListeners();
  }

  double? _reported;
  bool _unavailable = false;

  bool get isUnavailable => _unavailable;

  double get height =>
      _unavailable ? 0 : math.max(_reported ?? fallbackHeight, _minHeight);

  @override
  void onHeightChanged(double height) {
    // An unchanged height still restores a collapsed button.
    if (height <= 0 || (height == _reported && !_unavailable)) return;
    _reported = height;
    _unavailable = false;
    notifyListeners();
  }

  @override
  void onUnavailable() {
    if (_unavailable) return;
    _unavailable = true;
    notifyListeners();
  }
}
