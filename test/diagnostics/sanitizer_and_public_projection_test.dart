import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test('CanvasDataException exposes sanitized public details', () async {
    expect(await _runFlutterConsumerTest(_sanitizerProjectionSource), isTrue);
  });
}

Future<bool> _runFlutterConsumerTest(String testSource) async {
  final packageDir = await Directory.systemTemp.createTemp(
    'iwb_canvas_engine_diagnostics_projection_consumer_',
  );

  try {
    await Directory('${packageDir.path}/test').create();
    await File(
      '${packageDir.path}/pubspec.yaml',
    ).writeAsString(_pubspecSource());
    await File(
      '${packageDir.path}/test/diagnostics_projection_test.dart',
    ).writeAsString(testSource);

    final pubGet = await Process.run('flutter', [
      'pub',
      'get',
    ], workingDirectory: packageDir.path);
    expect(pubGet.exitCode, 0, reason: _processOutput(pubGet));

    final test = await Process.run('flutter', [
      'test',
      'test/diagnostics_projection_test.dart',
    ], workingDirectory: packageDir.path);
    expect(test.exitCode, 0, reason: _processOutput(test));

    return true;
  } finally {
    await packageDir.delete(recursive: true);
  }
}

String _pubspecSource() {
  return '''
name: iwb_canvas_engine_diagnostics_projection_consumer
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

const _sanitizerProjectionSource = '''
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('details are detached from mutable caller maps and deep frozen', () {
    final exception = _detachedException();

    expect(exception.details['nested'], isA<Map<String, Object?>>());
    _expectExceptionIdentityFields(exception);
    _expectDetailsDeepFrozen(exception);
  });

  test('accepted scalar, list, and nested map details stay readable', () {
    final exception = _readableDetailsException();

    expect(exception.details['null'], isNull);
    _expectReadableDetails(exception);
  });

  test('unsupported objects do not escape public exception state', () {
    final projection = _unsupportedObjectProjection();

    expect(_containsSameObject(projection.details, projection.handle), isFalse);
    _expectUnsupportedProjection(projection.details);
  });

  test('public details are bounded', () {
    final exception = _boundedDetailsException();

    expect(exception.details['longString'], '\${'x' * 256}<truncated>');
    _expectBoundedList(exception);
  });
}

CanvasDataException _detachedException() {
  final callerDetails = <String, Object?>{
    'nested': <String, Object?>{
      'items': <Object?>[1, true],
    },
  };
  final exception = _exceptionWithDetails(callerDetails);

  callerDetails['nested'] = 'mutated';

  return exception;
}

CanvasDataException _exceptionWithDetails(Map<String, Object?> callerDetails) {
  return CanvasDataException(
    code: CanvasDataErrorCode.invalidJson,
    message: 'Invalid JSON.',
    path: r'\$.document',
    details: callerDetails,
  );
}

void _expectExceptionIdentityFields(CanvasDataException exception) {
  expect(exception.code, CanvasDataErrorCode.invalidJson);
  expect(exception.message, 'Invalid JSON.');
  expect(exception.path, r'\$.document');
}

void _expectDetailsDeepFrozen(CanvasDataException exception) {
  expect(exception.details['nested'], isA<Map<String, Object?>>());
  expect(() => exception.details['added'] = true, throwsUnsupportedError);

  final nested = exception.details['nested']! as Map<String, Object?>;
  expect(() => nested['added'] = true, throwsUnsupportedError);

  final items = nested['items']! as List<Object?>;
  expect(items, [1, true]);
  expect(() => items.add(false), throwsUnsupportedError);
}

CanvasDataException _readableDetailsException() {
  return CanvasDataException(
    code: CanvasDataErrorCode.fieldMustBeInRange,
    message: 'Out of range.',
    details: {
      'null': null,
      'bool': true,
      'int': 7,
      'double': 1.5,
      'string': 'value',
      'list': <Object?>['a', 2],
      'map': <String, Object?>{'child': 'kept'},
    },
  );
}

void _expectReadableDetails(CanvasDataException exception) {
  expect(exception.details['bool'], isTrue);
  expect(exception.details['int'], 7);
  expect(exception.details['double'], 1.5);
  expect(exception.details['string'], 'value');
  expect(exception.details['list'], ['a', 2]);
  expect(exception.details['map'], {'child': 'kept'});
}

_UnsupportedObjectProjection _unsupportedObjectProjection() {
  final handle = _ApplicationHandle();
  final exception = CanvasDataException(
    code: CanvasDataErrorCode.invalidFieldType,
    message: 'Unsupported value.',
    details: {
      'handle': handle,
      'nested': <String, Object?>{'handle': handle},
    },
  );

  return _UnsupportedObjectProjection(exception.details, handle);
}

void _expectUnsupportedProjection(Map<String, Object?> details) {
  expect(details['handle'], {'unsupportedType': '_ApplicationHandle'});
  expect(details['nested'], {
    'handle': {'unsupportedType': '_ApplicationHandle'},
  });
}

CanvasDataException _boundedDetailsException() {
  return CanvasDataException(
    code: CanvasDataErrorCode.invalidMetadata,
    message: 'Too large.',
    details: {
      'longString': 'x' * 300,
      'longList': List<Object?>.generate(40, (index) => index),
    },
  );
}

void _expectBoundedList(CanvasDataException exception) {
  expect(
    exception.details['longList'],
    List<Object?>.generate(32, (index) => index),
  );
}

bool _containsSameObject(Object? value, Object target) {
  if (identical(value, target)) {
    return true;
  }
  if (value is Map<Object?, Object?>) {
    return value.entries.any(
      (entry) =>
          _containsSameObject(entry.key, target) ||
          _containsSameObject(entry.value, target),
    );
  }
  if (value is Iterable<Object?>) {
    return value.any((entry) => _containsSameObject(entry, target));
  }

  return false;
}

final class _ApplicationHandle {}

final class _UnsupportedObjectProjection {
  const _UnsupportedObjectProjection(this.details, this.handle);

  final Map<String, Object?> details;
  final _ApplicationHandle handle;
}
''';
