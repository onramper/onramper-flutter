/// A JSON value carried in provider-specific metadata such as
/// `QuoteResponse.providerContext`. Mirrors native `ProviderJSONValue`.
///
/// Provider metadata may contain tokens; don't log it.
sealed class ProviderJSONValue {
  const ProviderJSONValue();

  /// Decodes a standard-codec value (String, num, bool, null, List, Map).
  /// Unknown types decode as [ProviderJSONNull].
  static ProviderJSONValue fromObject(Object? value) => switch (value) {
        null => const ProviderJSONNull(),
        bool b => ProviderJSONBool(b),
        num n => ProviderJSONNumber(n.toDouble()),
        String s => ProviderJSONString(s),
        List<Object?> l =>
          ProviderJSONArray(List.unmodifiable(l.map(fromObject))),
        Map<Object?, Object?> m => ProviderJSONObject(Map.unmodifiable(
            m.map((k, v) => MapEntry('$k', fromObject(v))),
          )),
        _ => const ProviderJSONNull(),
      };

  /// The string payload, or `null` if this isn't a [ProviderJSONString].
  String? get stringValue =>
      switch (this) { ProviderJSONString(:final value) => value, _ => null };
}

final class ProviderJSONString extends ProviderJSONValue {
  const ProviderJSONString(this.value);
  final String value;
}

final class ProviderJSONNumber extends ProviderJSONValue {
  const ProviderJSONNumber(this.value);
  final double value;
}

final class ProviderJSONBool extends ProviderJSONValue {
  const ProviderJSONBool(this.value);
  final bool value;
}

final class ProviderJSONNull extends ProviderJSONValue {
  const ProviderJSONNull();
}

final class ProviderJSONArray extends ProviderJSONValue {
  const ProviderJSONArray(this.value);
  final List<ProviderJSONValue> value;
}

final class ProviderJSONObject extends ProviderJSONValue {
  const ProviderJSONObject(this.value);
  final Map<String, ProviderJSONValue> value;
}

/// A payment disclosure the provider requires to be shown next to the payment
/// button. The native checkout button already renders these and they can't be
/// hidden; this type exists for integrators who want to inspect them.
class PaymentDisclosure {
  const PaymentDisclosure({
    required this.code,
    required this.version,
    required this.contentMarkdown,
    required this.contentHtml,
  });

  final String code;
  final String version;
  final String contentMarkdown;
  final String contentHtml;

  /// Parses an object with all four string fields; otherwise `null`.
  static PaymentDisclosure? tryParse(ProviderJSONValue value) {
    if (value is! ProviderJSONObject) return null;
    final m = value.value;
    final code = m['code']?.stringValue;
    final version = m['version']?.stringValue;
    final md = m['contentMarkdown']?.stringValue;
    final html = m['contentHtml']?.stringValue;
    if (code == null || version == null || md == null || html == null) {
      return null;
    }
    return PaymentDisclosure(
      code: code,
      version: version,
      contentMarkdown: md,
      contentHtml: html,
    );
  }
}
