import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onramper_flutter_example/utils/debounced_text.dart';

void main() {
  test('commits 400 ms after the last keystroke', () {
    fakeAsync((async) {
      final commits = <String>[];
      final t = DebouncedText(initial: '100', onCommit: commits.add);
      t.controller.text = '2';
      t.onChanged('2');
      async.elapse(const Duration(milliseconds: 300));
      t.controller.text = '25';
      t.onChanged('25');
      async.elapse(const Duration(milliseconds: 399));
      expect(commits, isEmpty);
      async.elapse(const Duration(milliseconds: 1));
      expect(commits, ['25']);
      t.dispose();
    });
  });

  test('an outside change replaces the draft and cancels the pending commit',
      () {
    fakeAsync((async) {
      final commits = <String>[];
      final t = DebouncedText(initial: 'a', onCommit: commits.add);
      t.controller.text = 'typed';
      t.onChanged('typed');
      t.sync('default-wallet');
      expect(t.controller.text, 'default-wallet');
      async.elapse(const Duration(seconds: 1));
      expect(commits, isEmpty);
      t.dispose();
    });
  });

  test('sync does not clobber an uncommitted draft', () {
    fakeAsync((async) {
      final t = DebouncedText(initial: '100', onCommit: (_) {});
      t.controller.text = '1000';
      t.onChanged('1000');
      t.sync('100');
      expect(t.controller.text, '1000');
      t.dispose();
    });
  });
}
