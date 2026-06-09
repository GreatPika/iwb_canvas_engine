import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_checks.dart';

void main() {
  _registerCurrentDocumentLoadSurfaceTests();
}

void _registerCurrentDocumentLoadSurfaceTests() {
  _testDocumentLoadSurfaceUsesCurrentRoutes();
  _testUnsupportedPublicDeclarationsRejected();
  _testUnsupportedProductionAndExampleCallsRejected();
  _testInternalLoadTypesQuarantinedFromPublicApi();
}

void _testDocumentLoadSurfaceUsesCurrentRoutes() {
  test('document load surface uses current public routes', () async {
    expect(await checkCurrentDocumentLoadSurfaceOnly(), isEmpty);
  });
}

void _testUnsupportedPublicDeclarationsRejected() {
  test('unsupported public load declarations are rejected', () async {
    final violations = await checkCurrentDocumentLoadSurfaceOnly(
      sourceOverrides: _unsupportedPublicLoadRouteSources(),
    );

    expect(violations.map((violation) => violation.guardrailId).toSet(), {
      'api.current_document_load_surface_only',
    });
    expect(violations, hasLength(4));
  });
}

void _testUnsupportedProductionAndExampleCallsRejected() {
  test('unsupported production and example load calls are rejected', () async {
    final violations = await checkCurrentDocumentLoadSurfaceOnly(
      sourceOverrides: _unsupportedRuntimeAndExampleLoadCallSources(),
    );

    expect(violations.map((violation) => violation.guardrailId).toSet(), {
      'api.current_document_load_surface_only',
    });
    expect(
      violations.map((violation) => violation.path),
      containsAll([
        'example/lib/src/canvas_json_dialogs.dart',
        'lib/src/runtime/runtime_root.dart',
        'lib/src/store/document_store_kernel.dart',
      ]),
    );
    expect(
      violations.map((violation) => violation.message).join('\n'),
      allOf(
        contains('decodeCanvasDocument helpers'),
        contains('loadDocument(document)'),
      ),
    );
  });
}

void _testInternalLoadTypesQuarantinedFromPublicApi() {
  test(
    'internal load and store types are quarantined from public API',
    () async {
      final violations = await checkCurrentDocumentLoadSurfaceOnly(
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
        'api.current_document_load_surface_only',
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

Map<String, String> _unsupportedPublicLoadRouteSources() {
  return {
    'lib/src/api/canvas_runtime.dart': '''
final class CanvasRuntime {
  CanvasRuntime({CanvasDocument? initialDocument});
}
''',
    'lib/src/contracts/public/canvas_runtime.dart': '''
abstract interface class CanvasEditPort {
  void loadDocument(CanvasDocument document);
}
''',
    'lib/src/api/canvas_codec.dart': '''
CanvasDocument decodeCanvasDocument(Map<String, Object?> json) => throw '';
CanvasDocument decodeCanvasDocumentFromJson(String json) => throw '';
''',
    'docs/_registry/public_api_v1.yaml': '''
public_exports:
  - decodeCanvasDocument
  - decodeCanvasDocumentFromJson
diagnostics_public_surface: []
''',
  };
}

Map<String, String> _unsupportedRuntimeAndExampleLoadCallSources() {
  return {
    'example/lib/src/canvas_json_dialogs.dart': '''
void importJson(CanvasRuntime runtime, String json) {
  final document = decodeCanvasDocumentFromJson(json);
  runtime.edits.loadDocument(document);
}
''',
    'lib/src/runtime/runtime_root.dart': '''
final class RuntimeRoot {
  void loadReplacement(CanvasDocument document) {
    edits.loadDocument(document);
  }
}
''',
    'lib/src/store/document_store_kernel.dart': '''
final class DocumentStoreKernel {
  void replaceFromJson(String json) {
    final document = decodeCanvasDocumentFromJson(json);
    loadDocument(document);
  }
}
''',
  };
}
