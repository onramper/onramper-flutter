import '../platform/pigeon.g.dart';

/// Quote returned by the BFF for a given checkout intent.
///
/// Every field is optional because the BFF may omit data when an
/// upstream onramp errors out — the [errors] list explains why.
class QuoteResponse {
  const QuoteResponse({
    this.quoteId,
    this.ramp,
    this.rate,
    this.networkFee,
    this.transactionFee,
    this.payout,
    this.paymentMethod,
    this.recommendations,
    this.errors,
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
        errors: dto.errors?.map(QuoteError.fromDto).toList(growable: false),
      );

  final String? quoteId;
  final String? ramp;
  final double? rate;
  final double? networkFee;
  final double? transactionFee;
  final double? payout;
  final String? paymentMethod;
  final List<String>? recommendations;
  final List<QuoteError>? errors;
}

/// Per-onramp error embedded in a [QuoteResponse.errors] list.
class QuoteError {
  const QuoteError({this.type, this.message});

  factory QuoteError.fromDto(QuoteErrorDto dto) =>
      QuoteError(type: dto.type, message: dto.message);

  final String? type;
  final String? message;
}
