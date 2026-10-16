import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter_example/theme/demo_theme.dart';
import 'package:onramper_flutter_example/widgets/spaced.dart';

void main() {
  test('spaced puts a gap between children, not around them', () {
    const a = Text('a'), b = Text('b'), c = Text('c');
    final out = spaced(8, [a, b, c]);
    expect(out.length, 5);
    expect(out[0], same(a));
    expect((out[1] as SizedBox).width, 8);
    expect((out[1] as SizedBox).height, 8);
    expect(out[4], same(c));
    expect(spaced(8, []), isEmpty);
    expect(spaced(8, [a]), [a]);
  });

  test('faded keeps the colour and sets the opacity', () {
    expect(DemoPalette.dark.accent.faded(0.25), const Color(0x40B5F798));
  });
}
