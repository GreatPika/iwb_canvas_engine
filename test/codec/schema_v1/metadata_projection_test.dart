import 'package:test/test.dart';

import '../../support/flutter_consumer_test_harness.dart';

void main() {
  test('schema v1 metadata projects through CanvasMetadata only', () async {
    await expectLater(
      runFlutterConsumerTest(
        packageName: 'iwb_canvas_engine_schema_v1_metadata_projection',
        testFileName: 'metadata_projection_test.dart',
        testSource: _metadataProjectionSource,
      ),
      completes,
    );
  });
}

const _metadataProjectionSource = r'''
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('metadata decodes to CanvasMetadata and encodes as JSON object', () {
    final source = <String, Object?>{
      'schemaVersion': 1,
      'camera': {
        'offset': {'x': 0, 'y': 0},
      },
      'background': {
        'color': '#FFFFFFFF',
        'grid': {'enabled': false, 'cellSize': 10, 'color': '#1F000000'},
      },
      'palette': {
        'penColors': <Object?>[],
        'backgroundColors': <Object?>[],
        'gridSizes': <Object?>[],
      },
      'resources': [
        {
          'id': 'resource-a',
          'kind': 'image',
          'source': {'kind': 'appKey', 'key': 'resource-a'},
          'mimeType': 'image/png',
          'contentHash': 'hash-a',
          'byteLength': 12,
          'metadata': _metadataJson('resource'),
          'unknownResourceField': true,
        },
      ],
      'backgroundLayer': {
        'elements': [
          {
            'id': 'background-rect-a',
            'kind': 'rect',
            'revision': 1,
            'transform': _identityTransform,
            'opacity': 1,
            'hitPadding': 0,
            'isVisible': true,
            'isSelectable': true,
            'isLocked': false,
            'isDeletable': true,
            'isTransformable': true,
            'metadata': _metadataJson('backgroundElement'),
            'size': {'w': 20, 'h': 10},
            'fillColor': '#330000FF',
            'strokeColor': '#FF0000FF',
            'strokeWidth': 2,
            'unknownBackgroundElementField': true,
          },
        ],
      },
      'layers': [
        {
          'id': 'layer-a',
          'elements': [
            {
              'id': 'layer-image-a',
              'kind': 'image',
              'revision': 2,
              'transform': _identityTransform,
              'opacity': 0.9,
              'hitPadding': 1,
              'isVisible': true,
              'isSelectable': true,
              'isLocked': false,
              'isDeletable': true,
              'isTransformable': true,
              'metadata': _metadataJson('layerElement'),
              'resourceId': 'resource-a',
              'size': {'w': 64, 'h': 32},
              'naturalSize': {'w': 128, 'h': 64},
              'unknownLayerElementField': true,
            },
          ],
          'metadata': _metadataJson('layer'),
          'unknownLayerField': true,
        },
      ],
      'metadata': _metadataJson('whiteboard'),
      'unknownNonMetadata': {'discard': true},
    };

    final document = decodeSchemaV1Document(source);
    expect(document.metadata, isA<CanvasMetadata>());
    _expectMetadataProjection(document.metadata, 'whiteboard');
    _expectMetadataProjection(document.resources.single.metadata, 'resource');
    _expectMetadataProjection(
      document.backgroundElements.single.metadata,
      'backgroundElement',
    );
    _expectMetadataProjection(document.layers.single.metadata, 'layer');
    _expectMetadataProjection(
      document.layers.single.elements.single.metadata,
      'layerElement',
    );

    final encoded = encodeCanvasDocument(document);
    expect(encoded.containsKey('unknownNonMetadata'), isFalse);
    _expectEncodedMetadataOwner(encoded, 'whiteboard');

    final resource = (encoded['resources'] as List<Object?>).single as Map<String, Object?>;
    expect(resource.containsKey('unknownResourceField'), isFalse);
    _expectEncodedMetadataOwner(resource, 'resource');

    final backgroundLayer = encoded['backgroundLayer'] as Map<String, Object?>;
    final backgroundElement =
        (backgroundLayer['elements'] as List<Object?>).single as Map<String, Object?>;
    expect(backgroundElement.containsKey('unknownBackgroundElementField'), isFalse);
    _expectEncodedMetadataOwner(backgroundElement, 'backgroundElement');

    final layer = (encoded['layers'] as List<Object?>).single as Map<String, Object?>;
    expect(layer.containsKey('unknownLayerField'), isFalse);
    _expectEncodedMetadataOwner(layer, 'layer');

    final layerElement = (layer['elements'] as List<Object?>).single as Map<String, Object?>;
    expect(layerElement.containsKey('unknownLayerElementField'), isFalse);
    _expectEncodedMetadataOwner(layerElement, 'layerElement');
  });
}

Map<String, Object?> _metadataJson(String owner) {
  return {
    'owner': owner,
    'nested': {
      'labels': ['alpha', owner],
    },
  };
}

void _expectMetadataProjection(CanvasMetadata metadata, String owner) {
  expect(metadata, isA<CanvasMetadata>());
  expect(metadata['owner'], owner);
  final nested = metadata['nested'] as Map<String, Object?>;
  expect(nested['labels'], ['alpha', owner]);
}

void _expectEncodedMetadataOwner(Map<String, Object?> owner, String ownerName) {
  final metadata = owner['metadata'] as Map<String, Object?>;
  expect(metadata, _metadataJson(ownerName));
  expect(() => metadata['new'] = true, throwsUnsupportedError);

  final nested = metadata['nested'] as Map<String, Object?>;
  expect(() => nested['labels'] = const [], throwsUnsupportedError);

  final labels = nested['labels'] as List<Object?>;
  expect(() => labels.add('new'), throwsUnsupportedError);
}

const _identityTransform = {
  'a': 1,
  'b': 0,
  'c': 0,
  'd': 1,
  'tx': 0,
  'ty': 0,
};
''';
