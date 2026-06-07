import '../contracts/public/canvas_diagnostics.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';
import '../codec/validated_import_draft.dart';
import '../diagnostics/diagnostics_hub.dart';
import '../store/committed_document.dart';
import '../store/document_store_kernel.dart';
import '../store/store_revision_delta.dart';

final class PreparedDocumentLoad {
  PreparedDocumentLoad._({
    required this.document,
    required this.resourceIds,
    required this.layerIds,
    required this.elementIds,
    required this.revisionDelta,
    required CommittedDocument storeDocument,
    required Object ownerToken,
  }) : _storeDocument = storeDocument,
       _ownerToken = ownerToken;

  final CanvasDocument document;
  final Set<CanvasResourceId> resourceIds;
  final Set<CanvasLayerId> layerIds;
  final Set<CanvasElementId> elementIds;
  final StoreRevisionDelta revisionDelta;
  final CommittedDocument _storeDocument;
  final Object _ownerToken;
  bool _isConsumed = false;

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
    final draft = ValidatedImportDraft.fromSchemaV1Json(
      json,
      diagnostics: _diagnostics,
    );

    return PreparedDocumentLoad._(
      document: draft.document,
      resourceIds: draft.resourceIds,
      layerIds: draft.layerIds,
      elementIds: draft.elementIds,
      revisionDelta: _replacementRevisionDelta,
      storeDocument: CommittedDocument(draft.document),
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

    _store.replacePreparedLoadDocument(load._storeDocument, load.revisionDelta);
  }
}

PreparedDocumentLoad prepareDraftReplacement(CanvasDocument document) {
  final draft = ValidatedImportDraft.fromDraftReplacement(document);

  return PreparedDocumentLoad._(
    document: draft.document,
    resourceIds: draft.resourceIds,
    layerIds: draft.layerIds,
    elementIds: draft.elementIds,
    revisionDelta: _replacementRevisionDelta,
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
