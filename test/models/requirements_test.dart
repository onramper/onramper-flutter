import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/src/models/quote.dart';
import 'package:onramper_flutter/src/models/requirements.dart';
import 'package:onramper_flutter/src/platform/pigeon.g.dart';

QuoteDto _quoteDto({String quoteId = 'q'}) => QuoteDto(
      quoteId: quoteId,
      ramp: 'r',
      rate: 1,
      networkFee: 0,
      transactionFee: 0,
      payout: 1,
      paymentMethod: 'pm',
    );

void main() {
  group('WalletInfo.toDto', () {
    test('round-trips required + optional fields', () {
      const w = WalletInfo(network: 'BTC', address: 'bc1...', memo: 'tag');
      final dto = w.toDto();
      expect(dto.network, 'BTC');
      expect(dto.address, 'bc1...');
      expect(dto.memo, 'tag');
    });

    test('memo can be null', () {
      const w = WalletInfo(network: 'BTC', address: 'bc1...');
      final dto = w.toDto();
      expect(dto.memo, isNull);
    });
  });

  group('OnramperTransactionData.toDto', () {
    test('round-trips all fields and maps TransactionType', () {
      const data = OnramperTransactionData(
        source: 'USD',
        destination: 'BTC',
        amount: 100.0,
        type: TransactionType.buy,
        paymentMethod: 'credit_card',
        wallet: WalletInfo(network: 'BTC', address: 'bc1...'),
        country: 'US',
        subdivision: 'CA',
      );

      final dto = data.toDto();
      expect(dto.source, 'USD');
      expect(dto.destination, 'BTC');
      expect(dto.amount, 100.0);
      expect(dto.type, TransactionTypeDto.buy);
      expect(dto.paymentMethod, 'credit_card');
      expect(dto.wallet.address, 'bc1...');
      expect(dto.country, 'US');
      expect(dto.subdivision, 'CA');
    });

    test('sell type maps to TransactionTypeDto.sell', () {
      const data = OnramperTransactionData(
        source: 's',
        destination: 'd',
        amount: 1.0,
        type: TransactionType.sell,
        paymentMethod: 'p',
        wallet: WalletInfo(network: 'n', address: 'a'),
      );
      expect(data.toDto().type, TransactionTypeDto.sell);
    });
  });

  group('CheckoutIntentRequest.toDto', () {
    test('passes through transactionData and onlyOnramps', () {
      const req = CheckoutIntentRequest(
        transactionData: OnramperTransactionData(
          source: 'USD',
          destination: 'BTC',
          amount: 50,
          type: TransactionType.buy,
          paymentMethod: 'cc',
          wallet: WalletInfo(network: 'BTC', address: 'a'),
        ),
        onlyOnramps: <String>['moonpay', 'transak'],
      );

      final dto = req.toDto();
      expect(dto.onlyOnramps, <String>['moonpay', 'transak']);
    });

    test('onlyOnramps null is preserved', () {
      const req = CheckoutIntentRequest(
        transactionData: OnramperTransactionData(
          source: 'USD',
          destination: 'BTC',
          amount: 50,
          type: TransactionType.buy,
          paymentMethod: 'cc',
          wallet: WalletInfo(network: 'BTC', address: 'a'),
        ),
      );
      expect(req.toDto().onlyOnramps, isNull);
    });
  });

  group('TosItem.fromDto', () {
    test('round-trips every type', () {
      for (final t in TosItemTypeDto.values) {
        final dto = TosItemDto(
          type: t,
          required: true,
          satisfied: false,
          url: 'https://example.com',
          content: 'body',
        );
        final item = TosItem.fromDto(dto);
        expect(item.type, isA<TosItemType>());
        expect(item.required, true);
        expect(item.satisfied, false);
        expect(item.url, 'https://example.com');
        expect(item.content, 'body');
      }
    });

    test('all TosItemType counts match dto', () {
      expect(TosItemType.values.length, TosItemTypeDto.values.length);
    });
  });

  group('TosRequirement.fromDto', () {
    test('preserves providerId and items', () {
      final dto = TosRequirementDto(
        providerId: 'moonpay',
        items: <TosItemDto>[
          TosItemDto(
            type: TosItemTypeDto.tos,
            required: true,
            satisfied: false,
            url: 'https://tos',
          ),
          TosItemDto(
            type: TosItemTypeDto.privacyPolicy,
            required: false,
            satisfied: true,
          ),
        ],
      );

      final r = TosRequirement.fromDto(dto);
      expect(r.providerId, 'moonpay');
      expect(r.items, hasLength(2));
      expect(r.items[0].type, TosItemType.tos);
      expect(r.items[1].type, TosItemType.privacyPolicy);
    });
  });

  group('AmountLimitRequirement.fromDto', () {
    test('preserves providerId, limits, and satisfied flag', () {
      final r = AmountLimitRequirement.fromDto(AmountLimitRequirementDto(
        providerId: 'moonpay',
        amountLimitSatisfied: true,
        minAmountLimit: 10,
        maxAmountLimit: 1000,
      ));
      expect(r.providerId, 'moonpay');
      expect(r.minAmountLimit, 10);
      expect(r.maxAmountLimit, 1000);
      expect(r.amountLimitSatisfied, isTrue);
    });

    test('preserves null limits + unsatisfied flag', () {
      final r = AmountLimitRequirement.fromDto(
        AmountLimitRequirementDto(
            providerId: 'mp', amountLimitSatisfied: false),
      );
      expect(r.minAmountLimit, isNull);
      expect(r.maxAmountLimit, isNull);
      expect(r.amountLimitSatisfied, isFalse);
    });
  });

  group('UserInfoField.fromDto', () {
    test('round-trips every field type', () {
      for (final t in UserInfoFieldTypeDto.values) {
        final dto = UserInfoFieldDto(
          type: t,
          required: true,
          satisfied: false,
        );
        final f = UserInfoField.fromDto(dto);
        expect(f.type, isA<UserInfoFieldType>());
      }
    });

    test('all counts match', () {
      expect(
          UserInfoFieldType.values.length, UserInfoFieldTypeDto.values.length);
    });
  });

  group('UserInfoRequirement.fromDto', () {
    test('preserves providerId and fields', () {
      final dto = UserInfoRequirementDto(
        providerId: 'mp',
        fields: <UserInfoFieldDto>[
          UserInfoFieldDto(
            type: UserInfoFieldTypeDto.email,
            required: true,
            satisfied: false,
          ),
        ],
      );
      final r = UserInfoRequirement.fromDto(dto);
      expect(r.providerId, 'mp');
      expect(r.fields, hasLength(1));
      expect(r.fields.first.type, UserInfoFieldType.email);
    });
  });

  group('ReverificationRequirement.fromDto', () {
    test('maps phone reverification with lastVerifiedAt', () {
      final dto = ReverificationRequirementDto(
        providerId: 'moonpay',
        field: ReverificationFieldDto.phone,
        requiredRecencyDays: 90,
        lastVerifiedAt: '2026-05-01T00:00:00Z',
      );
      final r = ReverificationRequirement.fromDto(dto);
      expect(r.providerId, 'moonpay');
      expect(r.field, ReverificationField.phone);
      expect(r.requiredRecencyDays, 90);
      expect(r.lastVerifiedAt, '2026-05-01T00:00:00Z');
    });

    test('maps email reverification without lastVerifiedAt', () {
      final dto = ReverificationRequirementDto(
        providerId: 'moonpay',
        field: ReverificationFieldDto.email,
        requiredRecencyDays: 30,
      );
      final r = ReverificationRequirement.fromDto(dto);
      expect(r.field, ReverificationField.email);
      expect(r.lastVerifiedAt, isNull);
    });
  });

  group('CheckoutRequirement.fromDto', () {
    test('tos variant', () {
      final dto = CheckoutRequirementDto(
        type: CheckoutRequirementTypeDto.tos,
        tos: TosRequirementDto(
          providerId: 'mp',
          items: <TosItemDto>[
            TosItemDto(
              type: TosItemTypeDto.tos,
              required: true,
              satisfied: false,
            ),
          ],
        ),
      );
      final r = CheckoutRequirement.fromDto(dto);
      expect(r.kind, CheckoutRequirementKind.tos);
      expect(r.tos, isNotNull);
      expect(r.amountLimit, isNull);
      expect(r.userInfo, isNull);
      expect(r.reverification, isNull);
    });

    test('amountLimit variant', () {
      final dto = CheckoutRequirementDto(
        type: CheckoutRequirementTypeDto.amountLimit,
        amountLimit: AmountLimitRequirementDto(
          providerId: 'mp',
          amountLimitSatisfied: false,
          minAmountLimit: 1,
        ),
      );
      final r = CheckoutRequirement.fromDto(dto);
      expect(r.kind, CheckoutRequirementKind.amountLimit);
      expect(r.amountLimit, isNotNull);
      expect(r.amountLimit!.minAmountLimit, 1);
      expect(r.amountLimit!.amountLimitSatisfied, isFalse);
    });

    test('userInfo variant', () {
      final dto = CheckoutRequirementDto(
        type: CheckoutRequirementTypeDto.userInfo,
        userInfo: UserInfoRequirementDto(
          providerId: 'mp',
          fields: <UserInfoFieldDto>[
            UserInfoFieldDto(
              type: UserInfoFieldTypeDto.email,
              required: true,
              satisfied: false,
            ),
          ],
        ),
      );
      final r = CheckoutRequirement.fromDto(dto);
      expect(r.kind, CheckoutRequirementKind.userInfo);
      expect(r.userInfo, isNotNull);
      expect(r.reverification, isNull);
    });

    test('reverification variant', () {
      final dto = CheckoutRequirementDto(
        type: CheckoutRequirementTypeDto.reverification,
        reverification: ReverificationRequirementDto(
          providerId: 'mp',
          field: ReverificationFieldDto.phone,
          requiredRecencyDays: 30,
        ),
      );
      final r = CheckoutRequirement.fromDto(dto);
      expect(r.kind, CheckoutRequirementKind.reverification);
      expect(r.reverification, isNotNull);
      expect(r.reverification!.field, ReverificationField.phone);
    });

    test('all CheckoutRequirementKind counts match dto', () {
      expect(CheckoutRequirementKind.values.length,
          CheckoutRequirementTypeDto.values.length);
    });
  });

  group('CheckoutRequirementsResult.fromDto', () {
    test('aggregates requirements and quote', () {
      final dto = CheckoutRequirementsResultDto(
        headlessCheckoutId: 'hc-1',
        requirements: <CheckoutRequirementDto>[
          CheckoutRequirementDto(
            type: CheckoutRequirementTypeDto.tos,
            tos: TosRequirementDto(
              providerId: 'mp',
              items: <TosItemDto>[
                TosItemDto(
                  type: TosItemTypeDto.tos,
                  required: true,
                  satisfied: false,
                  url: 'https://tos',
                ),
              ],
            ),
          ),
          CheckoutRequirementDto(
            type: CheckoutRequirementTypeDto.amountLimit,
            amountLimit: AmountLimitRequirementDto(
              providerId: 'mp',
              amountLimitSatisfied: true,
            ),
          ),
        ],
        quote: _quoteDto(),
        buttonHandle: 'handle-1',
      );

      final r = CheckoutRequirementsResult.fromDto(dto);

      expect(r.headlessCheckoutId, 'hc-1');
      expect(r.requirements, hasLength(2));
      expect(r.quote, isA<QuoteResponse>());
      expect(r.quote.quoteId, 'q');
      expect(r.buttonHandle, 'handle-1');
    });

    test('tos convenience getter filters non-tos and missing payloads', () {
      final dto = CheckoutRequirementsResultDto(
        headlessCheckoutId: 'hc',
        requirements: <CheckoutRequirementDto>[
          CheckoutRequirementDto(
            type: CheckoutRequirementTypeDto.tos,
            tos: TosRequirementDto(providerId: 'a', items: <TosItemDto>[]),
          ),
          CheckoutRequirementDto(
            type: CheckoutRequirementTypeDto.amountLimit,
            amountLimit: AmountLimitRequirementDto(
              providerId: 'b',
              amountLimitSatisfied: false,
            ),
          ),
          CheckoutRequirementDto(
            type: CheckoutRequirementTypeDto.tos,
            tos: TosRequirementDto(providerId: 'c', items: <TosItemDto>[]),
          ),
        ],
        quote: _quoteDto(),
        buttonHandle: 'handle-2',
      );

      final r = CheckoutRequirementsResult.fromDto(dto);
      expect(r.tos, hasLength(2));
      expect(r.tos.map((t) => t.providerId), <String>['a', 'c']);
    });
  });
}
