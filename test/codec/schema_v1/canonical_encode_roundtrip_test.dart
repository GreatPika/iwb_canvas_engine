import 'package:test/test.dart';

import 'schema_v1_consumer_harness.dart';

void main() {
  test('schema v1 canonical encode roundtrips public DTOs', () async {
    await expectLater(
      runSchemaV1ConsumerTest(
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
            ),
          ],
        ),
      ],
    );

    final encoded = encodeCanvasDocument(document);
    expect(encoded['schemaVersion'], 1);
    expect(encoded.containsKey('backgroundElements'), isFalse);
    expect(encoded['backgroundLayer'], isA<Map<String, Object?>>());
    expect((encoded['resources'] as List<Object?>).single, {
      'id': 'image-a',
      'kind': 'image',
      'source': {'kind': 'appKey', 'key': 'image-a'},
      'mimeType': 'image/png',
      'contentHash': 'hash-a',
      'byteLength': 42,
      'metadata': {},
    });

    final backgroundLayer = encoded['backgroundLayer'] as Map<String, Object?>;
    final backgroundElements = backgroundLayer['elements'] as List<Object?>;
    final rect = backgroundElements.single as Map<String, Object?>;
    expect(rect['fillColor'], '#330000FF');
    expect(rect['strokeColor'], '#FF0000FF');
    expect(rect.keys, containsAll(['revision', 'transform', 'opacity', 'metadata']));

    final layers = encoded['layers'] as List<Object?>;
    final firstLayer = layers.single as Map<String, Object?>;
    final elements = firstLayer['elements'] as List<Object?>;
    expect(elements.map((element) => (element as Map<String, Object?>)['id']), [
      'text-a',
      'image-element-a',
    ]);
    final text = elements.first as Map<String, Object?>;
    expect(text['color'], '#FFABCDEF');
    expect(text['fontFamily'], isNull);
    expect(text['maxWidth'], isNull);
    expect(text['lineHeight'], isNull);

    final decoded = decodeCanvasDocument(encoded);
    expect(decoded.layers.single.elements.map((element) => element.id.value), [
      'text-a',
      'image-element-a',
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
''';
