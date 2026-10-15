import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/platform/pigeon.g.dart',
  dartOptions: DartOptions(),
  swiftOut: 'ios/Classes/Pigeon.g.swift',
  swiftOptions: SwiftOptions(),
  dartPackageName: 'onramper_flutter',
))

// ---- Configuration ----

enum EnvironmentDto { development, production }

enum ThemeDto { system, light, dark }

enum LogLevelDto { off, error, warning, info, debug, trace }

class ConfigurationDto {
  ConfigurationDto({
    required this.apiKey,
    required this.clientId,
    required this.environment,
    required this.theme,
    required this.logLevel,
  });
  final String apiKey;
  final String clientId;
  final EnvironmentDto environment;
  final ThemeDto theme;
  final LogLevelDto logLevel;
}

class SessionCredentialsDto {
  SessionCredentialsDto({required this.sessionId, required this.sessionToken});
  final String sessionId;
  final String sessionToken;
}

// ---- Transaction inputs ----

enum TransactionTypeDto { buy, sell }

class WalletInfoDto {
  WalletInfoDto({required this.network, required this.address, this.memo});
  final String network;
  final String address;
  final String? memo;
}

class OnramperTransactionDataDto {
  OnramperTransactionDataDto({
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
  final TransactionTypeDto type;
  final String paymentMethod;
  final WalletInfoDto wallet;
  final String? country;
  final String? subdivision;
}

class CheckoutIntentRequestDto {
  CheckoutIntentRequestDto({required this.transactionData, this.onlyOnramps});
  final OnramperTransactionDataDto transactionData;
  final List<String>? onlyOnramps;
}

/// Values the integrator already knows about the user, used to pre-populate
/// the OnramperID sign-in and additional-info screens. All optional.
class UserPrefillDto {
  UserPrefillDto({this.email, this.firstName, this.lastName, this.phoneNumber});
  final String? email;
  final String? firstName;
  final String? lastName;

  /// E.164, e.g. `+3712345678`.
  final String? phoneNumber;
}

// ---- Quote ----

class QuoteDto {
  QuoteDto({
    required this.quoteId,
    required this.ramp,
    required this.rate,
    required this.networkFee,
    required this.transactionFee,
    required this.payout,
    required this.paymentMethod,
    this.recommendations,
  });
  final String quoteId;
  final String ramp;
  final double rate;
  final double networkFee;
  final double transactionFee;
  final double payout;
  final String paymentMethod;
  final List<String>? recommendations;
}

// ---- Checkout requirements ----

enum CheckoutRequirementTypeDto { tos, amountLimit, userInfo, reverification }

enum ReverificationFieldDto { email, phone }

enum TosItemTypeDto { tos, privacyPolicy, userAgreement }

class TosItemDto {
  TosItemDto({
    required this.type,
    required this.required,
    required this.satisfied,
    this.url,
    this.content,
  });
  final TosItemTypeDto type;
  final bool required;
  final bool satisfied;
  final String? url;
  final String? content;
}

class TosRequirementDto {
  TosRequirementDto({required this.providerId, required this.items});
  final String providerId;
  final List<TosItemDto> items;
}

class AmountLimitRequirementDto {
  AmountLimitRequirementDto({
    required this.providerId,
    required this.amountLimitSatisfied,
    this.minAmountLimit,
    this.maxAmountLimit,
  });
  final String providerId;

  /// True when the requested amount is already within the provider's min/max
  /// bounds. Consumers can treat this as a "no action needed" signal.
  final bool amountLimitSatisfied;
  final double? minAmountLimit;
  final double? maxAmountLimit;
}

enum UserInfoFieldTypeDto {
  firstName,
  lastName,
  email,
  emailVerification,
  phoneNumber,
  phoneVerification,
  ssnLastFour,
  address,
}

class UserInfoFieldDto {
  UserInfoFieldDto(
      {required this.type, required this.required, required this.satisfied});
  final UserInfoFieldTypeDto type;
  final bool required;
  final bool satisfied;
}

class UserInfoRequirementDto {
  UserInfoRequirementDto({required this.providerId, required this.fields});
  final String providerId;
  final List<UserInfoFieldDto> fields;
}

class ReverificationRequirementDto {
  ReverificationRequirementDto({
    required this.providerId,
    required this.field,
    required this.requiredRecencyDays,
    this.lastVerifiedAt,
  });
  final String providerId;
  final ReverificationFieldDto field;
  final int requiredRecencyDays;

  /// ISO-8601 timestamp of the last successful verification for [field], or
  /// null if never verified.
  final String? lastVerifiedAt;
}

class CheckoutRequirementDto {
  CheckoutRequirementDto({
    required this.type,
    this.tos,
    this.amountLimit,
    this.userInfo,
    this.reverification,
  });
  final CheckoutRequirementTypeDto type;
  final TosRequirementDto? tos;
  final AmountLimitRequirementDto? amountLimit;
  final UserInfoRequirementDto? userInfo;
  final ReverificationRequirementDto? reverification;
}

class CheckoutRequirementsResultDto {
  CheckoutRequirementsResultDto({
    required this.headlessCheckoutId,
    required this.requirements,
    required this.quote,
    required this.buttonHandle,
  });
  final String headlessCheckoutId;
  final List<CheckoutRequirementDto> requirements;
  final QuoteDto quote;

  /// Opaque handle used to look up the native OnramperCheckoutButton in the
  /// platform-view registry. Pass to OnramperNativeCheckoutButton.
  final String buttonHandle;
}

// ---- Render context ----

enum RenderTypeDto { webview, deeplink }

enum CheckoutPaymentTypeDto { applePay, revolutPay }

class RenderContextDto {
  RenderContextDto({
    required this.url,
    required this.renderType,
    this.paymentType,
  });
  final String url;
  final RenderTypeDto renderType;

  /// Payment type for this render context. Present when the context comes from
  /// a finalized checkout (state.rendering, checkoutFinalized event) but null
  /// on the intermediate renderingStarted event, which the native SDK emits
  /// without payment-type info.
  final CheckoutPaymentTypeDto? paymentType;
}

// ---- Checkout finalize response ----

class HeadlessCheckoutDataDto {
  HeadlessCheckoutDataDto({
    required this.url,
    required this.renderType,
    required this.checkoutPaymentType,
  });
  final String url;
  final RenderTypeDto renderType;
  final CheckoutPaymentTypeDto checkoutPaymentType;
}

class CheckoutFinalizeResponseDto {
  CheckoutFinalizeResponseDto({
    required this.headlessCheckoutId,
    required this.onramperTransactionId,
    required this.headlessCheckoutData,
  });
  final String headlessCheckoutId;

  /// Onramper's durable transaction id (ULID). The id to store and quote to
  /// support. Distinct from the per-attempt checkout id.
  final String onramperTransactionId;
  final HeadlessCheckoutDataDto headlessCheckoutData;
}

// ---- State ----

enum OnramperStateKindDto {
  idle,
  initializing,
  ready,
  checkoutPreparing,
  requireLogin,
  authenticating,
  readyToCheckout,
  finalizing,
  rendering,
  completed,
  failed,
}

class OnramperStateDto {
  OnramperStateDto({
    required this.kind,
    this.requireLoginRequirements,
    this.renderContext,
    this.failedError,
  });
  final OnramperStateKindDto kind;
  final List<CheckoutRequirementDto>? requireLoginRequirements;
  final RenderContextDto? renderContext;
  final OnramperErrorDto? failedError;
}

// ---- Events ----

enum CheckoutEventKindDto {
  stateChanged,
  checkoutStarted,
  loginRequired,
  readyToCheckout,
  requirementSatisfied,
  checkoutFinalized,
  renderingStarted,
  completed,
  failed,
  // Provider-lifecycle events emitted from the third-party checkout webview.
  // Not every provider emits every event.
  checkoutCancelled,
  providerReady,
  paymentAuthorized,
  paymentProcessing,
  paymentCancelled,
  providerError,
}

class CheckoutEventDto {
  CheckoutEventDto({
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
  final CheckoutEventKindDto kind;
  final OnramperStateDto? state;
  final String? checkoutId;
  final List<CheckoutRequirementDto>? loginRequirements;
  final CheckoutRequirementTypeDto? requirementType;
  final RenderContextDto? renderContext;

  /// Populated on `checkoutFinalized`. Carries the full finalize payload so
  /// consumers can inspect provider-side metadata.
  final CheckoutFinalizeResponseDto? finalizeResponse;

  /// Populated on `providerError` — a short human-readable string from the
  /// underlying provider explaining the failure.
  final String? providerReason;
  final OnramperErrorDto? error;
}

// ---- Errors ----

// One enum value per native OnramperError case (1:1).
enum OnramperErrorKindDto {
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

class OnramperErrorDto {
  OnramperErrorDto({
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
  final OnramperErrorKindDto kind;
  final String message;
  final bool recoverable;
  // Variant payloads (nullable; only populated for the relevant kind):
  final int? code; // networkError.code, securityStorageFailed.status
  final double? minAmount; // amountOutOfRange.min
  final double? maxAmount; // amountOutOfRange.max
  final double? retryAfterSeconds; // temporaryFailure.retryAfter
  final String? field; // invalidRequest.field
  final String?
      debugInfo; // invalidRequest / quoteUnavailable / checkoutForbidden / temporaryFailure / unrecoverable
  final String? fromState; // invalidStateTransition.from
  final String? toState; // invalidStateTransition.to
  final String? expectedState; // invalidState.expected
  final String? actualState; // invalidState.actual
  final String? host; // securityTrustFailed.host
}

// ---- Button style ----

/// Colors are hex strings (`#RRGGBB` or `#RRGGBBAA`) matching the format the
/// React Native SDK uses. `borderRadius` is in points.
class CheckoutButtonStyleDto {
  CheckoutButtonStyleDto({
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius,
  });
  final String? backgroundColor;
  final String? foregroundColor;
  final double? borderRadius;
}

// ---- APIs ----

@HostApi()
abstract class OnramperHostApi {
  void configure(ConfigurationDto config);
  @async
  void initialize(SessionCredentialsDto credentials);
  @async
  CheckoutRequirementsResultDto getCheckoutRequirements(
    CheckoutIntentRequestDto request,
    UserPrefillDto? prefill,
    CheckoutButtonStyleDto? buttonStyle,
  );
  @async
  void reset();

  /// Clears the SDK's cached OIDC tokens. Distinct from [reset]: partner
  /// session (DPoP key + session token) is preserved, but the next checkout
  /// will re-prompt for OnramperID login.
  @async
  void signOut();

  /// Drops a stored native checkout button by handle without tearing down the
  /// whole SDK client. Useful when the consumer's UI navigates away from a
  /// prepared intent without dismissing it.
  void cancelPreparedIntent(String buttonHandle);
  @async
  void dispose();
  // Resolves a pending sessionExpired callback; Dart calls this after sourcing
  // fresh credentials in response to OnramperFlutterApi.onSessionExpired.
  void provideRefreshedSession(SessionCredentialsDto credentials);
  // Aborts a pending session refresh (e.g. user signed out). Causes the
  // in-flight SDK call to fail with sessionRefreshAborted.
  void failRefreshedSession(String reason);
}

@FlutterApi()
abstract class OnramperFlutterApi {
  void onStateChanged(OnramperStateDto state);
  void onEvent(CheckoutEventDto event);
  void onError(OnramperErrorDto error);
  // Fired when the native SDK Session expires; Dart MUST respond with either
  // provideRefreshedSession or failRefreshedSession or the in-flight call hangs.
  void onSessionExpired();

  // Mirrors native `@Published currentTransactionId`. Null when cleared (new
  // intent or reset).
  void onTransactionIdChanged(String? transactionId);
}
