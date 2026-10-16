import 'package:flutter/material.dart';
import 'package:onramper_flutter/onramper_flutter.dart';

import '../theme/demo_theme.dart';
import '../utils/format.dart';
import 'demo_card.dart';

class QuoteCard extends StatelessWidget {
  const QuoteCard({
    super.key,
    required this.quote,
    required this.amount,
    required this.fiat,
    required this.cryptoSymbol,
  });

  final QuoteResponse quote;
  final double amount;
  final String fiat;
  final String cryptoSymbol;

  @override
  Widget build(BuildContext context) {
    final p = DemoTheme.of(context);
    final f = fiat.toUpperCase();
    final rows = <(String, String)>[
      ('You pay', '${formatAmount(amount)} $f'),
      ('You receive', '${formatAmount(quote.payout)} $cryptoSymbol'),
      ('Rate', '1 $cryptoSymbol ≈ ${formatAmount(quote.rate)} $f'),
      ('Network fee', '${formatAmount(quote.networkFee)} $f'),
      ('Transaction fee', '${formatAmount(quote.transactionFee)} $f'),
      if (quote.ramp.isNotEmpty) ('Provider', quote.ramp.toUpperCase()),
    ];
    return DemoCard(title: 'Quote', gap: 8, children: [
      for (final (label, value) in rows)
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: p.textSecondary, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: p.text, fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
    ]);
  }
}
