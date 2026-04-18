import '../../contract/snapshot.dart';

typedef SceneControllerSelectedPaintOrderResolver =
    ({int layerIndex, int nodeIndex})? Function(NodeId nodeId);

final class SceneControllerSelectedPaintOrderToken {
  const SceneControllerSelectedPaintOrderToken({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;

  @override
  bool operator ==(Object other) {
    return other is SceneControllerSelectedPaintOrderToken &&
        other.nodeId == nodeId &&
        other.layerIndex == layerIndex &&
        other.nodeIndex == nodeIndex;
  }

  @override
  int get hashCode => Object.hash(nodeId, layerIndex, nodeIndex);
}

final class SceneControllerSelectedPaintOrderCache {
  List<SceneControllerSelectedPaintOrderToken> _orderedTokens =
      const <SceneControllerSelectedPaintOrderToken>[];
  int _debugRebuildCount = 0;

  int get debugRebuildCount => _debugRebuildCount;

  List<SceneControllerSelectedPaintOrderToken> orderedSelectedTokens({
    required Set<NodeId> selectedNodeIds,
    required SceneControllerSelectedPaintOrderResolver resolveOrder,
  }) {
    final nextTokens = <SceneControllerSelectedPaintOrderToken>[];
    for (final nodeId in selectedNodeIds) {
      final order = resolveOrder(nodeId);
      if (order == null) {
        continue;
      }
      nextTokens.add(
        SceneControllerSelectedPaintOrderToken(
          nodeId: nodeId,
          layerIndex: order.layerIndex,
          nodeIndex: order.nodeIndex,
        ),
      );
    }
    nextTokens.sort(_compareSelectedPaintOrderTokens);

    if (_sameOrderedTokens(_orderedTokens, nextTokens)) {
      return _orderedTokens;
    }

    _orderedTokens = List<SceneControllerSelectedPaintOrderToken>.unmodifiable(
      nextTokens,
    );
    _debugRebuildCount += 1;
    return _orderedTokens;
  }
}

int _compareSelectedPaintOrderTokens(
  SceneControllerSelectedPaintOrderToken a,
  SceneControllerSelectedPaintOrderToken b,
) {
  final layerOrder = a.layerIndex.compareTo(b.layerIndex);
  if (layerOrder != 0) {
    return layerOrder;
  }
  final nodeOrder = a.nodeIndex.compareTo(b.nodeIndex);
  return nodeOrder != 0 ? nodeOrder : a.nodeId.compareTo(b.nodeId);
}

bool _sameOrderedTokens(
  List<SceneControllerSelectedPaintOrderToken> a,
  List<SceneControllerSelectedPaintOrderToken> b,
) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
