import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test('CanvasTransform public value behavior is executable', () async {
    expect(await _runFlutterConsumerTest(_canvasTransformSource), isTrue);
  });
}

Future<bool> _runFlutterConsumerTest(String testSource) async {
  final packageDir = await Directory.systemTemp.createTemp(
    'iwb_canvas_engine_transform_consumer_',
  );

  try {
    await Directory('${packageDir.path}/test').create();
    await File(
      '${packageDir.path}/pubspec.yaml',
    ).writeAsString(_pubspecSource());
    await File(
      '${packageDir.path}/test/canvas_transform_test.dart',
    ).writeAsString(testSource);

    final pubGet = await Process.run('flutter', [
      'pub',
      'get',
    ], workingDirectory: packageDir.path);
    expect(pubGet.exitCode, 0, reason: _processOutput(pubGet));

    final test = await Process.run('flutter', [
      'test',
      'test/canvas_transform_test.dart',
    ], workingDirectory: packageDir.path);
    expect(test.exitCode, 0, reason: _processOutput(test));

    return true;
  } finally {
    await packageDir.delete(recursive: true);
  }
}

String _pubspecSource() {
  return '''
name: iwb_canvas_engine_transform_consumer
publish_to: none

environment:
  sdk: ^3.10.4

dependencies:
  flutter:
    sdk: flutter
  iwb_canvas_engine:
    path: $repositoryRoot

dev_dependencies:
  flutter_test:
    sdk: flutter
''';
}

String _processOutput(ProcessResult result) {
  return '''
stdout:
${result.stdout}

stderr:
${result.stderr}
''';
}

const _canvasTransformSource = '''
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('rotation and TRS composition transform points', () {
    final rotation = CanvasTransform.rotationDegrees(90);

    _expectOffsetClose(rotation.applyToPoint(const Offset(2, 0)), const Offset(0, 2));

    final trs = CanvasTransform.trs(
      translation: const Offset(10, 20),
      rotationDegrees: 90,
      scaleX: 2,
      scaleY: 3,
    );
    _expectOffsetClose(trs.applyToPoint(const Offset(1, 1)), const Offset(7, 22));
  });

  test('multiply applies the argument first', () {
    final translate = CanvasTransform.translation(const Offset(10, 0));
    final scale = CanvasTransform.scale(2, 2);

    _expectOffsetClose(
      translate.multiply(scale).applyToPoint(const Offset(3, 4)),
      const Offset(16, 8),
    );
  });

  test('rect application returns transformed axis-aligned bounds', () {
    final transform = CanvasTransform.rotationDegrees(90);
    final rect = transform.applyToRect(const Rect.fromLTWH(0, 0, 2, 1));

    expect(rect.left, closeTo(-1, 1e-9));
    expect(rect.top, closeTo(0, 1e-9));
    expect(rect.right, closeTo(0, 1e-9));
    expect(rect.bottom, closeTo(2, 1e-9));
  });

  test('invert, matrix conversion, and JSON projection are stable', () {
    final transform = CanvasTransform(a: 2, b: 0, c: 0, d: 4, tx: 10, ty: 20);
    final inverse = transform.invert();

    expect(inverse, isNotNull);
    _expectOffsetClose(
      inverse!.applyToPoint(transform.applyToPoint(const Offset(3, 5))),
      const Offset(3, 5),
    );
    expect(CanvasTransform(a: 1, b: 0, c: 0, d: 0, tx: 0, ty: 0).invert(), isNull);
    expect(transform.toJsonMap(), {
      'a': 2.0,
      'b': 0.0,
      'c': 0.0,
      'd': 4.0,
      'tx': 10.0,
      'ty': 20.0,
    });
    expect(transform.toCanvasTransform(), [
      2.0, 0.0, 0.0, 0.0,
      0.0, 4.0, 0.0, 0.0,
      0.0, 0.0, 1.0, 0.0,
      10.0, 20.0, 0.0, 1.0,
    ]);

    final out = Float64List(16);
    transform.writeToCanvasTransform(out);
    expect(out, transform.toCanvasTransform());
    expect(() => transform.writeToCanvasTransform(Float64List(15)), throwsArgumentError);
  });

  test('invalid transform construction rejects non-finite values', () {
    expect(
      () => CanvasTransform(a: 1, b: 0, c: 0, d: 1, tx: double.nan, ty: 0),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasTransform.rotationRadians(double.infinity),
      throwsA(isA<CanvasDataException>()),
    );
  });
}

void _expectOffsetClose(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, 1e-9));
  expect(actual.dy, closeTo(expected.dy, 1e-9));
}
''';
