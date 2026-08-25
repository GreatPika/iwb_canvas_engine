import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import '../../support/runtime_with_document.dart';

void main() {
  test('generated ids skip committed ids and advance per runtime', () {
    final runtime = runtimeWithDocument(_document());

    expect(runtime.generateElementId(), CanvasElementId('e1'));
    _expectGeneratedIds(runtime);

    runtime.dispose();
    _expectGeneratorsRejectDisposedRuntime(runtime);
  });

  test('store admission rejects duplicate committed ids', () {
    expect(
      () => runtimeWithDocument(_documentWithDuplicateElementIds()),
      throwsA(isA<CanvasDataException>()),
    );
    _expectDuplicateAdmissionRejected(
      _documentWithDuplicateElementIds(),
      CanvasDataErrorCode.duplicateElementId,
    );
    _expectDuplicateAdmissionRejected(
      _documentWithDuplicateLayerIds(),
      CanvasDataErrorCode.duplicateLayerId,
    );
    _expectDuplicateAdmissionRejected(
      _documentWithDuplicateResourceIds(),
      CanvasDataErrorCode.duplicateResourceId,
    );
    _expectDuplicateAdmissionRejected(
      _documentWithMissingResourceReference(),
      CanvasDataErrorCode.missingResourceReference,
    );
  });
}

void _expectGeneratedIds(CanvasRuntime runtime) {
  expect(runtime.generateElementId(), CanvasElementId('e3'));
  expect(runtime.generateLayerId(), CanvasLayerId('l1'));
  expect(runtime.generateLayerId(), CanvasLayerId('l2'));
  expect(runtime.generateResourceId(), CanvasResourceId('r1'));
  expect(runtime.generateResourceId(), CanvasResourceId('r2'));
}

void _expectGeneratorsRejectDisposedRuntime(CanvasRuntime runtime) {
  expect(runtime.generateElementId, throwsStateError);
  expect(runtime.generateLayerId, throwsStateError);
  expect(runtime.generateResourceId, throwsStateError);
}

void _expectDuplicateAdmissionRejected(
  CanvasDocument document,
  CanvasDataErrorCode code,
) {
  expect(
    () => runtimeWithDocument(document),
    throwsA(
      isA<CanvasDataException>().having((error) => error.code, 'code', code),
    ),
  );
}

CanvasDocument _document() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('r0'),
        source: CanvasResourceSource.appKey('asset-a'),
      ),
    ],
    backgroundElements: [
      CanvasRectElement(id: CanvasElementId('e0'), size: const Size(1, 1)),
      CanvasRectElement(id: CanvasElementId('e2'), size: const Size(1, 1)),
    ],
    layers: [CanvasLayer(id: CanvasLayerId('l0'))],
  );
}

CanvasDocument _documentWithDuplicateElementIds() {
  return CanvasDocument(
    backgroundElements: [
      CanvasRectElement(id: CanvasElementId('e0'), size: const Size(1, 1)),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('l0'),
        elements: [
          CanvasRectElement(id: CanvasElementId('e0'), size: const Size(1, 1)),
        ],
      ),
    ],
  );
}

CanvasDocument _documentWithDuplicateLayerIds() {
  return CanvasDocument(
    layers: [
      CanvasLayer(id: CanvasLayerId('l0')),
      CanvasLayer(id: CanvasLayerId('l0')),
    ],
  );
}

CanvasDocument _documentWithDuplicateResourceIds() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('r0'),
        source: CanvasResourceSource.appKey('asset-a'),
      ),
      CanvasImageResource(
        id: CanvasResourceId('r0'),
        source: CanvasResourceSource.appKey('asset-b'),
      ),
    ],
  );
}

CanvasDocument _documentWithMissingResourceReference() {
  return CanvasDocument(
    backgroundElements: [
      CanvasImageElement(
        id: CanvasElementId('image-a'),
        resourceId: CanvasResourceId('missing-resource'),
        size: const Size(1, 1),
      ),
    ],
  );
}
