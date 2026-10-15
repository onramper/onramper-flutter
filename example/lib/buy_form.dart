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

/// Everything the demo's buy form edits. Mirrors the RN demo's `BuyForm`.
class BuyForm {
  const BuyForm({
    this.fiat = DemoFiat.usd,
    this.onramp,
    this.countryOverride = false,
    this.country = DemoCountry.us,
    this.usState = 'CA',
  });

  static const _crypto = 'sol';
  static const _network = 'solana';
  static const _amount = 100.0;
  static const _paymentMethod = 'applepay';

  final DemoFiat fiat;

  /// Onramp id for `onlyOnramps`, or `null` for any onramp.
  final String? onramp;

  /// When false, no country/subdivision is sent and the backend infers them.
  final bool countryOverride;
  final DemoCountry country;

  /// Only sent when [countryOverride] is on and [country] is US.
  final String usState;

  BuyForm copyWith({
    DemoFiat? fiat,
    String? Function()? onramp,
    bool? countryOverride,
    String? usState,
  }) =>
      BuyForm(
        fiat: fiat ?? this.fiat,
        onramp: onramp != null ? onramp() : this.onramp,
        countryOverride: countryOverride ?? this.countryOverride,
        country: country,
        usState: usState ?? this.usState,
      );

  /// Selects [newCountry] and switches to its default fiat.
  BuyForm withCountry(DemoCountry newCountry) => BuyForm(
        fiat: newCountry.defaultFiat,
        onramp: onramp,
        countryOverride: countryOverride,
        country: newCountry,
        usState: usState,
      );

  static const defaultWallet = 'Br2jjHYskB1JJikv3Qw2QcmWVQGfZvkJFng4ZEwiGSjv';

  CheckoutIntentRequest toRequest({String walletAddress = defaultWallet}) {
    final override = countryOverride;
    return CheckoutIntentRequest(
      transactionData: OnramperTransactionData(
        source: fiat.name,
        destination: _crypto,
        amount: _amount,
        type: TransactionType.buy,
        paymentMethod: _paymentMethod,
        country: override ? country.name : null,
        subdivision: override && country == DemoCountry.us
            ? 'us-${usState.toLowerCase()}'
            : null,
        wallet: WalletInfo(network: _network, address: walletAddress),
      ),
      onlyOnramps: onramp == null ? null : [onramp!],
    );
  }
}
