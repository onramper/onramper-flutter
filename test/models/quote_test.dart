import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/src/models/provider_json.dart';
import 'package:onramper_flutter/src/models/quote.dart';
import 'package:onramper_flutter/src/platform/pigeon.g.dart';

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
    });

    test('omitted recommendations map to null', () {
      final dto = QuoteDto(
        quoteId: 'q',
        ramp: 'r',
        rate: 1,
        networkFee: 0,
        transactionFee: 0,
        payout: 1,
        paymentMethod: 'pm',
      );

      final q = QuoteResponse.fromDto(dto);

      expect(q.recommendations, isNull);
    });

    test('recommendations list is unmodifiable', () {
      final dto = QuoteDto(
        quoteId: 'q',
        ramp: 'r',
        rate: 1,
        networkFee: 0,
        transactionFee: 0,
        payout: 1,
        paymentMethod: 'pm',
        recommendations: <String>['a'],
      );

      final q = QuoteResponse.fromDto(dto);

      expect(() => q.recommendations!.add('b'), throwsUnsupportedError);
    });
  });

  test('maps providerContext and paymentDisclosures', () {
    final q = QuoteResponse.fromDto(QuoteDto(
      quoteId: 'q',
      ramp: 'moonpay',
      rate: 1,
      networkFee: 0,
      transactionFee: 0,
      payout: 1,
      paymentMethod: 'applepay',
      providerContext: {
        'executable': true,
        'paymentDisclosures': [
          {
            'code': 'c',
            'version': '1',
            'contentMarkdown': 'm',
            'contentHtml': 'h',
          },
        ],
      },
    ));
    expect((q.providerContext!['executable'] as ProviderJSONBool).value, true);
    expect(q.paymentDisclosures.single.code, 'c');
  });

  test('paymentDisclosures is empty without providerContext', () {
    final q = QuoteResponse.fromDto(QuoteDto(
      quoteId: 'q',
      ramp: 'r',
      rate: 1,
      networkFee: 0,
      transactionFee: 0,
      payout: 1,
      paymentMethod: 'p',
    ));
    expect(q.providerContext, isNull);
    expect(q.paymentDisclosures, isEmpty);
  });
}
