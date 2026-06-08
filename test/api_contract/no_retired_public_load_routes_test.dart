import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_checks.dart';

void main() {
  _registerRetiredPublicRouteTests();
  _registerDocumentLoadCodecInputTests();
  _registerDocumentLoadRouteInputTests();
  _registerDocumentLoadStoreInputTests();
  _registerDocumentLoadTestingInputTests();
  _registerDocumentLoadCallbackInputTests();
}

void _registerRetiredPublicRouteTests() {
  _testRetiredRoutesAbsentFromRealSurfaces();
  _testRetiredPublicDeclarationsRejected();
  _testRetiredProductionAndExampleCallsRejected();
  _testInternalLoadTypesQuarantinedFromPublicApi();
}

void _testRetiredRoutesAbsentFromRealSurfaces() {
  test(
    'retired public load routes are absent from real public surfaces',
    () async {
      expect(await checkNoRetiredPublicLoadRoutes(), isEmpty);
    },
  );
}

void _testRetiredPublicDeclarationsRejected() {
  test('retired public load route declarations are rejected', () async {
    final violations = await checkNoRetiredPublicLoadRoutes(
      sourceOverrides: _retiredPublicLoadRouteSources(),
    );

    expect(violations.map((violation) => violation.guardrailId).toSet(), {
      'api.no_retired_public_load_routes',
    });
    expect(violations, hasLength(4));
  });
}

