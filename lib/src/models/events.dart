import '../platform/pigeon.g.dart';
import 'errors.dart';
import 'requirements.dart';
import 'state.dart';

/// Discriminator for events streamed to consumers of [OnramperClient.events].
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
}

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
        error: dto.error == null ? null : OnramperError.fromDto(dto.error!),
      );

  final CheckoutEventKind kind;
  final OnramperState? state;
  final String? checkoutId;
  final List<CheckoutRequirement>? loginRequirements;
  final CheckoutRequirementKind? requirementType;
  final RenderContext? renderContext;
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
      };

  static CheckoutRequirementKind _reqTypeFromDto(
    CheckoutRequirementTypeDto dto,
  ) =>
      switch (dto) {
        CheckoutRequirementTypeDto.tos => CheckoutRequirementKind.tos,
        CheckoutRequirementTypeDto.amountLimit =>
          CheckoutRequirementKind.amountLimit,
        CheckoutRequirementTypeDto.userInfo => CheckoutRequirementKind.userInfo,
      };
}
