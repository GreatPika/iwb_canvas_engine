import 'dart:ui';

import '../../../core/nodes.dart';
import '../../../core/scene.dart';
import '../../../core/transform2d.dart';
import '../../action_events.dart';
import '../../internal/contracts.dart';
import '../../internal/selection_geometry.dart';

class SceneCommands {
  SceneCommands(this._contracts);

  final InputSliceContracts _contracts;
  int _resolveTimestampMs(int? timestampMs) =>
      timestampMs ?? _contracts.nextMonotonicTimestampMs();

  void notifySceneChanged() {
    final selectedNodeIds = _contracts.selectedNodeIds;
    if (selectedNodeIds.isNotEmpty) {
      final existingIds = <NodeId>{};
      for (final layer in _contracts.scene.layers) {
        for (final node in layer.nodes) {
          existingIds.add(node.id);
        }
      }
      _contracts.setSelection(
        selectedNodeIds.where(existingIds.contains),
        notify: false,
      );
    }
    _contracts.markSceneStructuralChanged();
    _contracts.notifyNow();
  }

  void mutate(void Function(Scene scene) fn, {bool structural = false}) {
    fn(_contracts.scene);
    if (structural) {
      notifySceneChanged();
      return;
    }
    _contracts.markSceneGeometryChanged();
    _contracts.requestRepaintOncePerFrame();
  }

  void addNode(SceneNode node, {int layerIndex = 0}) {
    if (layerIndex < 0) {
      throw RangeError.range(layerIndex, 0, null, 'layerIndex');
    }
    if (_sceneContainsNodeId(node.id)) {
      throw ArgumentError.value(
        node.id,
        'node.id',
        'Node id must be unique within the scene.',
      );
    }

    final layers = _contracts.scene.layers;
    if (layers.isEmpty) {
      if (layerIndex != 0) {
        throw RangeError.range(layerIndex, 0, 0, 'layerIndex');
      }
      layers.add(Layer());
    }

    if (layerIndex >= layers.length) {
      throw RangeError.range(layerIndex, 0, layers.length - 1, 'layerIndex');
    }

    layers[layerIndex].nodes.add(node);
    _contracts.markSceneStructuralChanged();
    _contracts.notifyNow();
  }

  bool _sceneContainsNodeId(NodeId id) {
    for (final layer in _contracts.scene.layers) {
      for (final node in layer.nodes) {
        if (node.id == id) return true;
      }
    }
    return false;
  }

  void removeNode(NodeId id, {int? timestampMs}) {
    for (final layer in _contracts.scene.layers) {
      final index = layer.nodes.indexWhere((node) => node.id == id);
      if (index == -1) continue;

      layer.nodes.removeAt(index);
      _contracts.setSelection(
        _contracts.selectedNodeIds.where((candidate) => candidate != id),
        notify: false,
      );
      _contracts.markSceneStructuralChanged();
      _contracts.emitAction(ActionType.delete, [
        id,
      ], _resolveTimestampMs(timestampMs));
      _contracts.notifyNow();
      return;
    }
  }

  void moveNode(NodeId id, {required int targetLayerIndex, int? timestampMs}) {
    final layers = _contracts.scene.layers;
    if (layers.isEmpty) {
      throw RangeError.range(targetLayerIndex, 0, 0, 'targetLayerIndex');
    }
    if (targetLayerIndex < 0 || targetLayerIndex >= layers.length) {
      throw RangeError.range(
        targetLayerIndex,
        0,
        layers.length - 1,
        'targetLayerIndex',
      );
    }

    for (var layerIndex = 0; layerIndex < layers.length; layerIndex++) {
      final layer = layers[layerIndex];
      final nodeIndex = layer.nodes.indexWhere((node) => node.id == id);
      if (nodeIndex == -1) continue;

      if (layerIndex == targetLayerIndex) return;

      final node = layer.nodes.removeAt(nodeIndex);
      layers[targetLayerIndex].nodes.add(node);
      _contracts.markSceneStructuralChanged();
      _contracts.emitAction(
        ActionType.move,
        [id],
        _resolveTimestampMs(timestampMs),
        payload: <String, Object?>{
          'sourceLayerIndex': layerIndex,
          'targetLayerIndex': targetLayerIndex,
        },
      );
      _contracts.notifyNow();
      return;
    }
  }

  void clearSelection() {
    if (_contracts.selectedNodeIds.isEmpty) return;
    _contracts.setSelection(const <NodeId>[], notify: false);
    _contracts.notifyNow();
  }

  void setSelection(Iterable<NodeId> nodeIds) {
    _contracts.setSelection(nodeIds);
  }

  void toggleSelection(NodeId id) {
    final selectedNodeIds = _contracts.selectedNodeIds;
    if (selectedNodeIds.contains(id)) {
      _contracts.setSelection(
        selectedNodeIds.where((candidate) => candidate != id),
      );
    } else {
      _contracts.setSelection(<NodeId>[...selectedNodeIds, id]);
    }
  }

