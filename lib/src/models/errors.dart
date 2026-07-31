import '../platform/pigeon.g.dart';

/// Categorical taxonomy of errors emitted by the native SDK.
///
/// Mirrors `OnramperErrorKindDto` 1:1.
enum OnramperErrorKind {
  notInitialized,
  initializationFailed,
  attestationFailed,
  invalidStateTransition,
  invalidState,
  networkError,
  decodingError,
  timeout,
  requirementNotSatisfied,
  amountOutOfRange,
  oidcFlowCancelled,
  oidcTokenExchangeFailed,
  oidcFlowFailed,
  userTokenInvalid,
  userTokenRefreshFailed,
  webviewLoadFailed,
  deepLinkFailed,
  invalidRequest,
  quoteUnavailable,
  checkoutForbidden,
  temporaryFailure,
  unrecoverable,
  configurationError,
  deviceBlocked,
  securityStorageFailed,
  securityTrustFailed,
}

/// Public, throwable error type exposed by the SDK.
///
/// Use [OnramperError.fromDto] to convert a Pigeon DTO into this idiomatic
/// Dart representation. Implements [Exception] so it can be thrown across
/// `async` boundaries and caught with `on OnramperError`.
class OnramperError implements Exception {
  const OnramperError({
    required this.kind,
    required this.message,
    required this.recoverable,
    this.code,
    this.minAmount,
    this.maxAmount,
    this.retryAfterSeconds,
    this.field,
    this.debugInfo,
    this.fromState,
    this.toState,
    this.expectedState,
    this.actualState,
    this.host,
  });

  factory OnramperError.fromDto(OnramperErrorDto dto) => OnramperError(
        kind: _kindFromDto(dto.kind),
        message: dto.message,
        recoverable: dto.recoverable,
        code: dto.code,
        minAmount: dto.minAmount,
        maxAmount: dto.maxAmount,
        retryAfterSeconds: dto.retryAfterSeconds,
        field: dto.field,
        debugInfo: dto.debugInfo,
        fromState: dto.fromState,
        toState: dto.toState,
        expectedState: dto.expectedState,
        actualState: dto.actualState,
        host: dto.host,
      );

  final OnramperErrorKind kind;
  final String message;
  final bool recoverable;
  final int? code;
  final double? minAmount;
  final double? maxAmount;
  final double? retryAfterSeconds;
  final String? field;
  final String? debugInfo;
  final String? fromState;
  final String? toState;
  final String? expectedState;
  final String? actualState;

  /// Populated for [OnramperErrorKind.securityTrustFailed]. The host whose
  /// certificate pinning check failed.
  final String? host;

  @override
  String toString() => 'OnramperError(${kind.name}): $message';

  static OnramperErrorKind _kindFromDto(OnramperErrorKindDto dto) {
    return switch (dto) {
      OnramperErrorKindDto.notInitialized => OnramperErrorKind.notInitialized,
      OnramperErrorKindDto.initializationFailed =>
        OnramperErrorKind.initializationFailed,
      OnramperErrorKindDto.attestationFailed =>
        OnramperErrorKind.attestationFailed,
      OnramperErrorKindDto.invalidStateTransition =>
        OnramperErrorKind.invalidStateTransition,
      OnramperErrorKindDto.invalidState => OnramperErrorKind.invalidState,
      OnramperErrorKindDto.networkError => OnramperErrorKind.networkError,
      OnramperErrorKindDto.decodingError => OnramperErrorKind.decodingError,
      OnramperErrorKindDto.timeout => OnramperErrorKind.timeout,
      OnramperErrorKindDto.requirementNotSatisfied =>
        OnramperErrorKind.requirementNotSatisfied,
      OnramperErrorKindDto.amountOutOfRange =>
        OnramperErrorKind.amountOutOfRange,
      OnramperErrorKindDto.oidcFlowCancelled =>
        OnramperErrorKind.oidcFlowCancelled,
      OnramperErrorKindDto.oidcTokenExchangeFailed =>
        OnramperErrorKind.oidcTokenExchangeFailed,
      OnramperErrorKindDto.oidcFlowFailed => OnramperErrorKind.oidcFlowFailed,
      OnramperErrorKindDto.userTokenInvalid =>
        OnramperErrorKind.userTokenInvalid,
      OnramperErrorKindDto.userTokenRefreshFailed =>
        OnramperErrorKind.userTokenRefreshFailed,
      OnramperErrorKindDto.webviewLoadFailed =>
        OnramperErrorKind.webviewLoadFailed,
      OnramperErrorKindDto.deepLinkFailed => OnramperErrorKind.deepLinkFailed,
      OnramperErrorKindDto.invalidRequest => OnramperErrorKind.invalidRequest,
      OnramperErrorKindDto.quoteUnavailable =>
        OnramperErrorKind.quoteUnavailable,
      OnramperErrorKindDto.checkoutForbidden =>
        OnramperErrorKind.checkoutForbidden,
      OnramperErrorKindDto.temporaryFailure =>
        OnramperErrorKind.temporaryFailure,
      OnramperErrorKindDto.unrecoverable => OnramperErrorKind.unrecoverable,
      OnramperErrorKindDto.configurationError =>
        OnramperErrorKind.configurationError,
      OnramperErrorKindDto.deviceBlocked => OnramperErrorKind.deviceBlocked,
      OnramperErrorKindDto.securityStorageFailed =>
        OnramperErrorKind.securityStorageFailed,
      OnramperErrorKindDto.securityTrustFailed =>
        OnramperErrorKind.securityTrustFailed,
    };
  }
}
