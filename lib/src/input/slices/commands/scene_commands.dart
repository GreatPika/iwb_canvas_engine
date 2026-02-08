import 'dart:ui';

import '../../../core/background_layer_invariants.dart';
import '../../../core/nodes.dart';
import '../../../core/scene.dart';
import '../../../core/transform2d.dart';
import '../../action_events.dart';
import '../../internal/contracts.dart';
import '../../internal/node_interaction_policy.dart';
import '../../internal/selection_geometry.dart';

class SceneCommands {
  SceneCommands(this._contracts);

  final InputSliceContracts _contracts;

  void notifySceneChanged() {
    _contracts.rebuildNodeIdIndex();
    final selectedNodeIds = _contracts.selectedNodeIds;
    if (selectedNodeIds.isNotEmpty) {
      _contracts.setSelection(
        selectedNodeIds.where(_contracts.containsNodeId),
        notify: false,
      );
    }
    _contracts.markSceneStructuralChanged();
    _contracts.notifyNow();
  }

  void mutate(void Function(Scene scene) fn) {
    String? beforeFingerprint;
    assert(() {
      beforeFingerprint = _structuralFingerprint(_contracts.scene);
      return true;
    }());

    fn(_contracts.scene);

    assert(() {
      final afterFingerprint = _structuralFingerprint(_contracts.scene);
      if (beforeFingerprint != afterFingerprint) {
        throw StateError(
          'Structural scene mutation detected in mutate(...). '
          'Use mutateStructural(...) for add/remove/reorder layers or nodes.',
        );
      }
      return true;
    }());

    _contracts.markSceneGeometryChanged();
    _contracts.requestRepaintOncePerFrame();
  }

  void mutateStructural(void Function(Scene scene) fn) {
    fn(_contracts.scene);
    notifySceneChanged();
  }

  void addNode(SceneNode node, {int? layerIndex}) {
    if (layerIndex != null && layerIndex < 0) {
      throw RangeError.range(layerIndex, 0, null, 'layerIndex');
    }
    if (_contracts.containsNodeId(node.id)) {
      throw ArgumentError.value(
        node.id,
        'node.id',
        'Node id must be unique within the scene.',
      );
    }

    final layers = _contracts.scene.layers;
    if (layers.isEmpty) {
      if (layerIndex != null && layerIndex != 0) {
        throw RangeError.range(layerIndex, 0, 0, 'layerIndex');
      }
      layers.add(Layer());
    }

    final resolvedLayerIndex =
        layerIndex ?? _resolveDefaultAddLayerIndex(layers);
    if (resolvedLayerIndex >= layers.length) {
      throw RangeError.range(
        resolvedLayerIndex,
        0,
        layers.length - 1,
        'layerIndex',
      );
    }

    layers[resolvedLayerIndex].nodes.add(node);
    _contracts.registerNodeId(node.id);
    _contracts.markSceneStructuralChanged();
    _contracts.notifyNow();
  }

  int _resolveDefaultAddLayerIndex(List<Layer> layers) {
    for (var i = 0; i < layers.length; i++) {
      if (!layers[i].isBackground) {
        return i;
      }
    }
    layers.add(Layer());
    return layers.length - 1;
  }

  String _structuralFingerprint(Scene scene) {
    final buffer = StringBuffer();
    buffer.write('layers=${scene.layers.length};');
    for (var layerIndex = 0; layerIndex < scene.layers.length; layerIndex++) {
      final layer = scene.layers[layerIndex];
      buffer
        ..write('L')
        ..write(layerIndex)
        ..write(':bg=')
        ..write(layer.isBackground ? '1' : '0')
        ..write(':nodes=')
        ..write(layer.nodes.length)
        ..write(':');
      for (final node in layer.nodes) {
        buffer
          ..write(node.id)
          ..write('|');
      }
      buffer.write(';');
    }
    return buffer.toString();
  }

  void removeNode(NodeId id, {int? timestampMs}) {
    for (final layer in _contracts.scene.layers) {
      final index = layer.nodes.indexWhere((node) => node.id == id);
      if (index == -1) continue;

      layer.nodes.removeAt(index);
      _contracts.unregisterNodeId(id);
      _contracts.setSelection(
        _contracts.selectedNodeIds.where((candidate) => candidate != id),
        notify: false,
      );
      _contracts.markSceneStructuralChanged();
      _contracts.emitAction(ActionType.delete, [
        id,
      ], _contracts.resolveTimestampMs(timestampMs));
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
        _contracts.resolveTimestampMs(timestampMs),
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
        if (!isNodeInteractiveForSelection(
          node,
          layer,
          onlySelectable: onlySelectable,
        )) {
          continue;
        }
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
      _contracts.resolveTimestampMs(timestampMs),
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
      _contracts.resolveTimestampMs(timestampMs),
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
      _contracts.resolveTimestampMs(timestampMs),
      payload: <String, Object?>{'delta': delta.toJsonMap()},
    );
    _contracts.markSceneGeometryChanged();
    _contracts.notifyNow();
  }

  void deleteSelection({int? timestampMs}) {
    final selectedNodeIds = _contracts.selectedNodeIds;
    if (selectedNodeIds.isEmpty) return;
    final deletableIds = <NodeId>[];
    final selectedIdSet = selectedNodeIds.toSet();

    for (final layer in _contracts.scene.layers) {
      layer.nodes.removeWhere((node) {
        if (!selectedIdSet.contains(node.id)) return false;
        if (!isNodeDeletableInLayer(node, layer)) return false;
        deletableIds.add(node.id);
        _contracts.unregisterNodeId(node.id);
        return true;
      });
    }

    if (deletableIds.isEmpty) return;
    final deletableIdSet = deletableIds.toSet();
    _contracts.setSelection(
      selectedNodeIds.where((id) => !deletableIdSet.contains(id)),
      notify: false,
    );
    _contracts.markSceneStructuralChanged();
    _contracts.emitAction(
      ActionType.delete,
      deletableIds,
      _contracts.resolveTimestampMs(timestampMs),
    );
    _contracts.notifyNow();
  }

  void clearScene({int? timestampMs}) {
    canonicalizeBackgroundLayerInvariants(
      _contracts.scene.layers,
      onMultipleBackgroundError: (count) {
        throw StateError(
          'clearScene requires at most one background layer; found $count.',
        );
      },
    );

    final clearedIds = <NodeId>[];
    final layers = _contracts.scene.layers;
    for (var layerIndex = 1; layerIndex < layers.length; layerIndex++) {
      for (final node in layers[layerIndex].nodes) {
        clearedIds.add(node.id);
        _contracts.unregisterNodeId(node.id);
      }
    }
    layers.removeRange(1, layers.length);

    if (clearedIds.isEmpty) return;
    _contracts.setSelection(const <NodeId>[], notify: false);
    _contracts.markSceneStructuralChanged();
    _contracts.emitAction(
      ActionType.clear,
      clearedIds,
      _contracts.resolveTimestampMs(timestampMs),
    );
    _contracts.notifyNow();
  }
}
