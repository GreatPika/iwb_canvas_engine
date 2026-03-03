import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

// INV:INV-G-NODEID-UNIQUE
// INV:INV-ENG-WRITE-NUMERIC-GUARDS
void assertSceneInvariants(
  SceneSnapshot snapshot, {
  Set<NodeId> selectedNodeIds = const <NodeId>{},
}) {
  expect(_isFiniteOffset(snapshot.camera.offset), isTrue);

  final contentNodeIds = <NodeId>{};
  final allNodeIds = <NodeId>{};
  var contentNodeCount = 0;
  for (var layerIndex = 0; layerIndex < snapshot.layers.length; layerIndex++) {
    final layer = snapshot.layers[layerIndex];
    for (final node in layer.nodes) {
      contentNodeCount = contentNodeCount + 1;
      expect(allNodeIds.add(node.id), isTrue);
      contentNodeIds.add(node.id);
      _expectNodeFinite(node);
    }
  }

  // Snapshot is typed (`backgroundLayer` + content `layers`), so there is no
  // standalone `layerIndex` field to validate here. Instead we assert that
  // indexed content-layer traversal is complete and unique.
  final flattenedContentNodeCount = snapshot.layers
      .expand((layer) => layer.nodes)
      .length;
  expect(flattenedContentNodeCount, contentNodeCount);
  expect(contentNodeIds.length, contentNodeCount);

  for (final node in snapshot.backgroundLayer.nodes) {
    expect(contentNodeIds.contains(node.id), isFalse);
    expect(allNodeIds.add(node.id), isTrue);
    _expectNodeFinite(node);
  }

  for (final selectedId in selectedNodeIds) {
    expect(contentNodeIds.contains(selectedId), isTrue);
    final node = _findContentNodeById(snapshot: snapshot, id: selectedId);
    expect(node, isNotNull);
    expect(node!.isVisible, isTrue);
  }
}

NodeSnapshot? _findContentNodeById({
  required SceneSnapshot snapshot,
  required NodeId id,
}) {
  for (final layer in snapshot.layers) {
    for (final node in layer.nodes) {
      if (node.id == id) {
        return node;
      }
    }
  }
  return null;
}

void _expectNodeFinite(NodeSnapshot node) {
  expect(node.transform.isFinite, isTrue);
  expect(node.opacity.isFinite, isTrue);
  expect(node.hitPadding.isFinite, isTrue);

  switch (node) {
    case ImageNodeSnapshot image:
      _expectFiniteSize(image.size);
      if (image.naturalSize != null) {
        _expectFiniteSize(image.naturalSize!);
      }
    case TextNodeSnapshot text:
      _expectFiniteSize(text.size);
      expect(text.fontSize.isFinite, isTrue);
      if (text.maxWidth != null) {
        expect(text.maxWidth!.isFinite, isTrue);
      }
      if (text.lineHeight != null) {
        expect(text.lineHeight!.isFinite, isTrue);
      }
    case StrokeNodeSnapshot stroke:
      expect(stroke.thickness.isFinite, isTrue);
      for (final point in stroke.points) {
        expect(_isFiniteOffset(point), isTrue);
      }
    case LineNodeSnapshot line:
      expect(_isFiniteOffset(line.start), isTrue);
      expect(_isFiniteOffset(line.end), isTrue);
      expect(line.thickness.isFinite, isTrue);
    case RectNodeSnapshot rect:
      _expectFiniteSize(rect.size);
      expect(rect.strokeWidth.isFinite, isTrue);
    case PathNodeSnapshot path:
      expect(path.strokeWidth.isFinite, isTrue);
  }
}

void _expectFiniteSize(Size size) {
  expect(size.width.isFinite, isTrue);
  expect(size.height.isFinite, isTrue);
}

bool _isFiniteOffset(Offset offset) {
  return offset.dx.isFinite && offset.dy.isFinite;
}
