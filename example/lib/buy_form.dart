import 'package:onramper_flutter/onramper_flutter.dart';

/// Fiat currencies the demo can pay with.
enum DemoFiat {
  usd('USD'),
  eur('EUR');

  const DemoFiat(this.label);
  final String label;
}

/// Countries the demo can override to; each has a default fiat.
enum DemoCountry {
  us('US', DemoFiat.usd),
  es('ES', DemoFiat.eur),
  nl('NL', DemoFiat.eur),
  gr('GR', DemoFiat.eur);

  const DemoCountry(this.label, this.defaultFiat);
  final String label;
  final DemoFiat defaultFiat;
}

/// Onramp filter options. `null` means any onramp (no `onlyOnramps`).
const onrampOptions = <(String?, String)>[
  (null, 'Any'),
  ('moonpay', 'MoonPay'),
  ('paybis', 'Paybis'),
  ('coinbasepay', 'Coinbase Pay'),
];

/// `code` is the ISO 3166-2:US suffix; sent as `us-<code lower>`.
class UsState {
  const UsState(this.code, this.name);
  final String code;
  final String name;
}

/// 50 states + DC, sorted by name (same list as the iOS and RN demos).
const usStates = <UsState>[
  UsState('AL', 'Alabama'),
  UsState('AK', 'Alaska'),
  UsState('AZ', 'Arizona'),
  UsState('AR', 'Arkansas'),
  UsState('CA', 'California'),
  UsState('CO', 'Colorado'),
  UsState('CT', 'Connecticut'),
  UsState('DE', 'Delaware'),
  UsState('DC', 'District of Columbia'),
  UsState('FL', 'Florida'),
  UsState('GA', 'Georgia'),
  UsState('HI', 'Hawaii'),
  UsState('ID', 'Idaho'),
  UsState('IL', 'Illinois'),
  UsState('IN', 'Indiana'),
  UsState('IA', 'Iowa'),
  UsState('KS', 'Kansas'),
  UsState('KY', 'Kentucky'),
  UsState('LA', 'Louisiana'),
  UsState('ME', 'Maine'),
  UsState('MD', 'Maryland'),
  UsState('MA', 'Massachusetts'),
  UsState('MI', 'Michigan'),
  UsState('MN', 'Minnesota'),
  UsState('MS', 'Mississippi'),
  UsState('MO', 'Missouri'),
  UsState('MT', 'Montana'),
  UsState('NE', 'Nebraska'),
  UsState('NV', 'Nevada'),
  UsState('NH', 'New Hampshire'),
  UsState('NJ', 'New Jersey'),
  UsState('NM', 'New Mexico'),
  UsState('NY', 'New York'),
  UsState('NC', 'North Carolina'),
  UsState('ND', 'North Dakota'),
  UsState('OH', 'Ohio'),
  UsState('OK', 'Oklahoma'),
  UsState('OR', 'Oregon'),
  UsState('PA', 'Pennsylvania'),
  UsState('RI', 'Rhode Island'),
  UsState('SC', 'South Carolina'),
  UsState('SD', 'South Dakota'),
  UsState('TN', 'Tennessee'),
  UsState('TX', 'Texas'),
  UsState('UT', 'Utah'),
  UsState('VT', 'Vermont'),
  UsState('VA', 'Virginia'),
  UsState('WA', 'Washington'),
  UsState('WV', 'West Virginia'),
  UsState('WI', 'Wisconsin'),
  UsState('WY', 'Wyoming'),
];

/// Cryptos the demo can buy, with predefined demo wallets (same as RN).
enum DemoCrypto {
  btc('BTC', 'bitcoin', 'bc1qj5lez36llxlmflw9rh4yqakkap297fz8h6l2kp'),
  eth('ETH', 'ethereum', '0x97EF62c275A9A4C2E6199Bd7a4feB6efd207fC86'),
  sol('SOL', 'solana', 'Br2jjHYskB1JJikv3Qw2QcmWVQGfZvkJFng4ZEwiGSjv');

  const DemoCrypto(this.symbol, this.network, this.defaultWallet);
  final String symbol;
  final String network;
  final String defaultWallet;
}

final _amountPattern = RegExp(r'^\d+(\.\d+)?$');

/// Parses typed amount text (`,` or `.` decimal). Null unless a number > 0.
double? parseAmount(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  if (!_amountPattern.hasMatch(normalized)) return null;
  final value = double.parse(normalized);
  return value > 0 ? value : null;
}

/// Everything the demo's buy form edits. Mirrors the RN demo's `BuyForm`;
/// text fields hold what the user typed.
class BuyForm {
  const BuyForm({
    this.crypto = DemoCrypto.sol,
    String? wallet,
    this.amount = '100',
    this.fiat = DemoFiat.usd,
    this.onramp,
    this.countryOverride = false,
    this.country = DemoCountry.us,
    this.usState = 'CA',
  }) : _wallet = wallet;

  static const _paymentMethod = 'applepay';

  final DemoCrypto crypto;
  final String? _wallet;

  /// Wallet address as typed; defaults to the crypto's demo wallet.
  String get wallet => _wallet ?? crypto.defaultWallet;
  final String amount;
  final DemoFiat fiat;

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
    String? Function()? onramp,
    bool? countryOverride,
    String? usState,
  }) =>
      BuyForm(
        crypto: crypto,
        wallet: wallet ?? _wallet,
        amount: amount ?? this.amount,
        fiat: fiat ?? this.fiat,
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
        paymentMethod: _paymentMethod,
        country: countryOverride ? country.name : null,
        subdivision: countryOverride && country == DemoCountry.us
            ? 'us-${usState.toLowerCase()}'
            : null,
        wallet: WalletInfo(network: crypto.network, address: address),
      ),
      onlyOnramps: onramp == null ? null : [onramp!],
    );
  }
}
