import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_sdk/src/models/events.dart';
import 'package:onramper_sdk/src/models/requirements.dart';
import 'package:onramper_sdk/src/models/state.dart';
import 'package:onramper_sdk/src/platform/pigeon.g.dart';

void main() {
  group('CheckoutEvent.fromDto', () {
    test('every CheckoutEventKindDto maps to a non-null Dart kind', () {
      for (final k in CheckoutEventKindDto.values) {
        final e = CheckoutEvent.fromDto(CheckoutEventDto(kind: k));
        expect(e.kind, isA<CheckoutEventKind>());
      }
    });

    test('all CheckoutEventKind counts match dto', () {
      expect(CheckoutEventKind.values.length,
          CheckoutEventKindDto.values.length);
    });

    test('stateChanged carries state', () {
      final e = CheckoutEvent.fromDto(CheckoutEventDto(
        kind: CheckoutEventKindDto.stateChanged,
        state: OnramperStateDto(kind: OnramperStateKindDto.ready),
      ));
      expect(e.kind, CheckoutEventKind.stateChanged);
      expect(e.state, isNotNull);
      expect(e.state!.kind, OnramperStateKind.ready);
    });

    test('checkoutStarted carries checkoutId', () {
      final e = CheckoutEvent.fromDto(CheckoutEventDto(
        kind: CheckoutEventKindDto.checkoutStarted,
        checkoutId: 'hc-1',
      ));
      expect(e.checkoutId, 'hc-1');
    });

    test('loginRequired carries loginRequirements', () {
      final e = CheckoutEvent.fromDto(CheckoutEventDto(
        kind: CheckoutEventKindDto.loginRequired,
        loginRequirements: <CheckoutRequirementDto>[
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
      expect(e.kind, CheckoutEventKind.loginRequired);
      expect(e.loginRequirements, hasLength(1));
      expect(e.loginRequirements!.first.kind, CheckoutRequirementKind.userInfo);
    });

    test('requirementSatisfied carries requirementType', () {
      for (final t in CheckoutRequirementTypeDto.values) {
        final e = CheckoutEvent.fromDto(CheckoutEventDto(
          kind: CheckoutEventKindDto.requirementSatisfied,
          requirementType: t,
        ));
        expect(e.requirementType, isA<CheckoutRequirementKind>());
      }
    });

    test('renderingStarted carries renderContext', () {
      final e = CheckoutEvent.fromDto(CheckoutEventDto(
        kind: CheckoutEventKindDto.renderingStarted,
        renderContext: RenderContextDto(
          url: 'u',
          renderType: RenderTypeDto.webview,
          paymentType: CheckoutPaymentTypeDto.applePay,
        ),
      ));
      expect(e.kind, CheckoutEventKind.renderingStarted);
      expect(e.renderContext, isNotNull);
      expect(e.renderContext!.url, 'u');
    });

    test('failed carries error', () {
      final e = CheckoutEvent.fromDto(CheckoutEventDto(
        kind: CheckoutEventKindDto.failed,
        error: OnramperErrorDto(
          kind: OnramperErrorKindDto.networkError,
          message: 'm',
          recoverable: true,
        ),
      ));
      expect(e.kind, CheckoutEventKind.failed);
      expect(e.error, isNotNull);
      expect(e.error!.message, 'm');
    });

    test('completed has no payloads required', () {
      final e = CheckoutEvent.fromDto(
        CheckoutEventDto(kind: CheckoutEventKindDto.completed),
      );
      expect(e.kind, CheckoutEventKind.completed);
      expect(e.state, isNull);
      expect(e.checkoutId, isNull);
      expect(e.loginRequirements, isNull);
      expect(e.requirementType, isNull);
      expect(e.renderContext, isNull);
      expect(e.error, isNull);
    });
  });
}
