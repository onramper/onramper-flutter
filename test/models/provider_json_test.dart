import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/onramper_flutter.dart';

void main() {
  test('fromObject decodes nested JSON', () {
    final v = ProviderJSONValue.fromObject({
      'a': 'x',
      'b': 2,
      'c': true,
      'd': null,
      'e': [1.5, 'y'],
      'f': {'g': false},
    });
    final obj = (v as ProviderJSONObject).value;
    expect((obj['a'] as ProviderJSONString).value, 'x');
    expect((obj['b'] as ProviderJSONNumber).value, 2.0);
    expect((obj['c'] as ProviderJSONBool).value, isTrue);
    expect(obj['d'], isA<ProviderJSONNull>());
    final arr = (obj['e'] as ProviderJSONArray).value;
    expect((arr[0] as ProviderJSONNumber).value, 1.5);
    expect(arr[1].stringValue, 'y');
    final inner = (obj['f'] as ProviderJSONObject).value;
    expect((inner['g'] as ProviderJSONBool).value, isFalse);
  });

  test('PaymentDisclosure.tryParse reads a complete object, rejects partial',
      () {
    final ok = PaymentDisclosure.tryParse(ProviderJSONValue.fromObject({
      'code': 'moonpay_terms',
      'version': '1',
      'contentMarkdown': '**md**',
      'contentHtml': '<b>md</b>',
    }));
    expect(ok?.code, 'moonpay_terms');
    expect(ok?.contentHtml, '<b>md</b>');
    expect(
      PaymentDisclosure.tryParse(ProviderJSONValue.fromObject({'code': 'x'})),
      isNull,
    );
  });
}
