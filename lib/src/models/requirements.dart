import '../platform/pigeon.g.dart';
import 'quote.dart';

// ---------------------------------------------------------------------------
// Inputs (Dart -> Pigeon)
// ---------------------------------------------------------------------------

/// Whether the user is buying crypto with fiat or selling crypto for fiat.
enum TransactionType { buy, sell }

/// Wallet payload submitted with a checkout intent.
class WalletInfo {
  const WalletInfo({
    required this.network,
    required this.address,
    this.memo,
  });

  final String network;
  final String address;
  final String? memo;

  WalletInfoDto toDto() =>
      WalletInfoDto(network: network, address: address, memo: memo);
}

/// Transaction parameters for a single checkout intent.
///
/// `destination` was made required in v1.1.0 of the native SDK — every
/// checkout must name the target asset (e.g. `"BTC"`, `"ETH"`).
class OnramperTransactionData {
  const OnramperTransactionData({
    required this.source,
    required this.destination,
    required this.amount,
    required this.type,
    required this.paymentMethod,
    required this.wallet,
    this.country,
    this.subdivision,
  });

  final String source;
  final String destination;
  final double amount;
  final TransactionType type;
  final String paymentMethod;
  final WalletInfo wallet;
  final String? country;
  final String? subdivision;

  OnramperTransactionDataDto toDto() => OnramperTransactionDataDto(
        source: source,
        destination: destination,
        amount: amount,
        type: switch (type) {
          TransactionType.buy => TransactionTypeDto.buy,
          TransactionType.sell => TransactionTypeDto.sell,
        },
        paymentMethod: paymentMethod,
        wallet: wallet.toDto(),
        country: country,
        subdivision: subdivision,
      );
}

/// Top-level request passed to [OnramperClient.getCheckoutRequirements].
class CheckoutIntentRequest {
  const CheckoutIntentRequest({
    required this.transactionData,
    this.onlyOnramps,
  });

  final OnramperTransactionData transactionData;
  final List<String>? onlyOnramps;

  CheckoutIntentRequestDto toDto() => CheckoutIntentRequestDto(
        transactionData: transactionData.toDto(),
        onlyOnramps: onlyOnramps == null
            ? null
            : List<String>.unmodifiable(onlyOnramps!),
      );
}

// ---------------------------------------------------------------------------
// Outputs (Pigeon -> Dart)
// ---------------------------------------------------------------------------

/// Discriminator for the four [CheckoutRequirement] variants.
enum CheckoutRequirementKind { tos, amountLimit, userInfo, reverification }

/// Which identity field a [ReverificationRequirement] applies to.
enum ReverificationField { email, phone }

/// Specific Terms of Service style document the user must accept.
enum TosItemType { tos, privacyPolicy, userAgreement }

/// Human-readable label for a [TosItemType]. Mirrors native
/// `ToSPresentation.displayName` in OnramperSDK so Dart rendering matches the
/// iOS SDK's wording 1:1.
extension TosItemTypeDisplayName on TosItemType {
  String get displayName {
    switch (this) {
      case TosItemType.tos:
        return 'Terms of Service';
      case TosItemType.privacyPolicy:
        return 'Privacy Policy';
      case TosItemType.userAgreement:
        return 'User Agreement';
    }
  }
}

/// Identity / KYC fields that may be required before checkout.
enum UserInfoFieldType {
  firstName,
  lastName,
  email,
  emailVerification,
  phoneNumber,
  phoneVerification,
  ssnLastFour,
  address,
}

/// Single document inside a [TosRequirement].
class TosItem {
  const TosItem({
    required this.type,
    required this.required,
    required this.satisfied,
    this.url,
    this.content,
  });

  factory TosItem.fromDto(TosItemDto dto) => TosItem(
        type: switch (dto.type) {
          TosItemTypeDto.tos => TosItemType.tos,
          TosItemTypeDto.privacyPolicy => TosItemType.privacyPolicy,
          TosItemTypeDto.userAgreement => TosItemType.userAgreement,
        },
        required: dto.required,
        satisfied: dto.satisfied,
        url: dto.url,
        content: dto.content,
      );

  final TosItemType type;
  final bool required;
  final bool satisfied;
  final String? url;
  final String? content;
}

/// Terms of Service requirement: provider + list of documents.
class TosRequirement {
  const TosRequirement({required this.providerId, required this.items});

  factory TosRequirement.fromDto(TosRequirementDto dto) => TosRequirement(
        providerId: dto.providerId,
        items: List<TosItem>.unmodifiable(dto.items.map(TosItem.fromDto)),
      );

  final String providerId;
  final List<TosItem> items;
}

/// Amount-bounds requirement for a specific provider.
///
/// `amountLimitSatisfied` is a v1.1.0+ signal: when true, the requested
/// amount already falls within the provider's min/max bounds and no
/// consumer-facing UI action is needed. When false, the consumer should
/// prompt the user to adjust the amount (or select a different provider).
class AmountLimitRequirement {
  const AmountLimitRequirement({
    required this.providerId,
    required this.amountLimitSatisfied,
    this.minAmountLimit,
    this.maxAmountLimit,
  });

  factory AmountLimitRequirement.fromDto(AmountLimitRequirementDto dto) =>
      AmountLimitRequirement(
        providerId: dto.providerId,
        amountLimitSatisfied: dto.amountLimitSatisfied,
        minAmountLimit: dto.minAmountLimit,
        maxAmountLimit: dto.maxAmountLimit,
      );

  final String providerId;
  final bool amountLimitSatisfied;
  final double? minAmountLimit;
  final double? maxAmountLimit;
}

