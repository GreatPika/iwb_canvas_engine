import '../contracts/public/canvas_diagnostics.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_errors.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_metadata.dart';
import '../codec/schema_v1_diagnostics.dart';
import '../codec/schema_v1_import_events.dart';
import '../codec/validated_import_draft.dart';
import '../diagnostics/diagnostics_hub.dart';
import '../store/committed_document.dart';
import '../store/document_store_kernel.dart';
import '../store/schema_v1_store_import.dart';
import '../store/store_revision_delta.dart';

final class PreparedDocumentLoad {
  PreparedDocumentLoad._({
    required this.camera,
    required this.background,
    required this.palette,
    required this.metadata,
    required this.resourceIds,
    required this.layerIds,
    required this.elementIds,
    required this.revisionDelta,
    required Object ownerToken,
    CanvasDocument? projectionDocument,
    CommittedDocument? storeDocument,
    PreparedStoreDocumentImport? storeImport,
  }) : _projectionDocument = projectionDocument,
       _storeDocument = storeDocument,
       _storeImport = storeImport,
       _ownerToken = ownerToken;

  final CanvasCamera camera;
  final CanvasBackground background;
  final CanvasPalette palette;
  final CanvasMetadata metadata;
  final Set<CanvasResourceId> resourceIds;
  final Set<CanvasLayerId> layerIds;
  final Set<CanvasElementId> elementIds;
  final StoreRevisionDelta revisionDelta;
  final CanvasDocument? _projectionDocument;
  final CommittedDocument? _storeDocument;
  final PreparedStoreDocumentImport? _storeImport;
  final Object _ownerToken;
  bool _isConsumed = false;

  CanvasDocument get document {
    final document = _projectionDocument;
    if (document == null) {
      throw StateError(
        'Prepared JSON load does not materialize a CanvasDocument projection.',
      );
    }

    return document;
  }

  CanvasDocumentSummary get summary {
    return CanvasDocumentSummary(
      elementCount: elementIds.length,
      layerCount: layerIds.length,
      resourceCount: resourceIds.length,
    );
  }
}

final class LoadDocumentPipeline {
  LoadDocumentPipeline({
    required DocumentStoreKernel store,
    CanvasDiagnosticPolicy diagnosticPolicy =
        const CanvasDiagnosticPolicy.disabled(),
  }) : _store = store,
       _diagnostics = _diagnosticsHubFor(diagnosticPolicy);

  final DocumentStoreKernel _store;
  final DiagnosticsHub? _diagnostics;
  final Object _ownerToken = Object();

  bool get hasDiagnosticsRecordingSurface => _diagnostics != null;
  int get diagnosticRecordCount => _diagnostics?.recordCount ?? 0;
  List<DiagnosticRecord> get diagnosticRecords {
    return _diagnostics?.records ?? const [];
  }

  PreparedDocumentLoad prepareFromJson(String json) {
    final sink = StoreSchemaV1ImportBuilder();
    importSchemaV1DocumentFromJson(json, sink, diagnostics: _diagnostics);
    late final PreparedStoreDocumentImport preparedStoreImport;
    try {
      preparedStoreImport = _store.prepareSchemaV1Import(
        sink,
        _replacementRevisionDelta,
      );
    } on CanvasDataException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        recordSchemaV1FailureDiagnostic(_diagnostics, error),
        stackTrace,
      );
    }
    final committed = preparedStoreImport.document;

    return PreparedDocumentLoad._(
      camera: committed.camera,
      background: committed.background,
      palette: committed.palette,
      metadata: committed.metadata,
      resourceIds: preparedStoreImport.resourceIds,
      layerIds: preparedStoreImport.layerIds,
      elementIds: preparedStoreImport.elementIds,
      revisionDelta: _replacementRevisionDelta,
      storeImport: preparedStoreImport,
      ownerToken: _ownerToken,
    );
  }

  void consume(PreparedDocumentLoad load) {
    if (!identical(load._ownerToken, _ownerToken)) {
      throw StateError(
        'PreparedDocumentLoad was created by a different load pipeline.',
      );
    }
    if (load._isConsumed) {
      throw StateError('PreparedDocumentLoad has already been consumed.');
    }
    load._isConsumed = true;

    final storeImport = load._storeImport;
    if (storeImport != null) {
      _store.installPreparedSchemaV1Import(storeImport);

      return;
    }
    final storeDocument = load._storeDocument;
    if (storeDocument == null) {
      throw StateError('PreparedDocumentLoad has no store payload.');
    }
    _store.replacePreparedLoadDocument(storeDocument, load.revisionDelta);
  }
}

PreparedDocumentLoad prepareDraftReplacement(CanvasDocument document) {
  final draft = ValidatedImportDraft.fromDraftReplacement(document);

  return PreparedDocumentLoad._(
    camera: draft.document.camera,
    background: draft.document.background,
    palette: draft.document.palette,
    metadata: draft.document.metadata,
    resourceIds: draft.resourceIds,
    layerIds: draft.layerIds,
    elementIds: draft.elementIds,
    revisionDelta: _replacementRevisionDelta,
    projectionDocument: draft.document,
    storeDocument: CommittedDocument(draft.document),
    ownerToken: _draftReplacementOwnerToken,
  );
}

const _replacementRevisionDelta = StoreRevisionDelta(
  document: true,
  projection: true,
  structural: true,
  bounds: true,
  elementVisual: true,
  background: true,
  grid: true,
  resource: true,
);

final Object _draftReplacementOwnerToken = Object();

DiagnosticsHub? _diagnosticsHubFor(CanvasDiagnosticPolicy policy) {
  if (policy is CanvasDiagnosticsDisabled) {
    return null;
  }

  return DiagnosticsHub(policy: policy);
}
