import 'package:onramper_flutter/onramper_flutter.dart';

/// Terminal checkout outcome shown by the demo, with the transaction id
/// captured when it happened. Mirrors the native demo's "Transaction
/// Complete" panel: it stays after the payment sheet is closed and is cleared
/// by "New transaction", Reset, or a new quote.
class CheckoutOutcome {
  const CheckoutOutcome({required this.pending, required this.transactionId});

  /// `completed` → done, `paymentPending` → accepted but not settled.
  /// Other events don't end a checkout.
  static CheckoutOutcome? fromEvent(
    CheckoutEventKind kind,
    String? transactionId,
  ) =>
      switch (kind) {
        CheckoutEventKind.completed =>
          CheckoutOutcome(pending: false, transactionId: transactionId),
        CheckoutEventKind.paymentPending =>
          CheckoutOutcome(pending: true, transactionId: transactionId),
        _ => null,
      };

  final bool pending;

  /// `null` means the SDK never populated it — shown as "unavailable" rather
  /// than hidden, like the native demo.
  final String? transactionId;
}

/// Turns `currentTransactionId` changes into log lines like the native demo:
/// the id arriving at finalize, and being dropped when a new intent
/// supersedes it or `reset()` runs. The initial `null` is not "cleared".
class TransactionIdLog {
  String? _last;

  String? next(String? id) {
    if (id == _last) return null;
    final previous = _last;
    _last = id;
    if (id != null) return 'transactionId → $id';
    return previous != null ? 'transactionId cleared' : null;
  }
}
