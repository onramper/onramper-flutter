import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/platform/pigeon.g.dart',
  dartOptions: DartOptions(),
  swiftOut: 'ios/Classes/Pigeon.g.swift',
  swiftOptions: SwiftOptions(),
  dartPackageName: 'onramper_sdk',
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
  final TransactionTypeDto type;
  final String paymentMethod;
  final WalletInfoDto wallet;
  final String? destination;
  final String? country;
  final String? subdivision;
}

class CheckoutIntentRequestDto {
  CheckoutIntentRequestDto({required this.transactionData, this.onlyOnramps});
  final OnramperTransactionDataDto transactionData;
  final List<String>? onlyOnramps;
}

// ---- Quote ----

class QuoteErrorDto {
  QuoteErrorDto({this.type, this.message});
  final String? type;
  final String? message;
}

class QuoteDto {
  QuoteDto({
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
  final String? quoteId;
  final String? ramp;
  final double? rate;
  final double? networkFee;
  final double? transactionFee;
  final double? payout;
  final String? paymentMethod;
  final List<String>? recommendations;
  final List<QuoteErrorDto>? errors;
}

// ---- Checkout requirements ----

enum CheckoutRequirementTypeDto { tos, amountLimit, userInfo }

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
    this.minAmountLimit,
    this.maxAmountLimit,
  });
  final String providerId;
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

class CheckoutRequirementDto {
  CheckoutRequirementDto({
    required this.type,
    this.tos,
    this.amountLimit,
    this.userInfo,
  });
  final CheckoutRequirementTypeDto type;
  final TosRequirementDto? tos;
  final AmountLimitRequirementDto? amountLimit;
  final UserInfoRequirementDto? userInfo;
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
    required this.paymentType,
  });
  final String url;
  final RenderTypeDto renderType;
  final CheckoutPaymentTypeDto paymentType;
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
}

class CheckoutEventDto {
  CheckoutEventDto({
    required this.kind,
    this.state,
    this.checkoutId,
    this.loginRequirements,
    this.requirementType,
    this.renderContext,
    this.error,
  });
  final CheckoutEventKindDto kind;
  final OnramperStateDto? state;
  final String? checkoutId;
  final List<CheckoutRequirementDto>? loginRequirements;
  final CheckoutRequirementTypeDto? requirementType;
  final RenderContextDto? renderContext;
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
}

// ---- APIs ----

@HostApi()
abstract class OnramperHostApi {
  void configure(ConfigurationDto config);
  @async
  void initialize(SessionCredentialsDto credentials);
  @async
  CheckoutRequirementsResultDto getCheckoutRequirements(
      CheckoutIntentRequestDto request);

  /// Programmatically starts checkout — equivalent to tapping the Buy button.
  /// Only valid in readyToCheckout state.
  @async
  void autoCheckout();
  @async
  void reset();
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
}
