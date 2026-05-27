import '../contracts/internal/touched_set.dart';
import '../contracts/public/canvas_ids.dart';

// The builder exposes one explicit touch method per invalidation category so
// call sites cannot smuggle generic global invalidation into ordinary P5 edits.
// ignore: number-of-methods
final class TouchedSetBuilder {
  final Set<CanvasElementId> _addedElementIds = {};
  final Set<CanvasElementId> _removedElementIds = {};
  final Set<CanvasElementId> _updatedElementIds = {};
  final Set<CanvasElementId> _transformedElementIds = {};
  final Set<CanvasElementId> _geometryElementIds = {};
  final Set<CanvasElementId> _visualElementIds = {};
  final Set<CanvasResourceId> _resourceDescriptorChangedIds = {};
  final Set<CanvasResourceId> _resourceVisualChangedIds = {};
  final Set<CanvasLayerId> _layerIds = {};
  bool _backgroundLayerChanged = false;
  bool _selection = false;
  bool _persistedCamera = false;
  bool _background = false;
  bool _grid = false;
  bool _palette = false;
  bool _documentReplaced = false;

  void touchAddedElement(CanvasElementId id) {
    _addedElementIds.add(id);
  }

  void touchRemovedElement(CanvasElementId id) {
    _removedElementIds.add(id);
  }

  void touchRemovedElements(Iterable<CanvasElementId> ids) {
    _removedElementIds.addAll(ids);
  }

  void touchUpdatedElement(CanvasElementId id) {
    _updatedElementIds.add(id);
  }

  void touchTransformedElement(CanvasElementId id) {
    _transformedElementIds.add(id);
  }

  void touchGeometryElement(CanvasElementId id) {
    _geometryElementIds.add(id);
  }

  void touchVisualElement(CanvasElementId id) {
    _visualElementIds.add(id);
  }

  void touchResourceDescriptor(CanvasResourceId id) {
    _resourceDescriptorChangedIds.add(id);
  }

  void touchResourceDescriptors(Iterable<CanvasResourceId> ids) {
    _resourceDescriptorChangedIds.addAll(ids);
  }

  void touchResourceVisual(CanvasResourceId id) {
    _resourceVisualChangedIds.add(id);
  }

  void touchLayer(CanvasLayerId id) {
    _layerIds.add(id);
  }

  void touchBackgroundLayer() {
    _backgroundLayerChanged = true;
  }

  void touchSelection() {
    _selection = true;
  }

  void touchPersistedCamera() {
    _persistedCamera = true;
  }

  void touchBackground() {
    _background = true;
  }

  void touchGrid() {
    _grid = true;
  }

  void touchPalette() {
    _palette = true;
  }

  void touchDocumentReplacement() {
    _documentReplaced = true;
  }

  TouchedSet build() {
    return TouchedSet(
      addedElementIds: _addedElementIds,
      removedElementIds: _removedElementIds,
      updatedElementIds: _updatedElementIds,
      transformedElementIds: _transformedElementIds,
      geometryElementIds: _geometryElementIds,
      visualElementIds: _visualElementIds,
      resourceDescriptorChangedIds: _resourceDescriptorChangedIds,
      resourceVisualChangedIds: _resourceVisualChangedIds,
      layerIds: _layerIds,
      backgroundLayerChanged: _backgroundLayerChanged,
      selection: _selection,
      persistedCamera: _persistedCamera,
      background: _background,
      grid: _grid,
      palette: _palette,
      documentReplaced: _documentReplaced,
    );
  }
}
