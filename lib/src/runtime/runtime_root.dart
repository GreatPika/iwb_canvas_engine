// RuntimeRoot is the composition root for public facade ports, store facts, and
// selection state; its imports reflect owned seams that are meant to meet here
// instead of being hidden behind metric-only wrapper files.
// The composition root directly names each owned seam so dependency direction is
// visible at the facade boundary.
// ignore_for_file: number-of-imports

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../contracts/internal/commit_delivery.dart';
import '../contracts/internal/document_facts_port.dart';
import '../contracts/internal/frame_facts_port.dart';
import '../contracts/internal/load_interaction_boundary.dart';
import '../contracts/internal/resource_catalog_port.dart';
import '../contracts/internal/resource_dirty_outcome.dart';
import '../contracts/internal/resource_session_invalidation_sink.dart';
import '../contracts/internal/resolver_mutation_guard.dart';
import '../contracts/internal/selection_facts_port.dart';
import '../contracts/internal/selection_membership_port.dart';
import '../contracts/internal/touched_set.dart';
import '../contracts/public/canvas_actions.dart';
import '../contracts/public/canvas_diagnostics.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_preview.dart';
import '../contracts/public/canvas_resource.dart';
import '../contracts/public/canvas_runtime.dart';
import '../contracts/public/canvas_surface_styles.dart';
import '../edit/commit_applier.dart';
import '../edit/commit_plan.dart';
import '../edit/edit_kernel.dart';
import '../edit/staged_document_load.dart';
import '../frame/captured_frame.dart';
import '../frame/frame_engine.dart';
import '../frame/frame_paint_output.dart';
import '../geometry/spatial_kernel.dart';
import '../resources/resource_kernel.dart';
import '../selection/selection_kernel.dart';
import '../store/document_store_kernel.dart';
import 'noop_load_interaction_boundary.dart';
import 'runtime_config.dart';

