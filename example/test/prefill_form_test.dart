import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter_example/prefill_form.dart';

void main() {
  test('build returns null when every field is blank', () {
    final c = PrefillController();
    c.firstName.text = '   ';
    expect(c.build(), isNull);
    c.dispose();
  });

  test('build returns trimmed non-blank values', () {
    final c = PrefillController();
    c.firstName.text = ' Ada ';
    c.phone.text = '+3712345678';
    final p = c.build()!;
    expect(p.firstName, 'Ada');
    expect(p.phoneNumber, '+3712345678');
    expect(p.email, isNull);
    c.dispose();
  });
}
