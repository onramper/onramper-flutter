import 'package:flutter/foundation.dart';
import 'package:onramper_flutter/onramper_flutter.dart';

import '../config/catalog.dart';

final _amountPattern = RegExp(r'^\d+(\.\d+)?$');

/// Parses typed amount text (`,` or `.` decimal). Null unless a number > 0.
double? parseAmount(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  if (!_amountPattern.hasMatch(normalized)) return null;
  final value = double.parse(normalized);
  return value > 0 ? value : null;
}

/// Everything the buy form edits. Mirrors RN `BuyForm`; text fields hold what
/// the user typed. Value equality lets the quote controller compare inputs.
@immutable
class BuyForm {
  const BuyForm({
    this.crypto = DemoCrypto.sol,
    String? wallet,
    this.amount = '100',
    this.fiat = DemoFiat.usd,
    this.paymentMethod = DemoPaymentMethod.applepay,
    this.onramp,
    this.countryOverride = false,
    this.country = DemoCountry.us,
    this.usState = 'CA',
  }) : _wallet = wallet;

  final DemoCrypto crypto;
  final String? _wallet;

  /// Wallet address as typed; defaults to the crypto's demo wallet.
  String get wallet => _wallet ?? crypto.defaultWallet;
  final String amount;
  final DemoFiat fiat;
  final DemoPaymentMethod paymentMethod;

  /// Onramp id for `onlyOnramps`, or `null` for any onramp.
  final String? onramp;

  /// When false, no country/subdivision is sent and the backend infers them.
  final bool countryOverride;
  final DemoCountry country;

  /// Only sent when [countryOverride] is on and [country] is US.
  final String usState;

  BuyForm copyWith({
    String? wallet,
    String? amount,
    DemoFiat? fiat,
    DemoPaymentMethod? paymentMethod,
    String? Function()? onramp,
    bool? countryOverride,
    String? usState,
  }) =>
      BuyForm(
        crypto: crypto,
        wallet: wallet ?? _wallet,
        amount: amount ?? this.amount,
        fiat: fiat ?? this.fiat,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        onramp: onramp != null ? onramp() : this.onramp,
        countryOverride: countryOverride ?? this.countryOverride,
        country: country,
        usState: usState ?? this.usState,
      );

  /// Selects [newCrypto] and switches to its demo wallet.
  BuyForm withCrypto(DemoCrypto newCrypto) => BuyForm(
        crypto: newCrypto,
        amount: amount,
        fiat: fiat,
        paymentMethod: paymentMethod,
        onramp: onramp,
        countryOverride: countryOverride,
        country: country,
        usState: usState,
      );

  /// Selects [newCountry] and switches to its default fiat.
  BuyForm withCountry(DemoCountry newCountry) => BuyForm(
        crypto: crypto,
        wallet: _wallet,
        amount: amount,
        fiat: newCountry.defaultFiat,
        paymentMethod: paymentMethod,
        onramp: onramp,
        countryOverride: countryOverride,
        country: newCountry,
        usState: usState,
      );

  /// The SDK request, or `null` while the amount or wallet is invalid.
  CheckoutIntentRequest? toRequest() {
    final value = parseAmount(amount);
    final address = wallet.trim();
    if (value == null || address.isEmpty) return null;
    return CheckoutIntentRequest(
      transactionData: OnramperTransactionData(
        source: fiat.name,
        destination: crypto.name,
        amount: value,
        type: TransactionType.buy,
        paymentMethod: paymentMethod.name,
        country: countryOverride ? country.name : null,
        subdivision: countryOverride && country == DemoCountry.us
            ? 'us-${usState.toLowerCase()}'
            : null,
        wallet: WalletInfo(network: crypto.network, address: address),
      ),
      onlyOnramps: onramp == null ? null : [onramp!],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BuyForm &&
      other.crypto == crypto &&
      other.wallet == wallet &&
      other.amount == amount &&
      other.fiat == fiat &&
      other.paymentMethod == paymentMethod &&
      other.onramp == onramp &&
      other.countryOverride == countryOverride &&
      other.country == country &&
      other.usState == usState;

  @override
  int get hashCode => Object.hash(crypto, wallet, amount, fiat, paymentMethod,
      onramp, countryOverride, country, usState);
}
