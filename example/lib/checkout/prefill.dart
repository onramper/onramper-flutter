import 'package:flutter/foundation.dart';
import 'package:onramper_flutter/onramper_flutter.dart';

/// Prefill inputs (RN `PrefillForm`). `email` is the binding identity: if it
/// doesn't match the account that signs in, the whole prefill is dropped, so
/// it's only sent with [sendEmail] on.
@immutable
class PrefillInput {
  const PrefillInput({
    this.enabled = false,
    this.firstName = 'Ada',
    this.lastName = 'Lovelace',
    this.phoneNumber = '',
    this.sendEmail = false,
    this.email = '',
  });

  final bool enabled;
  final String firstName;
  final String lastName;

  /// E.164, e.g. +3712345678.
  final String phoneNumber;
  final bool sendEmail;
  final String email;

  PrefillInput copyWith({
    bool? enabled,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    bool? sendEmail,
    String? email,
  }) =>
      PrefillInput(
        enabled: enabled ?? this.enabled,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        sendEmail: sendEmail ?? this.sendEmail,
        email: email ?? this.email,
      );

  @override
  bool operator ==(Object other) =>
      other is PrefillInput &&
      other.enabled == enabled &&
      other.firstName == firstName &&
      other.lastName == lastName &&
      other.phoneNumber == phoneNumber &&
      other.sendEmail == sendEmail &&
      other.email == email;

  @override
  int get hashCode =>
      Object.hash(enabled, firstName, lastName, phoneNumber, sendEmail, email);
}

/// Names of the fields that would be sent, in RN order. Never the values:
/// prefill is user PII and is never logged.
List<String> prefillFields(PrefillInput f) {
  if (!f.enabled) return const [];
  return [
    if (f.firstName.trim().isNotEmpty) 'firstName',
    if (f.lastName.trim().isNotEmpty) 'lastName',
    if (f.phoneNumber.trim().isNotEmpty) 'phoneNumber',
    if (f.sendEmail && f.email.trim().isNotEmpty) 'email',
  ];
}

/// Only fields the user filled in are sent; `null` when nothing would be.
OnramperUserPrefill? buildPrefill(PrefillInput f) {
  if (prefillFields(f).isEmpty) return null;
  String? v(String s) => s.trim().isEmpty ? null : s.trim();
  return OnramperUserPrefill(
    firstName: v(f.firstName),
    lastName: v(f.lastName),
    phoneNumber: v(f.phoneNumber),
    email: f.sendEmail ? v(f.email) : null,
  );
}

String prefillSummary(PrefillInput f) {
  final fields = prefillFields(f);
  return fields.isEmpty ? 'Sends: nothing' : 'Sends: ${fields.join(', ')}';
}
