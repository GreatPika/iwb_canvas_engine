// RuntimeRoot intentionally owns the composition boundary. Import count is
// accepted here because the file exposes dependency direction at the facade
// boundary instead of hiding owned seams behind metric-only wrappers.
// ignore_for_file: number-of-imports

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../contracts/internal/command_facts_port.dart';
import '../contracts/internal/commit_action_intent.dart';
import '../contracts/internal/commit_delivery.dart';
import '../contracts/internal/document_facts_port.dart';
import '../contracts/internal/frame_facts_port.dart';
import '../contracts/internal/load_interaction_boundary.dart';
import '../contracts/internal/measured_text_layout.dart';
import '../contracts/internal/prepared_selection_effect.dart';
import '../contracts/internal/resource_catalog_port.dart';
import '../contracts/internal/resource_dirty_outcome.dart';
import '../contracts/internal/resource_session_release_sink.dart';
import '../contracts/internal/resolver_mutation_guard.dart';
import '../contracts/internal/selection_facts_port.dart';
import '../contracts/internal/selection_membership_port.dart';
import '../contracts/internal/surface_resource_session_lifecycle.dart';
import '../contracts/internal/text_edit_paint_suppression.dart';
import '../contracts/internal/touched_set.dart';
import '../contracts/public/canvas_actions.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_element_update.dart';
import '../contracts/public/canvas_field_update.dart';
import '../contracts/public/canvas_geometry.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_pointer.dart';
import '../contracts/public/canvas_preview.dart';
import '../contracts/public/canvas_resource.dart';
import '../contracts/public/canvas_runtime.dart';
import '../contracts/public/canvas_surface_styles.dart';
import '../contracts/public/canvas_text_editing.dart';
import '../contracts/public/canvas_tools.dart';
import '../contracts/public/canvas_value_validators.dart';
import '../diagnostics/diagnostics_hub.dart';
import '../edit/commit_applier.dart';
import '../edit/commit_plan.dart';
import '../edit/edit_kernel.dart';
import '../edit/edit_session.dart';
import '../edit/staged_document_load.dart';
import '../frame/captured_frame.dart';
import '../frame/frame_engine.dart';
import '../frame/frame_paint_output.dart';
import '../frame/frame_text_layout_measurer.dart';
import '../geometry/geometry_policy.dart';
import '../geometry/spatial_kernel.dart';
import '../interaction/interaction_engine.dart';
import '../interaction/interaction_pointer_context.dart';
import '../interaction/interaction_read_port.dart';
import '../interaction/interaction_request_registry.dart';
import '../interaction/interaction_runtime_intents.dart';
import '../interaction/pointer_cleanup_protocol.dart';
import '../interaction/text_edit_guard_decision.dart';
import '../resources/resource_kernel.dart';
import '../selection/selection_kernel.dart';
import '../store/committed_document.dart';
import '../store/document_store_kernel.dart';
import '../store/element_registry.dart';
import '../store/resource_table.dart';
import 'runtime_command_facts_adapter.dart';
import 'runtime_config.dart';
import 'runtime_action_finalizer.dart';
import 'runtime_interaction_diagnostics_adapter.dart';
import 'runtime_interaction_read_adapter.dart';

@visibleForTesting
typedef TextEditPrepareInput = ({
  CanvasInteractionRequestId requestId,
  CanvasElementId targetElementId,
  String previousText,
  String newText,
  int? timestampMs,
});

@visibleForTesting
typedef TextEditPrepareOverride =
    CommitDeliveryResult Function(TextEditPrepareInput input);

typedef RuntimeSurfaceFrameSignal = ({
  CanvasRuntimeState state,
  int generation,
  bool mainCanvas,
  bool overlayCanvas,
  String reason,
});

