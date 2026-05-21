// RuntimeRoot is the composition root for public facade ports, store facts, and
// selection state; its imports reflect owned seams that are meant to meet here
// instead of being hidden behind metric-only wrapper files.
// ignore_for_file: type=metrics

import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../api/canvas_document.dart';
import '../api/canvas_ids.dart';
import '../api/canvas_runtime.dart';
import '../selection/selection_kernel.dart';
import '../store/document_store_kernel.dart';
import 'document_facts_port.dart';
import 'frame_facts_port.dart';
import 'runtime_config.dart';
import 'selection_facts_port.dart';
import 'selection_normalization_port.dart';

final class RuntimeRoot implements DocumentFactsPort, FrameFactsPort {
  RuntimeRoot({
    required CanvasDocument initialDocument,
    required CanvasRuntimeConfig config,
  }) : this._(
         store: DocumentStoreKernel(initialDocument),
         config: RuntimeConfig.from(config),
       );

  RuntimeRoot._({required DocumentStoreKernel store, required this.config})
    : _store = store,
      _selection = SelectionKernel(
        normalization: _StoreSelectionNormalization(store),
      ),
      _state = ValueNotifier<CanvasRuntimeState>(_runtimeState(store, null));

  final RuntimeConfig config;
  final DocumentStoreKernel _store;
  final SelectionKernel _selection;
  final ValueNotifier<CanvasRuntimeState> _state;
  bool _isDisposed = false;
  late final CanvasSelectionPort _selectionPort = _RuntimeSelectionPort(this);

  ValueListenable<CanvasRuntimeState> get state => _state;
  bool get isDisposed => _isDisposed;
  int get projectionBuildCount => _store.projectionBuildCount;
  CanvasSelectionPort get selection => _selectionPort;
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
        ),
    ]);
  }

  @override
  FrameElementFacts? resolveElement(FrameElementHandle handle) {
    final facts = _store.resolveElement(
      StoreElementHandle(
        id: handle.id,
        structuralRevision: handle.structuralRevision,
        generation: handle.generation,
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
    _publishSelectionChange(_selection.setSelection(ids));
  }

  void toggleSelection(CanvasElementId id) {
    _ensureNotDisposed();
    _publishSelectionChange(_selection.toggleSelection(id));
  }

  void clearSelection() {
    _ensureNotDisposed();
    _publishSelectionChange(_selection.clearSelection());
  }

  void selectAll({required bool onlySelectable}) {
    _ensureNotDisposed();
    _publishSelectionChange(
      _selection.selectAll(onlySelectable: onlySelectable),
    );
  }

  Never rejectSelectionDocumentMutation() {
    _ensureNotDisposed();
    throw UnsupportedError(
      'Selection document mutation is owned by later edit phases.',
    );
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _state.dispose();
  }

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError('CanvasRuntime is disposed.');
    }
  }

  void _publishSelectionChange(bool didChange) {
    if (!didChange) {
      return;
    }
    _state.value = _runtimeState(_store, _selection.selectionFacts);
  }
}

CanvasRuntimeState _runtimeState(
  DocumentStoreKernel store,
  SelectionFacts? selectionFacts,
) {
  final selection =
      selectionFacts ??
      SelectionFacts(selectedElementIds: const {}, selectionRevision: 0);

  return CanvasRuntimeState(
    revisions: CanvasRuntimeRevisions(
      document: store.documentRevision,
      selection: selection.selectionRevision,
      preview: 0,
      viewCamera: 0,
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

final class _StoreSelectionNormalization implements SelectionNormalizationPort {
  const _StoreSelectionNormalization(this.store);

  final DocumentStoreKernel store;

  @override
  Set<CanvasElementId> normalizeSelection(Iterable<CanvasElementId> ids) {
    return store.normalizeSelection(ids);
  }

  @override
  Set<CanvasElementId> allSelectableElementIds({required bool onlySelectable}) {
    return onlySelectable
        ? store.selectableElementIds
        : store.contentElementIds;
  }
}

// The public selection port is one interface; keeping its adapter whole makes
// unsupported later-phase commands and selection-only commands auditable
// together instead of scattering facade behavior across metric-shaped classes.
// ignore: metrics
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
