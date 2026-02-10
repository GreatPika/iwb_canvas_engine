import 'dart:ui';

import 'package:iwb_canvas_engine/src/legacy_api.dart' as v1;
import 'package:iwb_canvas_engine/basic.dart' as v2;
import 'package:iwb_canvas_engine/src/core/transform2d.dart';
import 'package:iwb_canvas_engine/src/v2/controller/scene_controller_v2.dart';

import 'event_script.dart';
import 'normalize.dart';

abstract class ParityHarnessAdapter {
  void apply(HarnessOperation operation);

  HarnessRunResult result();

  void dispose();
}

class V1HarnessAdapter implements ParityHarnessAdapter {
  V1HarnessAdapter()
    : _controller = v1.SceneController(scene: v1.Scene(layers: [v1.Layer()]));

  final v1.SceneController _controller;
  final List<NormalizedParityEvent> _events = <NormalizedParityEvent>[];

  @override
  void apply(HarnessOperation operation) {
    if (operation is AddRectOp) {
      _controller.addNode(
        v1.RectNode(
          id: operation.id,
          size: operation.size,
          fillColor: operation.fillColor,
          strokeColor: operation.strokeColor,
          strokeWidth: operation.strokeWidth,
        )..position = operation.position,
      );
      return;
    }
    if (operation is AddTextOp) {
      _controller.addNode(
        v1.TextNode(
          id: operation.id,
          text: operation.text,
          size: operation.size,
          fontSize: operation.fontSize,
          color: operation.color,
        )..position = operation.position,
      );
      return;
    }
    if (operation is PatchNodeCommonOp) {
      _controller.mutate((scene) {
        final node = _v1FindNode(scene, operation.id);
        if (node == null) return;
        if (operation.transform != null) {
          node.transform = operation.transform!;
        }
        if (operation.opacity != null) {
          node.opacity = operation.opacity!;
        }
      });
      return;
    }
    if (operation is PatchRectStyleOp) {
      _controller.mutate((scene) {
        final node = _v1FindNode(scene, operation.id);
        if (node is! v1.RectNode) return;
        node.fillColor = operation.fillColor;
        node.strokeColor = operation.strokeColor;
        if (operation.strokeWidth != null) {
          node.strokeWidth = operation.strokeWidth!;
        }
      });
      return;
    }
    if (operation is DeleteNodeOp) {
      _controller.removeNode(operation.id);
      _events.add(
        NormalizedParityEvent(
          type: 'node.deleted',
          nodeIds: canonicalNodeIds(<String>[operation.id]),
        ),
      );
      return;
    }
    if (operation is ReplaceSelectionOp) {
      _controller.setSelection(operation.ids);
      return;
    }
    if (operation is ToggleSelectionOp) {
      _controller.toggleSelection(operation.id);
      return;
    }
    if (operation is TranslateSelectionOp) {
      final selected = _controller.selectedNodeIds;
      _controller.mutate((scene) {
        for (final layer in scene.layers) {
          for (final node in layer.nodes) {
            if (!selected.contains(node.id)) continue;
            if (!node.isTransformable || node.isLocked) continue;
            node.position = node.position + operation.delta;
          }
        }
      });
      _events.add(
        NormalizedParityEvent(
          type: 'selection.translated',
          nodeIds: canonicalNodeIds(selected),
          payloadSubset: canonicalPayloadSubset(<String, Object?>{
            'dx': operation.delta.dx,
            'dy': operation.delta.dy,
          }),
        ),
      );
      return;
    }
    if (operation is DrawStrokeOp) {
      _controller.addNode(
        v1.StrokeNode(
          id: operation.id,
          points: operation.points,
          thickness: operation.thickness,
          color: operation.color,
          opacity: operation.opacity,
        ),
      );
      _events.add(
        NormalizedParityEvent(
          type: 'draw.stroke',
          nodeIds: canonicalNodeIds(<String>[operation.id]),
          payloadSubset: canonicalPayloadSubset(<String, Object?>{
            'tool': 'stroke',
            'color': operation.color.toARGB32(),
            'thickness': operation.thickness,
          }),
        ),
      );
      return;
    }
    if (operation is DrawLineOp) {
      _controller.addNode(
        v1.LineNode(
          id: operation.id,
          start: operation.start,
          end: operation.end,
          thickness: operation.thickness,
          color: operation.color,
          opacity: operation.opacity,
        ),
      );
      _events.add(
        NormalizedParityEvent(
          type: 'draw.line',
          nodeIds: canonicalNodeIds(<String>[operation.id]),
          payloadSubset: canonicalPayloadSubset(<String, Object?>{
            'tool': 'line',
            'color': operation.color.toARGB32(),
            'thickness': operation.thickness,
          }),
        ),
      );
      return;
    }
    if (operation is EraseNodesOp) {
      for (final id in operation.ids) {
        _controller.removeNode(id);
      }
      _events.add(
        NormalizedParityEvent(
          type: 'draw.erase',
          nodeIds: canonicalNodeIds(operation.ids),
        ),
      );
      return;
    }
    if (operation is SetGridEnabledOp) {
      _controller.setGridEnabled(operation.value);
      return;
    }
    if (operation is SetGridCellSizeOp) {
      _controller.setGridCellSize(operation.value);
      return;
    }
    if (operation is ReplaceSceneOp) {
      final replacement = v1.decodeScene(operation.sceneJson);
      _controller.mutateStructural((scene) {
        scene.layers
          ..clear()
          ..addAll(replacement.layers);
        scene.camera = replacement.camera;
        scene.background = replacement.background;
        scene.palette = replacement.palette;
      });
      return;
    }
    throw UnsupportedError(
      'Unsupported harness operation for v1: ${operation.runtimeType}',
    );
  }