// RuntimeRoot is intentionally the one place where public runtime behavior,
// store read facts, and selection ownership meet.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class RuntimeRoot
    implements
        DocumentFactsPort,
        FrameFactsPort,
        ResolverMutationGuard,
        ResourceDirtyOutcomeSink {
  RuntimeRoot({
    required CanvasDocument initialDocument,
    required CanvasRuntimeConfig config,
    CommitEffectObserver? commitEffectObserver,
  }) : this._(
         store: DocumentStoreKernel(initialDocument),
         config: RuntimeConfig.from(config),
         diagnosticPolicy: config.diagnosticPolicy,
         loadInteractionBoundary: noopLoadInteractionBoundary,
         initialViewCamera: initialDocument.camera,
         commitEffectObserver: commitEffectObserver ?? _ignoreCommitEffects,
       );

  @visibleForTesting
  RuntimeRoot.test({
    required CanvasDocument initialDocument,
    required CanvasRuntimeConfig config,
    required LoadInteractionBoundary loadInteractionBoundary,
    CommitEffectObserver? commitEffectObserver,
  }) : this._(
         store: DocumentStoreKernel(initialDocument),
         config: RuntimeConfig.from(config),
         diagnosticPolicy: config.diagnosticPolicy,
         loadInteractionBoundary: loadInteractionBoundary,
         initialViewCamera: initialDocument.camera,
         commitEffectObserver: commitEffectObserver ?? _ignoreCommitEffects,
       );

  RuntimeRoot._({
    required DocumentStoreKernel store,
    required this.config,
    required CanvasDiagnosticPolicy diagnosticPolicy,
    required LoadInteractionBoundary loadInteractionBoundary,
    required CanvasCamera initialViewCamera,
    required CommitEffectObserver commitEffectObserver,
  }) : _store = store,
       _viewCamera = initialViewCamera,
       _loadInteractionBoundary = loadInteractionBoundary,
       _loadPipeline = LoadDocumentPipeline(
         store: store,
         diagnosticPolicy: diagnosticPolicy,
       ),
       _commitEffectObserver = commitEffectObserver,
       _selection = SelectionKernel(
         membership: _StoreSelectionMembership(store),
       ),
       _state = ValueNotifier<CanvasRuntimeState>(
         _runtimeState(store, null, const _RuntimeRevisionFacts()),
       ) {
    _spatial.rebuild(this);
  }

  final RuntimeConfig config;
  final DocumentStoreKernel _store;
  CanvasCamera _viewCamera;
  final LoadInteractionBoundary _loadInteractionBoundary;
  final LoadDocumentPipeline _loadPipeline;
  final CommitEffectObserver _commitEffectObserver;
  final SelectionKernel _selection;
  final SpatialKernel _spatial = SpatialKernel();
  final ValueNotifier<CanvasRuntimeState> _state;
  final StreamController<CanvasActionCommitted> _actions =
      StreamController<CanvasActionCommitted>.broadcast();
  final CommitApplier _commitApplier = const CommitApplier();
  int _viewCameraRevision = 0;
  int _previewRevision = 0;
  CanvasPreviewState _preview = const CanvasNoPreview();
  int _epochRevision = 0;
  bool _isDisposed = false;
  bool _isDeliveringCommitEffects = false;
  bool _isRunningResolverCallback = false;
  ResourceSessionInvalidationSink? _activeResourceSessionInvalidationSink;
  late final EditKernel _editKernel = EditKernel(
    mutationGuard: this,
    readDocument: _store.readDocument,
    selectedElementIds: () => _selection.selectedElementIds,
    installCommit: _applyEditCommit,
    deliverApplyResult: _deliverEditCommitResult,
    installLoadedDocument: _loadDocument,
  );
  late final CanvasEditPort _editPort = _editKernel.port;
  late final CanvasSelectionPort _selectionPort = _RuntimeSelectionPort(this);
  late final CanvasCameraPort _cameraPort = _RuntimeCameraPort(this);
  late final ResourceCatalogPort _resourceCatalogPort = _StoreResourceCatalog(
    _store,
  );
  late final ResourceKernel _resourceKernel = ResourceKernel(
    catalog: _resourceCatalogPort,
    mutationGuard: this,
    dirtyOutcomeSink: this,
  );
  late final FrameEngine _frameEngine = FrameEngine(
    frameFacts: this,
    selectionFacts: _selection,
    spatialKernel: _spatial,
  );

  ValueListenable<CanvasRuntimeState> get state => _state;
  bool get isDisposed => _isDisposed;
  int get projectionBuildCount => _store.projectionBuildCount;
  CanvasEditPort get edits => _editPort;
  Stream<CanvasActionCommitted> get actions => _actions.stream;
  CanvasSelectionPort get selection => _selectionPort;
  CanvasCameraPort cameraPort() => _cameraPort;
  CanvasResourcePort get resources => _resourceKernel;
  ResourceCatalogPort get resourceCatalogPort => _resourceCatalogPort;
  CanvasPreviewState get preview => _preview;
  CanvasCamera get viewCamera => _viewCamera;
  Offset get viewCameraOffset => _viewCamera.offset;
  SelectionFacts get selectionFacts => _selection.selectionFacts;

  DocumentFactsPort get documentFactsPort => this;
  FrameFactsPort get frameFactsPort => this;
  @visibleForTesting
  SpatialKernel get spatialKernel => _spatial;

  MainFramePaintOutput buildResourceFreeMainFrame({
    required Rect viewportWorldBounds,
    required double devicePixelRatio,
    required CanvasSelectionStyle selectionStyle,
    required CanvasGridStyle gridStyle,
  }) {
    return _frameEngine.buildResourceFreeMainFrame(
      inputs: _frameInputs(
        viewportWorldBounds: viewportWorldBounds,
        devicePixelRatio: devicePixelRatio,
        selectionStyle: selectionStyle,
        gridStyle: gridStyle,
      ),
      viewCameraBucket: _viewCameraRevision,
    );
  }

  OverlayFramePaintOutput buildResourceFreeOverlayFrame({
    required Rect viewportWorldBounds,
    required double devicePixelRatio,
    required CanvasSelectionStyle selectionStyle,
    required CanvasGridStyle gridStyle,
  }) {
    return _frameEngine.buildResourceFreeOverlayFrame(
      inputs: _frameInputs(
        viewportWorldBounds: viewportWorldBounds,
        devicePixelRatio: devicePixelRatio,
        selectionStyle: selectionStyle,
        gridStyle: gridStyle,
      ),
    );
  }

  FrameCaptureInputs _frameInputs({
    required Rect viewportWorldBounds,
    required double devicePixelRatio,
    required CanvasSelectionStyle selectionStyle,
    required CanvasGridStyle gridStyle,
  }) {
    return FrameCaptureInputs(
      viewportWorldBounds: viewportWorldBounds,
      devicePixelRatio: devicePixelRatio,
      selectionStyle: selectionStyle,
      gridStyle: gridStyle,
      preview: preview,
      previewRevision: _previewRevision,
      viewCameraOffset: _viewCamera.offset,
    );
  }

  void attachResourceSessionInvalidationSink(
    ResourceSessionInvalidationSink sink,
  ) {
    ensureRuntimeMutationAllowed();
    _activeResourceSessionInvalidationSink = sink;
  }

  void clearResourceSessionInvalidationSink(
    ResourceSessionInvalidationSink sink,
  ) {
    ensureRuntimeMutationAllowed();
    if (identical(_activeResourceSessionInvalidationSink, sink)) {
      _activeResourceSessionInvalidationSink = null;
    }
  }

  @override
  DocumentFacts get documentFacts {
    final summary = _store.documentSummary;

    return DocumentFacts(
      elementCount: summary.elementCount,
      layerCount: summary.layerCount,
      resourceCount: summary.resourceCount,
      documentRevision: _store.documentRevision,
      structuralRevision: _store.structuralRevision,
      contentElementIds: _store.contentElementIds,
      selectableElementIds: _store.selectableElementIds,
    );
  }

  @override
  FrameRevisionFacts get frameRevisions {
    return FrameRevisionFacts(
      documentRevision: _store.documentRevision,
      structuralRevision: _store.structuralRevision,
      boundsRevision: _store.boundsRevision,
      elementVisualRevision: _store.elementVisualRevision,
      backgroundRevision: _store.backgroundRevision,
      gridRevision: _store.gridRevision,
      resourceRevision: _store.resourceRevision,
    );
  }

  @override
  CanvasBackground get background {
    return _store.background;
  }

  CanvasDocument readDocument() => _store.readDocument();
  CanvasElementId generateElementId() {
    ensureRuntimeMutationAllowed();

    return _store.generateElementId();
  }

  CanvasLayerId generateLayerId() {
    ensureRuntimeMutationAllowed();

    return _store.generateLayerId();
  }

  CanvasResourceId generateResourceId() {
    ensureRuntimeMutationAllowed();

    return _store.generateResourceId();
  }

  @override
  int elementCount(int structuralRevision) {
    return _store.elementCount(structuralRevision);
  }

  @override
  List<FrameElementHandle> elementHandles(int structuralRevision) {
    return List.unmodifiable([
      for (final handle in _store.elementHandles(structuralRevision))
        FrameElementHandle(
          id: handle.id,
          structuralRevision: handle.structuralRevision,
          generation: handle.generation,
          orderToken: handle.orderToken,
        ),
    ]);
  }

  @override
  FrameElementHandle? elementHandleForId(
    int structuralRevision,
    CanvasElementId id,
  ) {
    final handle = _store.elementHandleForId(structuralRevision, id);
    if (handle == null) {
      return null;
    }

    return FrameElementHandle(
      id: handle.id,
      structuralRevision: handle.structuralRevision,
      generation: handle.generation,
      orderToken: handle.orderToken,
    );
  }

  @override
  // The resolver copies every frame fact field explicitly so the public read
  // port cannot accidentally expose the store-owned fact object.
  // ignore: halstead-volume, source-lines-of-code
  FrameElementFacts? resolveElement(FrameElementHandle handle) {
    final facts = _store.resolveElement(
      StoreElementHandle(
        id: handle.id,
        structuralRevision: handle.structuralRevision,
        generation: handle.generation,
        orderToken: handle.orderToken,
      ),
    );
    if (facts == null) {
      return null;
    }

    return FrameElementFacts(
      id: facts.id,
      kind: facts.kind,
      revision: facts.revision,
      generation: facts.generation,
      orderToken: facts.orderToken,
      locationKind: switch (facts.locationKind) {
        StoreElementLocationKind.background =>
          FrameElementLocationKind.background,
        StoreElementLocationKind.content => FrameElementLocationKind.content,
      },
      transform: facts.transform,
      opacity: facts.opacity,
      hitPadding: facts.hitPadding,
      isVisible: facts.isVisible,
      isSelectable: facts.isSelectable,
      isLocked: facts.isLocked,
      isDeletable: facts.isDeletable,
      isTransformable: facts.isTransformable,
      metadata: facts.metadata,
      resourceId: facts.resourceId,
      layerId: facts.layerId,
      size: facts.size,
      naturalSize: facts.naturalSize,
      svgPathData: facts.svgPathData,
      fillColor: facts.fillColor,
      strokeColor: facts.strokeColor,
      strokeWidth: facts.strokeWidth,
      fillRule: facts.fillRule,
      text: facts.text,
      fontSize: facts.fontSize,
      textColor: facts.textColor,
      textAlign: facts.textAlign,
      textDirection: facts.textDirection,
      isBold: facts.isBold,
      isItalic: facts.isItalic,
      isUnderline: facts.isUnderline,
      fontFamily: facts.fontFamily,
      maxWidth: facts.maxWidth,
      lineHeight: facts.lineHeight,
      points: facts.points,
      start: facts.start,
      end: facts.end,
      color: facts.color,
      thickness: facts.thickness,
    );
  }

  @override
  FrameResourceDescriptorFacts? resourceDescriptor(CanvasResourceId id) {
    final facts = _store.resourceDescriptor(id);
    if (facts == null) {
      return null;
    }

    return FrameResourceDescriptorFacts(
      id: facts.id,
      appKey: facts.appKey,
      mimeType: facts.mimeType,
      contentHash: facts.contentHash,
      byteLength: facts.byteLength,
      resourceRevision: facts.resourceRevision,
      metadata: facts.metadata,
    );
  }

  Set<CanvasElementId> get selectedElementIds {
    return _selection.selectedElementIds;
  }

  void setSelection(Iterable<CanvasElementId> ids) {
    ensureRuntimeMutationAllowed();
    _publishSelectionChange(_selection.setSelection(ids));
  }

  void toggleSelection(CanvasElementId id) {
    ensureRuntimeMutationAllowed();
    _publishSelectionChange(_selection.toggleSelection(id));
  }

  void clearSelection() {
    ensureRuntimeMutationAllowed();
    _publishSelectionChange(_selection.clearSelection());
  }

  void selectAll({required bool onlySelectable}) {
    ensureRuntimeMutationAllowed();
    _publishSelectionChange(
      _selection.selectAll(onlySelectable: onlySelectable),
    );
  }

  void setCameraOffset(Offset offset) {
    ensureRuntimeMutationAllowed();
    final camera = CanvasCamera(offset: offset);
    if (camera == _viewCamera) {
      return;
    }
    _viewCamera = camera;
    _viewCameraRevision += 1;
    _publishRuntimeState();
  }

  void panCameraBy(Offset delta) {
    setCameraOffset(_viewCamera.offset + delta);
  }

  Never rejectSelectionDocumentMutation() {
    ensureRuntimeMutationAllowed();
    throw UnsupportedError(
      'Selection document mutation is owned by later edit phases.',
    );
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _ensureNoActiveEditSession();
    _isDisposed = true;
    _state.dispose();
    unawaited(_actions.close());
  }

  @override
  T runResolverCallback<T>(T Function() callback) {
    _ensureNotDisposed();
    if (_isRunningResolverCallback) {
      throw StateError('Nested resource resolver callbacks are not supported.');
    }
    _isRunningResolverCallback = true;
    try {
      return callback();
    } finally {
      _isRunningResolverCallback = false;
    }
  }

  @override
  void ensureRuntimeMutationAllowed() {
    _ensureNotDisposed();
    _ensureNoActiveEditSession();
    if (_isRunningResolverCallback) {
      throw StateError(
        'CanvasRuntime public mutations cannot run during resource resolver callbacks.',
      );
    }
  }

  @override
  void deliverResourceDirtyOutcome(ResourceDirtyOutcome outcome) {
    if (!outcome.hasDirtyResources) {
      return;
    }
    _invalidateActiveResourceSession(outcome);
    _deliverResourceDirtyResult(_resourceDirtyEffects(outcome));
  }

  void _invalidateActiveResourceSession(ResourceDirtyOutcome outcome) {
    final sink = _activeResourceSessionInvalidationSink;
    if (sink == null) {
      return;
    }
    if (outcome.allResourcesDirty) {
      sink.invalidateAllResourceImages();

      return;
    }
    for (final id in outcome.dirtyResourceIds) {
      sink.invalidateResourceImage(id);
    }
  }

  void _ensureNotDisposed() {
    _ensureNotDeliveringCommitEffects();
    if (_isDisposed) {
      throw StateError('CanvasRuntime is disposed.');
    }
  }

  void _ensureNoActiveEditSession() {
    _ensureNotDeliveringCommitEffects();
    if (_editKernel.hasOpenSession) {
      throw StateError(
        'CanvasRuntime public mutations cannot run inside an active edit callback.',
      );
    }
  }

  void _ensureNotDeliveringCommitEffects() {
    if (_isDeliveringCommitEffects) {
      throw StateError(
        'CanvasRuntime public mutations cannot run during post-commit effect delivery.',
      );
    }
  }

  void _publishSelectionChange(bool didChange) {
    if (!didChange) {
      return;
    }
    _publishRuntimeState();
  }

  void _publishRuntimeState() {
    _state.value = _runtimeState(
      _store,
      _selection.selectionFacts,
      _RuntimeRevisionFacts(
        viewCamera: _viewCameraRevision,
        preview: _previewRevision,
        epoch: _epochRevision,
        resourceVisual: _resourceKernel.resourceVisualRevision,
      ),
    );
  }

  void _loadDocument(CanvasDocument document) {
    final preparedLoad = _loadPipeline.prepare(document);

    final cleanupOutcome = _loadInteractionBoundary.prepareLoadCleanup();
    _loadPipeline.consume(preparedLoad);
    final didClearSelection = _selection.clearForDocumentReplacement();
    _viewCamera = preparedLoad.document.camera;
    _viewCameraRevision += 1;
    if (cleanupOutcome.previewChanged) {
      _preview = const CanvasNoPreview();
      _previewRevision += 1;
    }
    _epochRevision += 1;
    _deliverLoadResult(_loadEffects(didClearSelection: didClearSelection));
  }

  CommitDeliveryResult _applyEditCommit(
    CanvasDocument document,
    CommitPlan plan,
  ) {
    return _commitApplier.apply(
      document: document,
      plan: plan,
      documentInstallers: CommitDocumentInstallers(
        installDocument: _store.installDocument,
        replaceDocument: _store.replaceDocument,
      ),
      installSelectionEffects: _selection.pruneSelection,
    );
  }

  void _deliverEditCommitResult(CommitDeliveryResult applyResult) {
    _isDeliveringCommitEffects = true;
    try {
      _deliverSpatialEffects(applyResult.effects);
      if (applyResult.shouldPublishState) {
        if (applyResult.replacedDocument) {
          _epochRevision += 1;
        }
        _publishRuntimeState();
      }
      if (applyResult.effects.isNotEmpty) {
        _commitEffectObserver(applyResult.effects);
      }
    } on Object {
      // Observer failures are contained post-commit notifications. A future
      // diagnostics seam can report them without changing commit acceptance.
    } finally {
      _isDeliveringCommitEffects = false;
    }
  }

  void _deliverLoadResult(List<CommitDeliveryEffect> effects) {
    _isDeliveringCommitEffects = true;
    try {
      _deliverSpatialEffects(effects);
      _publishRuntimeState();
      if (effects.isNotEmpty) {
        _commitEffectObserver(effects);
      }
    } on Object {
      // Observer failures are contained post-load notifications. A future
      // diagnostics seam can report them without changing load acceptance.
    } finally {
      _isDeliveringCommitEffects = false;
    }
  }

  void _deliverResourceDirtyResult(List<CommitDeliveryEffect> effects) {
    _isDeliveringCommitEffects = true;
    try {
      _publishRuntimeState();
      if (effects.isNotEmpty) {
        _commitEffectObserver(effects);
      }
    } on Object {
      // Observer failures are contained post-dirty notifications. A future
      // diagnostics seam can report them without changing dirty acceptance.
    } finally {
      _isDeliveringCommitEffects = false;
    }
  }

  void _deliverSpatialEffects(List<CommitDeliveryEffect> effects) {
    for (final effect in effects.whereType<SpatialDeliveryEffect>()) {
      _spatial.applyTouched(this, effect.touchedSet);
    }
  }
}

