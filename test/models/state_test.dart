import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/src/models/state.dart';
import 'package:onramper_flutter/src/platform/pigeon.g.dart';

void main() {
  group('RenderContext.fromDto', () {
    test('round-trips fields and enums', () {
      final dto = RenderContextDto(
        url: 'https://pay.example.com',
        renderType: RenderTypeDto.webview,
        paymentType: CheckoutPaymentTypeDto.applePay,
      );
      final ctx = RenderContext.fromDto(dto);
      expect(ctx.url, 'https://pay.example.com');
      expect(ctx.renderType, RenderType.webview);
      expect(ctx.paymentType, CheckoutPaymentType.applePay);
    });

    test('deeplink + revolutPay variants', () {
      final ctx = RenderContext.fromDto(RenderContextDto(
        url: 'onramper://x',
        renderType: RenderTypeDto.deeplink,
        paymentType: CheckoutPaymentTypeDto.revolutPay,
      ));
      expect(ctx.renderType, RenderType.deeplink);
      expect(ctx.paymentType, CheckoutPaymentType.revolutPay);
    });

    test('paymentType is nullable and defaults to null when omitted', () {
      final ctx = RenderContext.fromDto(RenderContextDto(
        url: 'u',
        renderType: RenderTypeDto.webview,
      ));
      expect(ctx.paymentType, isNull);
    });

    test('all RenderType / CheckoutPaymentType counts match dto', () {
      expect(RenderType.values.length, RenderTypeDto.values.length);
      expect(CheckoutPaymentType.values.length,
          CheckoutPaymentTypeDto.values.length);
    });
  });

  group('OnramperState.fromDto', () {
    test('every kind round-trips and counts match', () {
      for (final k in OnramperStateKindDto.values) {
        final s = OnramperState.fromDto(OnramperStateDto(kind: k));
        expect(s.kind, isA<OnramperStateKind>());
      }
      expect(
          OnramperStateKind.values.length, OnramperStateKindDto.values.length);
    });

    test('rendering state carries non-null renderContext', () {
      final s = OnramperState.fromDto(OnramperStateDto(
        kind: OnramperStateKindDto.rendering,
        renderContext: RenderContextDto(
          url: 'u',
          renderType: RenderTypeDto.webview,
          paymentType: CheckoutPaymentTypeDto.applePay,
        ),
      ));
      expect(s.kind, OnramperStateKind.rendering);
      expect(s.renderContext, isNotNull);
      expect(s.renderContext!.url, 'u');
      expect(s.failedError, isNull);
      expect(s.requireLoginRequirements, isNull);
    });

    test('requireLogin state carries non-null requirements', () {
      final s = OnramperState.fromDto(OnramperStateDto(
        kind: OnramperStateKindDto.requireLogin,
        requireLoginRequirements: <CheckoutRequirementDto>[
          CheckoutRequirementDto(
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
          ),
        ],
      ));
      expect(s.kind, OnramperStateKind.requireLogin);
      expect(s.requireLoginRequirements, hasLength(1));
    });

    test('failed state carries non-null failedError', () {
      final s = OnramperState.fromDto(OnramperStateDto(
        kind: OnramperStateKindDto.failed,
        failedError: OnramperErrorDto(
          kind: OnramperErrorKindDto.networkError,
          message: 'boom',
          userMessage: 'Something went wrong. Please try again.',
          supportCode: 'test',
          recoverable: false,
        ),
      ));
      expect(s.kind, OnramperStateKind.failed);
      expect(s.failedError, isNotNull);
      expect(s.failedError!.message, 'boom');
    });

    test('ready state has no payloads', () {
      final s = OnramperState.fromDto(
        OnramperStateDto(kind: OnramperStateKindDto.ready),
      );
      expect(s.kind, OnramperStateKind.ready);
      expect(s.renderContext, isNull);
      expect(s.requireLoginRequirements, isNull);
      expect(s.failedError, isNull);
    });
  });

  test('maps paymentPending', () {
    final s = OnramperState.fromDto(
        OnramperStateDto(kind: OnramperStateKindDto.paymentPending));
    expect(s.kind, OnramperStateKind.paymentPending);
  });
}