  @override
  HarnessRunResult result() {
    return HarnessRunResult(
      sceneJsonCanonical: canonicalizeJsonLike(
        v1.encodeScene(_controller.scene),
      ),
      selectedNodeIds: canonicalNodeIds(_controller.selectedNodeIds),
      events: _events,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
  }

  static v1.SceneNode? _v1FindNode(v1.Scene scene, String id) {
    for (final layer in scene.layers) {
      for (final node in layer.nodes) {
        if (node.id == id) {
          return node;
        }
      }
    }
    return null;
  }
}

class V2HarnessAdapter implements ParityHarnessAdapter {
  V2HarnessAdapter()
    : _controller = SceneControllerV2(initialSnapshot: _defaultSnapshot());

  final SceneControllerV2 _controller;
  final List<NormalizedParityEvent> _events = <NormalizedParityEvent>[];

  @override
  void apply(HarnessOperation operation) {
    if (operation is AddRectOp) {
      _controller.commands.writeAddNode(
        v2.RectNodeSpec(
          id: operation.id,
          size: operation.size,
          fillColor: operation.fillColor,
          strokeColor: operation.strokeColor,
          strokeWidth: operation.strokeWidth,
          transform: _translation(operation.position),
        ),
      );
      return;
    }
    if (operation is AddTextOp) {
      _controller.commands.writeAddNode(
        v2.TextNodeSpec(
          id: operation.id,
          text: operation.text,
          size: operation.size,
          fontSize: operation.fontSize,
          color: operation.color,
          transform: _translation(operation.position),
        ),
      );
      return;
    }
    if (operation is PatchNodeCommonOp) {
      _controller.commands.writePatchNode(
        _buildCommonPatch(
          id: operation.id,
          kind: operation.kind,
          transform: operation.transform,
          opacity: operation.opacity,
        ),
      );
      return;
    }
    if (operation is PatchRectStyleOp) {
      _controller.commands.writePatchNode(
        v2.RectNodePatch(
          id: operation.id,
          fillColor: v2.PatchField<Color?>.value(operation.fillColor),
          strokeColor: v2.PatchField<Color?>.value(operation.strokeColor),
          strokeWidth: operation.strokeWidth == null
              ? const v2.PatchField<double>.absent()
              : v2.PatchField<double>.value(operation.strokeWidth!),
        ),
      );
      return;
    }
    if (operation is DeleteNodeOp) {
      _controller.commands.writeDeleteNode(operation.id);
      _events.add(
        NormalizedParityEvent(
          type: 'node.deleted',
          nodeIds: canonicalNodeIds(<String>[operation.id]),
        ),
      );
      return;
    }
    if (operation is ReplaceSelectionOp) {
      _controller.commands.writeSelectionReplace(operation.ids);
      return;
    }
    if (operation is ToggleSelectionOp) {
      _controller.commands.writeSelectionToggle(operation.id);
      return;
    }
    if (operation is TranslateSelectionOp) {
      _controller.move.writeTranslateSelection(operation.delta);
      _events.add(
        NormalizedParityEvent(
          type: 'selection.translated',
          nodeIds: canonicalNodeIds(_controller.selectedNodeIds),
          payloadSubset: canonicalPayloadSubset(<String, Object?>{
            'dx': operation.delta.dx,
            'dy': operation.delta.dy,
          }),
        ),
      );
      return;
    }
    if (operation is DrawStrokeOp) {
      _controller.commands.writeAddNode(
        v2.StrokeNodeSpec(
          id: operation.id,
          points: operation.points,
          thickness: operation.thickness,
          color: operation.color,
          opacity: operation.opacity,
        ),
      );
      _events.add(
        NormalizedParityEvent(
          type: 'draw.stroke',
          nodeIds: canonicalNodeIds(<String>[operation.id]),
          payloadSubset: canonicalPayloadSubset(<String, Object?>{
            'tool': 'stroke',
            'color': operation.color.toARGB32(),
            'thickness': operation.thickness,
          }),
        ),
      );
      return;
    }
    if (operation is DrawLineOp) {
      _controller.commands.writeAddNode(
        v2.LineNodeSpec(
          id: operation.id,
          start: operation.start,
          end: operation.end,
          thickness: operation.thickness,
          color: operation.color,
          opacity: operation.opacity,
        ),
      );
      _events.add(
        NormalizedParityEvent(
          type: 'draw.line',
          nodeIds: canonicalNodeIds(<String>[operation.id]),
          payloadSubset: canonicalPayloadSubset(<String, Object?>{
            'tool': 'line',
            'color': operation.color.toARGB32(),
            'thickness': operation.thickness,
          }),
        ),
      );
      return;
    }
    if (operation is EraseNodesOp) {
      _controller.draw.writeEraseNodes(operation.ids);
      _events.add(
        NormalizedParityEvent(
          type: 'draw.erase',
          nodeIds: canonicalNodeIds(operation.ids),
        ),
      );
      return;
    }
    if (operation is SetGridEnabledOp) {
      _controller.write<void>((writer) {
        writer.writeGridEnable(operation.value);
      });
      return;
    }
    if (operation is SetGridCellSizeOp) {
      _controller.write<void>((writer) {
        writer.writeGridCellSize(operation.value);
      });
      return;
    }
    if (operation is ReplaceSceneOp) {
      _controller.writeReplaceScene(v2.decodeScene(operation.sceneJson));
      return;
    }
    throw UnsupportedError(
      'Unsupported harness operation for v2: ${operation.runtimeType}',
    );
  }

