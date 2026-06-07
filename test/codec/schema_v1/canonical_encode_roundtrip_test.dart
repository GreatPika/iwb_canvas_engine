import 'package:test/test.dart';

import '../../support/flutter_consumer_test_harness.dart';

void main() {
  test('schema v1 canonical encode roundtrips public DTOs', () async {
    await expectLater(
      runFlutterConsumerTest(
        packageName: 'iwb_canvas_engine_schema_v1_roundtrip',
        testFileName: 'canonical_encode_roundtrip_test.dart',
        testSource: _canonicalEncodeRoundtripSource,
      ),
      completes,
    );
  });
}

const _canonicalEncodeRoundtripSource = r'''
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('canonical encode writes schema v1 fields and preserves order', () {
    final document = CanvasDocument(
      camera: CanvasCamera(offset: const Offset(12, -7)),
      background: CanvasBackground(
        color: const Color(0xff112233),
        grid: CanvasGrid(enabled: true, cellSize: 20, color: const Color(0x1f445566)),
      ),
      palette: CanvasPalette(
        penColors: const [Color(0xff000000), Color(0xffe53935)],
        backgroundColors: const [Color(0xffffffff)],
        gridSizes: const [10, 20],
      ),
      resources: [
        CanvasImageResource(
          id: CanvasResourceId('image-a'),
          source: CanvasResourceSource.appKey('image-a'),
          mimeType: 'image/png',
          contentHash: 'hash-a',
          byteLength: 42,
          metadata: CanvasMetadata.fromMap({
            'owner': 'resource',
            'variants': ['thumbnail', 'full'],
          }),
        ),
      ],
      backgroundElements: [
        CanvasRectElement(
          id: CanvasElementId('rect-a'),
          revision: 11,
          transform: CanvasTransform(a: 1, b: 0, c: 0, d: 1, tx: 5, ty: -3),
          opacity: 0.75,
          hitPadding: 4,
          isVisible: false,
          isSelectable: false,
          isLocked: true,
          isDeletable: false,
          isTransformable: false,
          size: const Size(20, 10),
          fillColor: const Color(0x330000ff),
          strokeColor: const Color(0xff0000ff),
          strokeWidth: 2,
          metadata: CanvasMetadata.fromMap({
            'owner': 'backgroundElement',
            'nested': {'z': 0},
          }),
        ),
      ],
      layers: [
        CanvasLayer(
          id: CanvasLayerId('layer-a'),
          metadata: CanvasMetadata.fromMap({
            'owner': 'layer',
            'visible': true,
          }),
          elements: [
            CanvasTextElement(
              id: CanvasElementId('text-a'),
              text: 'hello',
              fontSize: 18,
              color: const Color(0xffabcdef),
              align: TextAlign.right,
              textDirection: TextDirection.rtl,
              isBold: true,
              isItalic: true,
              isUnderline: true,
              fontFamily: 'Inter',
              maxWidth: 240,
              lineHeight: 1.5,
              revision: 21,
              transform: CanvasTransform(a: 1, b: 0, c: 0, d: 1, tx: 1, ty: 2),
              opacity: 0.9,
              hitPadding: 1.5,
              isSelectable: false,
              metadata: CanvasMetadata.fromMap({'owner': 'text'}),
            ),
            CanvasImageElement(
              id: CanvasElementId('image-element-a'),
              resourceId: CanvasResourceId('image-a'),
              size: const Size(64, 32),
              naturalSize: const Size(128, 64),
              revision: 22,
              transform: CanvasTransform(a: 1.2, b: 0, c: 0, d: 1.1, tx: 3, ty: 4),
              opacity: 0.8,
              hitPadding: 2,
              isLocked: true,
              metadata: CanvasMetadata.fromMap({'owner': 'imageElement'}),
            ),
            CanvasPathElement(
              id: CanvasElementId('path-a'),
              svgPathData: 'M 0 0 L 10 10',
              fillColor: const Color(0xff00ff00),
              strokeColor: const Color(0xff000000),
              strokeWidth: 1,
              fillRule: CanvasPathFillRule.evenOdd,
              revision: 23,
              transform: CanvasTransform(a: 0.9, b: 0.1, c: -0.1, d: 0.9, tx: 5, ty: 6),
              opacity: 0.7,
              hitPadding: 3,
              isDeletable: false,
              metadata: CanvasMetadata.fromMap({'owner': 'path'}),
            ),
            CanvasStrokeElement(
              id: CanvasElementId('stroke-a'),
              points: const [Offset(0, 0), Offset(1, 1), Offset(2, 1.5)],
              thickness: 3,
              color: const Color(0xff123456),
              revision: 24,
              transform: CanvasTransform(a: 1, b: 0, c: 0.2, d: 1, tx: 7, ty: 8),
              opacity: 0.6,
              hitPadding: 4,
              isTransformable: false,
              metadata: CanvasMetadata.fromMap({'owner': 'stroke'}),
            ),
            CanvasLineElement(
              id: CanvasElementId('line-a'),
              start: const Offset(1, 2),
              end: const Offset(3, 4),
              thickness: 2,
              color: const Color(0xff654321),
              revision: 25,
              transform: CanvasTransform(a: 1, b: -0.1, c: 0.1, d: 1, tx: 9, ty: 10),
              opacity: 0.5,
              hitPadding: 5,
              isVisible: false,
              metadata: CanvasMetadata.fromMap({'owner': 'line'}),
            ),
          ],
        ),
      ],
      metadata: CanvasMetadata.fromMap({
        'owner': 'document',
        'flags': {'canonical': true},
      }),
    );

    final encoded = encodeCanvasDocument(document);
    _expectKeys(encoded, _rootKeys);
    expect(encoded['schemaVersion'], 1);
    expect(encoded.containsKey('backgroundElements'), isFalse);
    _expectKeys(encoded['camera'] as Map<String, Object?>, _cameraKeys);
    _expectKeys(encoded['background'] as Map<String, Object?>, _backgroundKeys);
    _expectKeys(
      (encoded['background'] as Map<String, Object?>)['grid'] as Map<String, Object?>,
      _gridKeys,
    );
    _expectKeys(encoded['palette'] as Map<String, Object?>, _paletteKeys);
    expect(encoded['backgroundLayer'], isA<Map<String, Object?>>());

    final resource = (encoded['resources'] as List<Object?>).single as Map<String, Object?>;
    _expectKeys(resource, _resourceKeys);
    _expectKeys(resource['source'] as Map<String, Object?>, _resourceSourceKeys);
    expect(resource, {
      'id': 'image-a',
      'kind': 'image',
      'source': {'kind': 'appKey', 'key': 'image-a'},
      'mimeType': 'image/png',
      'contentHash': 'hash-a',
      'byteLength': 42,
      'metadata': {
        'owner': 'resource',
        'variants': ['thumbnail', 'full'],
      },
    });

    final backgroundLayer = encoded['backgroundLayer'] as Map<String, Object?>;
    _expectKeys(backgroundLayer, _backgroundLayerKeys);
    final backgroundElements = backgroundLayer['elements'] as List<Object?>;
    final rect = backgroundElements.single as Map<String, Object?>;
    _expectKeys(rect, _rectElementKeys);
    expect(rect['fillColor'], '#330000FF');
    expect(rect['strokeColor'], '#FF0000FF');

    final layers = encoded['layers'] as List<Object?>;
    final firstLayer = layers.single as Map<String, Object?>;
    _expectKeys(firstLayer, _layerKeys);
    final elements = firstLayer['elements'] as List<Object?>;
    expect(elements.map((element) => (element as Map<String, Object?>)['id']), [
      'text-a',
      'image-element-a',
      'path-a',
      'stroke-a',
      'line-a',
    ]);
    final text = elements.first as Map<String, Object?>;
    _expectKeys(text, _textElementKeys);
    expect(text['color'], '#FFABCDEF');
    expect(text['fontFamily'], 'Inter');
    expect(text['maxWidth'], 240);
    expect(text['lineHeight'], 1.5);
    _expectKeys(elements[1] as Map<String, Object?>, _imageElementKeys);
    _expectKeys(elements[2] as Map<String, Object?>, _pathElementKeys);
    _expectKeys(elements[3] as Map<String, Object?>, _strokeElementKeys);
    _expectKeys(elements[4] as Map<String, Object?>, _lineElementKeys);

    final decoded = decodeSchemaV1Document(encoded);
    _expectDocumentEquivalent(decoded, document);
    _expectDocumentEquivalent(
      decodeSchemaV1DocumentFromJson(encodeCanvasDocumentToJson(document)),
      document,
    );
    expect(jsonDecode(encodeCanvasDocumentToJson(document)), isA<Map<String, Object?>>());
  });

  test('encode rejects document facts that schema decode would reject', () {
    expect(
      () => encodeCanvasDocument(
        CanvasDocument(
          backgroundElements: [
            CanvasImageElement(
              id: CanvasElementId('missing-image'),
              resourceId: CanvasResourceId('missing-resource'),
              size: const Size(1, 1),
            ),
          ],
        ),
      ),
      throwsA(
        isA<CanvasDataException>().having(
          (error) => error.code,
          'code',
          CanvasDataErrorCode.missingResourceReference,
        ),
      ),
    );
  });
}

void _expectKeys(Map<String, Object?> value, Set<String> expected) {
  expect(value.keys.toSet(), expected);
}

void _expectDocumentEquivalent(CanvasDocument actual, CanvasDocument expected) {
  expect(actual.camera, expected.camera);
  expect(actual.background, expected.background);
  expect(actual.palette.penColors, expected.palette.penColors);
  expect(actual.palette.backgroundColors, expected.palette.backgroundColors);
  expect(actual.palette.gridSizes, expected.palette.gridSizes);
  expect(actual.metadata, expected.metadata);
  _expectResourcesEquivalent(actual.resources, expected.resources);
  _expectElementsEquivalent(actual.backgroundElements, expected.backgroundElements);
  _expectLayersEquivalent(actual.layers, expected.layers);
}

void _expectResourcesEquivalent(
  List<CanvasResource> actual,
  List<CanvasResource> expected,
) {
  expect(actual, hasLength(expected.length));
  for (var index = 0; index < expected.length; index += 1) {
    _expectResourceEquivalent(actual[index], expected[index]);
  }
}

void _expectResourceEquivalent(CanvasResource actual, CanvasResource expected) {
  expect(actual.id.value, expected.id.value);
  _expectResourceSourceEquivalent(actual.source, expected.source);
  expect(actual.contentHash, expected.contentHash);
  expect(actual.byteLength, expected.byteLength);
  expect(actual.metadata, expected.metadata);

  expect(actual, isA<CanvasImageResource>());
  expect(expected, isA<CanvasImageResource>());
  expect(
    (actual as CanvasImageResource).mimeType,
    (expected as CanvasImageResource).mimeType,
  );
}

void _expectResourceSourceEquivalent(
  CanvasResourceSource actual,
  CanvasResourceSource expected,
) {
  expect(actual, isA<CanvasAppKeyResourceSource>());
  expect(expected, isA<CanvasAppKeyResourceSource>());
  expect(
    (actual as CanvasAppKeyResourceSource).key,
    (expected as CanvasAppKeyResourceSource).key,
  );
}

void _expectLayersEquivalent(List<CanvasLayer> actual, List<CanvasLayer> expected) {
  expect(actual, hasLength(expected.length));
  for (var index = 0; index < expected.length; index += 1) {
    expect(actual[index].id.value, expected[index].id.value);
    expect(actual[index].metadata, expected[index].metadata);
    _expectElementsEquivalent(actual[index].elements, expected[index].elements);
  }
}

void _expectElementsEquivalent(
  List<CanvasElement> actual,
  List<CanvasElement> expected,
) {
  expect(actual, hasLength(expected.length));
  for (var index = 0; index < expected.length; index += 1) {
    _expectElementEquivalent(actual[index], expected[index]);
  }
}

void _expectElementEquivalent(CanvasElement actual, CanvasElement expected) {
  expect(actual.id.value, expected.id.value);
  expect(actual.kind, expected.kind);
  expect(actual.revision, expected.revision);
  expect(actual.transform, expected.transform);
  expect(actual.opacity, expected.opacity);
  expect(actual.hitPadding, expected.hitPadding);
  expect(actual.isVisible, expected.isVisible);
  expect(actual.isSelectable, expected.isSelectable);
  expect(actual.isLocked, expected.isLocked);
  expect(actual.isDeletable, expected.isDeletable);
  expect(actual.isTransformable, expected.isTransformable);
  expect(actual.metadata, expected.metadata);

  if (actual is CanvasImageElement && expected is CanvasImageElement) {
    expect(actual.resourceId.value, expected.resourceId.value);
    expect(actual.size, expected.size);
    expect(actual.naturalSize, expected.naturalSize);
  } else if (actual is CanvasPathElement && expected is CanvasPathElement) {
    expect(actual.svgPathData, expected.svgPathData);
    expect(actual.fillColor, expected.fillColor);
    expect(actual.strokeColor, expected.strokeColor);
    expect(actual.strokeWidth, expected.strokeWidth);
    expect(actual.fillRule, expected.fillRule);
  } else if (actual is CanvasTextElement && expected is CanvasTextElement) {
    expect(actual.text, expected.text);
    expect(actual.fontSize, expected.fontSize);
    expect(actual.color, expected.color);
    expect(actual.align, expected.align);
    expect(actual.textDirection, expected.textDirection);
    expect(actual.isBold, expected.isBold);
    expect(actual.isItalic, expected.isItalic);
    expect(actual.isUnderline, expected.isUnderline);
    expect(actual.fontFamily, expected.fontFamily);
    expect(actual.maxWidth, expected.maxWidth);
    expect(actual.lineHeight, expected.lineHeight);
  } else if (actual is CanvasStrokeElement && expected is CanvasStrokeElement) {
    expect(actual.points, expected.points);
    expect(actual.thickness, expected.thickness);
    expect(actual.color, expected.color);
  } else if (actual is CanvasLineElement && expected is CanvasLineElement) {
    expect(actual.start, expected.start);
    expect(actual.end, expected.end);
    expect(actual.thickness, expected.thickness);
    expect(actual.color, expected.color);
  } else if (actual is CanvasRectElement && expected is CanvasRectElement) {
    expect(actual.size, expected.size);
    expect(actual.fillColor, expected.fillColor);
    expect(actual.strokeColor, expected.strokeColor);
    expect(actual.strokeWidth, expected.strokeWidth);
  } else {
    fail('unexpected element pair: ${actual.runtimeType} vs ${expected.runtimeType}');
  }
}

const _rootKeys = {
  'schemaVersion',
  'camera',
  'background',
  'palette',
  'resources',
  'backgroundLayer',
  'layers',
  'metadata',
};

const _cameraKeys = {'offset'};
const _backgroundKeys = {'color', 'grid'};
const _gridKeys = {'enabled', 'cellSize', 'color'};
const _paletteKeys = {'penColors', 'backgroundColors', 'gridSizes'};
const _resourceKeys = {
  'id',
  'kind',
  'source',
  'mimeType',
  'contentHash',
  'byteLength',
  'metadata',
};
const _resourceSourceKeys = {'kind', 'key'};
const _backgroundLayerKeys = {'elements'};
const _layerKeys = {'id', 'elements', 'metadata'};
const _commonElementKeys = {
  'id',
  'kind',
  'revision',
  'transform',
  'opacity',
  'hitPadding',
  'isVisible',
  'isSelectable',
  'isLocked',
  'isDeletable',
  'isTransformable',
  'metadata',
};
const _imageElementKeys = {
  ..._commonElementKeys,
  'resourceId',
  'size',
  'naturalSize',
};
const _pathElementKeys = {
  ..._commonElementKeys,
  'svgPathData',
  'fillColor',
  'strokeColor',
  'strokeWidth',
  'fillRule',
};
const _textElementKeys = {
  ..._commonElementKeys,
  'text',
  'fontSize',
  'color',
  'align',
  'textDirection',
  'isBold',
  'isItalic',
  'isUnderline',
  'fontFamily',
  'maxWidth',
  'lineHeight',
};
const _strokeElementKeys = {
  ..._commonElementKeys,
  'points',
  'thickness',
  'color',
};
const _lineElementKeys = {
  ..._commonElementKeys,
  'start',
  'end',
  'thickness',
  'color',
};
const _rectElementKeys = {
  ..._commonElementKeys,
  'size',
  'fillColor',
  'strokeColor',
  'strokeWidth',
};
''';