void _ignoreCommitEffects(List<CommitDeliveryEffect> _) {}

List<CommitDeliveryEffect> _loadEffects({required bool didClearSelection}) {
  return List.unmodifiable([
    const ProjectionDeliveryEffect(),
    SpatialDeliveryEffect(touchedSet: TouchedSet(documentReplaced: true)),
    ResourceDeliveryEffect(touchedSet: TouchedSet(documentReplaced: true)),
    const RepaintDeliveryEffect(mainCanvas: true, overlayCanvas: true),
    if (didClearSelection) const SelectionDeliveryEffect(),
    const PublicStateDeliveryEffect(),
  ]);
}

List<CommitDeliveryEffect> _resourceDirtyEffects(ResourceDirtyOutcome outcome) {
  return List.unmodifiable([
    ResourceDeliveryEffect(
      touchedSet: TouchedSet(
        resourceVisualChangedIds: outcome.dirtyResourceIds,
        allResourceVisualsChanged: outcome.allResourcesDirty,
      ),
    ),
    const RepaintDeliveryEffect(mainCanvas: true),
    const PublicStateDeliveryEffect(),
  ]);
}

CanvasRuntimeState _runtimeState(
  DocumentStoreKernel store,
  SelectionFacts? selectionFacts,
  _RuntimeRevisionFacts runtimeRevisions,
) {
  final selection =
      selectionFacts ??
      SelectionFacts(selectedElementIds: const {}, selectionRevision: 0);

  return CanvasRuntimeState(
    revisions: CanvasRuntimeRevisions(
      document: store.documentRevision,
      selection: selection.selectionRevision,
      preview: runtimeRevisions.preview,
      viewCamera: runtimeRevisions.viewCamera,
      resourceVisual: runtimeRevisions.resourceVisual,
      interaction: 0,
      epoch: runtimeRevisions.epoch,
    ),
    summary: CanvasRuntimeSummary(
      elementCount: store.documentSummary.elementCount,
      layerCount: store.documentSummary.layerCount,
      resourceCount: store.documentSummary.resourceCount,
      selectedCount: selection.selectedCount,
    ),
  );
}

