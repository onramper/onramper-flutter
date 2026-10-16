import 'dart:ui' show Color;

/// Fiat currencies the demo can pay with (RN `FIATS`).
enum DemoFiat {
  usd('USD'),
  eur('EUR'),
  gbp('GBP');

  const DemoFiat(this.label);
  final String label;
}

/// Countries the demo can override to; each has a default fiat.
enum DemoCountry {
  us('US', DemoFiat.usd, '🇺🇸'),
  es('ES', DemoFiat.eur, '🇪🇸'),
  nl('NL', DemoFiat.eur, '🇳🇱'),
  gr('GR', DemoFiat.eur, '🇬🇷');

  const DemoCountry(this.label, this.defaultFiat, this.flag);
  final String label;
  final DemoFiat defaultFiat;
  final String flag;
}

/// Payment methods (RN `PAYMENT_METHODS`); the enum name is the SDK id.
enum DemoPaymentMethod {
  applepay('Apple Pay'),
  revolutpay('Revolut Pay');

  const DemoPaymentMethod(this.label);
  final String label;
}

/// Cryptos the demo can buy, with predefined demo wallets (same as RN).
enum DemoCrypto {
  btc('BTC', 'Bitcoin', 'bitcoin', Color(0xFFF7931A),
      'bc1qj5lez36llxlmflw9rh4yqakkap297fz8h6l2kp'),
  eth('ETH', 'Ethereum', 'ethereum', Color(0xFF8E5CF7),
      '0x97EF62c275A9A4C2E6199Bd7a4feB6efd207fC86'),
  sol('SOL', 'Solana', 'solana', Color(0xFF32ADE6),
      'Br2jjHYskB1JJikv3Qw2QcmWVQGfZvkJFng4ZEwiGSjv');

  const DemoCrypto(this.symbol, this.displayName, this.network, this.color,
      this.defaultWallet);
  final String symbol;
  final String displayName;
  final String network;
  final Color color;
  final String defaultWallet;
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
