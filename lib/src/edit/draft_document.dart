import 'dart:async';
import 'dart:ui';

import 'package:meta/meta.dart' show visibleForTesting;

import '../codec/validated_import_draft.dart';
import '../contracts/internal/touched_set.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_element_update.dart';
import '../contracts/public/canvas_errors.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_metadata.dart';
import '../contracts/public/canvas_resource.dart';
import '../contracts/public/canvas_runtime.dart';
import '../store/sparse_store_commit.dart';
import '../store/store_revision_delta.dart';
import 'commit_compiler.dart';
import 'commit_plan.dart';
import 'draft_structure.dart';
import 'draft_resources.dart';
import 'element_update_application.dart';
import 'staged_document_load.dart';
import 'touched_set_builder.dart';

export 'draft_structure.dart'
    show
        DraftStructureOrderKind,
        DraftStructureMapKind,
        DraftStructureMapOperation,
        DraftStructureWorkEvent,
        DraftStructureWorkKind,
        observeDraftStructureWork;
export 'draft_resources.dart'
    show
        DraftResourceWorkEvent,
        DraftResourceWorkKind,
        observeDraftResourceWork;

// The draft boundary directly names the public DTOs it can mutate so rollback
// admission remains auditable in one owner instead of being split into sync
// glue. Element update application is shared with sparse sessions so DTO patch
// semantics cannot drift between materialized and sparse paths.
// ignore_for_file: number-of-imports

