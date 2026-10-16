import 'package:flutter/foundation.dart';
import 'package:onramper_flutter/onramper_flutter.dart';

import '../logging/event_log.dart';
import '../theme/demo_theme.dart';
import '../utils/format.dart';
import 'prefill.dart';
import 'request.dart';

/// Re-requests checkout requirements whenever the client or any input
/// changes — the Flutter port of RN `useCheckout`. A response for older
/// inputs, or for a client that has since been replaced, is dropped.
class CheckoutController extends ChangeNotifier {
  CheckoutController(
      {required void Function(EventLevel level, String line) log})
      : _log = log;

  final void Function(EventLevel level, String line) _log;

  OnramperClient? _client;
  BuyForm? _form;
  PrefillInput? _prefill;
  DemoPalette? _palette;
  int _generation = 0;
  bool _disposed = false;

  CheckoutRequirementsResult? _result;
  OnramperClient? _resultClient;
  bool _loading = false;
  String? _error;
  String? _amountHint;

  /// Only a result produced by the current client is exposed.
  CheckoutRequirementsResult? get result =>
      _resultClient != null && identical(_resultClient, _client)
          ? _result
          : null;
  bool get loading => _loading;
  String? get error => _error;
  String? get amountHint => _amountHint;

  void update({
    required OnramperClient? client,
    required BuyForm form,
    required PrefillInput prefill,
    required DemoPalette palette,
  }) {
    if (identical(client, _client) &&
        form == _form &&
        prefill == _prefill &&
        identical(palette, _palette)) {
      return;
    }
    _client = client;
    _form = form;
    _prefill = prefill;
    _palette = palette;
    _request();
  }

  void refresh() => _request();

  void _request() {
    final generation = ++_generation;
    _result = null;
    _resultClient = null;
    _error = null;
    _amountHint = null;
    final client = _client;
    final request = _form?.toRequest();
    final prefill = _prefill;
    final palette = _palette;
    if (client == null ||
        request == null ||
        prefill == null ||
        palette == null) {
      _loading = false;
      _notify();
      return;
    }
    _loading = true;
    final data = request.transactionData;
    _log(
        EventLevel.info,
        'quote: ${plainNumber(data.amount)} ${data.source.toUpperCase()} → '
        '${data.destination.toUpperCase()} via ${data.paymentMethod}');
    _log(EventLevel.info, prefillSummary(prefill));
    _notify();
    client
        .getCheckoutRequirements(
      request,
      prefill: buildPrefill(prefill),
      buttonStyle: checkoutButtonStyle(palette),
    )
        .then((r) {
      if (_disposed || generation != _generation) return;
      _result = r;
      _resultClient = client;
      _loading = false;
      _log(EventLevel.info,
          'quote ok: ${r.quote.ramp} rate=${r.quote.rate} payout=${r.quote.payout}');
      _notify();
    }, onError: (Object e) {
      if (_disposed || generation != _generation) return;
      _loading = false;
      // Reset, sign-out or a client change cancelled this preparation; the
      // follow-up refresh (if any) requests a new quote.
      if (e is OnramperError && e.kind == OnramperErrorKind.intentInvalidated) {
        _log(EventLevel.info, 'quote superseded');
        _notify();
        return;
      }
      final d = describeError(e);
      if (d.code == OnramperErrorKind.amountOutOfRange.name) {
        _amountHint = d.message;
      } else {
        _error = '${d.code} — ${d.message}';
      }
      _log(EventLevel.error, 'quote failed: ${d.code} — ${d.message}');
      _notify();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
