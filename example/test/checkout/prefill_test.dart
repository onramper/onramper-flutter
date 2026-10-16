import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter_example/checkout/prefill.dart';

void main() {
  test('disabled prefill sends nothing', () {
    const input = PrefillInput();
    expect(input.enabled, isFalse);
    expect(input.firstName, 'Ada');
    expect(input.lastName, 'Lovelace');
    expect(buildPrefill(input), isNull);
    expect(prefillSummary(input), 'Sends: nothing');
  });

  test('enabled prefill sends trimmed non-empty fields in RN order', () {
    const input = PrefillInput(enabled: true, phoneNumber: ' +3712345678 ');
    final p = buildPrefill(input)!;
    expect(p.firstName, 'Ada');
    expect(p.phoneNumber, '+3712345678');
    expect(p.email, isNull);
    expect(prefillSummary(input), 'Sends: firstName, lastName, phoneNumber');
  });

  test('email is sent only with Send email on', () {
    const off = PrefillInput(enabled: true, email: 'a@b.c');
    expect(buildPrefill(off)!.email, isNull);
    final on = off.copyWith(sendEmail: true);
    expect(buildPrefill(on)!.email, 'a@b.c');
    expect(prefillFields(on).last, 'email');
  });

  test('all-blank enabled prefill sends nothing', () {
    const input = PrefillInput(enabled: true, firstName: ' ', lastName: '');
    expect(buildPrefill(input), isNull);
  });

  test('value equality', () {
    expect(const PrefillInput(), const PrefillInput());
    expect(const PrefillInput().copyWith(enabled: true) == const PrefillInput(),
        isFalse);
  });
}