typedef _RuntimeSurfaceRepaintTarget = ({
  bool mainCanvas,
  bool overlayCanvas,
  String reason,
});

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
    required CanvasRuntimeConfig config,
    CommitEffectObserver? commitEffectObserver,
  }) : this._(
         store: DocumentStoreKernel(),
         config: RuntimeConfig.from(config),
         diagnostics: diagnosticsHubForPolicy(config.diagnosticPolicy),
         loadInteractionBoundary: null,
         textEditPrepareOverride: null,
         initialViewCamera: CanvasCamera(),
         commitEffectObserver: commitEffectObserver ?? _ignoreCommitEffects,
       );

  @visibleForTesting
  factory RuntimeRoot.test({
    required CanvasRuntimeConfig config,
    DocumentStoreKernel? store,
    LoadInteractionBoundary? loadInteractionBoundary,
    TextEditPrepareOverride? textEditPrepareOverride,
    CommitEffectObserver? commitEffectObserver,
  }) {
    final resolvedStore = store ?? DocumentStoreKernel();

    return RuntimeRoot._(
      store: resolvedStore,
      config: RuntimeConfig.from(config),
      diagnostics: diagnosticsHubForPolicy(config.diagnosticPolicy),
      loadInteractionBoundary: loadInteractionBoundary,
      textEditPrepareOverride: textEditPrepareOverride,
      initialViewCamera: resolvedStore.camera,
      commitEffectObserver: commitEffectObserver ?? _ignoreCommitEffects,
    );
  }

  RuntimeRoot._({
    required DocumentStoreKernel store,
    required this.config,
    required DiagnosticsHub? diagnostics,
    required LoadInteractionBoundary? loadInteractionBoundary,
    required TextEditPrepareOverride? textEditPrepareOverride,
    required CanvasCamera initialViewCamera,
    required CommitEffectObserver commitEffectObserver,
  }) : _store = store,
       _diagnostics = diagnostics,
       _viewCamera = initialViewCamera,
       _loadInteractionBoundary = loadInteractionBoundary,
       _textEditPrepareOverride = textEditPrepareOverride,
       _loadPipeline = LoadDocumentPipeline(
         store: store,
         diagnostics: diagnostics,
       ),
       _commitEffectObserver = commitEffectObserver,
       _selection = SelectionKernel(
         membership: _StoreSelectionMembership(store),
       ),
       _textLayoutMeasurer = FrameTextLayoutMeasurer(),
       _spatial = SpatialKernel(),
       _interactionEngine = InteractionEngine(
         initialMode: config.initialMode,
         initialDrawStyle: config.initialDrawStyle,
         pointerPolicy: config.pointerPolicy,
         diagnosticsSink: RuntimeInteractionDiagnosticsAdapter(diagnostics),
       ),
       _state = ValueNotifier<CanvasRuntimeState>(
         _runtimeState(store, null, const _RuntimeRevisionFacts()),
       ),
       _surfaceFrameSignal = ValueNotifier<RuntimeSurfaceFrameSignal?>(null) {
    _interactionEngine.attachReadPort(_interactionReadPort);
    _spatial.rebuild(this);
  }

  // Configuration and owned infrastructure.
  final RuntimeConfig config;
  final DocumentStoreKernel _store;
  final DiagnosticsHub? _diagnostics;
  final LoadInteractionBoundary? _loadInteractionBoundary;
  final TextEditPrepareOverride? _textEditPrepareOverride;
  final LoadDocumentPipeline _loadPipeline;
  final CommitEffectObserver _commitEffectObserver;

  // Core kernels and engines.
  final SelectionKernel _selection;
  final FrameTextLayoutMeasurer _textLayoutMeasurer;
  final InteractionEngine _interactionEngine;
  final SpatialKernel _spatial;
  final CommitApplier _commitApplier = const CommitApplier();
  final RuntimeActionFinalizer _actionFinalizer = RuntimeActionFinalizer();

  // Public state and event streams.
  CanvasCamera _viewCamera;
  final ValueNotifier<CanvasRuntimeState> _state;
  final ValueNotifier<RuntimeSurfaceFrameSignal?> _surfaceFrameSignal;
  final StreamController<CanvasActionCommitted> _actions =
      StreamController<CanvasActionCommitted>.broadcast(sync: true);
  final StreamController<CanvasContextActionRequested> _contextActionRequests =
      StreamController<CanvasContextActionRequested>.broadcast();

  // Runtime revision counters.
  int _viewCameraRevision = 0;
  int _surfaceFrameGeneration = 0;
  int _runtimeStatePublicationGeneration = 0;
  int _epochRevision = 0;
  int _textEditInteractionRevision = 0;
  int _contextRequestGeneration = 0;
  final List<({int generation, PendingContextActionRequest pendingRequest})>
  _pendingContextRequests = [];
  bool _isContextRequestDeliveryScheduled = false;

  // Mutation and lifecycle guards.
  bool _isDisposed = false;
  bool _isDeliveringCommitEffects = false;
  bool _isInstallingDocumentLoad = false;
  bool _isRunningResolverCallback = false;
  Object? _activeSurfaceToken;
  SurfaceResourceSessionLifecycle? _activeSurfaceResourceSession;
  ResourceSessionReleaseSink? _activeResourceSessionReleaseSink;

  // Lazy internal adapters and kernels.
  late final InteractionReadPort _interactionReadPort =
      RuntimeInteractionReadAdapter(
        frame: this,
        documentSummary: _documentSummary,
        selection: _selection,
        spatial: _spatial,
        controllerEpoch: () => _epochRevision,
      );
  late final EditKernel _editKernel = EditKernel(
    mutationGuard: this,
    readDocument: _store.readDocument,
    readSparseFacts: () => _StoreSparseEditFacts(_store),
    selectedElementIds: () => _selection.selectedElementIds,
    prepareSparseCommit: _store.prepareSparseCommit,
    prepareMaterializedCommit: _store.prepareMaterializedCommit,
    installCommit: _applyEditCommit,
    deliverApplyResult: _deliverEditCommitResult,
    installLoadedDocument: _loadDocumentFromJson,
  );
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
    textLayoutMeasurer: _textLayoutMeasurer,
  );
  late final CommandFactsPort _commandFacts = RuntimeCommandFactsAdapter(
    frame: this,
    selection: _selection,
    resources: _resourceCatalogPort,
    documentSummary: _documentSummary,
  );

  // Public facade ports.
  late final CanvasEditPort _editPort = _editKernel.port;
  late final CanvasSelectionPort _selectionPort = _RuntimeSelectionPort(this);
  late final CanvasToolPort _toolPort = _RuntimeToolPort(this);
  late final CanvasCommandPort _commandPort = _RuntimeCommandPort(this);
  late final CanvasCameraPort _cameraPort = _RuntimeCameraPort(this);
  late final _RuntimeTextEditingPort _textEditingPort = _RuntimeTextEditingPort(
    this,
  );

  // Public state.
  ValueListenable<CanvasRuntimeState> get state => _state;
  ValueListenable<RuntimeSurfaceFrameSignal?> get surfaceFrameSignal =>
      _surfaceFrameSignal;
  bool get isDisposed => _isDisposed;
  int get projectionBuildCount => _store.projectionBuildCount;

  // Facade ports.
  CanvasEditPort get edits => _editPort;
  CanvasSelectionPort get selection => _selectionPort;
  CanvasToolPort get tools => _toolPort;
  CanvasCommandPort get commands => _commandPort;
  CanvasResourcePort get resources => _resourceKernel;
  CanvasTextEditingPort get textEditing => _textEditingPort;
  ResourceCatalogPort get resourceCatalogPort => _resourceCatalogPort;
  CanvasCameraPort cameraPort() => _cameraPort;

  // Event streams.
  Stream<CanvasActionCommitted> get actions => _actions.stream;
  Stream<CanvasContextActionRequested> get contextActionRequests =>
      _contextActionRequests.stream;

  // Backward-compatible method accessors.
  CanvasToolPort toolPort() => _toolPort;
  CanvasCommandPort commandPort() => _commandPort;
  Stream<CanvasContextActionRequested> contextActionRequestStream() {
    return _contextActionRequests.stream;
  }

  // Camera and interaction state.
  CanvasPreviewState get preview => _interactionEngine.preview;
  CanvasCamera get viewCamera => _viewCamera;
  Offset get viewCameraOffset => _viewCamera.offset;
  SelectionFacts get selectionFacts => _selection.selectionFacts;

  // Internal and test read ports.
  @visibleForTesting
  InteractionEngine get interactionEngine => _interactionEngine;
  @visibleForTesting
  InteractionReadPort get interactionReadPort => _interactionReadPort;
  @visibleForTesting
  List<DiagnosticRecord> get diagnosticRecords {
    return _diagnostics?.records ?? const [];
  }

  DocumentFactsPort get documentFactsPort => this;
  FrameFactsPort get frameFactsPort => this;
  @visibleForTesting
  SpatialKernel get spatialKernel => _spatial;
  @visibleForTesting
  Object? get activeTextEditSuppressionForTesting {
    return _textEditingPort.activeSuppressionToken;
  }

  @visibleForTesting
  ({
    CanvasInteractionRequestId requestId,
    CanvasElementId elementId,
    TextEditSuppressionFamily family,
    CanvasElementKind elementKind,
    int controllerEpoch,
    int elementRevision,
    int generation,
  })?
  get activeTextEditSuppressionIdentityForTesting {
    return _textEditingPort.activeSuppressionToken?.identityForTesting;
  }

  @visibleForTesting
  int get textEditCandidateStateCountForTesting {
    return _textEditingPort.candidateStateCount;
  }

  // Surface lifecycle.
  void attachSurface(Object token) {
    _ensureNotDisposed();
    final activeToken = _activeSurfaceToken;
    if (activeToken == null || identical(activeToken, token)) {
      _activeSurfaceToken = token;

      return;
    }

    throw StateError('CanvasRuntime already has an active CanvasSurface.');
  }

  bool detachSurface(Object token) {
    if (!identical(_activeSurfaceToken, token)) {
      return false;
    }
    _dropActiveSurfaceResourceSession();
    _activeSurfaceToken = null;
    _clearSurfaceFrameSignal();

    return true;
  }

  bool isActiveSurface(Object token) {
    return identical(_activeSurfaceToken, token);
  }

  void installSurfaceResourceSession(
    Object token,
    SurfaceResourceSessionLifecycle session,
  ) {
    ensureRuntimeMutationAllowed();
    if (!isActiveSurface(token)) {
      throw StateError('CanvasSurface is not active for this CanvasRuntime.');
    }
    _dropActiveSurfaceResourceSession();
    _activeSurfaceResourceSession = session;
    _activeResourceSessionReleaseSink = session;
  }

  @visibleForTesting
  SurfaceResourceSessionLifecycle? get activeSurfaceResourceSessionForTesting {
    return _activeSurfaceResourceSession;
  }

  // Frame facade.
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

  // The asset-binding builder stays supplied by surface/resources while frame
  // ownership remains inside FrameEngine.
  // ignore: number-of-parameters
  MainFramePaintOutput buildMainFrameWithAssetBindings({
    required Rect viewportWorldBounds,
    required double devicePixelRatio,
    required CanvasSelectionStyle selectionStyle,
    required CanvasGridStyle gridStyle,
    required FrameAssetBindingBuilder bindAssets,
  }) {
    return _frameEngine.buildMainFrameWithAssetBindings(
      inputs: _frameInputs(
        viewportWorldBounds: viewportWorldBounds,
        devicePixelRatio: devicePixelRatio,
        selectionStyle: selectionStyle,
        gridStyle: gridStyle,
      ),
      viewCameraBucket: _viewCameraRevision,
      bindAssets: bindAssets,
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
      previewRevision: _interactionEngine.previewRevision,
      viewCameraOffset: _viewCamera.offset,
      viewCameraRevision: _viewCameraRevision,
      textEditSuppression: _textEditingPort.activeFrameSuppression,
    );
  }

  // Resource session release API.
  void attachResourceSessionReleaseSink(ResourceSessionReleaseSink sink) {
    ensureRuntimeMutationAllowed();
    _activeResourceSessionReleaseSink = sink;
  }

  void clearResourceSessionReleaseSink(ResourceSessionReleaseSink sink) {
    ensureRuntimeMutationAllowed();
    if (identical(_activeResourceSessionReleaseSink, sink)) {
      _activeResourceSessionReleaseSink = null;
    }
  }

  // DocumentFactsPort.
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

  CanvasDocumentSummary _documentSummary() => _store.documentSummary;

  // FrameFactsPort.
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
      measuredTextLayout: _measuredTextLayoutFor(facts),
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

    return switch (facts) {
      StoreImageResourceDescriptorFacts() => FrameImageResourceDescriptorFacts(
        id: facts.id,
        appKey: facts.appKey,
        mimeType: facts.mimeType,
        contentHash: facts.contentHash,
        byteLength: facts.byteLength,
        resourceRevision: facts.resourceRevision,
        metadata: facts.metadata,
      ),
      StoreVectorResourceDescriptorFacts() =>
        FrameVectorResourceDescriptorFacts(
          id: facts.id,
          appKey: facts.appKey,
          contentHash: facts.contentHash,
          byteLength: facts.byteLength,
          resourceRevision: facts.resourceRevision,
          metadata: facts.metadata,
        ),
    };
  }

  FrameElementFacts? _frameFactsForElement(CanvasElementId id) {
    final handle = elementHandleForId(frameRevisions.structuralRevision, id);
    return handle == null ? null : resolveElement(handle);
  }

  // This explicit copy keeps a live text measurement in the same frame-facts
  // shape GeometryPolicy already owns; splitting fields into a partial builder
  // would make the frame handoff harder to audit.
  // ignore: halstead-volume, source-lines-of-code
  FrameElementFacts _textFrameFactsWithLiveText(
    FrameElementFacts source,
    String text, {
    CanvasTransform? transform,
    MeasuredTextLayout? measuredTextLayout,
  }) {
    final layout =
        measuredTextLayout ?? _measuredTextLayoutFromFrameFacts(source, text);

    return FrameElementFacts(
      id: source.id,
      kind: source.kind,
      revision: source.revision,
      generation: source.generation,
      orderToken: source.orderToken,
      locationKind: source.locationKind,
      transform: transform ?? source.transform,
      opacity: source.opacity,
      hitPadding: source.hitPadding,
      isVisible: source.isVisible,
      isSelectable: source.isSelectable,
      isLocked: source.isLocked,
      isDeletable: source.isDeletable,
      isTransformable: source.isTransformable,
      metadata: source.metadata,
      resourceId: source.resourceId,
      layerId: source.layerId,
      size: source.size,
      naturalSize: source.naturalSize,
      svgPathData: source.svgPathData,
      fillColor: source.fillColor,
      strokeColor: source.strokeColor,
      strokeWidth: source.strokeWidth,
      fillRule: source.fillRule,
      text: text,
      fontSize: source.fontSize,
      textColor: source.textColor,
      textAlign: source.textAlign,
      textDirection: source.textDirection,
      isBold: source.isBold,
      isItalic: source.isItalic,
      isUnderline: source.isUnderline,
      fontFamily: source.fontFamily,
      maxWidth: source.maxWidth,
      lineHeight: source.lineHeight,
      measuredTextLayout: layout,
      points: source.points,
      start: source.start,
      end: source.end,
      color: source.color,
      thickness: source.thickness,
    );
  }

  MeasuredTextLayout? _measuredTextLayoutFor(StoreElementFacts facts) {
    final text = facts.text;
    if (facts.kind != CanvasElementKind.text || text == null) {
      return null;
    }
    final result = _textLayoutMeasurer.measureTextLayout(
      MeasuredTextLayoutInput(
        text: text,
        fontSize: facts.fontSize ?? 24,
        color: _textLayoutColorFor(facts),
        align: facts.textAlign ?? TextAlign.left,
        direction: facts.textDirection ?? TextDirection.ltr,
        isBold: facts.isBold ?? false,
        isItalic: facts.isItalic ?? false,
        isUnderline: facts.isUnderline ?? false,
        fontFamily: facts.fontFamily,
        maxWidth: facts.maxWidth,
        lineHeight: facts.lineHeight,
      ),
    );

    return switch (result) {
      MeasuredTextLayoutReady(:final layout) => layout,
      MeasuredTextLayoutFailed(:final reason) => throw StateError(
        'Text layout measurement failed for ${facts.id.value}: $reason',
      ),
    };
  }

  MeasuredTextLayout _measuredTextLayoutFromFrameFacts(
    FrameElementFacts facts,
    String text,
  ) {
    final result = _textLayoutMeasurer.measureTextLayout(
      MeasuredTextLayoutInput(
        text: text,
        fontSize: facts.fontSize ?? 24,
        color: facts.textColor ?? const Color(0xFF000000),
        align: facts.textAlign ?? TextAlign.left,
        direction: facts.textDirection ?? TextDirection.ltr,
        isBold: facts.isBold ?? false,
        isItalic: facts.isItalic ?? false,
        isUnderline: facts.isUnderline ?? false,
        fontFamily: facts.fontFamily,
        maxWidth: facts.maxWidth,
        lineHeight: facts.lineHeight,
      ),
    );

    return switch (result) {
      MeasuredTextLayoutReady(:final layout) => layout,
      MeasuredTextLayoutFailed(:final reason) => throw StateError(
        'Text layout measurement failed for ${facts.id.value}: $reason',
      ),
    };
  }

  // Document read and id generation.
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

  // Selection commands.
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

  void moveSelection(Offset delta, {int? timestampMs}) {
    ensureRuntimeMutationAllowed();
    validateOffset(delta, path: 'selection.move.delta');
    if (delta == Offset.zero) {
      return;
    }
    final transform = CanvasTransform.translation(delta);
    _deliverSelectionTransform(
      transform: transform,
      operation: CanvasTransformOperation.move,
      pivotWorld: null,
      timestampMs: timestampMs,
    );
  }

  void rotateSelectionClockwise({int? timestampMs}) {
    ensureRuntimeMutationAllowed();
    _deliverSelectionTransformAroundCenter(
      operation: CanvasTransformOperation.rotateClockwise,
      localTransform: CanvasTransform.rotationDegrees(90),
      timestampMs: timestampMs,
    );
  }

  void rotateSelectionCounterClockwise({int? timestampMs}) {
    ensureRuntimeMutationAllowed();
    _deliverSelectionTransformAroundCenter(
      operation: CanvasTransformOperation.rotateCounterClockwise,
      localTransform: CanvasTransform.rotationDegrees(-90),
      timestampMs: timestampMs,
    );
  }

  void flipSelectionVertical({int? timestampMs}) {
    ensureRuntimeMutationAllowed();
    _deliverSelectionTransformAroundCenter(
      operation: CanvasTransformOperation.flipVertical,
      localTransform: CanvasTransform.scale(1, -1),
      timestampMs: timestampMs,
    );
  }

  void flipSelectionHorizontal({int? timestampMs}) {
    ensureRuntimeMutationAllowed();
    _deliverSelectionTransformAroundCenter(
      operation: CanvasTransformOperation.flipHorizontal,
      localTransform: CanvasTransform.scale(-1, 1),
      timestampMs: timestampMs,
    );
  }

  void deleteSelection({int? timestampMs}) {
    ensureRuntimeMutationAllowed();
    final facts = _commandFacts.selectionDeleteFacts();
    if (facts.deletableIds.isEmpty) {
      return;
    }
    final applyResult = _editKernel.prepareInteractionCommit(
      (edit) {
        for (final id in facts.deletableIds) {
          edit.removeElement(id);
        }
      },
      augmentPlan: (plan) => plan.withActionIntents([
        DeleteSelectionActionIntent(
          removedElementIds: facts.deletableIds,
          timestampHintMs: timestampMs,
        ),
      ]),
    );
    _deliverEditCommitResult(applyResult);
  }

  void _deliverSelectionTransformAroundCenter({
    required CanvasTransformOperation operation,
    required CanvasTransform localTransform,
    required int? timestampMs,
  }) {
    final facts = _commandFacts.selectionTransformFacts();
    if (facts.movableElements.isEmpty || facts.selectionBoundsWorld.isEmpty) {
      return;
    }
    final pivot = facts.selectionBoundsWorld.center;
    _deliverSelectionTransform(
      transform: _aroundPivot(localTransform, pivot),
      operation: operation,
      pivotWorld: pivot,
      timestampMs: timestampMs,
      facts: facts,
    );
  }

  // The transform descriptor is kept explicit so move and pivoted transform
  // actions share one delivery path without hiding action payload fields.
  // ignore: number-of-parameters
  void _deliverSelectionTransform({
    required CanvasTransform transform,
    required CanvasTransformOperation operation,
    required Offset? pivotWorld,
    required int? timestampMs,
    SelectionTransformFacts? facts,
  }) {
    final commandFacts = facts ?? _commandFacts.selectionTransformFacts();
    if (commandFacts.movableElements.isEmpty) {
      return;
    }
    final elementIds = commandFacts.movableElements.map((e) => e.id);
    final List<CommitActionIntent> actionIntents;
    if (operation == CanvasTransformOperation.move) {
      actionIntents = [
        MoveSelectionActionIntent(
          elementIds: elementIds,
          transform: transform,
          timestampHintMs: timestampMs,
        ),
      ];
    } else {
      final pivot = pivotWorld;
      if (pivot == null) {
        throw StateError(
          'Pivot is required for non-move selection transforms.',
        );
      }
      actionIntents = [
        TransformSelectionActionIntent(
          elementIds: elementIds,
          transform: transform,
          operation: operation,
          pivotWorld: pivot,
          timestampHintMs: timestampMs,
        ),
      ];
    }
    final applyResult = _editKernel.prepareInteractionCommit((edit) {
      for (final element in commandFacts.movableElements) {
        edit.updateElement(
          _transformUpdate(element, transform.multiply(element.transform)),
        );
      }
    }, augmentPlan: (plan) => plan.withActionIntents(actionIntents));
    _deliverEditCommitResult(applyResult);
  }

  // Command operations.
  bool removeElementByCommand(CanvasElementId id, {int? timestampMs}) {
    ensureRuntimeMutationAllowed();
    final facts = _commandFacts.removeElementFacts(id);
    if (!facts.canRemove) {
      return false;
    }
    var didRemove = false;
    final applyResult = _editKernel.prepareInteractionCommit(
      (edit) {
        didRemove = edit.removeElement(id);
      },
      augmentPlan: (plan) => didRemove
          ? plan.withActionIntents([
              RemoveElementActionIntent(
                elementId: id,
                timestampHintMs: timestampMs,
              ),
            ])
          : plan,
    );
    _deliverEditCommitResult(applyResult);

    return didRemove;
  }

  CanvasClearResult clearContentByCommand({
    required bool removeUnusedResources,
    int? timestampMs,
  }) {
    ensureRuntimeMutationAllowed();
    final facts = _commandFacts.clearContentFacts(
      removeUnusedResources: removeUnusedResources,
    );
    if (facts.removableElementIds.isEmpty &&
        facts.removableResourceIds.isEmpty) {
      return CanvasClearResult(
        removedElementIds: const [],
        removedResourceIds: const [],
        didClearContent: false,
      );
    }
    late CanvasClearResult result;
    final applyResult = _editKernel.prepareInteractionCommit(
      (edit) {
        result = edit.clearContent(
          removeUnusedResources: removeUnusedResources,
        );
      },
      augmentPlan: (plan) => result.removedElementIds.isNotEmpty
          ? plan.withActionIntents([
              ClearContentActionIntent(
                removedElementIds: result.removedElementIds,
                removedResourceIds: result.removedResourceIds,
                timestampHintMs: timestampMs,
              ),
            ])
          : plan,
    );
    _deliverEditCommitResult(applyResult);

    return result;
  }

  bool commitTextEdit(
    CanvasInteractionRequestId requestId,
    String newText, {
    int? timestampMs,
  }) {
    ensureRuntimeMutationAllowed();
    _validateTextEditCommandInput(requestId, newText, timestampMs);

    final guard = _interactionEngine.textEditGuardDecision(requestId);
    if (guard.kind != TextEditGuardDecisionKind.accepted) {
      _textEditingPort.clearConsumedRequest(requestId);

      return false;
    }
    final targetElementId = guard.targetElementId as CanvasElementId;
    final previousText = guard.currentText as String;
    if (previousText == newText) {
      _interactionEngine.consumeTextEditRequest(requestId);
      _textEditingPort.clearAcceptedRequest(requestId);

      return true;
    }
    final applyResult = _prepareTextEditCommit((
      requestId: requestId,
      targetElementId: targetElementId,
      previousText: previousText,
      newText: newText,
      timestampMs: timestampMs,
    ));
    if (!applyResult.shouldPublishState) {
      return false;
    }
    _interactionEngine.consumeTextEditRequest(requestId);
    final didClearTextEditSuppression = _textEditingPort.clearAcceptedRequest(
      requestId,
      publishState: false,
    );
    if (didClearTextEditSuppression) {
      _markTextEditInteractionChanged();
    }
    _deliverEditCommitResult(applyResult);

    return true;
  }

  CommitDeliveryResult _prepareTextEditCommit(TextEditPrepareInput input) {
    final prepareOverride = _textEditPrepareOverride;
    if (prepareOverride != null) {
      return prepareOverride(input);
    }
    final transform = _textEditAnchorPreservingTransform(
      input.targetElementId,
      input.newText,
    );

    return _editKernel.prepareInteractionCommit(
      (edit) => edit.updateElement(
        CanvasTextElementUpdate(
          id: input.targetElementId,
          transform: transform == null
              ? const CanvasFieldUpdate.absent()
              : CanvasFieldSet(transform),
          text: CanvasFieldSet(input.newText),
        ),
      ),
      augmentPlan: (plan) => plan.withActionIntents([
        EditTextActionIntent(
          requestId: input.requestId,
          elementId: input.targetElementId,
          previousTextLength: input.previousText.length,
          nextTextLength: input.newText.length,
          timestampHintMs: input.timestampMs,
        ),
      ]),
    );
  }

  CanvasTransform? _textEditAnchorPreservingTransform(
    CanvasElementId elementId,
    String newText,
  ) {
    final anchorInputs = _textEditAnchorInputsFor(elementId, newText);
    if (anchorInputs == null) {
      return null;
    }
    final current = anchorInputs.current;
    final delta = _textEditAnchorWorldDelta(
      current,
      anchorInputs.currentLayout,
      anchorInputs.nextLayout,
    );
    if (delta == Offset.zero) {
      return null;
    }

    return current.transform.withTranslation(
      current.transform.translation + delta,
    );
  }

  CanvasTransform _textEditAnchorPreservingTransformForLayout(
    FrameElementFacts current,
    MeasuredTextLayout currentLayout,
    MeasuredTextLayout nextLayout,
  ) {
    final delta = _textEditAnchorWorldDelta(current, currentLayout, nextLayout);
    if (delta == Offset.zero) {
      return current.transform;
    }

    return current.transform.withTranslation(
      current.transform.translation + delta,
    );
  }

  ({
    FrameElementFacts current,
    MeasuredTextLayout currentLayout,
    MeasuredTextLayout nextLayout,
  })?
  _textEditAnchorInputsFor(CanvasElementId elementId, String newText) {
    final current = _frameFactsForElement(elementId);
    final currentLayout = current?.measuredTextLayout;
    if (current == null ||
        current.kind != CanvasElementKind.text ||
        currentLayout == null ||
        current.text == newText) {
      return null;
    }
    final nextLayout = _textFrameFactsWithLiveText(
      current,
      newText,
    ).measuredTextLayout;
    if (nextLayout == null) {
      return null;
    }

    return (
      current: current,
      currentLayout: currentLayout,
      nextLayout: nextLayout,
    );
  }

  Offset _textEditAnchorWorldDelta(
    FrameElementFacts current,
    MeasuredTextLayout currentLayout,
    MeasuredTextLayout nextLayout,
  ) {
    final align = current.textAlign ?? TextAlign.left;
    final direction = current.textDirection ?? TextDirection.ltr;
    final oldAnchorWorld = current.transform.applyToPoint(
      _textEditAnchorLocalFor(currentLayout.paintBoundsLocal, align, direction),
    );
    final nextAnchorWorld = current.transform.applyToPoint(
      _textEditAnchorLocalFor(nextLayout.paintBoundsLocal, align, direction),
    );

    return oldAnchorWorld - nextAnchorWorld;
  }

  // Surface interaction lifecycle.
  void handleSurfaceInteractiveDisabled() {
    ensureRuntimeMutationAllowed();
    final outcome = _interactionEngine.interactiveDisabledCleanup();
    _applyPointerCleanupSelection(outcome);
    if (outcome.publicStateNeeded) {
      _publishRuntimeState(
        surfaceRepaintTarget: _surfaceRepaintTargetForCleanup(outcome),
      );
    }
  }

  // Tool state.
  void setInteractionMode(CanvasInteractionMode mode) {
    ensureRuntimeMutationAllowed();
    final previousMode = _interactionEngine.mode;
    final outcome = _interactionEngine.setMode(
      mode,
      cleanupSelectionMode: previousMode == CanvasInteractionMode.move,
    );
    _applyPointerCleanupSelection(outcome);
    final didChangeMode = previousMode != mode;
    final didClearSelection =
        didChangeMode &&
        mode == CanvasInteractionMode.draw &&
        config.clearSelectionOnDrawModeEnter &&
        _selection.clearSelection();
    if (didChangeMode || didClearSelection || outcome.publicStateNeeded) {
      _publishRuntimeState(
        surfaceRepaintTarget:
            _surfaceRepaintTargetForCleanup(outcome) ??
            (didClearSelection
                ? _surfaceRepaintTarget(
                    mainCanvas: true,
                    overlayCanvas: false,
                    reason: 'selection',
                  )
                : null),
      );
    }
  }

  void setDrawStyle(CanvasDrawStyle style) {
    ensureRuntimeMutationAllowed();
    final previous = _interactionEngine.drawStyle;
    final outcome = _interactionEngine.setDrawStyle(style);
    _applyPointerCleanupSelection(outcome);
    if (previous != style || outcome.publicStateNeeded) {
      _publishRuntimeState(
        surfaceRepaintTarget: _surfaceRepaintTargetForCleanup(outcome),
      );
    }
  }

  void setPointerPolicy(CanvasPointerPolicy policy) {
    ensureRuntimeMutationAllowed();
    final previous = _interactionEngine.pointerPolicy;
    final outcome = _interactionEngine.setPointerPolicy(policy);
    _applyPointerCleanupSelection(outcome);
    if (previous != policy || outcome.publicStateNeeded) {
      _publishRuntimeState(
        surfaceRepaintTarget: _surfaceRepaintTargetForCleanup(outcome),
      );
    }
  }

  // Camera.
  void setCameraOffset(Offset offset) {
    ensureRuntimeMutationAllowed();
    final camera = CanvasCamera(offset: offset);
    if (camera == _viewCamera) {
      return;
    }
    _viewCamera = camera;
    _viewCameraRevision += 1;
    _publishRuntimeState(
      surfaceRepaintTarget: _surfaceRepaintTarget(
        mainCanvas: true,
        overlayCanvas: true,
        reason: 'view_camera',
      ),
    );
  }

  void panCameraBy(Offset delta) {
    setCameraOffset(_viewCamera.offset + delta);
  }

  // Preview.
  bool replaceInteractionPreview(CanvasPreviewState preview) {
    ensureRuntimeMutationAllowed();
    final previous = _interactionEngine.preview;
    final didChange = _interactionEngine.replacePreview(preview);
    if (didChange) {
      final cleanupTarget = _surfaceRepaintTargetForPreview(previous);
      final previewTarget = _surfaceRepaintTargetForPreview(preview);
      if (_targetsDifferentLayers(cleanupTarget, previewTarget)) {
        _publishRuntimeState(surfaceRepaintTarget: cleanupTarget);
      }
      _publishRuntimeState(surfaceRepaintTarget: previewTarget);
    }

    return didChange;
  }

  bool clearInteractionPreview() {
    ensureRuntimeMutationAllowed();
    final previous = _interactionEngine.preview;
    final didChange = _interactionEngine.clearPreview();
    if (didChange) {
      _publishRuntimeState(
        surfaceRepaintTarget: _surfaceRepaintTargetForPreview(previous),
      );
    }

    return didChange;
  }

  // Pointer input.
  void handlePointer(CanvasPointerInput input) {
    ensureRuntimeMutationAllowed();
    final admission = _interactionEngine.handlePointerInput(
      input,
      InteractionPointerContext(
        viewCameraOffset: viewCameraOffset,
        controllerEpoch: _epochRevision,
        selectedIds: _selection.selectedElementIds,
        selectionRevision: _selection.selectionFacts.selectionRevision,
        resolveOutputTimestamp: _actionFinalizer.reserveTimestamp,
      ),
    );
    final replacementApplied = _applySelectionReplacement(
      admission.selectionReplacement,
    );
    if (replacementApplied &&
        admission.markProvisionalSelectionReplacementApplied) {
      _interactionEngine.markActiveProvisionalSelectionReplacementApplied(
        selectionRevision: _selection.selectionFacts.selectionRevision,
      );
    }
    if (_deliverPointerCommitAdmission(
      admission,
      timestampHintMs: switch (input) {
        CanvasPointerSample(:final timestampMs) => timestampMs,
        CanvasPointerTerminalCleanup() => null,
      },
    )) {
      return;
    }
    if (admission.publishRuntimeState) {
      _publishPointerAdmissionRuntimeState(admission);
    }
  }

  bool _deliverPointerCommitAdmission(
    InteractionPointerAdmission admission, {
    required int? timestampHintMs,
  }) {
    final selectedMoveCommit = admission.selectedMoveCommit;
    if (selectedMoveCommit != null) {
      _deliverSelectedMoveCommit(
        selectedMoveCommit,
        timestampHintMs: timestampHintMs,
      );

      return true;
    }
    final marqueeCommit = admission.marqueeCommit;
    if (marqueeCommit != null) {
      _deliverMarqueeCommit(marqueeCommit, timestampHintMs: timestampHintMs);

      return true;
    }
    final strokeCommit = admission.strokeCommit;
    if (strokeCommit != null) {
      _deliverDrawStrokeCommit(strokeCommit, timestampHintMs: timestampHintMs);

      return true;
    }
    final lineCommit = admission.lineCommit;
    if (lineCommit != null) {
      _deliverDrawLineCommit(lineCommit, timestampHintMs: timestampHintMs);

      return true;
    }
    final eraserCommit = admission.eraserCommit;
    if (eraserCommit != null) {
      _deliverEraserCommit(eraserCommit, timestampHintMs: timestampHintMs);

      return true;
    }
    final contextRequest = admission.contextRequest;
    if (contextRequest != null) {
      if (admission.publishRuntimeState) {
        _publishPointerAdmissionRuntimeState(admission);
      }
      _emitContextRequest(contextRequest);

      return true;
    }

    return false;
  }

  void _publishPointerAdmissionRuntimeState(
    InteractionPointerAdmission admission,
  ) {
    _publishRuntimeState(
      surfaceRepaintTarget:
          _surfaceRepaintTargetForCleanup(admission.cleanupOutcome) ??
          _surfaceRepaintTargetForPreview(_interactionEngine.preview),
    );
  }

  void handleDoubleTap({required Offset position, int? timestampMs}) {
    ensureRuntimeMutationAllowed();
    final intent = _interactionEngine.handleDoubleTap(
      position,
      InteractionPointerContext(
        viewCameraOffset: viewCameraOffset,
        controllerEpoch: _epochRevision,
        resolveOutputTimestamp: _actionFinalizer.reserveTimestamp,
      ),
      timestampHintMs: timestampMs,
    );
    if (intent != null) {
      _emitContextRequest(intent);
    }
  }

  Never rejectSelectionDocumentMutation() {
    ensureRuntimeMutationAllowed();
    throw UnsupportedError(
      'Selection document mutation is owned by later edit phases.',
    );
  }

  // Lifecycle.
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _ensureNotDeliveringCommitEffects();
    _ensureNoDocumentLoadInProgress();
    if (_isRunningResolverCallback) {
      _recordResolverReentrantMutationRejected('dispose');
      throw ResolverCallbackRejection(
        'CanvasRuntime public mutations cannot run during resource resolver callbacks.',
      );
    }
    _ensureNoActiveEditSession();
    final cleanupOutcome = _interactionEngine.disposeCleanup();
    _applyPointerCleanupSelection(cleanupOutcome);
    _interactionEngine.clearInteractionRequests();
    _suppressPendingContextRequests();
    _isDisposed = true;
    _dropActiveSurfaceResourceSession();
    _activeSurfaceToken = null;
    _clearSurfaceFrameSignal();
    if (cleanupOutcome.publicStateNeeded) {
      _publishRuntimeState(
        surfaceRepaintTarget: _surfaceRepaintTargetForCleanup(cleanupOutcome),
      );
    }
    _frameEngine.dispose();
    _textEditingPort.dispose();
    _surfaceFrameSignal.dispose();
    _state.dispose();
    unawaited(_actions.close());
    unawaited(_contextActionRequests.close());
  }

  // Mutation guard.
  @override
  T runResolverCallback<T>(T Function() callback) {
    _ensureNotDisposed();
    if (_isRunningResolverCallback) {
      throw ResolverCallbackRejection(
        'Nested resource resolver callbacks are not supported.',
      );
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
    _ensureNoDocumentLoadInProgress();
    if (_isRunningResolverCallback) {
      _recordResolverReentrantMutationRejected('runtimeMutation');
      throw ResolverCallbackRejection(
        'CanvasRuntime public mutations cannot run during resource resolver callbacks.',
      );
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

  void _ensureNoDocumentLoadInProgress() {
    if (_isInstallingDocumentLoad) {
      throw StateError(
        'CanvasRuntime public mutations cannot run during document load.',
      );
    }
  }

  void _recordResolverReentrantMutationRejected(String operation) {
    RuntimeInteractionDiagnosticsAdapter(
      _diagnostics,
    ).recordResolverReentrantMutationRejected(operation: operation);
  }

  // Test hooks.
  @visibleForTesting
  void deliverCommitPlanForTesting(
    CommitPlan plan, {
    required CanvasDocument document,
  }) {
    ensureRuntimeMutationAllowed();
    final applyResult = _applyEditCommit(
      AcceptedMaterializedDocument(
        document: document,
        revisionDelta: plan.revisionDelta,
      ),
      plan,
    );
    _deliverEditCommitResult(applyResult);
  }

  @visibleForTesting
  void deliverDrawStrokeCommitForTesting(
    DrawStrokeCommitIntent intent, {
    required int? timestampHintMs,
  }) {
    ensureRuntimeMutationAllowed();
    _deliverDrawStrokeCommit(intent, timestampHintMs: timestampHintMs);
  }

  @visibleForTesting
  void failEraserCommitPrepareForTesting(
    EraserCommitIntent intent, {
    required int? timestampHintMs,
  }) {
    ensureRuntimeMutationAllowed();
    _deliverEraserCommit(
      intent,
      timestampHintMs: timestampHintMs,
      prepareCommit: () => throw StateError('forced eraser edit failure'),
    );
  }

  // State publication.
  void _publishSelectionChange(bool didChange) {
    if (!didChange) {
      return;
    }
    _publishRuntimeState(
      surfaceRepaintTarget: _surfaceRepaintTarget(
        mainCanvas: true,
        overlayCanvas: false,
        reason: 'selection',
      ),
    );
  }

  void _publishRuntimeState({
    required _RuntimeSurfaceRepaintTarget? surfaceRepaintTarget,
  }) {
    _runtimeStatePublicationGeneration += 1;
    final publicationGeneration = _runtimeStatePublicationGeneration;
    final state = _runtimeState(
      _store,
      _selection.selectionFacts,
      _RuntimeRevisionFacts(
        viewCamera: _viewCameraRevision,
        preview: _interactionEngine.previewRevision,
        epoch: _epochRevision,
        resourceVisual: _resourceKernel.resourceVisualRevision,
        interaction:
            _interactionEngine.interactionRevision +
            _textEditInteractionRevision,
      ),
    );
    if (surfaceRepaintTarget != null) {
      _publishSurfaceFrame(state, surfaceRepaintTarget);
    }
    if (publicationGeneration != _runtimeStatePublicationGeneration) {
      return;
    }
    _state.value = state;
  }

  void _publishSurfaceFrame(
    CanvasRuntimeState state,
    _RuntimeSurfaceRepaintTarget repaintTarget,
  ) {
    if (_activeSurfaceToken == null) {
      return;
    }
    _surfaceFrameGeneration += 1;
    _surfaceFrameSignal.value = (
      state: state,
      generation: _surfaceFrameGeneration,
      mainCanvas: repaintTarget.mainCanvas,
      overlayCanvas: repaintTarget.overlayCanvas,
      reason: repaintTarget.reason,
    );
  }

  void _clearSurfaceFrameSignal() {
    _surfaceFrameSignal.value = null;
  }

  @visibleForTesting
  void publishUnclassifiedRuntimeStateForTesting() {
    ensureRuntimeMutationAllowed();
    _publishRuntimeState(
      surfaceRepaintTarget: _surfaceRepaintTarget(
        mainCanvas: true,
        overlayCanvas: true,
        reason: 'unclassified_runtime_state',
      ),
    );
  }

  _RuntimeSurfaceRepaintTarget? _surfaceRepaintTargetForCleanup(
    InteractionCleanupOutcome? outcome,
  ) {
    if (outcome == null) {
      return null;
    }

    return _surfaceRepaintTargetForPointerCleanup(outcome.repaintTarget);
  }

  _RuntimeSurfaceRepaintTarget? _surfaceRepaintTargetForPointerCleanup(
    PointerCleanupRepaintTarget target,
  ) {
    return switch (target) {
      PointerCleanupRepaintTarget.none => null,
      PointerCleanupRepaintTarget.main => _surfaceRepaintTarget(
        mainCanvas: true,
        overlayCanvas: false,
        reason: 'pointer_cleanup_main',
      ),
      PointerCleanupRepaintTarget.overlay => _surfaceRepaintTarget(
        mainCanvas: false,
        overlayCanvas: true,
        reason: 'pointer_cleanup_overlay',
      ),
      PointerCleanupRepaintTarget.mainAndOverlay => _surfaceRepaintTarget(
        mainCanvas: true,
        overlayCanvas: true,
        reason: 'pointer_cleanup_main_and_overlay',
      ),
    };
  }

  _RuntimeSurfaceRepaintTarget? _surfaceRepaintTargetForPreview(
    CanvasPreviewState preview,
  ) {
    return switch (preview.kind) {
      CanvasPreviewKind.none => null,
      CanvasPreviewKind.selectedMove => _surfaceRepaintTarget(
        mainCanvas: true,
        overlayCanvas: false,
        reason: 'selected_move_preview',
      ),
      CanvasPreviewKind.marquee ||
      CanvasPreviewKind.pencilStroke ||
      CanvasPreviewKind.markerStroke ||
      CanvasPreviewKind.pendingLineStart ||
      CanvasPreviewKind.linePreview ||
      CanvasPreviewKind.eraser => _surfaceRepaintTarget(
        mainCanvas: false,
        overlayCanvas: true,
        reason: 'overlay_preview',
      ),
    };
  }

  _RuntimeSurfaceRepaintTarget? _surfaceRepaintTargetForEffects(
    Iterable<CommitDeliveryEffect> effects,
  ) {
    for (final effect in effects) {
      if (effect case RepaintDeliveryEffect(
        :final mainCanvas,
        :final overlayCanvas,
      )) {
        return _surfaceRepaintTarget(
          mainCanvas: mainCanvas,
          overlayCanvas: overlayCanvas,
          reason: 'commit_repaint',
        );
      }
    }

    return null;
  }

  bool _targetsDifferentLayers(
    _RuntimeSurfaceRepaintTarget? first,
    _RuntimeSurfaceRepaintTarget? second,
  ) {
    return first != null &&
        second != null &&
        (first.mainCanvas != second.mainCanvas ||
            first.overlayCanvas != second.overlayCanvas);
  }

  _RuntimeSurfaceRepaintTarget _surfaceRepaintTarget({
    required bool mainCanvas,
    required bool overlayCanvas,
    required String reason,
  }) {
    return (
      mainCanvas: mainCanvas,
      overlayCanvas: overlayCanvas,
      reason: reason,
    );
  }

  void _markTextEditInteractionChanged() {
    _textEditInteractionRevision += 1;
  }

  void _publishTextEditInteractionState() {
    _markTextEditInteractionChanged();
    _publishRuntimeState(
      surfaceRepaintTarget: _surfaceRepaintTarget(
        mainCanvas: true,
        overlayCanvas: true,
        reason: 'text_edit_interaction',
      ),
    );
  }

  // Load pipeline.
  void _loadDocumentFromJson(String json) {
    final preparedLoad = _loadPipeline.prepareFromJson(json);

    _isInstallingDocumentLoad = true;
    late final bool didClearSelection;
    late final bool didClearTextEditing;
    try {
      didClearTextEditing = _prepareLoadInteractionCleanup();
      _loadPipeline.consume(preparedLoad);
      didClearSelection = _selection.clearForDocumentReplacement();
      _viewCamera = preparedLoad.camera;
      _viewCameraRevision += 1;
      _epochRevision += 1;
    } finally {
      _isInstallingDocumentLoad = false;
    }
    _deliverLoadResult(
      _loadEffects(didClearSelection: didClearSelection),
      didClearTextEditing: didClearTextEditing,
    );
  }

  bool _prepareLoadInteractionCleanup() {
    final testBoundary = _loadInteractionBoundary;
    if (testBoundary != null) {
      testBoundary.prepareLoadCleanup();
    }
    final didClearTextEditing = _textEditingPort.clearTransientState(
      publishState: false,
      notifyActiveSession: false,
    );
    _interactionEngine.prepareLoadCleanup();
    _interactionEngine.clearInteractionRequests();
    _suppressPendingContextRequests();

    return didClearTextEditing;
  }

  // Commit delivery pipeline.
  CommitDeliveryResult _applyEditCommit(
    AcceptedCommitDocument document,
    CommitPlan plan,
  ) {
    return _commitApplier.apply(
      document: document,
      plan: plan,
      documentInstallers: CommitDocumentInstallers(
        installDocument: _store.installDocument,
        replaceDocument: _store.replaceDocument,
        installSparseCommit: _store.installSparseCommit,
        installPreparedMaterializedCommit:
            _store.installPreparedMaterializedCommit,
      ),
      selectionInstallers: CommitSelectionInstallers(
        prepareSelectionEffect: _prepareCommitSelectionEffect,
        installSelectionEffect: _applyCommitSelectionEffect,
      ),
    );
  }

  PreparedSelectionEffect _prepareCommitSelectionEffect(
    CommitSelectionEffect effect,
    AcceptedCommitDocument document,
  ) {
    final elementIds = switch (effect) {
      PruneSelectionEffect() => _selection.selectedElementIds,
      ReplaceSelectionEffect(:final elementIds) => elementIds,
    };
    final acceptedIds = switch (document) {
      AcceptedMaterializedDocument(:final document, :final revisionDelta) =>
        revisionDelta.hasChanges
            ? _store.normalizeSelectionForCommittedDocument(
                CommittedDocument(document),
                elementIds,
              )
            : _store.normalizeSelection(elementIds),
      AcceptedMaterializedStoreDocument(:final commit) =>
        _store.normalizeSelectionForCommittedDocument(
          commit.document,
          elementIds,
        ),
      AcceptedSparseStoreDocument(:final commit) =>
        _store.normalizeSelectionForSparseCommit(commit, elementIds),
      AcceptedUnchangedStoreDocument() => _store.normalizeSelection(elementIds),
    };

    return PreparedSelectionEffect(acceptedIds);
  }

  bool _applyCommitSelectionEffect(PreparedSelectionEffect effect) {
    return _selection.installPreparedEffect(effect);
  }

  bool _applySelectionReplacement(
    InteractionSelectionReplacement? replacement,
  ) {
    if (replacement == null) {
      return false;
    }
    final expectedCurrentIds = replacement.expectedCurrentIds;
    if (expectedCurrentIds != null &&
        !_sameIdSet(_selection.selectedElementIds, expectedCurrentIds)) {
      return false;
    }
    final expectedCurrentRevision = replacement.expectedCurrentRevision;
    if (expectedCurrentRevision != null &&
        _selection.selectionFacts.selectionRevision !=
            expectedCurrentRevision) {
      return false;
    }

    return _selection.setSelection(replacement.elementIds);
  }

  bool _applyPointerCleanupSelection(InteractionCleanupOutcome outcome) {
    return _applySelectionReplacement(outcome.selectionReplacement);
  }

  void _deliverEditCommitResult(CommitDeliveryResult applyResult) {
    _isDeliveringCommitEffects = true;
    try {
      _deliverSpatialEffects(applyResult.effects);
      _deliverResourceEffects(applyResult.effects);
      if (applyResult.shouldPublishState) {
        if (applyResult.replacedDocument) {
          _epochRevision += 1;
        }
        _publishRuntimeState(
          surfaceRepaintTarget: applyResult.replacedDocument
              ? _surfaceRepaintTarget(
                  mainCanvas: true,
                  overlayCanvas: true,
                  reason: 'document_replaced',
                )
              : _surfaceRepaintTargetForEffects(applyResult.effects),
        );
        _emitActions(applyResult.actionIntents);
      }
      _deliverCommitEffectObserver(applyResult.effects);
    } finally {
      _isDeliveringCommitEffects = false;
    }
  }

  void _deliverLoadResult(
    List<CommitDeliveryEffect> effects, {
    required bool didClearTextEditing,
  }) {
    _isDeliveringCommitEffects = true;
    try {
      _deliverSpatialEffects(effects);
      _deliverResourceEffects(effects);
      _publishRuntimeState(
        surfaceRepaintTarget: _surfaceRepaintTargetForEffects(effects),
      );
      if (didClearTextEditing) {
        _textEditingPort.notifyActiveSessionChanged();
      }
      _deliverCommitEffectObserver(effects);
    } finally {
      _isDeliveringCommitEffects = false;
    }
  }

  // Resource dirty delivery.
  @override
  void deliverResourceDirtyOutcome(ResourceDirtyOutcome outcome) {
    if (!outcome.hasDirtyResources) {
      return;
    }
    _releaseActiveResourceSessionForDirtyOutcome(outcome);
    _deliverResourceDirtyResult(_resourceDirtyEffects(outcome));
  }

  void _releaseActiveResourceSessionForDirtyOutcome(
    ResourceDirtyOutcome outcome,
  ) {
    final sink = _activeResourceSessionReleaseSink;
    if (sink == null) {
      return;
    }
    try {
      if (outcome.allResourcesDirty) {
        sink.releaseAllResources();

        return;
      }
      sink.releaseResources(outcome.dirtyResourceIds);
    } on Object {
      _dropFailedResourceReleaseTarget(sink);
    }
  }

  void _dropActiveSurfaceResourceSession() {
    final session = _activeSurfaceResourceSession;
    if (session == null) {
      return;
    }
    _activeSurfaceResourceSession = null;
    if (identical(_activeResourceSessionReleaseSink, session)) {
      _activeResourceSessionReleaseSink = null;
    }
    session.drop();
  }

  void _deliverResourceDirtyResult(List<CommitDeliveryEffect> effects) {
    _isDeliveringCommitEffects = true;
    try {
      _publishRuntimeState(
        surfaceRepaintTarget: _surfaceRepaintTargetForEffects(effects),
      );
      _deliverCommitEffectObserver(effects);
    } finally {
      _isDeliveringCommitEffects = false;
    }
  }

  void _deliverCommitEffectObserver(List<CommitDeliveryEffect> effects) {
    if (effects.isEmpty) {
      return;
    }
    try {
      _commitEffectObserver(effects);
    } on Object {
      // Observer failures are contained post-delivery notifications. A future
      // diagnostics seam can report them without changing accepted outcomes.
    }
  }

  // Delivery shared helpers.
  void _deliverSpatialEffects(List<CommitDeliveryEffect> effects) {
    for (final effect in effects.whereType<SpatialDeliveryEffect>()) {
      _spatial.applyTouched(this, effect.touchedSet);
    }
  }

  void _deliverResourceEffects(List<CommitDeliveryEffect> effects) {
    final sink = _activeResourceSessionReleaseSink;
    if (sink == null && _activeSurfaceResourceSession == null) {
      return;
    }
    try {
      for (final effect in effects.whereType<ResourceDeliveryEffect>()) {
        final touchedSet = effect.touchedSet;
        if (touchedSet.documentReplaced) {
          _resetActiveResourceSessionForDocumentReplacement();
          continue;
        }
        if (touchedSet.allResourceVisualsChanged) {
          sink?.releaseAllResources();
          continue;
        }
        if (touchedSet.resourceIds.isNotEmpty) {
          sink?.releaseResources(touchedSet.resourceIds);
        }
      }
    } on Object {
      _dropFailedResourceReleaseTarget(sink);
    }
  }

  void _resetActiveResourceSessionForDocumentReplacement() {
    final session = _activeSurfaceResourceSession;
    if (session != null) {
      try {
        session.resetForDocumentReplacement();
      } on Object {
        _dropActiveSurfaceResourceSessionBestEffort();
      }

      return;
    }
    _activeResourceSessionReleaseSink?.releaseAllResources();
  }

  void _dropFailedResourceReleaseTarget(
    ResourceSessionReleaseSink? failedSink,
  ) {
    final session = _activeSurfaceResourceSession;
    if (session != null &&
        (failedSink == null || identical(failedSink, session))) {
      _dropActiveSurfaceResourceSessionBestEffort();

      return;
    }
    if (failedSink != null &&
        identical(_activeResourceSessionReleaseSink, failedSink)) {
      _activeResourceSessionReleaseSink = null;
    }
  }

  void _dropActiveSurfaceResourceSessionBestEffort() {
    final session = _activeSurfaceResourceSession;
    _activeSurfaceResourceSession = null;
    if (identical(_activeResourceSessionReleaseSink, session)) {
      _activeResourceSessionReleaseSink = null;
    }
    try {
      session?.drop();
    } on Object {
      // A failed cache-session drop must not block publication of the accepted
      // document state. Clearing ownership above prevents stale reuse.
    }
  }

  void _emitActions(List<CommitActionIntent> intents) {
    for (final action in _actionFinalizer.finalize(intents)) {
      _actions.add(action);
    }
  }

  void _emitContextRequest(ContextActionRequestIntent intent) {
    _pendingContextRequests.add((
      generation: _contextRequestGeneration,
      pendingRequest: intent.pendingRequest,
    ));
    if (_isContextRequestDeliveryScheduled) {
      return;
    }
    _isContextRequestDeliveryScheduled = true;
    scheduleMicrotask(() {
      _isContextRequestDeliveryScheduled = false;
      for (final pendingRequest in _takeDeliverablePendingContextRequests()) {
        final timestampMs = _actionFinalizer.reserveTimestamp(
          pendingRequest.timestampHintMs,
        );
        final request = pendingRequest.toRequest(timestampMs: timestampMs);
        _contextActionRequests.add(request);
      }
    });
  }

  void _suppressPendingContextRequests() {
    _contextRequestGeneration += 1;
    _pendingContextRequests.clear();
  }

  List<PendingContextActionRequest> _takeDeliverablePendingContextRequests() {
    if (_pendingContextRequests.isEmpty || _contextActionRequests.isClosed) {
      _pendingContextRequests.clear();

      return const [];
    }
    final pending = List.of(_pendingContextRequests);
    _pendingContextRequests.clear();
    final deliverable = <PendingContextActionRequest>[];
    for (final entry in pending) {
      if (entry.generation == _contextRequestGeneration) {
        deliverable.add(entry.pendingRequest);
      }
    }

    return deliverable;
  }

  // Selected move commit flow.
  void _deliverSelectedMoveCommit(
    SelectedMoveCommitIntent intent, {
    required int? timestampHintMs,
  }) {
    final resolver = config.moveCommitResolver;
    final Offset? resolvedDelta;
    try {
      resolvedDelta = resolver == null
          ? intent.proposedDelta
          : _resolveSelectedMoveDelta(intent: intent, resolver: resolver);
    } on Object {
      _cleanupSelectedMove(PointerCleanupReason.resolverError);
      rethrow;
    }
    if (resolvedDelta == null || resolvedDelta == Offset.zero) {
      _cleanupSelectedMove(PointerCleanupReason.resolverCancel);

      return;
    }
    try {
      final applyResult = _prepareSelectedMoveCommit(
        intent: intent,
        delta: resolvedDelta,
        timestampHintMs: timestampHintMs,
      );
      _cleanupSelectedMove(
        PointerCleanupReason.postSuccessCommit,
        publish: false,
      );
      _deliverEditCommitResult(applyResult);
    } on Object {
      _cleanupSelectedMove(PointerCleanupReason.editFailure);
      rethrow;
    }
  }

  Offset? _resolveSelectedMoveDelta({
    required SelectedMoveCommitIntent intent,
    required CanvasMoveCommitResolver resolver,
  }) {
    final resolution = runResolverCallback(
      () => resolver(
        CanvasMoveCommitRequest(
          documentSummary: intent.documentSummary,
          movedElements: intent.movedElements,
          proposedDelta: intent.proposedDelta,
          selectionBoundsWorld: intent.selectionBoundsWorld,
        ),
      ),
    );

    return switch (resolution) {
      CanvasMoveCommit(:final delta) => _finiteResolvedDelta(delta),
      CanvasMoveCancel() => null,
    };
  }

  Offset _finiteResolvedDelta(Offset delta) {
    if (!delta.dx.isFinite || !delta.dy.isFinite) {
      throw ArgumentError.value(delta, 'delta', 'must be finite');
    }

    return delta;
  }

  CommitDeliveryResult _prepareSelectedMoveCommit({
    required SelectedMoveCommitIntent intent,
    required Offset delta,
    required int? timestampHintMs,
  }) {
    final transform = CanvasTransform.translation(delta);

    return _editKernel.prepareInteractionCommit(
      (edit) {
        for (final element in intent.movedElements) {
          edit.updateElement(
            _transformUpdate(element, transform.multiply(element.transform)),
          );
        }
      },
      augmentPlan: (plan) => plan.withActionIntents([
        MoveSelectionActionIntent(
          elementIds: intent.movableIds,
          transform: transform,
          timestampHintMs: timestampHintMs,
        ),
      ]),
    );
  }

  void _cleanupSelectedMove(
    PointerCleanupReason reason, {
    bool publish = true,
  }) {
    final outcome = _interactionEngine.finishSelectedMove(reason);
    _applyPointerCleanupSelection(outcome);
    if (publish && outcome.publicStateNeeded) {
      _publishRuntimeState(
        surfaceRepaintTarget: _surfaceRepaintTargetForCleanup(outcome),
      );
    }
  }

  // Marquee commit flow.
  void _deliverMarqueeCommit(
    MarqueeCommitIntent intent, {
    required int? timestampHintMs,
  }) {
    try {
      final applyResult = _editKernel.prepareInteractionPlan(
        CommitPlan.replaceSelection(
          elementIds: intent.nextSelectionIds,
          actionIntents: [
            SelectMarqueeActionIntent(
              previousSelection: intent.previousSelectionIds,
              nextSelection: intent.nextSelectionIds,
              marqueeRectWorld: intent.rectWorld,
              timestampHintMs: timestampHintMs,
            ),
          ],
        ),
      );
      final cleanup = _cleanupMarquee(
        PointerCleanupReason.postSuccessCommit,
        publish: false,
        preservePendingContextTap: intent.preservePendingContextTap,
      );
      _deliverEditCommitResult(
        _withPointerCleanupEffects(applyResult, cleanup),
      );
    } on Object {
      _cleanupMarquee(PointerCleanupReason.editFailure);
      rethrow;
    }
  }

  InteractionCleanupOutcome _cleanupMarquee(
    PointerCleanupReason reason, {
    bool publish = true,
    bool preservePendingContextTap = false,
  }) {
    final outcome = _interactionEngine.finishMarquee(
      reason,
      preservePendingContextTap: preservePendingContextTap,
    );
    if (publish && outcome.publicStateNeeded) {
      _publishRuntimeState(
        surfaceRepaintTarget: _surfaceRepaintTargetForCleanup(outcome),
      );
    }

    return outcome;
  }

  // Draw stroke commit flow.
  void _deliverDrawStrokeCommit(
    DrawStrokeCommitIntent intent, {
    required int? timestampHintMs,
  }) {
    try {
      final elementId = generateElementId();
      final applyResult = _prepareDrawStrokeCommit(
        intent: intent,
        elementId: elementId,
        timestampHintMs: timestampHintMs,
      );
      final cleanup = _cleanupDrawStroke(
        PointerCleanupReason.postSuccessCommit,
        publish: false,
      );
      _deliverEditCommitResult(
        _withPointerCleanupEffects(applyResult, cleanup),
      );
    } on Object {
      _cleanupDrawStroke(PointerCleanupReason.editFailure);
      rethrow;
    }
  }

  CommitDeliveryResult _prepareDrawStrokeCommit({
    required DrawStrokeCommitIntent intent,
    required CanvasElementId elementId,
    required int? timestampHintMs,
  }) {
    final element = CanvasStrokeElement(
      id: elementId,
      points: intent.points,
      color: intent.color,
      thickness: intent.thickness,
      opacity: intent.opacity,
    );

    return _editKernel.prepareInteractionCommit(
      (edit) {
        edit.addElement(element);
      },
      augmentPlan: (plan) => plan.withActionIntents([
        DrawStrokeActionIntent(
          elementId: elementId,
          tool: intent.tool,
          color: intent.color,
          thickness: intent.thickness,
          opacity: intent.opacity,
          pointCount: intent.points.length,
          timestampHintMs: timestampHintMs,
        ),
      ]),
    );
  }

  InteractionCleanupOutcome _cleanupDrawStroke(
    PointerCleanupReason reason, {
    bool publish = true,
  }) {
    final outcome = _interactionEngine.finishDrawStroke(reason);
    if (publish && outcome.publicStateNeeded) {
      _publishRuntimeState(
        surfaceRepaintTarget: _surfaceRepaintTargetForCleanup(outcome),
      );
    }

    return outcome;
  }

  // Draw line commit flow.
  void _deliverDrawLineCommit(
    DrawLineCommitIntent intent, {
    required int? timestampHintMs,
  }) {
    try {
      final elementId = generateElementId();
      final applyResult = _prepareDrawLineCommit(
        intent: intent,
        elementId: elementId,
        timestampHintMs: timestampHintMs,
      );
      final cleanup = _cleanupLineEndpoint(
        PointerCleanupReason.postSuccessCommit,
        publish: false,
      );
      _deliverEditCommitResult(
        _withPointerCleanupEffects(applyResult, cleanup),
      );
    } on Object {
      _cleanupLineEndpoint(PointerCleanupReason.editFailure);
      rethrow;
    }
  }

  CommitDeliveryResult _prepareDrawLineCommit({
    required DrawLineCommitIntent intent,
    required CanvasElementId elementId,
    required int? timestampHintMs,
  }) {
    final element = CanvasLineElement(
      id: elementId,
      start: intent.startWorld,
      end: intent.endWorld,
      color: intent.color,
      thickness: intent.thickness,
      opacity: intent.opacity,
    );

    return _editKernel.prepareInteractionCommit(
      (edit) {
        edit.addElement(element);
      },
      augmentPlan: (plan) => plan.withActionIntents([
        DrawLineActionIntent(
          elementId: elementId,
          color: intent.color,
          thickness: intent.thickness,
          opacity: intent.opacity,
          startWorld: intent.startWorld,
          endWorld: intent.endWorld,
          timestampHintMs: timestampHintMs,
        ),
      ]),
    );
  }

  InteractionCleanupOutcome _cleanupLineEndpoint(
    PointerCleanupReason reason, {
    bool publish = true,
  }) {
    final outcome = _interactionEngine.finishLineEndpoint(reason);
    if (publish && outcome.publicStateNeeded) {
      _publishRuntimeState(
        surfaceRepaintTarget: _surfaceRepaintTargetForCleanup(outcome),
      );
    }

    return outcome;
  }

  // Eraser commit flow.
  void _deliverEraserCommit(
    EraserCommitIntent intent, {
    required int? timestampHintMs,
    CommitDeliveryResult Function()? prepareCommit,
  }) {
    try {
      final applyResult =
          prepareCommit?.call() ??
          _prepareEraserCommit(
            intent: intent,
            timestampHintMs: timestampHintMs,
          );
      final cleanup = _cleanupEraser(
        PointerCleanupReason.postSuccessCommit,
        publish: false,
      );
      _deliverEditCommitResult(
        _withPointerCleanupEffects(applyResult, cleanup),
      );
    } on Object {
      _cleanupEraser(PointerCleanupReason.editFailure);
      rethrow;
    }
  }

  CommitDeliveryResult _prepareEraserCommit({
    required EraserCommitIntent intent,
    required int? timestampHintMs,
  }) {
    return _editKernel.prepareInteractionCommit(
      (edit) {
        for (final id in intent.erasedElementIds) {
          edit.removeElement(id);
        }
      },
      augmentPlan: (plan) => plan.withActionIntents([
        EraseActionIntent(
          erasedElementIds: intent.erasedElementIds,
          eraserThickness: intent.eraserThickness,
          corridorPointCount: intent.corridorPointCount,
          timestampHintMs: timestampHintMs,
        ),
      ]),
    );
  }

  InteractionCleanupOutcome _cleanupEraser(
    PointerCleanupReason reason, {
    bool publish = true,
  }) {
    final outcome = _interactionEngine.finishEraser(reason);
    if (publish && outcome.publicStateNeeded) {
      _publishRuntimeState(
        surfaceRepaintTarget: _surfaceRepaintTargetForCleanup(outcome),
      );
    }

    return outcome;
  }

  CommitDeliveryResult _withPointerCleanupEffects(
    CommitDeliveryResult result,
    InteractionCleanupOutcome cleanup,
  ) {
    return CommitDeliveryResult(
      shouldPublishState:
          result.shouldPublishState || cleanup.publicStateNeeded,
      replacedDocument: result.replacedDocument,
      effects: _mergeRepaintEffects([
        ...result.effects,
        ..._cleanupDeliveryEffects(cleanup),
      ]),
      actionIntents: result.actionIntents,
    );
  }

  List<CommitDeliveryEffect> _cleanupDeliveryEffects(
    InteractionCleanupOutcome cleanup,
  ) {
    final repaint = _cleanupRepaintEffect(cleanup.repaintTarget);

    return repaint == null ? const [] : [repaint];
  }

  RepaintDeliveryEffect? _cleanupRepaintEffect(
    PointerCleanupRepaintTarget target,
  ) {
    return switch (target) {
      PointerCleanupRepaintTarget.none => null,
      PointerCleanupRepaintTarget.main => const RepaintDeliveryEffect(
        mainCanvas: true,
      ),
      PointerCleanupRepaintTarget.overlay => const RepaintDeliveryEffect(
        mainCanvas: false,
        overlayCanvas: true,
      ),
      PointerCleanupRepaintTarget.mainAndOverlay => const RepaintDeliveryEffect(
        mainCanvas: true,
        overlayCanvas: true,
      ),
    };
  }

  List<CommitDeliveryEffect> _mergeRepaintEffects(
    Iterable<CommitDeliveryEffect> effects,
  ) {
    final merged = <CommitDeliveryEffect>[];
    var repaintMain = false;
    var repaintOverlay = false;
    for (final effect in effects) {
      if (effect case RepaintDeliveryEffect(
        :final mainCanvas,
        :final overlayCanvas,
      )) {
        repaintMain = repaintMain || mainCanvas;
        repaintOverlay = repaintOverlay || overlayCanvas;
      } else {
        merged.add(effect);
      }
    }
    if (repaintMain || repaintOverlay) {
      merged.add(
        RepaintDeliveryEffect(
          mainCanvas: repaintMain,
          overlayCanvas: repaintOverlay,
        ),
      );
    }

    return List.unmodifiable(merged);
  }
}

// Internal adapter implementations.
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

// The adapter implements the complete sparse edit facts port so runtime can
// hand edit sessions store-owned facts without a public document projection.
// ignore: number-of-methods
final class _StoreSparseEditFacts implements SparseEditSessionFacts {
  const _StoreSparseEditFacts(this.store);

  final DocumentStoreKernel store;

  @override
  CanvasDocumentSummary get summary => store.documentSummary;

  @override
  CanvasBackground get background => store.background;

  @override
  CanvasCamera get camera => store.camera;

  @override
  CanvasPalette get palette => store.palette;

  @override
  bool hasLayer(CanvasLayerId id) => store.hasLayer(id);

  @override
  Iterable<CanvasElementId> get backgroundElementIds {
    return store.backgroundElementIds;
  }

  @override
  Iterable<CanvasElementId> get elementIds => store.elementIds;

  @override
  Iterable<CanvasLayerId> get layerIds => store.layerIds;

  @override
  Iterable<CanvasElementId> elementIdsInLayer(CanvasLayerId id) {
    return store.elementIdsInLayer(id);
  }

  @override
  Iterable<CanvasResourceId> get resourceIds => store.resourceIds;

  @override
  CanvasElement? elementById(CanvasElementId id) => store.elementById(id);

  @override
  ElementLocationFacts? elementLocationFor(CanvasElementId id) {
    return store.elementLocationFor(id);
  }

  @override
  CanvasResource? resourceById(CanvasResourceId id) => store.resourceById(id);

  @override
  int imageResourceReferenceCount(CanvasResourceId id) {
    return store.imageResourceReferenceCount(id);
  }

  @override
  int vectorResourceReferenceCount(CanvasResourceId id) {
    return store.vectorResourceReferenceCount(id);
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
    root.moveSelection(delta, timestampMs: timestampMs);
  }

  @override
  void rotateSelectionClockwise({int? timestampMs}) {
    root.rotateSelectionClockwise(timestampMs: timestampMs);
  }

  @override
  void rotateSelectionCounterClockwise({int? timestampMs}) {
    root.rotateSelectionCounterClockwise(timestampMs: timestampMs);
  }

  @override
  void flipSelectionVertical({int? timestampMs}) {
    root.flipSelectionVertical(timestampMs: timestampMs);
  }

  @override
  void flipSelectionHorizontal({int? timestampMs}) {
    root.flipSelectionHorizontal(timestampMs: timestampMs);
  }

  @override
  void deleteSelection({int? timestampMs}) {
    root.deleteSelection(timestampMs: timestampMs);
  }
}

// Tool settings share one runtime-owned adapter so mode/style/policy cleanup
// stays ordered with public state publication.
// ignore: number-of-methods
final class _RuntimeToolPort implements CanvasToolPort {
  const _RuntimeToolPort(this.root);

  final RuntimeRoot root;

  @override
  CanvasInteractionMode get mode => root.interactionEngine.mode;

  @override
  CanvasDrawStyle get drawStyle => root.interactionEngine.drawStyle;

  @override
  CanvasPointerPolicy get pointerPolicy => root.interactionEngine.pointerPolicy;

  @override
  void setMode(CanvasInteractionMode mode) {
    root.setInteractionMode(mode);
  }

  @override
  void setDrawStyle(CanvasDrawStyle style) {
    root.setDrawStyle(style);
  }

  @override
  void setDrawTool(CanvasDrawTool tool) {
    final style = drawStyle;
    root.setDrawStyle(
      CanvasDrawStyle(
        tool: tool,
        color: style.color,
        pencilThickness: style.pencilThickness,
        markerThickness: style.markerThickness,
        markerOpacity: style.markerOpacity,
        lineThickness: style.lineThickness,
        eraserThickness: style.eraserThickness,
      ),
    );
  }

  @override
  void setDrawColor(Color color) {
    final style = drawStyle;
    root.setDrawStyle(
      CanvasDrawStyle(
        tool: style.tool,
        color: color,
        pencilThickness: style.pencilThickness,
        markerThickness: style.markerThickness,
        markerOpacity: style.markerOpacity,
        lineThickness: style.lineThickness,
        eraserThickness: style.eraserThickness,
      ),
    );
  }

  @override
  void setPointerPolicy(CanvasPointerPolicy policy) {
    root.setPointerPolicy(policy);
  }

  @override
  void handlePointer(CanvasPointerInput input) {
    root.handlePointer(input);
  }

  @override
  void handleDoubleTap({required Offset position, int? timestampMs}) {
    root.handleDoubleTap(position: position, timestampMs: timestampMs);
  }
}

final class _RuntimeCommandPort implements CanvasCommandPort {
  const _RuntimeCommandPort(this.root);

  final RuntimeRoot root;

  @override
  bool removeElement(CanvasElementId id, {int? timestampMs}) {
    return root.removeElementByCommand(id, timestampMs: timestampMs);
  }

  @override
  bool commitTextEdit(
    CanvasInteractionRequestId requestId,
    String newText, {
    int? timestampMs,
  }) {
    return root.commitTextEdit(requestId, newText, timestampMs: timestampMs);
  }

  @override
  CanvasClearResult clearContent({
    bool removeUnusedResources = false,
    int? timestampMs,
  }) {
    return root.clearContentByCommand(
      removeUnusedResources: removeUnusedResources,
      timestampMs: timestampMs,
    );
  }
}

// Default observer helpers.
void _ignoreCommitEffects(List<CommitDeliveryEffect> effects) {
  _discardValue(effects);
}

int _discardValue(Object? value) => Object.hash(value, null);

// Text edit input and anchor helpers.
void _validateTextEditCommandInput(
  CanvasInteractionRequestId requestId,
  String newText,
  int? timestampMs,
) {
  if (timestampMs != null) {
    validateNonNegativeInt(timestampMs, path: 'textEdit.timestampMs');
  }
  final normalizedRequestId = CanvasInteractionRequestId(requestId.value);
  if (normalizedRequestId != requestId) {
    throw StateError('CanvasInteractionRequestId normalization drifted.');
  }
  CanvasTextElementUpdate(
    id: CanvasElementId('text-edit-validation-probe'),
    text: CanvasFieldSet(newText),
  );
}

Offset _textEditAnchorLocalFor(
  Rect bounds,
  TextAlign align,
  TextDirection direction,
) {
  return switch (_resolvedHorizontalTextAnchor(align, direction)) {
    _TextEditHorizontalAnchor.left => Offset(bounds.left, bounds.top),
    _TextEditHorizontalAnchor.center => Offset(bounds.center.dx, bounds.top),
    _TextEditHorizontalAnchor.right => Offset(bounds.right, bounds.top),
  };
}

_TextEditHorizontalAnchor _resolvedHorizontalTextAnchor(
  TextAlign align,
  TextDirection direction,
) {
  return switch (align) {
    TextAlign.left => _TextEditHorizontalAnchor.left,
    TextAlign.right => _TextEditHorizontalAnchor.right,
    TextAlign.center => _TextEditHorizontalAnchor.center,
    TextAlign.justify || TextAlign.start => switch (direction) {
      TextDirection.ltr => _TextEditHorizontalAnchor.left,
      TextDirection.rtl => _TextEditHorizontalAnchor.right,
    },
    TextAlign.end => switch (direction) {
      TextDirection.ltr => _TextEditHorizontalAnchor.right,
      TextDirection.rtl => _TextEditHorizontalAnchor.left,
    },
  };
}

enum _TextEditHorizontalAnchor { left, center, right }

// Transform update helpers.
CanvasTransform _aroundPivot(CanvasTransform transform, Offset pivot) {
  return CanvasTransform.translation(
    pivot,
  ).multiply(transform).multiply(CanvasTransform.translation(-pivot));
}

CanvasElementUpdate _transformUpdate(
  CanvasElementRead element,
  CanvasTransform transform,
) {
  final update = CanvasFieldSet(transform);

  return switch (element.kind) {
    CanvasElementKind.image => CanvasImageElementUpdate(
      id: element.id,
      transform: update,
    ),
    CanvasElementKind.vector => CanvasVectorElementUpdate(
      id: element.id,
      transform: update,
    ),
    CanvasElementKind.path => CanvasPathElementUpdate(
      id: element.id,
      transform: update,
    ),
    CanvasElementKind.text => CanvasTextElementUpdate(
      id: element.id,
      transform: update,
    ),
    CanvasElementKind.stroke => CanvasStrokeElementUpdate(
      id: element.id,
      transform: update,
    ),
    CanvasElementKind.line => CanvasLineElementUpdate(
      id: element.id,
      transform: update,
    ),
    CanvasElementKind.rect => CanvasRectElementUpdate(
      id: element.id,
      transform: update,
    ),
  };
}

// Commit delivery effect helpers.
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

bool _sameIdSet(
  Iterable<CanvasElementId> left,
  Iterable<CanvasElementId> right,
) {
  final leftSet = left.toSet();
  final rightSet = right.toSet();

  return leftSet.length == rightSet.length && leftSet.containsAll(rightSet);
}

Color _textLayoutColorFor(StoreElementFacts facts) {
  final color = facts.textColor ?? const Color(0xFF000000);
  final primitiveAlpha = (facts.opacity.clamp(0, 1) * 255).round();
  final sourceAlpha = (color.toARGB32() >> 24) & 0xFF;
  final combinedAlpha = (sourceAlpha * primitiveAlpha / 255).round();

  return color.withAlpha(combinedAlpha);
}

// Runtime state snapshot helpers.
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
      interaction: runtimeRevisions.interaction,
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
    this.interaction = 0,
  });

  final int viewCamera;
  final int preview;
  final int epoch;
  final int resourceVisual;
  final int interaction;
}

