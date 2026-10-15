import '../platform/pigeon.g.dart';
import 'errors.dart';
import 'requirements.dart';
import 'state.dart';

/// Discriminator for events streamed to consumers of [OnramperClient.events].
///
/// The first 9 kinds are the "canonical" SDK events. The last 6
/// (`checkoutCancelled` … `providerError`) are provider-lifecycle events
/// forwarded from the third-party checkout webview — not every provider emits
/// every kind.
enum CheckoutEventKind {
  stateChanged,
  checkoutStarted,
  loginRequired,
  readyToCheckout,
  requirementSatisfied,
  checkoutFinalized,
  renderingStarted,
  completed,
  failed,
  checkoutCancelled,
  providerReady,
  paymentAuthorized,
  paymentProcessing,
  paymentCancelled,
  providerError,
}

/// Full finalize response emitted with a [CheckoutEventKind.checkoutFinalized]
/// event. Consumers usually only need [renderContext] on the same event — this
/// carries the full payload for cases where partner-side metadata matters.
class CheckoutFinalizeResponse {
  const CheckoutFinalizeResponse({
    required this.headlessCheckoutId,
    required this.onramperTransactionId,
    required this.headlessCheckoutData,
  });

  factory CheckoutFinalizeResponse.fromDto(CheckoutFinalizeResponseDto dto) =>
      CheckoutFinalizeResponse(
        headlessCheckoutId: dto.headlessCheckoutId,
        onramperTransactionId: dto.onramperTransactionId,
        headlessCheckoutData:
            HeadlessCheckoutData.fromDto(dto.headlessCheckoutData),
      );

  final String headlessCheckoutId;

  /// Onramper's durable transaction id. Same value as
  /// [OnramperClient.currentTransactionId] for this checkout.
  final String onramperTransactionId;
  final HeadlessCheckoutData headlessCheckoutData;
}

/// Payment-render information carried inside [CheckoutFinalizeResponse].
class HeadlessCheckoutData {
  const HeadlessCheckoutData({
    required this.url,
    required this.renderType,
    required this.checkoutPaymentType,
  });

  factory HeadlessCheckoutData.fromDto(HeadlessCheckoutDataDto dto) =>
      HeadlessCheckoutData(
        url: dto.url,
        renderType: _renderTypeFromDto(dto.renderType),
        checkoutPaymentType: _paymentTypeFromDto(dto.checkoutPaymentType),
      );

  final String url;
  final RenderType renderType;
  final CheckoutPaymentType checkoutPaymentType;
}

RenderType _renderTypeFromDto(RenderTypeDto dto) => switch (dto) {
      RenderTypeDto.webview => RenderType.webview,
      RenderTypeDto.deeplink => RenderType.deeplink,
    };

CheckoutPaymentType _paymentTypeFromDto(CheckoutPaymentTypeDto dto) =>
    switch (dto) {
      CheckoutPaymentTypeDto.applePay => CheckoutPaymentType.applePay,
      CheckoutPaymentTypeDto.revolutPay => CheckoutPaymentType.revolutPay,
    };

/// Domain event observed from the native SDK.
///
/// Inspect [kind] to decide which payload field is meaningful — other
/// fields will be null.
class CheckoutEvent {
  const CheckoutEvent({
    required this.kind,
    this.state,
    this.checkoutId,
    this.loginRequirements,
    this.requirementType,
    this.renderContext,
    this.finalizeResponse,
    this.providerReason,
    this.error,
  });

  factory CheckoutEvent.fromDto(CheckoutEventDto dto) => CheckoutEvent(
        kind: _kindFromDto(dto.kind),
        state: dto.state == null ? null : OnramperState.fromDto(dto.state!),
        checkoutId: dto.checkoutId,
        loginRequirements: dto.loginRequirements == null
            ? null
            : List<CheckoutRequirement>.unmodifiable(
                dto.loginRequirements!.map(CheckoutRequirement.fromDto),
              ),
        requirementType: dto.requirementType == null
            ? null
            : _reqTypeFromDto(dto.requirementType!),
        renderContext: dto.renderContext == null
            ? null
            : RenderContext.fromDto(dto.renderContext!),
        finalizeResponse: dto.finalizeResponse == null
            ? null
            : CheckoutFinalizeResponse.fromDto(dto.finalizeResponse!),
        providerReason: dto.providerReason,
        error: dto.error == null ? null : OnramperError.fromDto(dto.error!),
      );

  final CheckoutEventKind kind;
  final OnramperState? state;
  final String? checkoutId;
  final List<CheckoutRequirement>? loginRequirements;
  final CheckoutRequirementKind? requirementType;
  final RenderContext? renderContext;

  /// Populated on [CheckoutEventKind.checkoutFinalized]. Full finalize
  /// response including provider-side metadata.
  final CheckoutFinalizeResponse? finalizeResponse;

  /// Populated on [CheckoutEventKind.providerError]. Short human-readable
  /// reason string forwarded from the underlying provider.
  final String? providerReason;
  final OnramperError? error;

  static CheckoutEventKind _kindFromDto(CheckoutEventKindDto dto) =>
      switch (dto) {
        CheckoutEventKindDto.stateChanged => CheckoutEventKind.stateChanged,
        CheckoutEventKindDto.checkoutStarted =>
          CheckoutEventKind.checkoutStarted,
        CheckoutEventKindDto.loginRequired => CheckoutEventKind.loginRequired,
        CheckoutEventKindDto.readyToCheckout =>
          CheckoutEventKind.readyToCheckout,
        CheckoutEventKindDto.requirementSatisfied =>
          CheckoutEventKind.requirementSatisfied,
        CheckoutEventKindDto.checkoutFinalized =>
          CheckoutEventKind.checkoutFinalized,
        CheckoutEventKindDto.renderingStarted =>
          CheckoutEventKind.renderingStarted,
        CheckoutEventKindDto.completed => CheckoutEventKind.completed,
        CheckoutEventKindDto.failed => CheckoutEventKind.failed,
        CheckoutEventKindDto.checkoutCancelled =>
          CheckoutEventKind.checkoutCancelled,
        CheckoutEventKindDto.providerReady => CheckoutEventKind.providerReady,
        CheckoutEventKindDto.paymentAuthorized =>
          CheckoutEventKind.paymentAuthorized,
        CheckoutEventKindDto.paymentProcessing =>
          CheckoutEventKind.paymentProcessing,
        CheckoutEventKindDto.paymentCancelled =>
          CheckoutEventKind.paymentCancelled,
        CheckoutEventKindDto.providerError => CheckoutEventKind.providerError,
      };

  static CheckoutRequirementKind _reqTypeFromDto(
    CheckoutRequirementTypeDto dto,
  ) =>
      switch (dto) {
        CheckoutRequirementTypeDto.tos => CheckoutRequirementKind.tos,
        CheckoutRequirementTypeDto.amountLimit =>
          CheckoutRequirementKind.amountLimit,
        CheckoutRequirementTypeDto.userInfo => CheckoutRequirementKind.userInfo,
        CheckoutRequirementTypeDto.reverification =>
          CheckoutRequirementKind.reverification,
      };
}
