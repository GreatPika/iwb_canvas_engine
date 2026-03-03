import '../../core/nodes.dart';
import '../../core/scene.dart';
import '../../model/document.dart';

class SelectionNormalizationResult {
  const SelectionNormalizationResult({
    required this.normalized,
    required this.normalizedChanged,
  });

  final Set<NodeId> normalized;
  final bool normalizedChanged;
}

class SelectionNormalizer {
  SelectionNormalizationResult writeNormalizeSelection({
    required Set<NodeId> rawSelection,
    required Scene scene,
    Map<NodeId, NodeLocatorEntry>? nodeLocator,
  }) {
    final normalized = txnNormalizeSelection(
      rawSelection: rawSelection,
      scene: scene,
      nodeLocator: nodeLocator,
    );
    final changed =
        normalized.length != rawSelection.length ||
        !normalized.containsAll(rawSelection);
    return SelectionNormalizationResult(
      normalized: normalized,
      normalizedChanged: changed,
    );
  }
}