// Text editing session helpers.
final class _TextEditActiveSessionNotifier extends ChangeNotifier
    implements ValueListenable<CanvasTextEditSession?> {
  CanvasTextEditSession? _value;

  @override
  CanvasTextEditSession? get value => _value;

  set value(CanvasTextEditSession? next) {
    if (_value == next) {
      return;
    }
    _value = next;
    notifyListeners();
  }

  CanvasTextEditSession? replaceSilently(CanvasTextEditSession? next) {
    final previous = _value;
    _value = next;

    return previous;
  }

  void notifyLiveTextChanged() {
    notifyListeners();
  }

  void notifyValueChanged() {
    notifyListeners();
  }
}

// Text editing admission, active publication, live text updates, guarded commit,
// and dismissal share one runtime-owned session state; splitting this port would
// require sync glue for the single-active and read-only invariants.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class _RuntimeTextEditingPort implements CanvasTextEditingPort {
  _RuntimeTextEditingPort(this._root);

  final RuntimeRoot _root;
  final _TextEditActiveSessionNotifier _activeSession =
      _TextEditActiveSessionNotifier();
  final List<_RuntimeTextEditSessionState> _ownedStates = [];
  bool _readOnly = false;
  _RuntimeTextEditSessionState? _active;
  _TextEditSuppressionToken? _suppressionToken;

  @override
  ValueListenable<CanvasTextEditSession?> get activeSession => _activeSession;

  @override
  bool get readOnly => _readOnly;

  _TextEditSuppressionToken? get activeSuppressionToken => _suppressionToken;
  TextEditPaintSuppression? get activeFrameSuppression {
    final state = _active;
    if (state == null || _isStale(state)) {
      return null;
    }

    return _suppressionToken?.frameSuppression;
  }

  int get candidateStateCount => _ownedStates.length;

  @override
  CanvasTextEditSession? sessionCandidateFor(
    CanvasContextActionRequested request,
  ) {
    _ensurePublicOperationAllowed();
    _pruneExpiredCandidateStates();
    final existing = _stateForRequest(request.requestId);
    if (existing != null && !_isStale(existing)) {
      return existing.session;
    }
    final state = _candidateStateFor(request);
    if (state == null) {
      return null;
    }
    _ownedStates.removeWhere(
      (owned) => !identical(owned, state) && _sameGuardIdentity(owned, state),
    );
    _ownedStates.add(state);

    return state.session;
  }

  @override
  CanvasTextEditSession? start(CanvasTextEditSession session) {
    _ensurePublicOperationAllowed();
    _pruneExpiredCandidateStates();
    final state = _stateForSession(session);
    if (_readOnly || state == null) {
      return null;
    }
    final current = _active;
    if (current != null) {
      if (identical(current.session, session) ||
          _sameGuardIdentity(current, state)) {
        _discardCandidateState(state);

        return current.session;
      }

      return null;
    }
    if (_isStale(state)) {
      _discardCandidateState(state);

      return null;
    }
    state.active = true;
    _active = state;
    _suppressionToken = _TextEditSuppressionToken.fromState(state);
    _activeSession.value = state.session;
    _root._publishTextEditInteractionState();

    return state.session;
  }

  @override
  CanvasTextEditSession? startFromContextAction(
    CanvasContextActionRequested request,
  ) {
    final candidate = sessionCandidateFor(request);

    return candidate == null ? null : start(candidate);
  }

  @override
  void setReadOnly(bool value) {
    _ensurePublicOperationAllowed();
    _readOnly = value;
    if (value) {
      _dismissActiveWithoutGuard();
    }
  }

  @override
  void dismissActive() {
    _ensurePublicOperationAllowed();
    _dismissActiveWithoutGuard();
  }

  bool _dismissActiveWithoutGuard({bool publishState = true}) {
    final state = _active;
    if (state == null) {
      _pruneExpiredCandidateStates();

      return false;
    }
    state.active = false;
    _active = null;
    _suppressionToken = null;
    _activeSession.value = null;
    _discardCandidateState(state);
    _pruneExpiredCandidateStates();
    if (publishState) {
      _root._publishTextEditInteractionState();
    }

    return true;
  }

  bool clearTransientState({
    bool publishState = true,
    bool notifyActiveSession = true,
  }) {
    final state = _active;
    if (state != null) {
      state.active = false;
      _active = null;
      _suppressionToken = null;
      if (notifyActiveSession) {
        _activeSession.value = null;
      } else {
        _activeSession.replaceSilently(null);
      }
    }
    _ownedStates.clear();
    if (state == null) {
      return false;
    }
    if (publishState) {
      _root._publishTextEditInteractionState();
    }

    return true;
  }

  void notifyActiveSessionChanged() {
    _activeSession.notifyValueChanged();
  }

  void _ensurePublicOperationAllowed() {
    _root.ensureRuntimeMutationAllowed();
  }

  bool clearAcceptedRequest(
    CanvasInteractionRequestId requestId, {
    bool publishState = true,
  }) {
    final state = _active;
    if (state != null && state.requestId == requestId) {
      return _dismissActiveWithoutGuard(publishState: publishState);
    }
    _pruneExpiredCandidateStates();

    return false;
  }

  bool clearConsumedRequest(
    CanvasInteractionRequestId requestId, {
    bool publishState = true,
  }) {
    final state = _active;
    if (state != null && state.requestId == requestId && _isStale(state)) {
      return _dismissActiveWithoutGuard(publishState: publishState);
    }
    _pruneExpiredCandidateStates();

    return false;
  }

  void dispose() {
    clearTransientState(publishState: false);
    _activeSession.dispose();
  }

  // Candidate creation captures request guard facts and runtime callbacks in one
  // atomic session value so later start/commit cannot mix guard identities.
  // ignore: halstead-volume, source-lines-of-code
  _RuntimeTextEditSessionState? _candidateStateFor(
    CanvasContextActionRequested request,
  ) {
    final guard = _root._interactionEngine.requestFactsFor(request.requestId);
    if (guard == null ||
        guard.requestId != request.requestId ||
        guard.targetKind != InteractionRequestTargetKind.contentElement ||
        guard.contentElementKind != CanvasElementKind.text) {
      return null;
    }
    final current = _currentGuardFacts(guard);
    if (!_textGuardMatches(guard, current)) {
      return null;
    }
    final targetElementId = guard.contentElementId as CanvasElementId;
    final facts = _root._frameFactsForElement(targetElementId);
    if (facts == null || facts.kind != CanvasElementKind.text) {
      return null;
    }
    final initialText = current.currentText as String;
    late final _RuntimeTextEditSessionState state;
    state = _RuntimeTextEditSessionState(
      requestId: guard.requestId,
      elementId: targetElementId,
      documentRevision: guard.documentRevision,
      elementKind: guard.contentElementKind as CanvasElementKind,
      controllerEpoch: guard.controllerEpoch,
      elementRevision: guard.elementRevision as int,
      generation: guard.generation as int,
      initialText: initialText,
      liveText: initialText,
      baseFacts: facts,
      session: canvasTextEditSessionForRuntime(
        elementId: targetElementId,
        requestId: guard.requestId,
        documentRevision: guard.documentRevision,
        elementRevision: guard.elementRevision as int,
        generation: guard.generation as int,
        initialText: initialText,
        liveText: () {
          _ensurePublicOperationAllowed();

          return state.liveText;
        },
        geometry: () {
          _ensurePublicOperationAllowed();

          return _geometryFor(state);
        },
        style: () {
          _ensurePublicOperationAllowed();

          return _styleFor(state.baseFacts);
        },
        isActive: () {
          _ensurePublicOperationAllowed();

          return state.active;
        },
        isStale: () {
          _ensurePublicOperationAllowed();

          return _isStale(state);
        },
        updateText: (text) => _updateText(state, text),
        commit: ({timestampMs}) => _commit(state, timestampMs),
        dismiss: () => _dismiss(state),
      ),
    );

    return state;
  }

  TextCommitGuardReadFacts _currentGuardFacts(
    InteractionRequestGuardFacts guard,
  ) {
    final targetElementId = guard.contentElementId;
    if (targetElementId == null) {
      return TextCommitGuardReadFacts.missing(
        targetElementId: CanvasElementId('missing-text-target'),
        controllerEpoch: guard.controllerEpoch,
        documentRevision: guard.documentRevision,
      );
    }

    return _root._interactionReadPort.textCommitGuardFacts(
      TextCommitGuardReadRequest(targetElementId: targetElementId),
    );
  }

  bool _textGuardMatches(
    InteractionRequestGuardFacts guard,
    TextCommitGuardReadFacts current,
  ) {
    return current.exists &&
        current.targetKind == CanvasElementKind.text &&
        current.controllerEpoch == guard.controllerEpoch &&
        current.generation == guard.generation &&
        current.elementRevision == guard.elementRevision &&
        current.targetKind == guard.contentElementKind &&
        current.currentText != null;
  }

  _RuntimeTextEditSessionState? _stateForSession(
    CanvasTextEditSession session,
  ) {
    if (_active case final active? when identical(active.session, session)) {
      return active;
    }

    for (final state in _ownedStates) {
      if (identical(state.session, session)) {
        return state;
      }
    }

    return null;
  }

  _RuntimeTextEditSessionState? _stateForRequest(
    CanvasInteractionRequestId requestId,
  ) {
    if (_active case final active? when active.requestId == requestId) {
      return active;
    }

    for (final state in _ownedStates) {
      if (state.requestId == requestId) {
        return state;
      }
    }

    return null;
  }

  bool _isStale(_RuntimeTextEditSessionState state) {
    final guard = _root._interactionEngine.requestFactsFor(state.requestId);
    if (guard == null) {
      return true;
    }

    return !_textGuardMatches(guard, _currentGuardFacts(guard));
  }

  bool _sameGuardIdentity(
    _RuntimeTextEditSessionState left,
    _RuntimeTextEditSessionState right,
  ) {
    return left.requestId == right.requestId &&
        left.elementId == right.elementId &&
        left.elementKind == right.elementKind &&
        left.controllerEpoch == right.controllerEpoch &&
        left.elementRevision == right.elementRevision &&
        left.generation == right.generation;
  }

  void _discardCandidateState(_RuntimeTextEditSessionState state) {
    if (identical(_active, state)) {
      return;
    }
    _ownedStates.removeWhere((owned) => identical(owned, state));
  }

  void _pruneExpiredCandidateStates() {
    _ownedStates.removeWhere((state) {
      return !identical(_active, state) && _isStale(state);
    });
  }

  void _updateText(_RuntimeTextEditSessionState state, String text) {
    _ensurePublicOperationAllowed();
    if (!identical(_active?.session, state.session)) {
      return;
    }
    state.liveText = text;
    _activeSession.notifyLiveTextChanged();
  }

  bool _commit(_RuntimeTextEditSessionState state, int? timestampMs) {
    _ensurePublicOperationAllowed();
    if (!identical(_active?.session, state.session)) {
      return false;
    }
    final didCommit = _root.commitTextEdit(
      state.requestId,
      state.liveText,
      timestampMs: timestampMs,
    );
    if (didCommit || _isStale(state)) {
      _dismiss(state);
    }

    return didCommit;
  }

  void _dismiss(_RuntimeTextEditSessionState state) {
    _ensurePublicOperationAllowed();
    if (!identical(_active?.session, state.session)) {
      return;
    }
    _dismissActiveWithoutGuard();
  }

  CanvasTextEditGeometry _geometryFor(_RuntimeTextEditSessionState state) {
    final measuredTextLayout = _root._measuredTextLayoutFromFrameFacts(
      state.baseFacts,
      state.liveText,
    );
    final baseLayout = state.baseFacts.measuredTextLayout;
    final transform = baseLayout == null
        ? state.baseFacts.transform
        : _root._textEditAnchorPreservingTransformForLayout(
            state.baseFacts,
            baseLayout,
            measuredTextLayout,
          );
    final facts = _root._textFrameFactsWithLiveText(
      state.baseFacts,
      state.liveText,
      transform: transform,
      measuredTextLayout: measuredTextLayout,
    );
    final bounds = const GeometryPolicy().boundsFor(facts);

    return CanvasTextEditGeometry(
      paintBoundsWorld: bounds.paintBoundsWorld,
      editBoundsWorld: bounds.editBoundsWorld,
      transform: facts.transform,
      maxWidth: facts.maxWidth,
      editBoundsLocal: bounds.editBoundsLocal,
    );
  }

  CanvasTextEditStyle _styleFor(FrameElementFacts facts) {
    return CanvasTextEditStyle(
      fontSize: facts.fontSize ?? 24,
      fontFamily: facts.fontFamily,
      isBold: facts.isBold ?? false,
      isItalic: facts.isItalic ?? false,
      isUnderline: facts.isUnderline ?? false,
      color: facts.textColor ?? const Color(0xFF000000),
      textAlign: facts.textAlign ?? TextAlign.left,
      textDirection: facts.textDirection ?? TextDirection.ltr,
      lineHeight: facts.lineHeight,
    );
  }
}

