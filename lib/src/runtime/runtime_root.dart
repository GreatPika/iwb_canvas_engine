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
import '../contracts/public/canvas_tools.dart';
import '../contracts/public/canvas_value_validators.dart';
import '../diagnostics/diagnostics_hub.dart';
import '../edit/commit_applier.dart';
import '../edit/commit_plan.dart';
import '../edit/edit_kernel.dart';
import '../edit/staged_document_load.dart';
import '../frame/captured_frame.dart';
import '../frame/frame_engine.dart';
import '../frame/frame_paint_output.dart';
import '../geometry/spatial_kernel.dart';
import '../interaction/draw_stroke_machine.dart';
import '../interaction/eraser_machine.dart';
import '../interaction/interaction_engine.dart';
import '../interaction/interaction_pointer_context.dart';
import '../interaction/interaction_read_port.dart';
import '../interaction/line_machine.dart';
import '../interaction/move_machine.dart';
import '../interaction/pointer_tool_cleanup_coordinator.dart';
import '../interaction/select_machine.dart';
import '../resources/resource_kernel.dart';
import '../selection/selection_kernel.dart';
import '../store/document_store_kernel.dart';
import 'runtime_command_facts_adapter.dart';
import 'runtime_config.dart';
import 'runtime_action_finalizer.dart';
import 'runtime_interaction_diagnostics_adapter.dart';
import 'runtime_interaction_read_adapter.dart';

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
         diagnostics: diagnosticsHubForPolicy(config.diagnosticPolicy),
         diagnosticPolicy: config.diagnosticPolicy,
         loadInteractionBoundary: null,
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
         diagnostics: diagnosticsHubForPolicy(config.diagnosticPolicy),
         diagnosticPolicy: config.diagnosticPolicy,
         loadInteractionBoundary: loadInteractionBoundary,
         initialViewCamera: initialDocument.camera,
         commitEffectObserver: commitEffectObserver ?? _ignoreCommitEffects,
       );

  RuntimeRoot._({
    required DocumentStoreKernel store,
    required this.config,
    required DiagnosticsHub? diagnostics,
    required CanvasDiagnosticPolicy diagnosticPolicy,
    required LoadInteractionBoundary? loadInteractionBoundary,
    required CanvasCamera initialViewCamera,
    required CommitEffectObserver commitEffectObserver,
  }) : _store = store,
       _diagnostics = diagnostics,
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
       _interactionEngine = InteractionEngine(
         initialMode: config.initialMode,
         initialDrawStyle: config.initialDrawStyle,
         pointerPolicy: config.pointerPolicy,
         diagnosticsSink: RuntimeInteractionDiagnosticsAdapter(diagnostics),
       ),
       _state = ValueNotifier<CanvasRuntimeState>(
         _runtimeState(store, null, const _RuntimeRevisionFacts()),
       ) {
    _interactionEngine.attachReadPort(_interactionReadPort);
    _spatial.rebuild(this);
  }

  // Configuration and owned infrastructure.
  final RuntimeConfig config;
  final DocumentStoreKernel _store;
  final DiagnosticsHub? _diagnostics;
  final LoadInteractionBoundary? _loadInteractionBoundary;
  final LoadDocumentPipeline _loadPipeline;
  final CommitEffectObserver _commitEffectObserver;

  // Core kernels and engines.
  final SelectionKernel _selection;
  final InteractionEngine _interactionEngine;
  final SpatialKernel _spatial = SpatialKernel();
  final CommitApplier _commitApplier = const CommitApplier();
  final RuntimeActionFinalizer _actionFinalizer = RuntimeActionFinalizer();

  // Public state and event streams.
  CanvasCamera _viewCamera;
  final ValueNotifier<CanvasRuntimeState> _state;
  final StreamController<CanvasActionCommitted> _actions =
      StreamController<CanvasActionCommitted>.broadcast(sync: true);
  final StreamController<CanvasContextActionRequested> _contextActionRequests =
      StreamController<CanvasContextActionRequested>.broadcast();

  // Runtime revision counters.
  int _viewCameraRevision = 0;
  int _epochRevision = 0;

  // Mutation and lifecycle guards.
  bool _isDisposed = false;
  bool _isDeliveringCommitEffects = false;
  bool _isRunningResolverCallback = false;
  ResourceSessionInvalidationSink? _activeResourceSessionInvalidationSink;

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
    selectedElementIds: () => _selection.selectedElementIds,
    installCommit: _applyEditCommit,
    deliverApplyResult: _deliverEditCommitResult,
    installLoadedDocument: _loadDocument,
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

  // Public state.
  ValueListenable<CanvasRuntimeState> get state => _state;
  bool get isDisposed => _isDisposed;
  int get projectionBuildCount => _store.projectionBuildCount;

  // Facade ports.
  CanvasEditPort get edits => _editPort;
  CanvasSelectionPort get selection => _selectionPort;
  CanvasToolPort get tools => _toolPort;
  CanvasCommandPort get commands => _commandPort;
  CanvasResourcePort get resources => _resourceKernel;
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
    );
  }

  // Resource session sink API.
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

    // Text edit commit is validated here but not supported by this phase.
    return false;
  }

  // Surface interaction lifecycle.
  void handleSurfaceInteractiveDisabled() {
    ensureRuntimeMutationAllowed();
    final outcome = _interactionEngine.interactiveDisabledCleanup();
    if (outcome.publicStateNeeded) {
      _publishRuntimeState();
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
    final didChangeMode = previousMode != mode;
    final didClearSelection =
        didChangeMode &&
        mode == CanvasInteractionMode.draw &&
        config.clearSelectionOnDrawModeEnter &&
        _selection.clearSelection();
    if (didChangeMode || didClearSelection || outcome.publicStateNeeded) {
      _publishRuntimeState();
    }
  }

  void setDrawStyle(CanvasDrawStyle style) {
    ensureRuntimeMutationAllowed();
    final previous = _interactionEngine.drawStyle;
    final outcome = _interactionEngine.setDrawStyle(style);
    if (previous != style || outcome.publicStateNeeded) {
      _publishRuntimeState();
    }
  }

  void setPointerPolicy(CanvasPointerPolicy policy) {
    ensureRuntimeMutationAllowed();
    final previous = _interactionEngine.pointerPolicy;
    final outcome = _interactionEngine.setPointerPolicy(policy);
    if (previous != policy || outcome.publicStateNeeded) {
      _publishRuntimeState();
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
    _publishRuntimeState();
  }

  void panCameraBy(Offset delta) {
    setCameraOffset(_viewCamera.offset + delta);
  }

  // Preview.
  bool replaceInteractionPreview(CanvasPreviewState preview) {
    ensureRuntimeMutationAllowed();
    final didChange = _interactionEngine.replacePreview(preview);
    if (didChange) {
      _publishRuntimeState();
    }

    return didChange;
  }

  bool clearInteractionPreview() {
    ensureRuntimeMutationAllowed();
    final didChange = _interactionEngine.clearPreview();
    if (didChange) {
      _publishRuntimeState();
    }

    return didChange;
  }

  // Pointer input.
  void handlePointer(CanvasPointerSample sample) {
    ensureRuntimeMutationAllowed();
    final admission = _interactionEngine.handlePointerSample(
      sample,
      InteractionPointerContext(
        viewCameraOffset: viewCameraOffset,
        controllerEpoch: _epochRevision,
        resolveOutputTimestamp: _actionFinalizer.reserveTimestamp,
      ),
    );
    if (_deliverPointerCommitAdmission(
      admission,
      timestampHintMs: sample.timestampMs,
    )) {
      return;
    }
    if (admission.kind != InteractionPointerAdmissionKind.ignored) {
      _publishRuntimeState();
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

    return false;
  }

  // Unsupported later-phase operations.
  // Double-tap context requests are not implemented by the current runtime.
  // ignore: avoid-unused-parameters
  Never handleDoubleTap({required Offset position, int? timestampMs}) {
    ensureRuntimeMutationAllowed();
    throw UnsupportedError('P12 context action double tap is not implemented.');
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
    if (_isRunningResolverCallback) {
      _recordResolverReentrantMutationRejected('dispose');
      throw StateError(
        'CanvasRuntime public mutations cannot run during resource resolver callbacks.',
      );
    }
    _ensureNoActiveEditSession();
    final cleanupOutcome = _interactionEngine.disposeCleanup();
    _isDisposed = true;
    if (cleanupOutcome.publicStateNeeded) {
      _publishRuntimeState();
    }
    _frameEngine.dispose();
    _state.dispose();
    unawaited(_actions.close());
    unawaited(_contextActionRequests.close());
  }

  // Mutation guard.
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
      _recordResolverReentrantMutationRejected('runtimeMutation');
      throw StateError(
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
    final applyResult = _applyEditCommit(document, plan);
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
    _publishRuntimeState();
  }

  void _publishRuntimeState() {
    _state.value = _runtimeState(
      _store,
      _selection.selectionFacts,
      _RuntimeRevisionFacts(
        viewCamera: _viewCameraRevision,
        preview: _interactionEngine.previewRevision,
        epoch: _epochRevision,
        resourceVisual: _resourceKernel.resourceVisualRevision,
        interaction: _interactionEngine.interactionRevision,
      ),
    );
  }

  // Load pipeline.
  void _loadDocument(CanvasDocument document) {
    final preparedLoad = _loadPipeline.prepare(document);

    _prepareLoadInteractionCleanup();
    _loadPipeline.consume(preparedLoad);
    final didClearSelection = _selection.clearForDocumentReplacement();
    _viewCamera = preparedLoad.document.camera;
    _viewCameraRevision += 1;
    _epochRevision += 1;
    _deliverLoadResult(_loadEffects(didClearSelection: didClearSelection));
  }

  void _prepareLoadInteractionCleanup() {
    final testBoundary = _loadInteractionBoundary;
    if (testBoundary != null) {
      testBoundary.prepareLoadCleanup();
    }
    _interactionEngine.prepareLoadCleanup();
  }

  // Commit delivery pipeline.
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
      installSelectionEffects: _applyCommitSelectionEffect,
    );
  }

  bool _applyCommitSelectionEffect(CommitSelectionEffect effect) {
    return switch (effect) {
      PruneSelectionEffect() => _selection.pruneSelection(),
      ReplaceSelectionEffect(:final elementIds) => _selection.setSelection(
        elementIds,
      ),
    };
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
        _emitActions(applyResult.actionIntents);
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

  // Resource dirty delivery.
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

  // Delivery shared helpers.
  void _deliverSpatialEffects(List<CommitDeliveryEffect> effects) {
    for (final effect in effects.whereType<SpatialDeliveryEffect>()) {
      _spatial.applyTouched(this, effect.touchedSet);
    }
  }

  void _emitActions(List<CommitActionIntent> intents) {
    for (final action in _actionFinalizer.finalize(intents)) {
      _actions.add(action);
    }
  }

  // Selected move commit flow.
  void _deliverSelectedMoveCommit(
    SelectedMoveCommitIntent intent, {
    required int? timestampHintMs,
  }) {
    final resolver = config.moveCommitResolver;
    final requestTimestamp = resolver == null
        ? null
        : _actionFinalizer.reserveTimestamp(timestampHintMs);
    final Offset? resolvedDelta;
    try {
      resolvedDelta = resolver == null
          ? intent.proposedDelta
          : _resolveSelectedMoveDelta(
              intent: intent,
              timestampMs: requestTimestamp as int,
              resolver: resolver,
            );
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
        timestampHintMs: requestTimestamp ?? timestampHintMs,
      );
      _cleanupSelectedMove(
        PointerCleanupReason.postSuccessCommit,
        publish: false,
      );
      _deliverEditCommitResult(applyResult);
    } on Object {
      _cleanupSelectedMove(PointerCleanupReason.editFailure);
      _publishRuntimeState();
      rethrow;
    }
  }

  Offset? _resolveSelectedMoveDelta({
    required SelectedMoveCommitIntent intent,
    required int timestampMs,
    required CanvasMoveCommitResolver resolver,
  }) {
    final resolution = runResolverCallback(
      () => resolver(
        CanvasMoveCommitRequest(
          documentSummary: intent.documentSummary,
          movedElements: intent.movedElements,
          proposedDelta: intent.proposedDelta,
          selectionBoundsWorld: intent.selectionBoundsWorld,
          timestampMs: timestampMs,
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
    if (publish && outcome.publicStateNeeded) {
      _publishRuntimeState();
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
      _cleanupMarquee(PointerCleanupReason.postSuccessCommit, publish: false);
      _deliverEditCommitResult(applyResult);
    } on Object {
      _cleanupMarquee(PointerCleanupReason.editFailure);
      _publishRuntimeState();
      rethrow;
    }
  }

  void _cleanupMarquee(PointerCleanupReason reason, {bool publish = true}) {
    final outcome = _interactionEngine.finishMarquee(reason);
    if (publish && outcome.publicStateNeeded) {
      _publishRuntimeState();
    }
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
      _cleanupDrawStroke(
        PointerCleanupReason.postSuccessCommit,
        publish: false,
      );
      _deliverEditCommitResult(applyResult);
    } on Object {
      _cleanupDrawStroke(PointerCleanupReason.editFailure);
      _publishRuntimeState();
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

  void _cleanupDrawStroke(PointerCleanupReason reason, {bool publish = true}) {
    final outcome = _interactionEngine.finishDrawStroke(reason);
    if (publish && outcome.publicStateNeeded) {
      _publishRuntimeState();
    }
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
      _cleanupLineEndpoint(
        PointerCleanupReason.postSuccessCommit,
        publish: false,
      );
      _deliverEditCommitResult(applyResult);
    } on Object {
      _cleanupLineEndpoint(PointerCleanupReason.editFailure);
      _publishRuntimeState();
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

  void _cleanupLineEndpoint(
    PointerCleanupReason reason, {
    bool publish = true,
  }) {
    final outcome = _interactionEngine.finishLineEndpoint(reason);
    if (publish && outcome.publicStateNeeded) {
      _publishRuntimeState();
    }
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
      _publishRuntimeState();
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

  PointerCleanupOutcome _cleanupEraser(
    PointerCleanupReason reason, {
    bool publish = true,
  }) {
    final outcome = _interactionEngine.finishEraser(reason);
    if (publish && outcome.publicStateNeeded) {
      _publishRuntimeState();
    }

    return outcome;
  }

  CommitDeliveryResult _withPointerCleanupEffects(
    CommitDeliveryResult result,
    PointerCleanupOutcome cleanup,
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
    PointerCleanupOutcome cleanup,
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
  void handlePointer(CanvasPointerSample sample) {
    root.handlePointer(sample);
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

void _ignoreCommitEffects(List<CommitDeliveryEffect> _) {}

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
