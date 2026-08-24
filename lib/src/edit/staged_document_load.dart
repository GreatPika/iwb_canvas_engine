// The load pipeline names codec diagnostics, store import, committed payloads,
// and public summary facts at the transaction boundary; hiding these imports
// behind wrapper types would make ownership less explicit.
// ignore_for_file: number-of-imports

import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_errors.dart';
import '../contracts/public/canvas_metadata.dart';
import '../codec/schema_v1_diagnostics.dart';
import '../codec/schema_v1_import_emitter.dart';
import '../codec/validated_import_draft.dart';
import '../diagnostics/diagnostics_hub.dart';
import '../store/committed_document.dart';
import '../store/document_store_kernel.dart';
import '../store/schema_v1_store_import.dart';
import '../store/store_revision_delta.dart';

final class PreparedDocumentLoad extends PreparedSummaryView {
  PreparedDocumentLoad._({
    required this.camera,
    required this.background,
    required this.palette,
    required this.metadata,
    required CanvasDocumentSummary summary,
    required this.revisionDelta,
    required Object ownerToken,
    CommittedDocument? storeDocument,
    PreparedStoreDocumentImport? storeImport,
  }) : _storeDocument = storeDocument,
       _storeImport = storeImport,
       _ownerToken = ownerToken,
       super.load(summary);

  final CanvasCamera camera;
  final CanvasBackground background;
  final CanvasPalette palette;
  final CanvasMetadata metadata;
  final StoreRevisionDelta revisionDelta;
  final CommittedDocument? _storeDocument;
  final PreparedStoreDocumentImport? _storeImport;
  final Object _ownerToken;
  bool _isConsumed = false;

  CanvasDocument get document {
    throw StateError(
      'Prepared document loads do not materialize a CanvasDocument projection.',
    );
  }
}

// LoadDocumentPipeline is the composition boundary between codec validation,
// store preparation, diagnostics, and consume-once install; splitting it would
// create sync glue across the irreversible load boundary.
// ignore: coupling-between-object-classes
final class LoadDocumentPipeline {
  LoadDocumentPipeline({
    required DocumentStoreKernel store,
    DiagnosticsHub? diagnostics,
  }) : _store = store,
       _diagnostics = diagnostics;

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
    importSchemaV1DocumentFromJsonIntoIsolatedSink(
      json,
      sink,
      diagnostics: _diagnostics,
    );
    late final PreparedStoreDocumentImport preparedStoreImport;
    try {
      preparedStoreImport = _store.prepareSchemaV1Import(
        sink,
        const StoreRevisionDelta.documentReplacement(),
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
      summary: preparedStoreImport.summary,
      revisionDelta: const StoreRevisionDelta.documentReplacement(),
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
  final storeDocument = CommittedDocument(draft.document);

  return PreparedDocumentLoad._(
    camera: storeDocument.camera,
    background: storeDocument.background,
    palette: storeDocument.palette,
    metadata: storeDocument.metadata,
    summary: capturePreparedSummary(
      elementCount: storeDocument.elements.elementCount,
      layerCount: storeDocument.elements.layerTable.rows.length,
      resourceCount: storeDocument.resourceTable.count,
    ),
    revisionDelta: const StoreRevisionDelta.documentReplacement(),
    storeDocument: storeDocument,
    ownerToken: _draftReplacementOwnerToken,
  );
}

final Object _draftReplacementOwnerToken = Object();
