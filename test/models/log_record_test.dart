import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter/onramper_flutter.dart';
import 'package:onramper_flutter/src/platform/pigeon.g.dart';

void main() {
  test('OnramperLogRecord.fromDto maps all fields', () {
    final r = OnramperLogRecord.fromDto(LogRecordDto(
      timestampMs: 1760500000000,
      level: LogLevelDto.info,
      category: 'Checkout',
      event: 'checkout.finalized',
      context: {'ramp': 'moonpay'},
      message: 'checkout.finalized ramp=moonpay',
    ));
    expect(r.timestamp,
        DateTime.fromMillisecondsSinceEpoch(1760500000000, isUtc: true));
    expect(r.level, OnramperLogLevel.info);
    expect(r.category, 'Checkout');
    expect(r.event, 'checkout.finalized');
    expect(r.context, {'ramp': 'moonpay'});
    expect(r.message, 'checkout.finalized ramp=moonpay');
  });
}