final class _RuntimeRevisionFacts {
  const _RuntimeRevisionFacts({
    this.viewCamera = 0,
    this.preview = 0,
    this.epoch = 0,
    this.resourceVisual = 0,
  });

  final int viewCamera;
  final int preview;
  final int epoch;
  final int resourceVisual;
}

final class _StoreSelectionMembership implements SelectionMembershipPort {
  const _StoreSelectionMembership(this.store);

  final DocumentStoreKernel store;

  @override
  Set<CanvasElementId> normalizeSelection(Iterable<CanvasElementId> ids) {
    return store.normalizeSelection(ids);
  }

  @override
  Set<CanvasElementId> selectAllElementIds({required bool onlySelectable}) {
    return onlySelectable
        ? store.selectableElementIds
        : store.contentElementIds;
  }
}

final class _StoreResourceCatalog implements ResourceCatalogPort {
  const _StoreResourceCatalog(this.store);

  final DocumentStoreKernel store;

  @override
  int get resourceCount => store.resourceCount;

  @override
  List<CanvasResource> get resources => store.resources;

  @override
  CanvasResource? resourceById(CanvasResourceId id) {
    return store.resourceById(id);
  }
}

final class _RuntimeCameraPort implements CanvasCameraPort {
  const _RuntimeCameraPort(this.root);