final class _RuntimeTextEditSessionState {
  _RuntimeTextEditSessionState({
    required this.requestId,
    required this.elementId,
    required this.documentRevision,
    required this.elementKind,
    required this.controllerEpoch,
    required this.elementRevision,
    required this.generation,
    required this.initialText,
    required this.liveText,
    required this.baseFacts,
    required this.session,
  });

  final CanvasInteractionRequestId requestId;
  final CanvasElementId elementId;
  final int documentRevision;
  final CanvasElementKind elementKind;
  final int controllerEpoch;
  final int elementRevision;
  final int generation;
  final String initialText;
  String liveText;
  final FrameElementFacts baseFacts;
  final CanvasTextEditSession session;
  bool active = false;
}

final class _TextEditSuppressionToken {
  const _TextEditSuppressionToken({
    required this.requestId,
    required this.elementId,
    required this.family,
    required this.elementKind,
    required this.controllerEpoch,
    required this.elementRevision,
    required this.generation,
  });

  factory _TextEditSuppressionToken.fromState(
    _RuntimeTextEditSessionState state,
  ) {
    return _TextEditSuppressionToken(
      requestId: state.requestId,
      elementId: state.elementId,
      family: TextEditSuppressionFamily.text,
      elementKind: state.elementKind,
      controllerEpoch: state.controllerEpoch,
      elementRevision: state.elementRevision,
      generation: state.generation,
    );
  }

  final CanvasInteractionRequestId requestId;
  final CanvasElementId elementId;
  final TextEditSuppressionFamily family;
  final CanvasElementKind elementKind;
  final int controllerEpoch;
  final int elementRevision;
  final int generation;

  TextEditPaintSuppression get frameSuppression {
    return TextEditPaintSuppression(
      requestId: requestId,
      elementId: elementId,
      family: family,
      elementKind: elementKind,
      controllerEpoch: controllerEpoch,
      elementRevision: elementRevision,
      generation: generation,
    );
  }

  ({
    CanvasInteractionRequestId requestId,
    CanvasElementId elementId,
    TextEditSuppressionFamily family,
    CanvasElementKind elementKind,
    int controllerEpoch,
    int elementRevision,
    int generation,
  })
  get identityForTesting {
    return (
      requestId: requestId,
      elementId: elementId,
      family: family,
      elementKind: elementKind,
      controllerEpoch: controllerEpoch,
      elementRevision: elementRevision,
      generation: generation,
    );
  }
}
