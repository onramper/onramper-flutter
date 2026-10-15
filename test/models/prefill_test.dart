import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/onramper_flutter.dart';

void main() {
  group('OnramperUserPrefill.toDto', () {
    test('maps all fields', () {
      final dto = const OnramperUserPrefill(
        email: 'ada@example.com',
        firstName: 'Ada',
        lastName: 'Lovelace',
        phoneNumber: '+3712345678',
      ).toDto()!;
      expect(dto.email, 'ada@example.com');
      expect(dto.firstName, 'Ada');
      expect(dto.lastName, 'Lovelace');
      expect(dto.phoneNumber, '+3712345678');
    });

    test('trims values and drops blank ones', () {
      final dto =
          const OnramperUserPrefill(firstName: '  Ada ', lastName: '   ')
              .toDto()!;
      expect(dto.firstName, 'Ada');
      expect(dto.lastName, isNull);
    });

    test('returns null when every field is null, empty or whitespace', () {
      expect(const OnramperUserPrefill().toDto(), isNull);
      expect(
        const OnramperUserPrefill(email: '', firstName: '  ').toDto(),
        isNull,
      );
    });
  });
}
