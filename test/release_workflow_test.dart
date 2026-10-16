import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Execute the actual workflow run blocks against disposable release files.
// curl is replaced so these tests cannot access or publish to a service.
void main() {
  final workflow = File('.github/workflows/release.yml').readAsStringSync();
  String step(String name) {
    final body = workflow.split('      - name: $name\n').last;
    return body
        .split('        run: |\n')[1]
        .split('\n')
        .takeWhile((line) => line.isEmpty || line.startsWith('          '))
        .map((line) => line.isEmpty ? '' : line.substring(10))
        .join('\n');
  }

  Future<ProcessResult> validate(String version,
      {String? nativeVersion, String? podVersion, String? changelog}) async {
    final fixture = Directory.systemTemp.createTempSync('release-validation-');
    addTearDown(() => fixture.deleteSync(recursive: true));
    Directory('${fixture.path}/ios').createSync();
    Directory('${fixture.path}/bin').createSync();
    File('${fixture.path}/pubspec.yaml')
        .writeAsStringSync('version: $version\n');
    File('${fixture.path}/ios/onramper_flutter.podspec').writeAsStringSync(
      "s.version = '${podVersion ?? version.replaceAll('+', '.')}'\n"
      'ONRAMPER_SDK_VERSION="v${nativeVersion ?? '1.3.1'}"\n',
    );
    File('${fixture.path}/CHANGELOG.md')
        .writeAsStringSync(changelog ?? '## $version — Release\n');
    final curl = File('${fixture.path}/bin/curl')
      ..writeAsStringSync('#!/bin/bash\n'
          '[[ "\${@: -1}" == "https://github.com/onramper/onramper-ios/releases/download/v1.3.1/OnramperSDK.xcframework.zip" ]]\n');
    await Process.run('chmod', ['+x', curl.path]);
    return Process.run(
      'bash',
      [
        '-e',
        '-c',
        [
          step('Validate version format'),
          step('Verify versions match'),
          step('Verify iOS release exists'),
        ].map((script) => '(\n$script\n)').join('\n'),
      ],
      workingDirectory: fixture.path,
      environment: {
        'VERSION': version,
        'PATH': '${fixture.path}/bin:${Platform.environment['PATH']}',
      },
    );
  }

  for (final version in ['1.3.1', '1.3.1+1', '1.3.1+12']) {
    test('release $version validates against the base iOS release', () async {
      final result = await validate(version);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    });
  }

  test('wrapper release rejects a different native SDK', () async {
    final result = await validate('1.3.1+1', nativeVersion: '1.3.0');
    expect(result.exitCode, isNot(0));
  });

  test('wrapper release rejects an unchanged CocoaPods version', () async {
    final result = await validate('1.3.1+1', podVersion: '1.3.1');
    expect(result.exitCode, isNot(0));
  });

  test('wrapper release requires its own changelog section', () async {
    final result = await validate('1.3.1+1', changelog: '## 1.3.1\n');
    expect(result.exitCode, isNot(0));
  });

  for (final version in ['1.3.1+', '1.3.1+abc', '1.3.1+0', '1.3.1-rc.1']) {
    test('release rejects unsupported version $version', () async {
      final result = await validate(version);
      expect(result.exitCode, isNot(0));
    });
  }
}