  @override
  HarnessRunResult result() {
    return HarnessRunResult(
      sceneJsonCanonical: canonicalizeJsonLike(
        v2.encodeScene(_controller.snapshot),
      ),
      selectedNodeIds: canonicalNodeIds(_controller.selectedNodeIds),
      events: _events,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
  }

  static Transform2D _translation(Offset position) {
    return Transform2D(
      a: 1,
      b: 0,
      c: 0,
      d: 1,
      tx: position.dx,
      ty: position.dy,
    );
  }

  static v2.SceneSnapshot _defaultSnapshot() {
    return v2.SceneSnapshot(
      layers: <v2.LayerSnapshot>[
        v2.LayerSnapshot(isBackground: true),
        v2.LayerSnapshot(),
      ],
      background: v2.BackgroundSnapshot(
        color: v1.SceneDefaults.backgroundColors.first,
        grid: v2.GridSnapshot(
          isEnabled: false,
          cellSize: v1.SceneDefaults.gridSizes.first,
          color: v1.SceneDefaults.gridColor,
        ),
      ),
      palette: v2.ScenePaletteSnapshot(
        penColors: v1.SceneDefaults.penColors,
        backgroundColors: v1.SceneDefaults.backgroundColors,
        gridSizes: v1.SceneDefaults.gridSizes,
      ),
    );
  }

  static v2.NodePatch _buildCommonPatch({
    required String id,
    required HarnessNodeKind kind,
    Transform2D? transform,
    double? opacity,
  }) {
    final common = v2.CommonNodePatch(
      transform: transform == null
          ? const v2.PatchField<Transform2D>.absent()
          : v2.PatchField<Transform2D>.value(transform),
      opacity: opacity == null
          ? const v2.PatchField<double>.absent()
          : v2.PatchField<double>.value(opacity),
    );

    switch (kind) {
      case HarnessNodeKind.rect:
        return v2.RectNodePatch(id: id, common: common);
      case HarnessNodeKind.text:
        return v2.TextNodePatch(id: id, common: common);
      case HarnessNodeKind.stroke:
        return v2.StrokeNodePatch(id: id, common: common);
      case HarnessNodeKind.line:
        return v2.LineNodePatch(id: id, common: common);
    }
  }
}
