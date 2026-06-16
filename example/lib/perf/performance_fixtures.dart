import 'dart:ui';

import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

const performanceLoadDocument100kFixtureId = 'load_document.100k';
const performanceCameraPan100kFixtureId = 'camera_pan.100k';
const performancePrimaryRectId = 'r0';
const performancePrimaryTextId = 't0';
const performancePrimaryResourceId = 'res0';
const performanceMissingResourceId = 'missing-res';

CanvasDocument performanceRectDocument(int elementCount) {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('l0'),
        elements: List<CanvasElement>.generate(
          elementCount,
          _performanceRectElement,
          growable: false,
        ),
      ),
    ],
  );
}

CanvasDocument performanceTextDocument({int rectCount = 0}) {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('l0'),
        elements: [
          CanvasTextElement(
            id: CanvasElementId(performancePrimaryTextId),
            transform: CanvasTransform.translation(const Offset(0, 32)),
            text: 'editable',
            color: const Color(0xFF222222),
            textDirection: TextDirection.ltr,
            fontSize: 20,
            maxWidth: 160,
          ),
          for (var index = 0; index < rectCount; index += 1)
            _performanceRectElement(index),
        ],
      ),
    ],
  );
}

CanvasDocument performanceResourceDocument({
  required String resourceId,
  required String appKey,
}) {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId(resourceId),
        source: CanvasResourceSource.appKey(appKey),
        mimeType: 'image/png',
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('l0'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('img0'),
            resourceId: CanvasResourceId(resourceId),
            size: const Size(48, 48),
            naturalSize: const Size(48, 48),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument performanceMissingResourceDocument() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId(performanceMissingResourceId),
        source: CanvasResourceSource.appKey('missing-image'),
        mimeType: 'image/png',
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('l0'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('missing-img'),
            resourceId: CanvasResourceId(performanceMissingResourceId),
            size: const Size(48, 48),
            naturalSize: const Size(48, 48),
          ),
        ],
      ),
    ],
  );
}

int performanceElementCount(CanvasDocument document) {
  return document.backgroundElements.length +
      document.layers.fold<int>(
        0,
        (count, layer) => count + layer.elements.length,
      );
}

String performanceFixtureJson(CanvasDocument document) {
  return encodeCanvasDocumentToJson(document);
}

CanvasRectElement _performanceRectElement(int index) {
  final column = index % 1000;
  final row = index ~/ 1000;

  return CanvasRectElement(
    id: CanvasElementId('r$index'),
    transform: CanvasTransform.translation(Offset(column * 3.0, row * 3.0)),
    size: const Size(2, 2),
  );
}
