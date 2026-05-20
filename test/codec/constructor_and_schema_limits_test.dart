import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test('public constructors and schema boundary enforce limits', () async {
    expect(
      await _runFlutterConsumerTest(_constructorAndSchemaLimitsTestSource),
      isTrue,
    );
  });
}

Future<bool> _runFlutterConsumerTest(String testSource) async {
  final packageDir = await Directory.systemTemp.createTemp(
    'iwb_canvas_engine_validation_limits_consumer_',
  );

  try {
    await Directory('${packageDir.path}/test').create();
    await File(
      '${packageDir.path}/pubspec.yaml',
    ).writeAsString(_pubspecSource());
    await File(
      '${packageDir.path}/test/validation_limits_test.dart',
    ).writeAsString(testSource);

    final pubGet = await Process.run('flutter', [
      'pub',
      'get',
    ], workingDirectory: packageDir.path);
    expect(pubGet.exitCode, 0, reason: _processOutput(pubGet));

    final test = await Process.run('flutter', [
      'test',
      'test/validation_limits_test.dart',
    ], workingDirectory: packageDir.path);
    expect(test.exitCode, 0, reason: _processOutput(test));

    return true;
  } finally {
    await packageDir.delete(recursive: true);
  }
}

String _pubspecSource() {
  return '''
name: iwb_canvas_engine_validation_limits_consumer
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

const _constructorAndSchemaLimitsTestSource = '''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('public constructors reject invalid geometry and scalar limits', () {
    expect(
      CanvasTransform(a: 1, b: 0, c: 0, d: 0, tx: 0, ty: 0),
      isA<CanvasTransform>(),
    );
    expect(
      () => CanvasRectElement(
        id: CanvasElementId('rect-invalid-transform'),
        size: const Size(1, 1),
        transform: CanvasTransform(a: 1, b: 0, c: 0, d: 0, tx: 0, ty: 0),
      ),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasTransform(a: 1, b: 0, c: 0, d: 1, tx: double.nan, ty: 0),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasGrid(enabled: true, cellSize: 0.5),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasDiagnosticsVerbose(maxPreviewLength: 0),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasPointerPolicy(tapSlop: -1),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasDrawStyle(markerOpacity: 2),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasSelectionStyle(strokeWidth: double.nan),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasSelectionStyle(marqueeFillOpacity: 2),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasSelectionStyle(haloWidth: -1),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasGridStyle(strokeWidth: -1),
      throwsA(isA<CanvasDataException>()),
    );
  });

  test('public DTO constructors reject invalid content limits', () {
    final id = CanvasElementId('element-1');

    expect(
      () => CanvasTextElement(
        id: id,
        text: 'x' * 100001,
        color: const Color(0xFF000000),
        textDirection: TextDirection.ltr,
      ),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasStrokeElement(
        id: id,
        points: List.filled(20001, Offset.zero),
        thickness: 1,
        color: const Color(0xFF000000),
      ),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasImageElement(
        id: id,
        resourceId: CanvasResourceId('resource-1'),
        size: Size.zero,
      ),
      throwsA(isA<CanvasDataException>()),
    );
  });

  test('metadata is deep frozen and limited at construction', () {
    final nested = <String, Object?>{
      'tags': <Object?>[
        <String, Object?>{'name': 'stable'},
      ],
    };
    final metadata = CanvasMetadata.fromMap(nested);
    nested['tags'] = const ['mutated'];

    expect(metadata['tags'], isNot(equals(['mutated'])));
    final spacedKeyMetadata = CanvasMetadata.fromMap({' app:key ': true});
    expect(spacedKeyMetadata.keys.single, ' app:key ');
    expect(spacedKeyMetadata[' app:key '], isTrue);
    final unusualKeysMetadata = CanvasMetadata.fromMap({
      '': true,
      'line\\nbreak': true,
    });
    expect(unusualKeysMetadata[''], isTrue);
    expect(unusualKeysMetadata['line\\nbreak'], isTrue);
    expect(
      () => CanvasMetadata.fromMap({
        'a': {
          'b': {
            'c': {
              'd': {
                'e': {
                  'f': {
                    'g': {
                      'h': {'i': true},
                    },
                  },
                },
              },
            },
          },
        },
      }),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasMetadata.fromMap({'k' * 257: true}),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasMetadata.fromMap({'long': 'x' * 65537}),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasMetadata.fromMap({'largeUtf8': '🙂' * 270000}),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasMetadata.fromMap({
        for (var index = 0; index < 1025; index++) 'k\$index': true,
      }),
      throwsA(isA<CanvasDataException>()),
    );
    final largeMetadata = CanvasMetadata.fromMap({
      for (var index = 0; index < 9; index++) 'k\$index': 'x' * 65536,
    });
    expect(
      () => CanvasDocument(
        metadata: largeMetadata,
        resources: [
          CanvasImageResource(
            id: CanvasResourceId('resource-with-large-metadata'),
            source: CanvasResourceSource.appKey('resource-with-large-metadata'),
            metadata: largeMetadata,
          ),
        ],
      ),
      throwsA(isA<CanvasDataException>()),
    );
  });

  test('schema boundary validates known root fields and JSON shape', () {
    expect(
      decodeCanvasDocument({'schemaVersion': 1, 'unknown': true}),
      isA<CanvasDocument>(),
    );
    expect(
      () => decodeCanvasDocument({
        'schemaVersion': 1,
        'metadata': {
          'bad': double.nan,
        },
      }),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => decodeCanvasDocument({
        'schemaVersion': 1,
        'resources': [
          {
            'id': 'resource-1',
            'kind': 'image',
            'source': {'kind': 'appKey', 'key': 'resource-1'},
          },
          {
            'id': 'resource-1',
            'kind': 'image',
            'source': {'kind': 'appKey', 'key': 'resource-1'},
          },
        ],
      }),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => decodeCanvasDocument({
        'schemaVersion': 1,
        'camera': null,
      }),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => decodeCanvasDocument({
        'schemaVersion': 1,
        'resources': null,
      }),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => decodeCanvasDocument({
        'schemaVersion': 1,
        'metadata': null,
      }),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => decodeCanvasDocument({
        'schemaVersion': 1,
        'backgroundElements': [
          {
            'id': 'image-1',
            'kind': 'image',
            'resourceId': 'missing-resource',
            'size': {'w': 1, 'h': 1},
          },
        ],
      }),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => decodeCanvasDocument({
        'schemaVersion': 1,
        'backgroundElements': [
          {
            'id': 'text-null-transform',
            'kind': 'text',
            'text': 'bad transform null',
            'color': '#FF000000',
            'transform': null,
          },
        ],
      }),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => decodeCanvasDocumentFromJson('[]'),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => decodeCanvasDocumentFromJson('{'),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => decodeCanvasDocument({
        'schemaVersion': 1,
        'backgroundElements': [
          {
            'id': 'text-missing-color',
            'kind': 'text',
            'text': 'missing color',
            'textDirection': 'ltr',
          },
        ],
      }),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => decodeCanvasDocument({
        'schemaVersion': 1,
        'backgroundElements': [
          {
            'id': 'text-null-known-field',
            'kind': 'text',
            'text': 'bad null',
            'color': '#FF000000',
            'isBold': null,
          },
        ],
      }),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => decodeCanvasDocument({
        'schemaVersion': 1,
        'backgroundElements': [
          {
            'id': 'text-null-enum',
            'kind': 'text',
            'text': 'bad enum null',
            'color': '#FF000000',
            'align': null,
          },
        ],
      }),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      decodeCanvasDocument({'schemaVersion': 1}),
      isA<CanvasDocument>(),
    );
  });

  test('edit update construction validates set values', () {
    final id = CanvasElementId('update-target');

    expect(
      () => CanvasTextElementUpdate(
        id: id,
        opacity: const CanvasFieldSet(2),
      ),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasTextElementUpdate(
        id: id,
        transform: CanvasFieldSet(
          CanvasTransform(a: 1, b: 0, c: 0, d: 0, tx: 0, ty: 0),
        ),
      ),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasStrokeElementUpdate(
        id: id,
        points: const CanvasFieldSet([]),
      ),
      throwsA(isA<CanvasDataException>()),
    );
    final callerOwnedPoints = [Offset.zero];
    final update = CanvasStrokeElementUpdate(
      id: id,
      points: CanvasFieldSet(callerOwnedPoints),
    );
    callerOwnedPoints.clear();

    final pointsUpdate = update.points as CanvasFieldSet<List<Offset>>;
    expect(pointsUpdate.value, hasLength(1));
    expect(() => pointsUpdate.value.clear(), throwsUnsupportedError);
  });

  test('resource construction validates payload limits', () {
    final id = CanvasResourceId('resource-payload');
    final source = CanvasResourceSource.appKey('resource-payload');

    expect(
      () => CanvasImageResource(
        id: id,
        source: source,
        byteLength: 32 * 1024 * 1024 + 1,
      ),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasImageResource(id: id, source: source, contentHash: ''),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasImageResource(id: id, source: source, mimeType: 'm' * 129),
      throwsA(isA<CanvasDataException>()),
    );
  });
}
''';
