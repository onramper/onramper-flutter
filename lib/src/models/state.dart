import '../platform/pigeon.g.dart';
import 'errors.dart';
import 'requirements.dart';

/// Coarse-grained machine state of an [OnramperClient].
enum OnramperStateKind {
  idle,
  initializing,
  ready,
  checkoutPreparing,
  requireLogin,
  authenticating,
  readyToCheckout,
  finalizing,
  rendering,

  /// Payment accepted; settlement pending. Neither success nor failure —
  /// track with `OnramperClient.currentTransactionId`.
  paymentPending,
  completed,
  failed,
}

/// Whether the native checkout is rendered in a webview or via a deep link.
enum RenderType { webview, deeplink }

/// Specific payment surface used inside the checkout view.
enum CheckoutPaymentType { applePay, revolutPay }

/// Render payload attached to [OnramperStateKind.rendering] and the
/// `renderingStarted` / `checkoutFinalized` events.
///
/// [paymentType] is nullable because the native `renderingStarted` event
/// carries only url + renderType; it becomes non-null once the SDK reaches
/// `state.rendering` or `checkoutFinalized`, which do include the type.
class RenderContext {
  const RenderContext({
    required this.url,
    required this.renderType,
    this.paymentType,
  });

  factory RenderContext.fromDto(RenderContextDto dto) => RenderContext(
        url: dto.url,
        renderType: switch (dto.renderType) {
          RenderTypeDto.webview => RenderType.webview,
          RenderTypeDto.deeplink => RenderType.deeplink,
        },
        paymentType: dto.paymentType == null
            ? null
            : switch (dto.paymentType!) {
                CheckoutPaymentTypeDto.applePay => CheckoutPaymentType.applePay,
                CheckoutPaymentTypeDto.revolutPay =>
                  CheckoutPaymentType.revolutPay,
              },
      );

  final String url;
  final RenderType renderType;
  final CheckoutPaymentType? paymentType;
}

/// Snapshot of the SDK state with whatever payload that state carries.
///
/// At most one of [requireLoginRequirements], [renderContext], or
/// [failedError] is non-null, matching the active [kind].
class OnramperState {
  const OnramperState({
    required this.kind,
    this.requireLoginRequirements,
    this.renderContext,
    this.failedError,
  });

  factory OnramperState.fromDto(OnramperStateDto dto) => OnramperState(
        kind: _kindFromDto(dto.kind),
        requireLoginRequirements: dto.requireLoginRequirements == null
            ? null
            : List<CheckoutRequirement>.unmodifiable(
                dto.requireLoginRequirements!.map(CheckoutRequirement.fromDto),
              ),
        renderContext: dto.renderContext == null
            ? null
            : RenderContext.fromDto(dto.renderContext!),
        failedError: dto.failedError == null
            ? null
            : OnramperError.fromDto(dto.failedError!),
      );

  final OnramperStateKind kind;
  final List<CheckoutRequirement>? requireLoginRequirements;
  final RenderContext? renderContext;
  final OnramperError? failedError;

  static OnramperStateKind _kindFromDto(OnramperStateKindDto dto) =>
      switch (dto) {
        OnramperStateKindDto.idle => OnramperStateKind.idle,
        OnramperStateKindDto.initializing => OnramperStateKind.initializing,
        OnramperStateKindDto.ready => OnramperStateKind.ready,
        OnramperStateKindDto.checkoutPreparing =>
          OnramperStateKind.checkoutPreparing,
        OnramperStateKindDto.requireLogin => OnramperStateKind.requireLogin,
        OnramperStateKindDto.authenticating => OnramperStateKind.authenticating,
        OnramperStateKindDto.readyToCheckout =>
          OnramperStateKind.readyToCheckout,
        OnramperStateKindDto.finalizing => OnramperStateKind.finalizing,
        OnramperStateKindDto.rendering => OnramperStateKind.rendering,
        OnramperStateKindDto.paymentPending => OnramperStateKind.paymentPending,
        OnramperStateKindDto.completed => OnramperStateKind.completed,
        OnramperStateKindDto.failed => OnramperStateKind.failed,
      };
}
