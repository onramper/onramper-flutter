import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../platform/pigeon.g.dart';

/// Tracks the native checkout button's content height reported over
/// [CheckoutButtonFlutterApi].
class CheckoutButtonHeightController extends ChangeNotifier
    implements CheckoutButtonFlutterApi {
  CheckoutButtonHeightController({this.minHeight = 0});

  /// Used until the native view reports its first height.
  static const double fallbackHeight = 56;

  final double minHeight;
  double? _reported;
  bool _unavailable = false;

  bool get isUnavailable => _unavailable;

  double get height =>
      _unavailable ? 0 : math.max(_reported ?? fallbackHeight, minHeight);

  @override
  void onHeightChanged(double height) {
    if (height <= 0 || height == _reported) return;
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