// DraftDocument keeps the mutable transaction state in one place; splitting the
// handle by metric family would require synchronizing element, resource, and
// revision buffers during rollback.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class DraftDocument {
  static final Object _sparseMutationApplicationZoneKey = Object();

  DraftDocument(
    CanvasDocument document, {
    Iterable<CanvasElementId> selectedElementIds = const [],
  }) : _selectedElementIds = Set.unmodifiable(selectedElementIds),
       camera = document.camera,
       background = document.background,
       palette = _copyPalette(document.palette),
       metadata = document.metadata,
       _structure = DraftStructure(document) {
    _resources = DraftResources(
      descriptors: document.resources,
      visitRows: _structure.visitCurrentRows,
    );
  }

  CanvasCamera camera;
  CanvasBackground background;
  CanvasPalette palette;
  CanvasMetadata metadata;
  late DraftResources _resources;
  DraftStructure _structure;
  final Set<CanvasElementId> _selectedElementIds;
  StoreRevisionDelta _revisionDelta = const StoreRevisionDelta();
  final TouchedSetBuilder _touchedSet = TouchedSetBuilder();
  bool _documentReplaced = false;

  bool get didChange => _revisionDelta.hasChanges;
  bool get documentReplaced => _documentReplaced;
  StoreRevisionDelta get revisionDelta => _revisionDelta;
  TouchedSet get touchedSet => _touchedSet.build();
  CommitPlan get commitPlan {
    return const CommitCompiler().compile(
      revisionDelta: _revisionDelta,
      touchedSet: touchedSet,
    );
  }

  /// Records completed sparse DTO applications in a zone-local observer only
  /// under asserts.
  @visibleForTesting
  static T observeSparseMutationApplications<T>(
    void Function(StoreSparseMutation mutation) sink,
    T Function() operation,
  ) {
    return runZoned(
      operation,
      zoneValues: {_sparseMutationApplicationZoneKey: sink},
    );
  }

  CanvasDocument readDocument() => _materialize();

  CanvasDocumentSummary get summary {
    return CanvasDocumentSummary(
      elementCount:
          _structure.backgroundElementCount + _structure.contentElementCount,
      layerCount: _structure.layerCount,
      resourceCount: _resources.length,
    );
  }

  bool ensureLayer(CanvasLayerId id, {int? index}) {
    if (!_structure.ensureLayer(id, index: index)) {
      return false;
    }
    _touchedSet.touchLayer(id);
    _markLayerStructural();

    return true;
  }

  CanvasElementId addElement(
    CanvasElement element, {
    CanvasLayerId? layerId,
    int? index,
  }) {
    _admitElement(element);
    final targetLayerId = _layerForElementAdd(layerId);
    _structure.addContent(element, layerId: targetLayerId, index: index);
    _resources.addElement(element);
    _touchedSet.touchAddedElement(element.id);
    _markStructural();

    return element.id;
  }

  CanvasElementId addBackgroundElement(CanvasElement element, {int? index}) {
    _admitElement(element);
    _structure.addBackground(element, index: index);
    _resources.addElement(element);
    _touchedSet.touchAddedElement(element.id);
    _touchedSet.touchBackgroundLayer();
    _markStructural();

    return element.id;
  }

  // The sealed DTO dispatcher stays whole so adding a mutation subtype fails at
  // this owner instead of leaving a second synchronized application route.
  // ignore: cyclomatic-complexity, source-lines-of-code
  void applyStoreSparseMutation(StoreSparseMutation mutation) {
    switch (mutation) {
      case StoreSparseEnsureLayer(:final id, :final index):
        ensureLayer(id, index: index);
      case StoreSparseAddElement(
        :final element,
        :final layerId,
        :final index,
        :final background,
      ):
        if (background) {
          addBackgroundElement(element, index: index);
        } else {
          addElement(element, layerId: layerId, index: index);
        }
      case StoreSparseUpdateElement(
        :final before,
        :final element,
        :final elementRevisionDelta,
      ):
        _applyStoreSparseUpdate(
          before: before,
          after: element,
          revisionDelta: elementRevisionDelta,
        );
      case StoreSparseRemoveElement(:final id):
        removeElement(id);
      case StoreSparseUpsertResource(:final resource):
        upsertResource(resource);
      case StoreSparseRemoveUnusedResource(:final id):
        removeUnusedResource(id);
      case StoreSparseClearContent(:final removeUnusedResources):
        clearContent(removeUnusedResources: removeUnusedResources);
      case StoreSparseSetBackground(:final background):
        _applyStoreSparseBackground(background);
      case StoreSparseSetCamera(:final camera):
        setCameraOffset(camera.offset);
      case StoreSparseSetPalette(:final palette):
        setPalette(palette);
    }
    _recordSparseMutationApplication(mutation);
  }

  // Update admission, draft replacement, touched taxonomy, and revision delta
  // are kept together so preflight cannot diverge from rollback-visible state.
  // ignore: halstead-volume
  bool updateElement(CanvasElementUpdate update) {
    final target = _findElement(update.id);
    if (target == null) {
      return false;
    }
    final before = target.element;
    if (!elementUpdateMatchesKind(before, update)) {
      throw ArgumentError.value(
        update,
        'update',
        'element update kind does not match the target element.',
      );
    }
    final updated = updatedElementFor(before, update);
    if (updated == null) {
      return false;
    }
    final compiledUpdate = const CommitCompiler().compileElementUpdate(
      before: before,
      after: updated,
    );
    return _replaceElement(
      before: before,
      after: updated,
      compiledUpdate: compiledUpdate,
      revisionDelta: compiledUpdate.revisionDelta,
    );
  }

  void _applyStoreSparseUpdate({
    required CanvasElement before,
    required CanvasElement after,
    required StoreRevisionDelta revisionDelta,
  }) {
    final target = _findElement(before.id);
    if (target == null) {
      return;
    }
    final compiledUpdate = const CommitCompiler().compileElementUpdate(
      before: before,
      after: after,
    );
    _replaceElement(
      before: before,
      after: after,
      compiledUpdate: compiledUpdate,
      revisionDelta: revisionDelta,
    );
  }

  bool _replaceElement({
    required CanvasElement before,
    required CanvasElement after,
    required ElementUpdateCompileResult compiledUpdate,
    required StoreRevisionDelta revisionDelta,
  }) {
    _structure.replaceElement(after);
    _resources.replaceElement(before: before, after: after);
    _touchedSet.touchUpdatedElement(after.id);
    if (compiledUpdate.touchesSpatial) {
      _touchedSet.touchGeometryElement(after.id);
    }
    if (compiledUpdate.transformsElement) {
      _touchedSet.touchTransformedElement(after.id);
    }
    if (compiledUpdate.touchesVisual) {
      _touchedSet.touchVisualElement(after.id);
    }
    if (compiledUpdate.prunesSelection &&
        _selectedElementIds.contains(after.id)) {
      _touchedSet.touchSelection();
    }
    _markElementUpdate(revisionDelta);

    return true;
  }

  void _applyStoreSparseBackground(CanvasBackground nextBackground) {
    if (background.color != nextBackground.color) {
      setBackgroundColor(nextBackground.color);
    }
    if (background.grid != nextBackground.grid) {
      setGrid(nextBackground.grid);
    }
  }

  bool removeElement(CanvasElementId id) {
    final target = _structure.remove(id);
    if (target == null) {
      return false;
    }
    _resources.removeElement(target.element);
    _touchedSet.touchRemovedElement(id);
    if (target.isBackground) {
      _touchedSet.touchBackgroundLayer();
    }
    if (_selectedElementIds.contains(id)) {
      _touchedSet.touchSelection();
    }
    _markStructural();

    return true;
  }

  bool upsertResource(CanvasResource resource) {
    if (!_resources.upsert(resource)) {
      return false;
    }
    _touchedSet.touchResourceDescriptor(resource.id);
    if (_resources.isReferenced(resource.id)) {
      _touchedSet.touchResourceVisual(resource.id);
    }
    _markResource();

    return true;
  }

  bool removeUnusedResource(CanvasResourceId id) {
    if (!_resources.removeUnused(id)) {
      return false;
    }
    _touchedSet.touchResourceDescriptor(id);
    _markResource();

    return true;
  }

  void setBackgroundColor(Color color) {
    if (background.color == color) {
      return;
    }
    background = CanvasBackground(color: color, grid: background.grid);
    _touchedSet.touchBackground();
    _markBackground();
  }

  void setGrid(CanvasGrid grid) {
    if (background.grid == grid) {
      return;
    }
    background = CanvasBackground(color: background.color, grid: grid);
    _touchedSet.touchGrid();
    _markGrid();
  }

  void setPalette(CanvasPalette nextPalette) {
    if (_samePalette(palette, nextPalette)) {
      return;
    }
    palette = _copyPalette(nextPalette);
    _touchedSet.touchPalette();
    _markProjectionOnly();
  }

  void setCameraOffset(Offset offset) {
    final nextCamera = CanvasCamera(offset: offset);
    if (camera == nextCamera) {
      return;
    }
    camera = nextCamera;
    _touchedSet.touchPersistedCamera();
    _markProjectionOnly();
  }

  CanvasClearResult clearContent({required bool removeUnusedResources}) {
    final removedElementIds = _clearElements();
    final removedResourceIds = _clearResources(
      removeUnusedResources: removeUnusedResources,
    );

    _markRemovedElements(removedElementIds);
    _markRemovedResources(removedResourceIds);

    return CanvasClearResult(
      removedElementIds: removedElementIds,
      removedResourceIds: removedResourceIds,
      didClearContent:
          removedElementIds.isNotEmpty || removedResourceIds.isNotEmpty,
    );
  }

  void replaceDocument(CanvasDocument document) {
    final draft = ValidatedImportDraft.fromDraftReplacement(document);
    final preparedLoad = prepareDraftReplacement(draft.document);
    final replacement = draft.document;
    camera = replacement.camera;
    background = replacement.background;
    palette = _copyPalette(replacement.palette);
    metadata = replacement.metadata;
    _structure = DraftStructure(replacement);
    _resources = DraftResources(
      descriptors: replacement.resources,
      visitRows: _structure.visitCurrentRows,
    );
    _documentReplaced = true;
    _touchedSet.touchDocumentReplacement();
    if (!_selectionValidForReplacement()) {
      _touchedSet.touchSelection();
    }
    _revisionDelta = _revisionDelta.merge(preparedLoad.revisionDelta);
  }

  CanvasDocument _materialize() {
    final structure = _structure.materialize();
    return CanvasDocument(
      camera: camera,
      background: background,
      palette: _copyPalette(palette),
      resources: _resources.materialize(),
      backgroundElements: structure.backgroundElements,
      layers: structure.layers,
      metadata: metadata,
    );
  }

  void _admitElement(CanvasElement element) {
    if (_structure.hasElement(element.id)) {
      throw CanvasDataException(
        code: CanvasDataErrorCode.duplicateElementId,
        message: 'duplicate element id.',
        path: 'elements.id',
      );
    }
  }

  List<CanvasElementId> _clearElements() {
    return _structure.clearContent(
      onElementRemoved: (id) {
        final target = _findElement(id);
        if (target == null) {
          throw StateError('Draft clear is missing its current element row.');
        }
        _resources.removeElement(target.element);
      },
    );
  }

  List<CanvasResourceId> _clearResources({
    required bool removeUnusedResources,
  }) {
    if (!removeUnusedResources) {
      return const [];
    }

    return _resources.removeAllUnused();
  }

  void _markRemovedElements(List<CanvasElementId> removedElementIds) {
    if (removedElementIds.isNotEmpty) {
      _touchedSet.touchRemovedElements(removedElementIds);
      if (_intersectsSelection(removedElementIds)) {
        _touchedSet.touchSelection();
      }
      _markStructural();
    }
  }

  void _markRemovedResources(List<CanvasResourceId> removedResourceIds) {
    if (removedResourceIds.isNotEmpty) {
      _touchedSet.touchResourceDescriptors(removedResourceIds);
      _markResource();
    }
  }

  CanvasLayerId _layerForElementAdd(CanvasLayerId? layerId) {
    if (layerId == null) {
      final lastLayerId = _structure.lastLayerId;
      if (lastLayerId == null) {
        final defaultLayerId = CanvasLayerId('default-layer');
        _structure.ensureLayer(defaultLayerId);
        _touchedSet.touchLayer(defaultLayerId);
        _markStructural();
        return defaultLayerId;
      }
      return lastLayerId;
    }

    if (_structure.hasLayer(layerId)) {
      return layerId;
    }
    _structure.ensureLayer(layerId);
    _touchedSet.touchLayer(layerId);
    _markStructural();
    return layerId;
  }

  DraftStructureElement? _findElement(CanvasElementId id) =>
      _structure.elementForId(id);

  static void _recordSparseMutationApplication(StoreSparseMutation mutation) {
    assert(() {
      final sink = Zone.current[_sparseMutationApplicationZoneKey];
      if (sink is void Function(StoreSparseMutation)) {
        sink(mutation);
      }
      return true;
    }(), 'draft sparse mutation application observation failed');
  }

  bool _intersectsSelection(Iterable<CanvasElementId> ids) {
    return ids.any(_selectedElementIds.contains);
  }

  bool _selectionValidForReplacement() {
    final selectableIds = <CanvasElementId>{
      for (final element in _contentElements())
        if (element.isVisible && element.isSelectable) element.id,
    };

    return _selectedElementIds.every(selectableIds.contains);
  }

  Iterable<CanvasElement> _contentElements() sync* {
    yield* _structure.orderedContentElements();
  }

  void _markStructural() {
    _revisionDelta = _revisionDelta.merge(
      const StoreRevisionDelta.structural(),
    );
  }

  void _markLayerStructural() {
    _revisionDelta = _revisionDelta.merge(
      const StoreRevisionDelta.layerStructural(),
    );
  }

  void _markElementUpdate(StoreRevisionDelta delta) {
    _revisionDelta = _revisionDelta.merge(delta);
  }

  void _markBackground() {
    _revisionDelta = _revisionDelta.merge(
      const StoreRevisionDelta.background(),
    );
  }

  void _markGrid() {
    _revisionDelta = _revisionDelta.merge(const StoreRevisionDelta.grid());
  }

  void _markResource() {
    _revisionDelta = _revisionDelta.merge(const StoreRevisionDelta.resource());
  }

  void _markProjectionOnly() {
    _revisionDelta = _revisionDelta.merge(
      const StoreRevisionDelta.projectionOnly(),
    );
  }
}

