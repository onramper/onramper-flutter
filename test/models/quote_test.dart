import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_sdk/src/models/quote.dart';
import 'package:onramper_sdk/src/platform/pigeon.g.dart';

void main() {
  group('QuoteResponse.fromDto', () {
    test('round-trips a fully-populated quote', () {
      final dto = QuoteDto(
        quoteId: 'q-1',
        ramp: 'moonpay',
        rate: 1.23,
        networkFee: 0.1,
        transactionFee: 0.2,
        payout: 100.0,
        paymentMethod: 'credit_card',
        recommendations: <String>['fastest', 'cheapest'],
        errors: <QuoteErrorDto>[
          QuoteErrorDto(type: 'min', message: 'amount too low'),
        ],
      );

      final q = QuoteResponse.fromDto(dto);

      expect(q.quoteId, 'q-1');
      expect(q.ramp, 'moonpay');
      expect(q.rate, 1.23);
      expect(q.networkFee, 0.1);
      expect(q.transactionFee, 0.2);
      expect(q.payout, 100.0);
      expect(q.paymentMethod, 'credit_card');
      expect(q.recommendations, <String>['fastest', 'cheapest']);
      expect(q.errors, hasLength(1));
      expect(q.errors!.first.type, 'min');
      expect(q.errors!.first.message, 'amount too low');
    });

    test('round-trips an all-nil quote', () {
      final dto = QuoteDto();
      final q = QuoteResponse.fromDto(dto);

      expect(q.quoteId, isNull);
      expect(q.ramp, isNull);
      expect(q.rate, isNull);
      expect(q.networkFee, isNull);
      expect(q.transactionFee, isNull);
      expect(q.payout, isNull);
      expect(q.paymentMethod, isNull);
      expect(q.recommendations, isNull);
      expect(q.errors, isNull);
    });

    test('round-trips a quote with multiple errors and no recommendations', () {
      final dto = QuoteDto(
        errors: <QuoteErrorDto>[
          QuoteErrorDto(type: 'a', message: 'A'),
          QuoteErrorDto(type: 'b', message: 'B'),
          QuoteErrorDto(),
        ],
      );

      final q = QuoteResponse.fromDto(dto);

      expect(q.recommendations, isNull);
      expect(q.errors, hasLength(3));
      expect(q.errors![2].type, isNull);
      expect(q.errors![2].message, isNull);
    });
  });

  group('QuoteError.fromDto', () {
    test('preserves both fields', () {
      final dto = QuoteErrorDto(type: 't', message: 'm');
      final err = QuoteError.fromDto(dto);
      expect(err.type, 't');
      expect(err.message, 'm');
    });

    test('preserves null fields', () {
      final err = QuoteError.fromDto(QuoteErrorDto());
      expect(err.type, isNull);
      expect(err.message, isNull);
    });
  });
}
