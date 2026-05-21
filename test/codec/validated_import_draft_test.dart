import 'package:test/test.dart';

import 'schema_v1/schema_v1_consumer_harness.dart';

void main() {
  test('validated import draft wraps immutable DTO facts only', () async {
    await expectLater(
      runSchemaV1ConsumerTest(
        packageName: 'iwb_canvas_engine_validated_import_draft',
        testFileName: 'validated_import_draft_test.dart',
        testSource: _validatedImportDraftSource,
      ),
      completes,
    );
  });
}

const _validatedImportDraftSource = r'''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/codec/validated_import_draft.dart';

void main() {
  test('validated draft keeps document facts and rejects invalid handoff facts', () {
    final document = CanvasDocument(
      resources: [
        CanvasImageResource(
          id: CanvasResourceId('image-a'),
          source: CanvasResourceSource.appKey('image-a'),
        ),
      ],
      layers: [
        CanvasLayer(
          id: CanvasLayerId('layer-a'),
          elements: [
            CanvasImageElement(
              id: CanvasElementId('image-element-a'),
              resourceId: CanvasResourceId('image-a'),
              size: const Size(1, 1),
            ),
          ],
        ),
      ],
    );

    final draft = ValidatedImportDraft.fromDocument(document);
    expect(draft.document, same(document));
    expect(draft.resourceIds.map((id) => id.value), {'image-a'});
    expect(draft.layerIds.map((id) => id.value), {'layer-a'});
    expect(draft.elementIds.map((id) => id.value), {'image-element-a'});
    expect(() => draft.elementIds.clear(), throwsUnsupportedError);

    expect(
      () => ValidatedImportDraft.fromDocument(
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
