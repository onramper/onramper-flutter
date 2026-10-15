import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/onramper_flutter.dart';
import 'package:onramper_flutter_example/checkout_outcome.dart';

void main() {
  test('completed and paymentPending capture the transaction id', () {
    final done = CheckoutOutcome.fromEvent(CheckoutEventKind.completed, 'T1')!;
    expect(done.pending, isFalse);
    expect(done.transactionId, 'T1');

    final pending =
        CheckoutOutcome.fromEvent(CheckoutEventKind.paymentPending, 'T2')!;
    expect(pending.pending, isTrue);
    expect(pending.transactionId, 'T2');
  });

  test('other events produce no outcome', () {
    for (final kind in [
      CheckoutEventKind.checkoutCancelled,
      CheckoutEventKind.failed,
      CheckoutEventKind.checkoutFinalized,
    ]) {
      expect(CheckoutOutcome.fromEvent(kind, 'T1'), isNull, reason: '$kind');
    }
  });

  test('outcome keeps a missing id visible as unavailable', () {
    final o = CheckoutOutcome.fromEvent(CheckoutEventKind.completed, null)!;
    expect(o.transactionId, isNull);
  });

  test('transaction id log mirrors the native demo', () {
    final log = TransactionIdLog();
    expect(log.next(null), isNull, reason: 'initial nil is not "cleared"');
    expect(log.next('T1'), 'transactionId → T1');
    expect(log.next('T1'), isNull, reason: 'no repeat for the same id');
    expect(log.next(null), 'transactionId cleared');
    expect(log.next(null), isNull);
  });
}
