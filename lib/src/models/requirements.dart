import 'package:flutter/widgets.dart';

import '../platform/pigeon.g.dart';
import '../widget/native_checkout_button.dart';
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
class OnramperTransactionData {
  const OnramperTransactionData({
    required this.source,
    required this.amount,
    required this.type,
    required this.paymentMethod,
    required this.wallet,
    this.destination,
    this.country,
    this.subdivision,
  });

  final String source;
  final double amount;
  final TransactionType type;
  final String paymentMethod;
  final WalletInfo wallet;
  final String? destination;
  final String? country;
  final String? subdivision;

  OnramperTransactionDataDto toDto() => OnramperTransactionDataDto(
        source: source,
        amount: amount,
        type: switch (type) {
          TransactionType.buy => TransactionTypeDto.buy,
          TransactionType.sell => TransactionTypeDto.sell,
        },
        paymentMethod: paymentMethod,
        wallet: wallet.toDto(),
        destination: destination,
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

/// Discriminator for the three [CheckoutRequirement] variants.
enum CheckoutRequirementKind { tos, amountLimit, userInfo }

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
class AmountLimitRequirement {
  const AmountLimitRequirement({
    required this.providerId,
    this.minAmountLimit,
    this.maxAmountLimit,
  });

  factory AmountLimitRequirement.fromDto(AmountLimitRequirementDto dto) =>
      AmountLimitRequirement(
        providerId: dto.providerId,
        minAmountLimit: dto.minAmountLimit,
        maxAmountLimit: dto.maxAmountLimit,
      );

  final String providerId;
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

/// Tagged union of the three requirement variants the BFF can return.
///
/// Inspect [kind] then read the matching payload ([tos], [amountLimit],
/// [userInfo]). Exactly one payload is non-null per instance.
class CheckoutRequirement {
  const CheckoutRequirement({
    required this.kind,
    this.tos,
    this.amountLimit,
    this.userInfo,
  });

  factory CheckoutRequirement.fromDto(CheckoutRequirementDto dto) {
    return CheckoutRequirement(
      kind: switch (dto.type) {
        CheckoutRequirementTypeDto.tos => CheckoutRequirementKind.tos,
        CheckoutRequirementTypeDto.amountLimit =>
          CheckoutRequirementKind.amountLimit,
        CheckoutRequirementTypeDto.userInfo => CheckoutRequirementKind.userInfo,
      },
      tos: dto.tos == null ? null : TosRequirement.fromDto(dto.tos!),
      amountLimit: dto.amountLimit == null
          ? null
          : AmountLimitRequirement.fromDto(dto.amountLimit!),
      userInfo:
          dto.userInfo == null ? null : UserInfoRequirement.fromDto(dto.userInfo!),
    );
  }

  final CheckoutRequirementKind kind;
  final TosRequirement? tos;
  final AmountLimitRequirement? amountLimit;
  final UserInfoRequirement? userInfo;
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

  /// The native `OnramperCheckoutButton` embedded directly in the Flutter widget
  /// tree via a platform view. Drop this into your layout — no `presentCheckout()`
  /// call needed. The button handles the full flow: OIDC login, finalize, payment.
  Widget get button => OnramperNativeCheckoutButton(buttonHandle: buttonHandle);

  /// Convenience: only the ToS requirements (if any).
  List<TosRequirement> get tos => requirements
      .where((r) => r.kind == CheckoutRequirementKind.tos && r.tos != null)
      .map((r) => r.tos!)
      .toList(growable: false);
}