/// One identity field needed by KYC.
class UserInfoField {
  const UserInfoField({
    required this.type,
    required this.required,
    required this.satisfied,
  });

  factory UserInfoField.fromDto(UserInfoFieldDto dto) => UserInfoField(
        type: switch (dto.type) {
          UserInfoFieldTypeDto.firstName => UserInfoFieldType.firstName,
          UserInfoFieldTypeDto.lastName => UserInfoFieldType.lastName,
          UserInfoFieldTypeDto.email => UserInfoFieldType.email,
          UserInfoFieldTypeDto.emailVerification =>
            UserInfoFieldType.emailVerification,
          UserInfoFieldTypeDto.phoneNumber => UserInfoFieldType.phoneNumber,
          UserInfoFieldTypeDto.phoneVerification =>
            UserInfoFieldType.phoneVerification,
          UserInfoFieldTypeDto.ssnLastFour => UserInfoFieldType.ssnLastFour,
          UserInfoFieldTypeDto.address => UserInfoFieldType.address,
        },
        required: dto.required,
        satisfied: dto.satisfied,
      );

  final UserInfoFieldType type;
  final bool required;
  final bool satisfied;
}

/// KYC requirement: provider + list of identity fields.
class UserInfoRequirement {
  const UserInfoRequirement({required this.providerId, required this.fields});

  factory UserInfoRequirement.fromDto(UserInfoRequirementDto dto) =>
      UserInfoRequirement(
        providerId: dto.providerId,
        fields: List<UserInfoField>.unmodifiable(
          dto.fields.map(UserInfoField.fromDto),
        ),
      );

  final String providerId;
  final List<UserInfoField> fields;
}

/// Re-verification requirement: the SDK asks the user to re-confirm a
/// previously-collected identity field (usually a phone number) because
/// enough time has elapsed relative to the provider's recency policy.
///
/// - [field] is the identity field to re-verify (`email` or `phone`).
/// - [requiredRecencyDays] is how recent the last verification must be for
///   the provider to accept it without re-verification.
/// - [lastVerifiedAt] is an ISO-8601 timestamp of the last verification, or
///   null if the user has never verified this field.
class ReverificationRequirement {
  const ReverificationRequirement({
    required this.providerId,
    required this.field,
    required this.requiredRecencyDays,
    this.lastVerifiedAt,
  });

  factory ReverificationRequirement.fromDto(ReverificationRequirementDto dto) =>
      ReverificationRequirement(
        providerId: dto.providerId,
        field: switch (dto.field) {
          ReverificationFieldDto.email => ReverificationField.email,
          ReverificationFieldDto.phone => ReverificationField.phone,
        },
        requiredRecencyDays: dto.requiredRecencyDays,
        lastVerifiedAt: dto.lastVerifiedAt,
      );

  final String providerId;
  final ReverificationField field;
  final int requiredRecencyDays;
  final String? lastVerifiedAt;
}

/// Tagged union of the four requirement variants the BFF can return.
///
/// Inspect [kind] then read the matching payload ([tos], [amountLimit],
/// [userInfo], [reverification]). Exactly one payload is non-null per instance.
class CheckoutRequirement {
  const CheckoutRequirement({
    required this.kind,
    this.tos,
    this.amountLimit,
    this.userInfo,
    this.reverification,
  });

  factory CheckoutRequirement.fromDto(CheckoutRequirementDto dto) {
    return CheckoutRequirement(
      kind: switch (dto.type) {
        CheckoutRequirementTypeDto.tos => CheckoutRequirementKind.tos,
        CheckoutRequirementTypeDto.amountLimit =>
          CheckoutRequirementKind.amountLimit,
        CheckoutRequirementTypeDto.userInfo => CheckoutRequirementKind.userInfo,
        CheckoutRequirementTypeDto.reverification =>
          CheckoutRequirementKind.reverification,
      },
      tos: dto.tos == null ? null : TosRequirement.fromDto(dto.tos!),
      amountLimit: dto.amountLimit == null
          ? null
          : AmountLimitRequirement.fromDto(dto.amountLimit!),
      userInfo: dto.userInfo == null
          ? null
          : UserInfoRequirement.fromDto(dto.userInfo!),
      reverification: dto.reverification == null
          ? null
          : ReverificationRequirement.fromDto(dto.reverification!),
    );
  }

  final CheckoutRequirementKind kind;
  final TosRequirement? tos;
  final AmountLimitRequirement? amountLimit;
  final UserInfoRequirement? userInfo;
  final ReverificationRequirement? reverification;
}

/// Aggregated response: a checkout id, requirements, quote, and the native button.
class CheckoutRequirementsResult {
  CheckoutRequirementsResult({
    required this.headlessCheckoutId,
    required this.requirements,
    required this.quote,
    required this.buttonHandle,
  });

  factory CheckoutRequirementsResult.fromDto(
    CheckoutRequirementsResultDto dto,
  ) =>
      CheckoutRequirementsResult(
        headlessCheckoutId: dto.headlessCheckoutId,
        requirements: List<CheckoutRequirement>.unmodifiable(
          dto.requirements.map(CheckoutRequirement.fromDto),
        ),
        quote: QuoteResponse.fromDto(dto.quote),
        buttonHandle: dto.buttonHandle,
      );

  final String headlessCheckoutId;
  final List<CheckoutRequirement> requirements;
  final QuoteResponse quote;

  /// Opaque handle for the native checkout button stored in the platform registry.
  final String buttonHandle;

  /// Convenience: only the ToS requirements (if any).
  List<TosRequirement> get tos => requirements
      .where((r) => r.kind == CheckoutRequirementKind.tos && r.tos != null)
      .map((r) => r.tos!)
      .toList(growable: false);
}
