// RuntimeRoot is the composition root for public facade ports, store facts, and
// selection state; its imports reflect owned seams that are meant to meet here
// instead of being hidden behind metric-only wrapper files.
// The composition root directly names each owned seam so dependency direction is
// visible at the facade boundary.
// ignore_for_file: number-of-imports

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../api/canvas_document.dart';
import '../api/canvas_ids.dart';
import '../api/canvas_runtime.dart';
import '../api/canvas_actions.dart';
import '../edit/commit_applier.dart';
import '../edit/commit_plan.dart';
import '../edit/edit_kernel.dart';
import '../selection/selection_kernel.dart';
import '../store/document_store_kernel.dart';
import 'commit_effect_observer.dart';
import 'document_facts_port.dart';
import 'frame_facts_port.dart';
import 'runtime_config.dart';
import 'selection_facts_port.dart';
import 'selection_membership_port.dart';

// RuntimeRoot is intentionally the one place where public runtime behavior,
// store read facts, and selection ownership meet.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class RuntimeRoot implements DocumentFactsPort, FrameFactsPort {
  RuntimeRoot({
    required CanvasDocument initialDocument,
    required CanvasRuntimeConfig config,
    CommitEffectObserver? commitEffectObserver,
  }) : this._(
         store: DocumentStoreKernel(initialDocument),
         config: RuntimeConfig.from(config),
         initialViewCamera: initialDocument.camera,
         commitEffectObserver: commitEffectObserver ?? _ignoreCommitEffects,
       );

  RuntimeRoot._({
    required DocumentStoreKernel store,
    required this.config,
    required CanvasCamera initialViewCamera,
    required CommitEffectObserver commitEffectObserver,
  }) : _store = store,
       _viewCamera = initialViewCamera,
       _commitEffectObserver = commitEffectObserver,
       _selection = SelectionKernel(
         membership: _StoreSelectionMembership(store),
       ),
       _state = ValueNotifier<CanvasRuntimeState>(
         _runtimeState(store, null, 0),
       );

  final RuntimeConfig config;
  final DocumentStoreKernel _store;
  CanvasCamera _viewCamera;
  final CommitEffectObserver _commitEffectObserver;
  final SelectionKernel _selection;
  final ValueNotifier<CanvasRuntimeState> _state;
  final StreamController<CanvasActionCommitted> _actions =
      StreamController<CanvasActionCommitted>.broadcast();
  final CommitApplier _commitApplier = const CommitApplier();
  int _viewCameraRevision = 0;
  bool _isDisposed = false;
  bool _isDeliveringCommitEffects = false;
  late final EditKernel _editKernel = EditKernel(
    isRuntimeDisposed: () {
      _ensureNotDeliveringCommitEffects();

      return _isDisposed;
    },
    readDocument: _store.readDocument,
    selectedElementIds: () => _selection.selectedElementIds,
    installDocument: _applyEditCommit,
    deliverApplyResult: _deliverEditCommitResult,
  );
  late final CanvasEditPort _editPort = _editKernel.port;
  late final CanvasSelectionPort _selectionPort = _RuntimeSelectionPort(this);
  late final CanvasCameraPort _cameraPort = _RuntimeCameraPort(this);

  ValueListenable<CanvasRuntimeState> get state => _state;
  bool get isDisposed => _isDisposed;
  int get projectionBuildCount => _store.projectionBuildCount;
  CanvasEditPort get edits => _editPort;
  Stream<CanvasActionCommitted> get actions => _actions.stream;
  CanvasSelectionPort get selection => _selectionPort;
  CanvasCameraPort cameraPort() => _cameraPort;
  CanvasCamera get viewCamera => _viewCamera;
  Offset get viewCameraOffset => _viewCamera.offset;
  SelectionFacts get selectionFacts => _selection.selectionFacts;

  DocumentFactsPort get documentFactsPort => this;
  FrameFactsPort get frameFactsPort => this;

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

  CanvasDocument readDocument() => _store.readDocument();
  CanvasElementId generateElementId() {
    _ensureNotDisposed();

    return _store.generateElementId();
  }

  CanvasLayerId generateLayerId() {
    _ensureNotDisposed();

    return _store.generateLayerId();
  }

  CanvasResourceId generateResourceId() {
    _ensureNotDisposed();

    return _store.generateResourceId();
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
      resourceRevision: facts.resourceRevision,
      metadata: facts.metadata,
    );
  }

  Set<CanvasElementId> get selectedElementIds {
    return _selection.selectedElementIds;
  }

  void setSelection(Iterable<CanvasElementId> ids) {
    _ensureNotDisposed();
    _ensureNoActiveEditSession();
    _publishSelectionChange(_selection.setSelection(ids));
  }

  void toggleSelection(CanvasElementId id) {
    _ensureNotDisposed();
    _ensureNoActiveEditSession();
    _publishSelectionChange(_selection.toggleSelection(id));
  }

  void clearSelection() {
    _ensureNotDisposed();
    _ensureNoActiveEditSession();
    _publishSelectionChange(_selection.clearSelection());
  }

  void selectAll({required bool onlySelectable}) {
    _ensureNotDisposed();
    _ensureNoActiveEditSession();
    _publishSelectionChange(
      _selection.selectAll(onlySelectable: onlySelectable),
    );
  }

  void setCameraOffset(Offset offset) {
    _ensureNotDisposed();
    _ensureNoActiveEditSession();
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
    _ensureNotDisposed();
    _ensureNoActiveEditSession();
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
      _viewCameraRevision,
    );
  }

  CommitApplyResult _applyEditCommit(CanvasDocument document, CommitPlan plan) {
    return _commitApplier.apply(
      document: document,
      plan: plan,
      installDocument: _store.installDocument,
      installSelectionEffects: _selection.pruneSelection,
    );
  }

  void _deliverEditCommitResult(CommitApplyResult applyResult) {
    if (applyResult.shouldPublishState) {
      _publishRuntimeState();
    }
    if (applyResult.effects.isEmpty) {
      return;
    }
    _isDeliveringCommitEffects = true;
    try {
      _commitEffectObserver(applyResult.effects);
    } on Object {
      // Observer failures are contained post-commit notifications. A future
      // diagnostics seam can report them without changing commit acceptance.
    } finally {
      _isDeliveringCommitEffects = false;
    }
  }
}

void _ignoreCommitEffects(List<CommitEffect> _) {}

CanvasRuntimeState _runtimeState(
  DocumentStoreKernel store,
  SelectionFacts? selectionFacts,
  int viewCameraRevision,
) {
  final selection =
      selectionFacts ??
      SelectionFacts(selectedElementIds: const {}, selectionRevision: 0);

  return CanvasRuntimeState(
    revisions: CanvasRuntimeRevisions(
      document: store.documentRevision,
      selection: selection.selectionRevision,
      preview: 0,
      viewCamera: viewCameraRevision,
      resourceVisual: 0,
      interaction: 0,
      epoch: 0,
    ),
    summary: CanvasRuntimeSummary(
      elementCount: store.documentSummary.elementCount,
      layerCount: store.documentSummary.layerCount,
      resourceCount: store.documentSummary.resourceCount,
      selectedCount: selection.selectedCount,
    ),
  );
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