  final RuntimeRoot root;

  @override
  CanvasCamera get camera => root.viewCamera;

  @override
  Offset get offset => root.viewCameraOffset;

  @override
  void setOffset(Offset offset) {
    root.setCameraOffset(offset);
  }

  @override
  void panBy(Offset delta) {
    root.panCameraBy(delta);
  }
}

// The public selection port is one interface; keeping its adapter whole makes
// unsupported later-phase commands and selection-only commands auditable
// together instead of scattering facade behavior across metric-shaped classes.
// ignore: number-of-methods
final class _RuntimeSelectionPort implements CanvasSelectionPort {
  const _RuntimeSelectionPort(this.root);

  final RuntimeRoot root;

  @override
  Set<CanvasElementId> get selectedElementIds => root.selectedElementIds;

  @override
  void setSelection(Iterable<CanvasElementId> ids) {
    root.setSelection(ids);
  }

  @override
  void toggleSelection(CanvasElementId id) {
    root.toggleSelection(id);
  }

  @override
  void clearSelection() {
    root.clearSelection();
  }

  @override
  void selectAll({bool onlySelectable = true}) {
    root.selectAll(onlySelectable: onlySelectable);
  }

  @override
  void moveSelection(Offset delta, {int? timestampMs}) {
    root.rejectSelectionDocumentMutation();
  }

  @override
  void rotateSelectionClockwise({int? timestampMs}) {
    root.rejectSelectionDocumentMutation();
  }

  @override
  void rotateSelectionCounterClockwise({int? timestampMs}) {
    root.rejectSelectionDocumentMutation();
  }

  @override
  void flipSelectionVertical({int? timestampMs}) {
    root.rejectSelectionDocumentMutation();
  }

  @override
  void flipSelectionHorizontal({int? timestampMs}) {
    root.rejectSelectionDocumentMutation();
  }

  @override
  void deleteSelection({int? timestampMs}) {
    root.rejectSelectionDocumentMutation();
  }
}
