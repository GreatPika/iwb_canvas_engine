import 'dart:ui';

import '../api/canvas_document.dart';
import '../api/canvas_element.dart';
import '../api/canvas_element_update.dart';
import '../api/canvas_errors.dart';
import '../api/canvas_field_update.dart';
import '../api/canvas_geometry.dart';
import '../api/canvas_ids.dart';
import '../api/canvas_metadata.dart';
import '../api/canvas_resource.dart';
import '../api/canvas_runtime.dart';
import '../store/resource_table.dart';
import '../store/store_revision_delta.dart';
import 'commit_compiler.dart';
import 'commit_plan.dart';
import 'staged_document_load.dart';
import 'touched_set.dart';

// The draft boundary directly names the public DTOs it can mutate so rollback
// admission remains auditable in one owner instead of being split into sync
// glue. Element copy/taxonomy helpers are still private to this draft owner.
// ignore_for_file: number-of-imports

// DraftDocument keeps the mutable transaction state in one place; splitting the
// handle by metric family would require synchronizing element, resource, and
// revision buffers during rollback.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class DraftDocument {
  DraftDocument(
    CanvasDocument document, {
    Iterable<CanvasElementId> selectedElementIds = const [],
  }) : _selectedElementIds = Set.unmodifiable(selectedElementIds),
       camera = document.camera,
       background = document.background,
       palette = _copyPalette(document.palette),
       metadata = document.metadata,
       resources = document.resources
           .map<CanvasResource>(ResourceTable.copy)
           .toList(),
       backgroundElements = List.of(document.backgroundElements),
       _layers = [
         for (final layer in document.layers)
           _DraftLayer(
             id: layer.id,
             elements: List.of(layer.elements),
             metadata: layer.metadata,
           ),
       ];

  CanvasCamera camera;
  CanvasBackground background;
  CanvasPalette palette;
  CanvasMetadata metadata;
  final List<CanvasResource> resources;
  final List<CanvasElement> backgroundElements;
  final List<_DraftLayer> _layers;
  final Set<CanvasElementId> _selectedElementIds;
  StoreRevisionDelta _revisionDelta = const StoreRevisionDelta();
  final TouchedSetBuilder _touchedSet = TouchedSetBuilder();

  bool get didChange => _revisionDelta.hasChanges;
  StoreRevisionDelta get revisionDelta => _revisionDelta;
  TouchedSet get touchedSet => _touchedSet.build();
  CommitPlan get commitPlan {
    return const CommitCompiler().compile(
      revisionDelta: _revisionDelta,
      touchedSet: touchedSet,
    );
  }

  CanvasDocument readDocument() => _materialize();

  CanvasDocumentSummary get summary {
    return CanvasDocumentSummary(
      elementCount: backgroundElements.length + _contentElementCount(),
      layerCount: _layers.length,
      resourceCount: resources.length,
    );
  }

  bool ensureLayer(CanvasLayerId id, {int? index}) {
    if (_layerIndex(id) != -1) {
      return false;
    }
    final targetIndex = _clampedInsertIndex(index, _layers.length);
    _layers.insert(targetIndex, _DraftLayer(id: id));
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
    final layer = _layerForElementAdd(layerId);
    final targetIndex = _clampedInsertIndex(index, layer.elements.length);
    layer.elements.insert(targetIndex, element);
    _touchedSet.touchAddedElement(element.id);
    _markStructural();

    return element.id;
  }

  CanvasElementId addBackgroundElement(CanvasElement element, {int? index}) {
    _admitElement(element);
    final targetIndex = _clampedInsertIndex(index, backgroundElements.length);
    backgroundElements.insert(targetIndex, element);
    _touchedSet.touchAddedElement(element.id);
    _touchedSet.touchBackgroundLayer();
    _markStructural();

    return element.id;
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
    if (!_updateMatchesElement(before, update)) {
      throw ArgumentError.value(
        update,
        'update',
        'element update kind does not match the target element.',
      );
    }
    final updated = _updatedElement(before, update);
    if (updated == null) {
      return false;
    }
    _validateElementResourceReferences(updated);
    target.replace(updated);
    final compiledUpdate = const CommitCompiler().compileElementUpdate(
      before: before,
      after: updated,
    );
    _touchedSet.touchUpdatedElement(updated.id);
    if (compiledUpdate.touchesGeometry) {
      _touchedSet.touchGeometryElement(updated.id);
    }
    if (compiledUpdate.transformsElement) {
      _touchedSet.touchTransformedElement(updated.id);
    }
    if (compiledUpdate.touchesVisual) {
      _touchedSet.touchVisualElement(updated.id);
    }
    if (compiledUpdate.prunesSelection &&
        _selectedElementIds.contains(updated.id)) {
      _touchedSet.touchSelection();
    }
    _markElementUpdate(compiledUpdate.revisionDelta);

    return true;
  }

  bool removeElement(CanvasElementId id) {
    final target = _findElement(id);
    if (target == null) {
      return false;
    }
    target.remove();
    _touchedSet.touchRemovedElement(id);
    if (target.isBackgroundLayer) {
      _touchedSet.touchBackgroundLayer();
    }
    if (_selectedElementIds.contains(id)) {
      _touchedSet.touchSelection();
    }
    _markStructural();

    return true;
  }

  bool upsertResource(CanvasResource resource) {
    final index = resources.indexWhere((row) => row.id == resource.id);
    if (index == -1) {
      resources.add(ResourceTable.copy(resource));
      _touchedSet.touchResourceDescriptor(resource.id);
      if (_isResourceReferenced(resource.id)) {
        _touchedSet.touchResourceVisual(resource.id);
      }
      _markResource();

      return true;
    }
    if (_sameResource(resources[index], resource)) {
      return false;
    }
    resources[index] = ResourceTable.copy(resource);
    _touchedSet.touchResourceDescriptor(resource.id);
    if (_isResourceReferenced(resource.id)) {
      _touchedSet.touchResourceVisual(resource.id);
    }
    _markResource();

    return true;
  }

  bool removeUnusedResource(CanvasResourceId id) {
    final index = resources.indexWhere((resource) => resource.id == id);
    if (index == -1 || _isResourceReferenced(id)) {
      return false;
    }
    resources.removeAt(index);
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
    final clearedElements = _clearElements();
    final removedResourceIds = _clearResources(
      removeUnusedResources: removeUnusedResources,
    );

    _markRemovedElements(clearedElements);
    _markRemovedResources(removedResourceIds);

    return CanvasClearResult(
      removedElementIds: clearedElements.allIds,
      removedResourceIds: removedResourceIds,
      didClearContent:
          clearedElements.allIds.isNotEmpty || removedResourceIds.isNotEmpty,
    );
  }

  void replaceDocument(CanvasDocument document) {
    final preparedLoad = prepareDraftReplacement(document);
    camera = preparedLoad.document.camera;
    background = preparedLoad.document.background;
    palette = _copyPalette(preparedLoad.document.palette);
    metadata = preparedLoad.document.metadata;
    resources
      ..clear()
      ..addAll(preparedLoad.document.resources.map(ResourceTable.copy));
    backgroundElements
      ..clear()
      ..addAll(preparedLoad.document.backgroundElements);
    _layers
      ..clear()
      ..addAll([
        for (final layer in preparedLoad.document.layers)
          _DraftLayer(
            id: layer.id,
            elements: List.of(layer.elements),
            metadata: layer.metadata,
          ),
      ]);
    _touchedSet.touchDocumentReplacement();
    if (!_selectionValidForReplacement()) {
      _touchedSet.touchSelection();
    }
    _revisionDelta = _revisionDelta.merge(preparedLoad.revisionDelta);
  }

  CanvasDocument _materialize() {
    return CanvasDocument(
      camera: camera,
      background: background,
      palette: _copyPalette(palette),
      resources: resources.map(ResourceTable.copy),
      backgroundElements: backgroundElements,
      layers: [
        for (final layer in _layers)
          CanvasLayer(
            id: layer.id,
            elements: layer.elements,
            metadata: layer.metadata,
          ),
      ],
      metadata: metadata,
    );
  }

  int _contentElementCount() {
    return _layers.fold<int>(
      0,
      (count, layer) => count + layer.elements.length,
    );
  }

  void _admitElement(CanvasElement element) {
    if (_hasElementId(element.id)) {
      throw CanvasDataException(
        code: CanvasDataErrorCode.duplicateElementId,
        message: 'duplicate element id.',
        path: 'elements.id',
      );
    }
    if (element case CanvasImageElement(:final resourceId)) {
      final hasResource = resources.any(
        (resource) => resource.id == resourceId,
      );
      if (!hasResource) {
        throw CanvasDataException(
          code: CanvasDataErrorCode.missingResourceReference,
          message: 'image element references a missing resource.',
          path: 'image.resourceId',
        );
      }
    }
  }

  _ClearedElements _clearElements() {
    final removedBackgroundElementIds = [
      for (final element in backgroundElements) element.id,
    ];
    final removedContentElementIds = [
      for (final layer in _layers)
        for (final element in layer.elements) element.id,
    ];
    final removedElementIds = [
      ...removedBackgroundElementIds,
      ...removedContentElementIds,
    ];
    backgroundElements.clear();
    for (final layer in _layers) {
      layer.elements.clear();
    }

    return _ClearedElements(
      backgroundIds: removedBackgroundElementIds,
      allIds: removedElementIds,
    );
  }

  List<CanvasResourceId> _clearResources({
    required bool removeUnusedResources,
  }) {
    if (removeUnusedResources) {
      final removedResourceIds = [
        for (final resource in resources) resource.id,
      ];
      resources.clear();

      return removedResourceIds;
    }

    return const [];
  }

  void _markRemovedElements(_ClearedElements clearedElements) {
    if (clearedElements.allIds.isNotEmpty) {
      _touchedSet.touchRemovedElements(clearedElements.allIds);
      if (clearedElements.backgroundIds.isNotEmpty) {
        _touchedSet.touchBackgroundLayer();
      }
      if (_intersectsSelection(clearedElements.allIds)) {
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

  bool _hasElementId(CanvasElementId id) {
    return backgroundElements.any((element) => element.id == id) ||
        _layers.any(
          (layer) => layer.elements.any((element) => element.id == id),
        );
  }

  int _layerIndex(CanvasLayerId id) {
    return _layers.indexWhere((layer) => layer.id == id);
  }

  _DraftLayer _layerForElementAdd(CanvasLayerId? layerId) {
    if (layerId == null) {
      if (_layers.isEmpty) {
        final layer = _DraftLayer(id: CanvasLayerId('default-layer'));
        _layers.add(layer);
        _touchedSet.touchLayer(layer.id);
        _markStructural();

        return layer;
      }

      return _layers.last;
    }

    final index = _layerIndex(layerId);
    if (index != -1) {
      return _layers[index];
    }
    final layer = _DraftLayer(id: layerId);
    _layers.add(layer);
    _touchedSet.touchLayer(layer.id);
    _markStructural();

    return layer;
  }

  _ElementTarget? _findElement(CanvasElementId id) {
    final backgroundIndex = backgroundElements.indexWhere(
      (element) => element.id == id,
    );
    if (backgroundIndex != -1) {
      return _ElementTarget(
        read: () => backgroundElements[backgroundIndex],
        write: (element) => backgroundElements[backgroundIndex] = element,
        removeAt: () => backgroundElements.removeAt(backgroundIndex),
        isBackgroundLayer: true,
      );
    }

    for (final layer in _layers) {
      final index = layer.elements.indexWhere((element) => element.id == id);
      if (index != -1) {
        return _ElementTarget(
          read: () => layer.elements[index],
          write: (element) => layer.elements[index] = element,
          removeAt: () => layer.elements.removeAt(index),
          isBackgroundLayer: false,
        );
      }
    }

    return null;
  }

  bool _isResourceReferenced(CanvasResourceId id) {
    return _allElements().any((element) {
      return element is CanvasImageElement && element.resourceId == id;
    });
  }

  void _validateElementResourceReferences(CanvasElement element) {
    if (element case CanvasImageElement(:final resourceId)) {
      final hasResource = resources.any(
        (resource) => resource.id == resourceId,
      );
      if (!hasResource) {
        throw CanvasDataException(
          code: CanvasDataErrorCode.missingResourceReference,
          message: 'image element references a missing resource.',
          path: 'image.resourceId',
        );
      }
    }
  }

  Iterable<CanvasElement> _allElements() sync* {
    yield* backgroundElements;
    for (final layer in _layers) {
      yield* layer.elements;
    }
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
    for (final layer in _layers) {
      yield* layer.elements;
    }
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

final class _DraftLayer {
  _DraftLayer({
    required this.id,
    List<CanvasElement>? elements,
    this.metadata = const CanvasMetadata.empty(),
  }) : elements = elements ?? <CanvasElement>[];

  final CanvasLayerId id;
  final List<CanvasElement> elements;
  final CanvasMetadata metadata;
}

final class _ClearedElements {
  const _ClearedElements({required this.backgroundIds, required this.allIds});

  final List<CanvasElementId> backgroundIds;
  final List<CanvasElementId> allIds;
}

final class _ElementTarget {
  const _ElementTarget({
    required CanvasElement Function() read,
    required void Function(CanvasElement element) write,
    required void Function() removeAt,
    required this.isBackgroundLayer,
  }) : _read = read,
       _write = write,
       _removeAt = removeAt;

  final CanvasElement Function() _read;
  final void Function(CanvasElement element) _write;
  final void Function() _removeAt;
  final bool isBackgroundLayer;

  CanvasElement get element => _read();

  void replace(CanvasElement element) {
    _write(element);
  }

  void remove() {
    _removeAt();
  }
}

int _clampedInsertIndex(int? requestedIndex, int length) {
  final index = requestedIndex ?? length;
  if (index < 0) {
    return 0;
  }
  if (index > length) {
    return length;
  }

  return index;
}

CanvasElement? _updatedElement(
  CanvasElement element,
  CanvasElementUpdate update,
) {
  final common = _CommonUpdate.apply(element, update);
  final updated = switch ((element, update)) {
    (final CanvasImageElement element, final CanvasImageElementUpdate update) =>
      _updatedImageElement(element, update, common),
    (final CanvasPathElement element, final CanvasPathElementUpdate update) =>
      _updatedPathElement(element, update, common),
    (final CanvasTextElement element, final CanvasTextElementUpdate update) =>
      _updatedTextElement(element, update, common),
    (
      final CanvasStrokeElement element,
      final CanvasStrokeElementUpdate update,
    ) =>
      _updatedStrokeElement(element, update, common),
    (final CanvasLineElement element, final CanvasLineElementUpdate update) =>
      _updatedLineElement(element, update, common),
    (final CanvasRectElement element, final CanvasRectElementUpdate update) =>
      _updatedRectElement(element, update, common),
    _ => null,
  };

  return updated != null && !_sameElement(element, updated) ? updated : null;
}

bool _updateMatchesElement(CanvasElement element, CanvasElementUpdate update) {
  return switch ((element, update)) {
    (CanvasImageElement(), CanvasImageElementUpdate()) => true,
    (CanvasPathElement(), CanvasPathElementUpdate()) => true,
    (CanvasTextElement(), CanvasTextElementUpdate()) => true,
    (CanvasStrokeElement(), CanvasStrokeElementUpdate()) => true,
    (CanvasLineElement(), CanvasLineElementUpdate()) => true,
    (CanvasRectElement(), CanvasRectElementUpdate()) => true,
    _ => false,
  };
}

CanvasImageElement _updatedImageElement(
  CanvasImageElement element,
  CanvasImageElementUpdate update,
  _CommonUpdate common,
) {
  return CanvasImageElement(
    id: element.id,
    resourceId: _requiredField(update.resourceId, element.resourceId),
    size: _requiredField(update.size, element.size),
    naturalSize: _nullableField(update.naturalSize, element.naturalSize),
    revision: element.revision + 1,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
    metadata: common.metadata,
  );
}

CanvasPathElement _updatedPathElement(
  CanvasPathElement element,
  CanvasPathElementUpdate update,
  _CommonUpdate common,
) {
  return CanvasPathElement(
    id: element.id,
    svgPathData: _requiredField(update.svgPathData, element.svgPathData),
    fillColor: _nullableField(update.fillColor, element.fillColor),
    strokeColor: _nullableField(update.strokeColor, element.strokeColor),
    strokeWidth: _requiredField(update.strokeWidth, element.strokeWidth),
    fillRule: _requiredField(update.fillRule, element.fillRule),
    revision: element.revision + 1,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
    metadata: common.metadata,
  );
}

// Text updates carry the full text field surface in one constructor call so
// omitted and nullable fields cannot drift from public DTO semantics.
// ignore: halstead-volume
CanvasTextElement _updatedTextElement(
  CanvasTextElement element,
  CanvasTextElementUpdate update,
  _CommonUpdate common,
) {
  return CanvasTextElement(
    id: element.id,
    text: _requiredField(update.text, element.text),
    color: _requiredField(update.color, element.color),
    textDirection: _requiredField(update.textDirection, element.textDirection),
    fontSize: _requiredField(update.fontSize, element.fontSize),
    align: _requiredField(update.align, element.align),
    isBold: _requiredField(update.isBold, element.isBold),
    isItalic: _requiredField(update.isItalic, element.isItalic),
    isUnderline: _requiredField(update.isUnderline, element.isUnderline),
    fontFamily: _nullableField(update.fontFamily, element.fontFamily),
    maxWidth: _nullableField(update.maxWidth, element.maxWidth),
    lineHeight: _nullableField(update.lineHeight, element.lineHeight),
    revision: element.revision + 1,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
    metadata: common.metadata,
  );
}

CanvasStrokeElement _updatedStrokeElement(
  CanvasStrokeElement element,
  CanvasStrokeElementUpdate update,
  _CommonUpdate common,
) {
  return CanvasStrokeElement(
    id: element.id,
    points: _requiredListField(update.points, element.points),
    thickness: _requiredField(update.thickness, element.thickness),
    color: _requiredField(update.color, element.color),
    revision: element.revision + 1,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
    metadata: common.metadata,
  );
}

CanvasLineElement _updatedLineElement(
  CanvasLineElement element,
  CanvasLineElementUpdate update,
  _CommonUpdate common,
) {
  return CanvasLineElement(
    id: element.id,
    start: _requiredField(update.start, element.start),
    end: _requiredField(update.end, element.end),
    thickness: _requiredField(update.thickness, element.thickness),
    color: _requiredField(update.color, element.color),
    revision: element.revision + 1,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
    metadata: common.metadata,
  );
}

CanvasRectElement _updatedRectElement(
  CanvasRectElement element,
  CanvasRectElementUpdate update,
  _CommonUpdate common,
) {
  return CanvasRectElement(
    id: element.id,
    size: _requiredField(update.size, element.size),
    fillColor: _nullableField(update.fillColor, element.fillColor),
    strokeColor: _nullableField(update.strokeColor, element.strokeColor),
    strokeWidth: _requiredField(update.strokeWidth, element.strokeWidth),
    revision: element.revision + 1,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
    metadata: common.metadata,
  );
}

final class _CommonUpdate {
  const _CommonUpdate({
    required this.transform,
    required this.opacity,
    required this.hitPadding,
    required this.isVisible,
    required this.isSelectable,
    required this.isLocked,
    required this.isDeletable,
    required this.isTransformable,
    required this.metadata,
  });

  factory _CommonUpdate.apply(
    CanvasElement element,
    CanvasElementUpdate update,
  ) {
    return _CommonUpdate(
      transform: _requiredField(update.transform, element.transform),
      opacity: _requiredField(update.opacity, element.opacity),
      hitPadding: _requiredField(update.hitPadding, element.hitPadding),
      isVisible: _requiredField(update.isVisible, element.isVisible),
      isSelectable: _requiredField(update.isSelectable, element.isSelectable),
      isLocked: _requiredField(update.isLocked, element.isLocked),
      isDeletable: _requiredField(update.isDeletable, element.isDeletable),
      isTransformable: _requiredField(
        update.isTransformable,
        element.isTransformable,
      ),
      metadata: _requiredField(update.metadata, element.metadata),
    );
  }

  final CanvasTransform transform;
  final double opacity;
  final double hitPadding;
  final bool isVisible;
  final bool isSelectable;
  final bool isLocked;
  final bool isDeletable;
  final bool isTransformable;
  final CanvasMetadata metadata;
}

T _requiredField<T extends Object>(CanvasFieldUpdate<T> update, T current) {
  return switch (update) {
    CanvasFieldAbsent<T>() => current,
    CanvasFieldSet<T>(:final value) => value,
    _ => throw CanvasDataException(
      code: CanvasDataErrorCode.forbiddenField,
      message: 'non-nullable fields cannot be cleared.',
      path: 'update',
    ),
  };
}

T? _nullableField<T extends Object>(CanvasFieldUpdate<T?> update, T? current) {
  return switch (update) {
    CanvasFieldAbsent<T?>() => current,
    CanvasFieldSet<T>(:final value) => value,
    CanvasFieldClear<T>() => null,
    _ => current,
  };
}

List<T> _requiredListField<T extends Object>(
  CanvasFieldUpdate<List<T>> update,
  List<T> current,
) {
  return switch (update) {
    CanvasFieldAbsent<List<T>>() => current,
    CanvasFieldSet<List<T>>(:final value) => List.unmodifiable(value),
    _ => throw CanvasDataException(
      code: CanvasDataErrorCode.forbiddenField,
      message: 'non-nullable fields cannot be cleared.',
      path: 'update',
    ),
  };
}

// Equality for no-op detection intentionally mirrors all public element
// families in one place so a missed field cannot silently create commits.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code
bool _sameElement(CanvasElement left, CanvasElement right) {
  if (!_sameCommonElementFields(left, right)) {
    return false;
  }

  return switch ((left, right)) {
    (final CanvasImageElement left, final CanvasImageElement right) =>
      left.resourceId == right.resourceId &&
          left.size == right.size &&
          left.naturalSize == right.naturalSize,
    (final CanvasPathElement left, final CanvasPathElement right) =>
      left.svgPathData == right.svgPathData &&
          left.fillColor == right.fillColor &&
          left.strokeColor == right.strokeColor &&
          left.strokeWidth == right.strokeWidth &&
          left.fillRule == right.fillRule,
    (final CanvasTextElement left, final CanvasTextElement right) =>
      left.text == right.text &&
          left.fontSize == right.fontSize &&
          left.color == right.color &&
          left.align == right.align &&
          left.textDirection == right.textDirection &&
          left.isBold == right.isBold &&
          left.isItalic == right.isItalic &&
          left.isUnderline == right.isUnderline &&
          left.fontFamily == right.fontFamily &&
          left.maxWidth == right.maxWidth &&
          left.lineHeight == right.lineHeight,
    (final CanvasStrokeElement left, final CanvasStrokeElement right) =>
      _sameList(left.points, right.points) &&
          left.thickness == right.thickness &&
          left.color == right.color,
    (final CanvasLineElement left, final CanvasLineElement right) =>
      left.start == right.start &&
          left.end == right.end &&
          left.thickness == right.thickness &&
          left.color == right.color,
    (final CanvasRectElement left, final CanvasRectElement right) =>
      left.size == right.size &&
          left.fillColor == right.fillColor &&
          left.strokeColor == right.strokeColor &&
          left.strokeWidth == right.strokeWidth,
    _ => false,
  };
}

// Common-field comparison stays whole because these fields are shared by every
// element family and define whether an update is a real draft change.
// ignore: cyclomatic-complexity
bool _sameCommonElementFields(CanvasElement left, CanvasElement right) {
  return left.id == right.id &&
      left.kind == right.kind &&
      left.transform == right.transform &&
      left.opacity == right.opacity &&
      left.hitPadding == right.hitPadding &&
      left.isVisible == right.isVisible &&
      left.isSelectable == right.isSelectable &&
      left.isLocked == right.isLocked &&
      left.isDeletable == right.isDeletable &&
      left.isTransformable == right.isTransformable &&
      left.metadata == right.metadata;
}

bool _sameResource(CanvasResource left, CanvasResource right) {
  return left is CanvasImageResource &&
      right is CanvasImageResource &&
      left.id == right.id &&
      left.source == right.source &&
      left.mimeType == right.mimeType &&
      left.contentHash == right.contentHash &&
      left.byteLength == right.byteLength &&
      left.metadata == right.metadata;
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
