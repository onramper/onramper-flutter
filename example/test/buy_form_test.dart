import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter_example/buy_form.dart';

void main() {
  test('default form sends no country, subdivision or onramp filter', () {
    final data = const BuyForm().toRequest().transactionData;
    expect(data.country, isNull);
    expect(data.subdivision, isNull);
    expect(const BuyForm().toRequest().onlyOnramps, isNull);
    expect(data.source, 'usd');
    expect(data.destination, 'sol');
    expect(data.paymentMethod, 'applepay');
  });

  test('US override sends country and us-<state> subdivision', () {
    const form = BuyForm(countryOverride: true, usState: 'NY');
    final data = form.toRequest().transactionData;
    expect(data.country, 'us');
    expect(data.subdivision, 'us-ny');
  });

  test('non-US override sends country without subdivision', () {
    final form = const BuyForm()
        .withCountry(DemoCountry.es)
        .copyWith(countryOverride: true);
    final data = form.toRequest().transactionData;
    expect(data.country, 'es');
    expect(data.subdivision, isNull);
  });

  test('selecting a country sets its default fiat; fiat can be changed after',
      () {
    final es = const BuyForm().withCountry(DemoCountry.es);
    expect(es.fiat, DemoFiat.eur);
    expect(es.copyWith(fiat: DemoFiat.usd).toRequest().transactionData.source,
        'usd');
    expect(es.withCountry(DemoCountry.us).fiat, DemoFiat.usd);
  });

  test('onramp filter sends onlyOnramps with the selected id', () {
    const form = BuyForm(onramp: 'moonpay');
    expect(form.toRequest().onlyOnramps, ['moonpay']);
  });

  test('US state list has 50 states plus DC', () {
    expect(usStates.length, 51);
    expect(usStates.any((s) => s.code == 'DC'), isTrue);
  });
}
