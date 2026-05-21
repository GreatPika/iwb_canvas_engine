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
        ),
      ],
      backgroundElements: [
        CanvasRectElement(
          id: CanvasElementId('rect-a'),
          size: const Size(20, 10),
          fillColor: const Color(0x330000ff),
          strokeColor: const Color(0xff0000ff),
          strokeWidth: 2,
        ),
      ],
      layers: [
        CanvasLayer(
          id: CanvasLayerId('layer-a'),
          elements: [
            CanvasTextElement(
              id: CanvasElementId('text-a'),
              text: 'hello',
              fontSize: 18,
              color: const Color(0xffabcdef),
              textDirection: TextDirection.ltr,
              isBold: true,
            ),
            CanvasImageElement(
              id: CanvasElementId('image-element-a'),
              resourceId: CanvasResourceId('image-a'),
              size: const Size(64, 32),
              naturalSize: const Size(128, 64),
            ),
            CanvasPathElement(
              id: CanvasElementId('path-a'),
              svgPathData: 'M 0 0 L 10 10',
              fillColor: const Color(0xff00ff00),
              strokeColor: const Color(0xff000000),
              strokeWidth: 1,
              fillRule: CanvasPathFillRule.evenOdd,
            ),
            CanvasStrokeElement(
              id: CanvasElementId('stroke-a'),
              points: const [Offset(0, 0), Offset(1, 1)],
              thickness: 3,
              color: const Color(0xff123456),
            ),
            CanvasLineElement(
              id: CanvasElementId('line-a'),
              start: const Offset(1, 2),
              end: const Offset(3, 4),
              thickness: 2,
              color: const Color(0xff654321),
            ),
          ],
        ),
      ],
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
      'metadata': {},
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
    expect(text['fontFamily'], isNull);
    expect(text['maxWidth'], isNull);
    expect(text['lineHeight'], isNull);
    _expectKeys(elements[1] as Map<String, Object?>, _imageElementKeys);
    _expectKeys(elements[2] as Map<String, Object?>, _pathElementKeys);
    _expectKeys(elements[3] as Map<String, Object?>, _strokeElementKeys);
    _expectKeys(elements[4] as Map<String, Object?>, _lineElementKeys);

    final decoded = decodeCanvasDocument(encoded);
    expect(decoded.layers.single.elements.map((element) => element.id.value), [
      'text-a',
      'image-element-a',
      'path-a',
      'stroke-a',
      'line-a',
    ]);
    expect(decodeCanvasDocumentFromJson(encodeCanvasDocumentToJson(document)), isA<CanvasDocument>());
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