  void selectAll({bool onlySelectable = true}) {
    final ids = <NodeId>[];
    for (final layer in _contracts.scene.layers) {
      for (final node in layer.nodes) {
        if (!node.isVisible) continue;
        if (onlySelectable && !node.isSelectable) continue;
        ids.add(node.id);
      }
    }
    _contracts.setSelection(ids);
  }

  void rotateSelection({required bool clockwise, int? timestampMs}) {
    final nodes = selectedTransformableNodesInSceneOrder(
      _contracts.scene,
      _contracts.selectedNodeIds,
    ).where((node) => !node.isLocked).toList(growable: false);
    if (nodes.isEmpty) return;

    final center = centerWorldForNodes(nodes);
    final pivot = Transform2D.translation(center);
    final unpivot = Transform2D.translation(Offset(-center.dx, -center.dy));
    final rotation = Transform2D.rotationDeg(clockwise ? 90.0 : -90.0);
    final delta = pivot.multiply(rotation).multiply(unpivot);

    for (final node in nodes) {
      node.transform = delta.multiply(node.transform);
    }

    _contracts.emitAction(
      ActionType.transform,
      nodes.map((node) => node.id).toList(growable: false),
      _resolveTimestampMs(timestampMs),
      payload: <String, Object?>{'delta': delta.toJsonMap()},
    );
    _contracts.markSceneGeometryChanged();
    _contracts.notifyNow();
  }

  void flipSelectionVertical({int? timestampMs}) {
    final nodes = selectedTransformableNodesInSceneOrder(
      _contracts.scene,
      _contracts.selectedNodeIds,
    ).where((node) => !node.isLocked).toList(growable: false);
    if (nodes.isEmpty) return;

    final center = centerWorldForNodes(nodes);
    final delta = Transform2D(
      a: -1,
      b: 0,
      c: 0,
      d: 1,
      tx: 2 * center.dx,
      ty: 0,
    );

    for (final node in nodes) {
      node.transform = delta.multiply(node.transform);
    }

    _contracts.emitAction(
      ActionType.transform,
      nodes.map((node) => node.id).toList(growable: false),
      _resolveTimestampMs(timestampMs),
      payload: <String, Object?>{'delta': delta.toJsonMap()},
    );
    _contracts.markSceneGeometryChanged();
    _contracts.notifyNow();
  }

  void flipSelectionHorizontal({int? timestampMs}) {
    final nodes = selectedTransformableNodesInSceneOrder(
      _contracts.scene,
      _contracts.selectedNodeIds,
    ).where((node) => !node.isLocked).toList(growable: false);
    if (nodes.isEmpty) return;

    final center = centerWorldForNodes(nodes);
    final delta = Transform2D(
      a: 1,
      b: 0,
      c: 0,
      d: -1,
      tx: 0,
      ty: 2 * center.dy,
    );

    for (final node in nodes) {
      node.transform = delta.multiply(node.transform);
    }

    _contracts.emitAction(
      ActionType.transform,
      nodes.map((node) => node.id).toList(growable: false),
      _resolveTimestampMs(timestampMs),
      payload: <String, Object?>{'delta': delta.toJsonMap()},
    );
    _contracts.markSceneGeometryChanged();
    _contracts.notifyNow();
  }

  void deleteSelection({int? timestampMs}) {
    final selectedNodeIds = _contracts.selectedNodeIds;
    if (selectedNodeIds.isEmpty) return;
    final deletableIds = <NodeId>[];

    for (final layer in _contracts.scene.layers) {
      layer.nodes.removeWhere((node) {
        if (!selectedNodeIds.contains(node.id)) return false;
        if (!node.isDeletable) return false;
        deletableIds.add(node.id);
        return true;
      });
    }

    if (deletableIds.isEmpty) return;
    _contracts.setSelection(
      selectedNodeIds.where((id) => !deletableIds.contains(id)),
      notify: false,
    );
    _contracts.markSceneStructuralChanged();
    _contracts.emitAction(
      ActionType.delete,
      deletableIds,
      _resolveTimestampMs(timestampMs),
    );
    _contracts.notifyNow();
  }

  void clearScene({int? timestampMs}) {
    final clearedIds = <NodeId>[];
    for (final layer in _contracts.scene.layers) {
      if (layer.isBackground) continue;
      for (final node in layer.nodes) {
        clearedIds.add(node.id);
      }
      layer.nodes.clear();
    }

    if (clearedIds.isEmpty) return;
    _contracts.setSelection(const <NodeId>[], notify: false);
    _contracts.markSceneStructuralChanged();
    _contracts.emitAction(
      ActionType.clear,
      clearedIds,
      _resolveTimestampMs(timestampMs),
    );
    _contracts.notifyNow();
  }
}
