import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/painting.dart';
import 'package:onramper_flutter_example/checkout/request.dart';
import 'package:onramper_flutter_example/config/catalog.dart';

void main() {
  test('default form sends no country, subdivision or onramp filter', () {
    final data = const BuyForm().toRequest()!.transactionData;
    expect(data.country, isNull);
    expect(data.subdivision, isNull);
    expect(const BuyForm().toRequest()!.onlyOnramps, isNull);
    expect(data.source, 'usd');
    expect(data.destination, 'sol');
    expect(data.paymentMethod, 'applepay');
  });

  test('US override sends country and us-<state> subdivision', () {
    const form = BuyForm(countryOverride: true, usState: 'NY');
    final data = form.toRequest()!.transactionData;
    expect(data.country, 'us');
    expect(data.subdivision, 'us-ny');
  });

  test('non-US override sends country without subdivision', () {
    final form = const BuyForm()
        .withCountry(DemoCountry.es)
        .copyWith(countryOverride: true);
    final data = form.toRequest()!.transactionData;
    expect(data.country, 'es');
    expect(data.subdivision, isNull);
  });

  test('selecting a country sets its default fiat; fiat can be changed after',
      () {
    final es = const BuyForm().withCountry(DemoCountry.es);
    expect(es.fiat, DemoFiat.eur);
    expect(es.copyWith(fiat: DemoFiat.usd).toRequest()!.transactionData.source,
        'usd');
    expect(es.withCountry(DemoCountry.us).fiat, DemoFiat.usd);
  });

  test('onramp filter sends onlyOnramps with the selected id', () {
    const form = BuyForm(onramp: 'moonpay');
    expect(form.toRequest()!.onlyOnramps, ['moonpay']);
  });

  test('US state list has 50 states plus DC', () {
    expect(usStates.length, 51);
    expect(usStates.any((s) => s.code == 'DC'), isTrue);
  });

  test('each crypto maps to its network and predefined wallet', () {
    for (final c in DemoCrypto.values) {
      final data = const BuyForm().withCrypto(c).toRequest()!.transactionData;
      expect(data.destination, c.name);
      expect(data.wallet.network, c.network);
      expect(data.wallet.address, c.defaultWallet);
    }
    expect(DemoCrypto.btc.network, 'bitcoin');
    expect(DemoCrypto.eth.network, 'ethereum');
    expect(DemoCrypto.sol.network, 'solana');
  });

  test('switching crypto replaces an edited wallet with its default', () {
    final form = const BuyForm()
        .copyWith(wallet: 'my-sol-wallet')
        .withCrypto(DemoCrypto.eth);
    expect(form.wallet, DemoCrypto.eth.defaultWallet);
  });

  test('amount accepts comma or dot decimals; trims wallet', () {
    final data = const BuyForm()
        .copyWith(amount: ' 12,5 ', wallet: '  addr  ')
        .toRequest()!
        .transactionData;
    expect(data.amount, 12.5);
    expect(data.wallet.address, 'addr');
  });

  test('invalid amount or empty wallet gives no request', () {
    for (final amount in ['', '0', '-1', 'abc', '1.2.3']) {
      expect(const BuyForm().copyWith(amount: amount).toRequest(), isNull,
          reason: amount);
    }
    expect(const BuyForm().copyWith(wallet: '   ').toRequest(), isNull);
  });

  test('GBP and Revolut Pay map to the request', () {
    final data = const BuyForm()
        .copyWith(fiat: DemoFiat.gbp, paymentMethod: DemoPaymentMethod.revolutpay)
        .toRequest()!
        .transactionData;
    expect(data.source, 'gbp');
    expect(data.paymentMethod, 'revolutpay');
  });

  test('BuyForm has value equality', () {
    expect(const BuyForm(), const BuyForm());
    expect(const BuyForm().copyWith(amount: '5'), const BuyForm(amount: '5'));
    expect(const BuyForm() == const BuyForm(amount: '5'), isFalse);
    expect(const BuyForm().hashCode, const BuyForm().hashCode);
  });

  test('catalog matches RN', () {
    expect(DemoFiat.values.map((f) => f.label), ['USD', 'EUR', 'GBP']);
    expect(DemoPaymentMethod.values.map((m) => m.label),
        ['Apple Pay', 'Revolut Pay']);
    expect(DemoCountry.values.map((c) => c.flag), ['🇺🇸', '🇪🇸', '🇳🇱', '🇬🇷']);
    expect(DemoCrypto.btc.displayName, 'Bitcoin');
    expect(DemoCrypto.sol.color, const Color(0xFF32ADE6));
  });
}
