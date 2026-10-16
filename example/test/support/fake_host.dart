import 'dart:async';

import 'package:flutter/services.dart';
import 'package:onramper_flutter/src/platform/pigeon.g.dart';

/// Records calls into [journal] as `<tag>.<method>` so tests can check order
/// across several clients.
class FakeHost implements OnramperHostApi {
  FakeHost({List<String>? journal, this.tag = 'h'})
      : journal = journal ?? <String>[];

  final List<String> journal;
  final String tag;

  ConfigurationDto? lastConfig;
  CheckoutIntentRequestDto? lastRequest;
  UserPrefillDto? lastPrefill;
  CheckoutButtonStyleDto? lastButtonStyle;
  int requirementsCalls = 0;
  int signOutCalls = 0;
  int resetCalls = 0;

  Completer<void>? initializeGate;
  Object? initializeError;
  Object? signOutError;
  Completer<void>? signOutGate;

  /// Each `getCheckoutRequirements` call waits for, then removes, the first
  /// gate here (if any).
  final List<Completer<void>> requirementsGates = [];
  Object? requirementsError;

  @override
  // ignore: non_constant_identifier_names
  BinaryMessenger? get pigeonVar_binaryMessenger => null;

  @override
  // ignore: non_constant_identifier_names
  String get pigeonVar_messageChannelSuffix => '';

  @override
  Future<void> configure(ConfigurationDto config) async {
    journal.add('$tag.configure');
    lastConfig = config;
  }

  @override
  Future<void> initialize(SessionCredentialsDto credentials) async {
    journal.add('$tag.initialize');
    await initializeGate?.future;
    final error = initializeError;
    if (error != null) throw error;
  }

  @override
  Future<CheckoutRequirementsResultDto> getCheckoutRequirements(
    CheckoutIntentRequestDto request,
    UserPrefillDto? prefill,
    CheckoutButtonStyleDto? buttonStyle,
  ) async {
    final n = ++requirementsCalls;
    lastRequest = request;
    lastPrefill = prefill;
    lastButtonStyle = buttonStyle;
    if (requirementsGates.isNotEmpty) {
      await requirementsGates.removeAt(0).future;
    }
    final error = requirementsError;
    if (error != null) throw error;
    return CheckoutRequirementsResultDto(
      headlessCheckoutId: 'checkout-$n',
      requirements: const [],
      buttonHandle: 'button-$n',
      quote: QuoteDto(
        quoteId: 'quote-$n',
        ramp: 'moonpay',
        rate: 50000,
        networkFee: 1,
        transactionFee: 2,
        payout: 0.002,
        paymentMethod: 'applepay',
      ),
    );
  }

  @override
  Future<void> reset() async {
    journal.add('$tag.reset');
    resetCalls++;
  }

  @override
  Future<void> signOut() async {
    journal.add('$tag.signOut');
    signOutCalls++;
    await signOutGate?.future;
    final error = signOutError;
    if (error != null) throw error;
  }

  @override
  Future<void> cancelPreparedIntent(String buttonHandle) async {}

  @override
  Future<void> dispose() async => journal.add('$tag.dispose');

  @override
  Future<void> provideRefreshedSession(SessionCredentialsDto credentials) async {}

  @override
  Future<void> failRefreshedSession(String reason) async {}

  @override
  Future<String> sdkVersion() async => '1.3.1';
}
