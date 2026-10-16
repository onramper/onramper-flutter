import '../platform/pigeon.g.dart';
import 'provider_json.dart';

/// Quote returned by the BFF for a given checkout intent.
///
/// v1.1.0 of the native SDK made every field non-optional at the type level —
/// when the BFF cannot produce a quote the SDK surfaces `quoteUnavailable`
/// (see `OnramperErrorKind.quoteUnavailable`) rather than returning a
/// partially-populated `QuoteResponse`. If you receive a `QuoteResponse`,
/// all the pricing fields are trustworthy.
class QuoteResponse {
  const QuoteResponse({
    required this.quoteId,
    required this.ramp,
    required this.rate,
    required this.networkFee,
    required this.transactionFee,
    required this.payout,
    required this.paymentMethod,
    this.recommendations,
    this.providerContext,
  });

  factory QuoteResponse.fromDto(QuoteDto dto) => QuoteResponse(
        quoteId: dto.quoteId,
        ramp: dto.ramp,
        rate: dto.rate,
        networkFee: dto.networkFee,
        transactionFee: dto.transactionFee,
        payout: dto.payout,
        paymentMethod: dto.paymentMethod,
        recommendations: dto.recommendations == null
            ? null
            : List<String>.unmodifiable(dto.recommendations!),
        providerContext: dto.providerContext == null
            ? null
            : Map.unmodifiable(dto.providerContext!.map(
                (k, v) => MapEntry(k, ProviderJSONValue.fromObject(v)),
              )),
      );

  final String quoteId;
  final String ramp;
  final double rate;
  final double networkFee;
  final double transactionFee;
  final double payout;
  final String paymentMethod;
  final List<String>? recommendations;

  /// Provider-specific data (e.g. executable flags, limits, disclosures).
  /// Most integrations can ignore it. May contain tokens; don't log it.
  final Map<String, ProviderJSONValue>? providerContext;

  /// Disclosures listed under `providerContext['paymentDisclosures']`.
  List<PaymentDisclosure> get paymentDisclosures {
    final raw = providerContext?['paymentDisclosures'];
    if (raw is! ProviderJSONArray) return const [];
    return raw.value
        .map(PaymentDisclosure.tryParse)
        .whereType<PaymentDisclosure>()
        .toList(growable: false);
  }
}
