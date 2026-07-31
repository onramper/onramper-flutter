import '../platform/pigeon.g.dart';

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
      );

  final String quoteId;
  final String ramp;
  final double rate;
  final double networkFee;
  final double transactionFee;
  final double payout;
  final String paymentMethod;
  final List<String>? recommendations;
}
