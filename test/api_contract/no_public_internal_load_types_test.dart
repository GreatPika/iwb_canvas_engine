import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_checks.dart';

void main() {
  _registerNoPublicInternalLoadTypesTests();
}

void _registerNoPublicInternalLoadTypesTests() {
  _testCurrentPublicApiDoesNotExportInternalLoadTypes();
  _testInternalLoadTypesQuarantinedFromPublicApi();
}

void _testCurrentPublicApiDoesNotExportInternalLoadTypes() {
  test('current public API does not export internal load types', () async {
    expect(await checkNoPublicInternalLoadTypes(), isEmpty);
  });
}

void _testInternalLoadTypesQuarantinedFromPublicApi() {
  test(
    'internal load and store types are quarantined from public API',
    () async {
      final violations = await checkNoPublicInternalLoadTypes(
        registryNamesOverride: _internalLoadPublicExportFixtureOrigins.keys
            .toSet(),
        exportedNamesOverride: {
          'CanvasRuntime',
          ..._internalLoadPublicExportFixtureOrigins.keys,
        },
        publicExportOriginsOverride: _internalLoadPublicExportFixtureOrigins,
      );

      expect(
        violations.single.guardrailId,
        'api.no_public_internal_load_types',
      );
      for (final name in _internalLoadPublicExportFixtureOrigins.keys) {
        if (name == 'CanvasActionPayload') {
          continue;
        }
        expect(violations.single.message, contains(name));
      }
      expect(violations.single.message, isNot(contains('CanvasActionPayload')));
    },
  );
}

const _internalLoadPublicExportFixtureOrigins = {
  'PreparedDocumentLoad':
      'package:iwb_canvas_engine/src/edit/staged_document_load.dart',
  'DocumentStoreKernel':
      'package:iwb_canvas_engine/src/store/document_store_kernel.dart',
  'StoreSchemaV1ImportBuilder':
      'package:iwb_canvas_engine/src/store/schema_v1_store_import.dart',
  'SchemaV1DocumentImportEvent':
      'package:iwb_canvas_engine/src/contracts/internal/schema_v1_import_events.dart',
  'SchemaV1ElementCommonImport':
      'package:iwb_canvas_engine/src/contracts/internal/schema_v1_import_events.dart',
  'SchemaV1ImportPayload':
      'package:iwb_canvas_engine/src/codec/schema_v1_import_emitter.dart',
  'StoreSchemaV1LoadPayload':
      'package:iwb_canvas_engine/src/store/schema_v1_store_import.dart',
  'CanvasActionPayload':
      'package:iwb_canvas_engine/src/contracts/public/canvas_actions.dart',
};
