import 'dart:io';

import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

void main() {
  test('public id constructors reject unchecked values', () async {
    await expectLater(
      runFlutterConsumerTest(
        packageName: 'iwb_canvas_engine_id_validation_consumer',
        testFileName: 'id_validation_test.dart',
        testSource: _idValidationTestSource,
      ),
      completes,
    );
  });

  test('public ids are classes, not extension types', () {
    final source = File('lib/src/api/canvas_ids.dart').readAsStringSync();

    expect(source, isNot(contains('extension type CanvasElementId')));
    expect(source, isNot(contains('extension type CanvasLayerId')));
    expect(source, isNot(contains('extension type CanvasResourceId')));
    expect(source, isNot(contains('extension type CanvasActionId')));
    expect(
      source,
      isNot(contains('extension type CanvasInteractionRequestId')),
    );
  });
}

const _idValidationTestSource = '''
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('ids validate at public construction', () {
    expect(CanvasElementId('element-1').value, 'element-1');
    expect(CanvasLayerId('layer-1').value, 'layer-1');
    expect(CanvasResourceId('resource-1').value, 'resource-1');
    expect(CanvasActionId('action-1').value, 'action-1');
    expect(CanvasInteractionRequestId('request-1').value, 'request-1');

    expect(() => CanvasElementId(''), throwsA(isA<CanvasDataException>()));
    expect(() => CanvasLayerId('   '), throwsA(isA<CanvasDataException>()));
    expect(
      () => CanvasElementId(' element-1'),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasLayerId('layer-1 '),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasResourceId('\\tresource-1'),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasActionId('action-1\\n'),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasResourceId('r' * 1025),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasInteractionRequestId('bad\\nid'),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasInteractionRequestId('i' * 257),
      throwsA(isA<CanvasDataException>()),
    );

    expect(
      () => CanvasResourceSource.appKey(''),
      throwsA(
        isA<CanvasDataException>()
            .having(
              (error) => error.code,
              'code',
              CanvasDataErrorCode.fieldMustNotBeEmpty,
            )
            .having(
              (error) => error.path,
              'path',
              'resource.source.appKey',
            ),
      ),
    );
    expect(
      () => CanvasResourceSource.appKey(' asset-main '),
      throwsA(
        isA<CanvasDataException>()
            .having(
              (error) => error.code,
              'code',
              CanvasDataErrorCode.invalidFieldType,
            )
            .having(
              (error) => error.path,
              'path',
              'resource.source.appKey',
            ),
      ),
    );
  });
}
''';
