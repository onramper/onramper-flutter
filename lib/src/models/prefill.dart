import '../platform/pigeon.g.dart';

/// Values you already know about the user, used to pre-populate the
/// OnramperID sign-in and additional-info screens.
///
/// Best-effort: if prefill can't be applied, sign-in proceeds normally and no
/// error is reported. A prefilled phone number is always a candidate the user
/// still verifies.
///
/// Pass [email] only when you're confident it's the address the user signs in
/// with. On a mismatch the whole prefill is dropped, which is worse than
/// omitting [email].
///
/// Prefill is enabled per integration; talk to your Onramper representative.
class OnramperUserPrefill {
  const OnramperUserPrefill({
    this.email,
    this.firstName,
    this.lastName,
    this.phoneNumber,
  });

  final String? email;
  final String? firstName;
  final String? lastName;

  /// E.164 format, e.g. `+3712345678`.
  final String? phoneNumber;

  /// Returns `null` when no field carries a non-blank value.
  UserPrefillDto? toDto() {
    final e = _clean(email);
    final f = _clean(firstName);
    final l = _clean(lastName);
    final p = _clean(phoneNumber);
    if (e == null && f == null && l == null && p == null) return null;
    return UserPrefillDto(email: e, firstName: f, lastName: l, phoneNumber: p);
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