// Sparse replay can apply a DTO but cannot inspect Draft state before finish.
abstract interface class DraftSparseMutationConsumer {
  void apply(StoreSparseMutation mutation);
}

// This target owns the Draft between factory creation and finish, so callers
// hold only a write capability while promotion is in progress.
final class DraftSparsePromotionTarget implements DraftSparseMutationConsumer {
  DraftSparsePromotionTarget.open(DraftDocument Function() draftFactory)
    : _draft = draftFactory();

  DraftDocument? _draft;

  @override
  void apply(StoreSparseMutation mutation) {
    final draft = _draft;
    if (draft == null) {
      throw StateError('Sparse promotion target has been released.');
    }
    draft.applyStoreSparseMutation(mutation);
  }

  DraftDocument finish() {
    final draft = _draft;
    if (draft == null) {
      throw StateError('Sparse promotion target has already finished.');
    }
    _draft = null;
    return draft;
  }
}

bool _samePalette(CanvasPalette left, CanvasPalette right) {
  return _sameList(left.penColors, right.penColors) &&
      _sameList(left.backgroundColors, right.backgroundColors) &&
      _sameList(left.gridSizes, right.gridSizes);
}

bool _sameList<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }

  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }

  return true;
}

CanvasPalette _copyPalette(CanvasPalette palette) {
  return CanvasPalette(
    penColors: palette.penColors,
    backgroundColors: palette.backgroundColors,
    gridSizes: palette.gridSizes,
  );
}
