import 'dart:io';

import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test(
    'CanvasSurfacePointerAdapter routes finite Flutter samples only',
    () async {
      await expectLater(
        runFlutterInPackageTest(
          'test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart',
        ),
        completes,
      );
    },
  );

  test('pointer adapter remains a Listener-only finite boundary', () {
    final source = File(
      'lib/src/surface/pointer_adapter.dart',
    ).readAsStringSync();

    expect(source, contains('Listener('));
    expect(source, contains('localPosition'));
    expect(source, isNot(contains('GestureDetector')));
    expect(source, isNot(contains('MouseRegion')));
    expect(source, isNot(contains('GestureRecognizer')));
    expect(source, isNot(contains('PointerSampleNormalizer')));
    expect(source, isNot(contains('viewCameraOffset')));
    expect(source, isNot(contains('worldPosition')));
  });
}