void _testRetiredProductionAndExampleCallsRejected() {
  test(
    'retired production and example load route calls are rejected',
    () async {
      final violations = await checkNoRetiredPublicLoadRoutes(
        sourceOverrides: _retiredRuntimeAndExampleLoadCallSources(),
      );

      expect(violations.map((violation) => violation.guardrailId).toSet(), {
        'api.no_retired_public_load_routes',
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
    },
  );
}

void _testInternalLoadTypesQuarantinedFromPublicApi() {
  test(
    'internal load and store types are quarantined from public API',
    () async {
      final violations = await checkNoRetiredPublicLoadRoutes(
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
        'api.no_retired_public_load_routes',
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
      'package:iwb_canvas_engine/src/codec/schema_v1_import_events.dart',
  'StoreSchemaV1LoadPayload':
      'package:iwb_canvas_engine/src/store/schema_v1_store_import.dart',
  'CanvasActionPayload':
      'package:iwb_canvas_engine/src/contracts/public/canvas_actions.dart',
};

void _registerDocumentLoadCodecInputTests() {
  test('codec import draft document admission is rejected', () async {
    final violations = await checkNoUnapprovedDocumentLoadInputs(
      sourceOverrides: _codecImportDraftDocumentInputSources(),
    );

    expect(
      violations.single.guardrailId,
      'api.no_unapproved_document_load_inputs',
    );
    expect(violations.single.message, contains('ValidatedImportDraft'));
  });
}

void _registerDocumentLoadRouteInputTests() {
  test(
    'production document load input guardrail accepts real surfaces',
    () async {
      final violations = await checkNoUnapprovedDocumentLoadInputs();

      expect(violations, isEmpty);
    },
  );

  _registerDocumentLoadRouteRejectionTests();
}

void _registerDocumentLoadRouteRejectionTests() {
  _registerDirectDocumentLoadRouteRejectionTests();
  _registerRenamedDocumentLoadRouteRejectionTests();
}

void _registerDirectDocumentLoadRouteRejectionTests() {
  test('unapproved production document load inputs are rejected', () async {
    final violations = await checkNoUnapprovedDocumentLoadInputs(
      sourceOverrides: _editKernelDocumentLoadInputSources(),
    );

    expect(
      violations.single.guardrailId,
      'api.no_unapproved_document_load_inputs',
    );
  });

  test('runtime and store document load input bypasses are rejected', () async {
    final violations = await checkNoUnapprovedDocumentLoadInputs(
      sourceOverrides: _runtimeAndStoreDocumentLoadInputSources(),
    );

    expect(
      violations.single.guardrailId,
      'api.no_unapproved_document_load_inputs',
    );
  });
}

void _registerRenamedDocumentLoadRouteRejectionTests() {
  _registerRenamedInternalLoadInputRejectionTest();
  _registerWrongOwnerAllowedNameRejectionTest();
  _registerRenamedPublicLoadInputRejectionTest();
  _registerAliasedDocumentLoadInputRejectionTest();
}

void _registerRenamedInternalLoadInputRejectionTest() {
  test(
    'renamed load and admission document input bypasses are rejected',
    () async {
      final violations = await checkNoUnapprovedDocumentLoadInputs(
        sourceOverrides: _renamedDocumentLoadInputBypassSources(),
      );

      expect(
        violations.single.guardrailId,
        'api.no_unapproved_document_load_inputs',
      );
      expect(violations.single.message, contains('RuntimeRoot._admitDocument'));
      expect(
        violations.single.message,
        contains('LoadDocumentPipeline.prepareDocument'),
      );
    },
  );
}

void _registerWrongOwnerAllowedNameRejectionTest() {
  test('allowed document input names in wrong owners are rejected', () async {
    final violations = await checkNoUnapprovedDocumentLoadInputs(
      sourceOverrides: _wrongOwnerAllowedNameDocumentInputSources(),
    );

    expect(
      violations.single.guardrailId,
      'api.no_unapproved_document_load_inputs',
    );
    expect(
      violations.single.message,
      contains('RuntimeRoot._validateDocumentReferences'),
    );
    expect(violations.single.message, contains('encodeCanvasDocument'));
  });
}

void _registerRenamedPublicLoadInputRejectionTest() {
  test('renamed public document load input bypasses are rejected', () async {
    final violations = await checkNoUnapprovedDocumentLoadInputs(
      sourceOverrides: _publicRuntimeDocumentLoadInputSources(),
    );

    expect(
      violations.single.guardrailId,
      'api.no_unapproved_document_load_inputs',
    );
    expect(
      violations.single.message,
      contains('CanvasEditPort.importDocument'),
    );
  });
}

void _registerAliasedDocumentLoadInputRejectionTest() {
  test('aliased document load input bypasses are rejected', () async {
    final violations = await checkNoUnapprovedDocumentLoadInputs(
      sourceOverrides: _aliasedDocumentLoadInputSources(),
    );

    expect(
      violations.single.guardrailId,
      'api.no_unapproved_document_load_inputs',
    );
    expect(violations.single.message, contains('RuntimeRoot.prepare'));
    expect(violations.single.message, contains('RuntimeRoot.prepareDeferred'));
    expect(
      violations.single.message,
      contains('RuntimeRoot.prepareFunctionTyped'),
    );
    expect(violations.single.message, contains('LoadDocumentPipeline.prepare'));
    expect(violations.single.message, contains('DocumentStoreKernel.prepare'));
    expect(violations.single.message, contains('StoreSchemaV1ImportBuilder'));
  });
}

void _registerDocumentLoadStoreInputTests() {
  test('store installer document inputs are rejected', () async {
    final violations = await checkNoUnapprovedDocumentLoadInputs(
      sourceOverrides: _storeInstallerDocumentInputSources(),
    );

    expect(
      violations.single.guardrailId,
      'api.no_unapproved_document_load_inputs',
    );
    expect(violations.single.message, contains('DocumentStoreKernel'));
  });

  test('store import document inputs are rejected', () async {
    final violations = await checkNoUnapprovedDocumentLoadInputs(
      sourceOverrides: _storeImportDocumentInputSources(),
    );

    expect(
      violations.single.guardrailId,
      'api.no_unapproved_document_load_inputs',
    );
    expect(violations.single.message, contains('StoreSchemaV1ImportBuilder'));
  });
}

void _registerDocumentLoadTestingInputTests() {
  test(
    'testing constructors cannot bypass document load input checks',
    () async {
      final violations = await checkNoUnapprovedDocumentLoadInputs(
        sourceOverrides: _testingConstructorDocumentInputSources(),
      );

      expect(
        violations.single.guardrailId,
        'api.no_unapproved_document_load_inputs',
      );
      expect(violations.single.message, contains('RuntimeRoot.test'));
    },
  );
}

void _registerDocumentLoadCallbackInputTests() {
  test('load installer callback document inputs are rejected', () async {
    final violations = await checkNoUnapprovedDocumentLoadInputs(
      sourceOverrides: _loadInstallerCallbackDocumentInputSources(),
    );

    expect(
      violations.single.guardrailId,
      'api.no_unapproved_document_load_inputs',
    );
    expect(violations.single.message, contains('DocumentLoadInstaller'));
  });
}

Map<String, String> _retiredPublicLoadRouteSources() {
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

Map<String, String> _publicRuntimeDocumentLoadInputSources() {
  return {
    'lib/src/contracts/public/canvas_runtime.dart': r'''
import 'canvas_document.dart';

abstract interface class CanvasEditPort {
  void loadDocumentFromJson(String json);
  void importDocument(CanvasDocument document);
}
''',
  };
}

Map<String, String> _retiredRuntimeAndExampleLoadCallSources() {
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

Map<String, String> _codecImportDraftDocumentInputSources() {
  return {
    'lib/src/codec/validated_import_draft.dart': '''
final class ValidatedImportDraft {
  ValidatedImportDraft.fromDocument(CanvasDocument document);
}
''',
    'lib/src/edit/edit_kernel.dart': '',
    'lib/src/runtime/runtime_root.dart': '',
    'lib/src/edit/staged_document_load.dart': '',
    'lib/src/store/document_store_kernel.dart': '',
    'lib/src/store/schema_v1_store_import.dart': '',
  };
}

Map<String, String> _editKernelDocumentLoadInputSources() {
  return {
    'lib/src/edit/edit_kernel.dart': '''
final class EditKernel {
  void loadDocument(CanvasDocument document) {}
}
''',
    'lib/src/runtime/runtime_root.dart': '',
    'lib/src/edit/staged_document_load.dart': '',
    'lib/src/store/document_store_kernel.dart': '',
    'lib/src/store/schema_v1_store_import.dart': '',
  };
}

Map<String, String> _loadInstallerCallbackDocumentInputSources() {
  return {
    'lib/src/edit/edit_kernel.dart': '''
typedef DocumentLoadInstaller = void Function(CanvasDocument document);
''',
    'lib/src/runtime/runtime_root.dart': '',
    'lib/src/edit/staged_document_load.dart': '',
    'lib/src/store/document_store_kernel.dart': '',
    'lib/src/store/schema_v1_store_import.dart': '',
  };
}

Map<String, String> _runtimeAndStoreDocumentLoadInputSources() {
  return {
    'lib/src/edit/edit_kernel.dart': '',
    'lib/src/runtime/runtime_root.dart': '''
final class RuntimeRoot {
  RuntimeRoot({required CanvasDocument initialDocument});
  void _loadDocument(CanvasDocument document) {}
}
    ''',
    'lib/src/edit/staged_document_load.dart': '''
final class LoadDocumentPipeline {
  PreparedDocumentLoad prepare(CanvasDocument document) => throw '';
  void consume(PreparedDocumentLoad load) {
    _store.replaceDocument(load.document, load.revisionDelta);
  }
}
''',
    'lib/src/store/document_store_kernel.dart': '''
final class DocumentStoreKernel {
  DocumentStoreKernel(CanvasDocument initialDocument);
}
''',
    'lib/src/store/schema_v1_store_import.dart': '',
  };
}

Map<String, String> _aliasedDocumentLoadInputSources() {
  return {
    'lib/src/edit/edit_kernel.dart': '''
typedef SharedLoadInput = CanvasDocument;
typedef DeferredLoadInput = CanvasDocument Function();
''',
    'lib/src/runtime/runtime_root.dart': '''
typedef RuntimeLoadInput = CanvasDocument;

final class RuntimeRoot {
  void prepare(RuntimeLoadInput document) {}
  void prepareDeferred(DeferredLoadInput readDocument) {}
  void prepareFunctionTyped(CanvasDocument readDocument()) {}
}
''',
    'lib/src/edit/staged_document_load.dart': '''
typedef DraftLoadInput = CanvasDocument;
typedef PipelineLoadInput = DraftLoadInput;

final class LoadDocumentPipeline {
  PreparedDocumentLoad prepare(PipelineLoadInput document) => throw '';
}
''',
    'lib/src/store/document_store_kernel.dart': '''
final class DocumentStoreKernel {
  void prepare(SharedLoadInput document) {}
}
''',
    'lib/src/store/schema_v1_store_import.dart': '''
final class StoreSchemaV1ImportBuilder {
  void prepare(InternalLoadInput document) {}
}
''',
    'lib/src/contracts/internal/load_contract.dart': '''
typedef InternalLoadInput = CanvasDocument;
''',
  };
}

Map<String, String> _storeInstallerDocumentInputSources() {
  return {
    'lib/src/edit/edit_kernel.dart': '',
    'lib/src/runtime/runtime_root.dart': '',
    'lib/src/edit/staged_document_load.dart': '',
    'lib/src/store/document_store_kernel.dart': '''
final class DocumentStoreKernel {
  void installDocument(CanvasDocument document, StoreRevisionDelta delta) {}
  void replaceDocument(CanvasDocument document, StoreRevisionDelta delta) {}
}
''',
    'lib/src/store/schema_v1_store_import.dart': '',
  };
}

Map<String, String> _storeImportDocumentInputSources() {
  return {
    'lib/src/edit/edit_kernel.dart': '',
    'lib/src/runtime/runtime_root.dart': '',
    'lib/src/edit/staged_document_load.dart': '',
    'lib/src/store/document_store_kernel.dart': '',
    'lib/src/store/schema_v1_store_import.dart': '''
final class StoreSchemaV1ImportBuilder {
  void addDocument(CanvasDocument document) {}
}
''',
  };
}

Map<String, String> _testingConstructorDocumentInputSources() {
  return {
    'lib/src/edit/edit_kernel.dart': '',
    'lib/src/runtime/runtime_root.dart': '''
final class RuntimeRoot {
  @visibleForTesting
  RuntimeRoot.test({required CanvasDocument initialDocument});
}
''',
    'lib/src/edit/staged_document_load.dart': '',
    'lib/src/store/document_store_kernel.dart': '',
    'lib/src/store/schema_v1_store_import.dart': '',
  };
}

Map<String, String> _renamedDocumentLoadInputBypassSources() {
  return {
    'lib/src/edit/edit_kernel.dart': '',
    'lib/src/runtime/runtime_root.dart': '''
final class RuntimeRoot {
  void _admitDocument(CanvasDocument document) {}
}
''',
    'lib/src/edit/staged_document_load.dart': '''
final class LoadDocumentPipeline {
  PreparedDocumentLoad prepareDocument(CanvasDocument document) => throw '';
}
PreparedDocumentLoad prepareDraftReplacement(CanvasDocument document) => throw '';
    ''',
    'lib/src/store/document_store_kernel.dart': '''
final class DocumentStoreKernel {
  void replaceDocument(CanvasDocument document, StoreRevisionDelta delta) {}
}
''',
    'lib/src/store/schema_v1_store_import.dart': '',
  };
}

Map<String, String> _wrongOwnerAllowedNameDocumentInputSources() {
  return {
    'lib/src/runtime/runtime_root.dart': '''
final class RuntimeRoot {
  void _validateDocumentReferences(CanvasDocument document) {}
}
''',
    'lib/src/store/document_store_kernel.dart': '''
Map<String, Object?> encodeCanvasDocument(CanvasDocument document) => {};
''',
    'lib/src/edit/edit_kernel.dart': '',
    'lib/src/edit/staged_document_load.dart': '',
    'lib/src/store/schema_v1_store_import.dart': '',
  };
}
