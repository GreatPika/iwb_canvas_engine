import '../../../../core/nodes.dart';
import '../../../../core/scene.dart';
import '../../../model/document.dart';

class V2SelectionNormalizationResult {
  const V2SelectionNormalizationResult({
    required this.normalized,
    required this.normalizedChanged,
  });

  final Set<NodeId> normalized;
  final bool normalizedChanged;
}

class V2SelectionSlice {
  V2SelectionNormalizationResult writeNormalizeSelection({
    required Set<NodeId> rawSelection,
    required Scene scene,
  }) {
    final normalized = txnNormalizeSelection(
      rawSelection: rawSelection,
      scene: scene,
    );
    final changed =
        normalized.length != rawSelection.length ||
        !normalized.containsAll(rawSelection);
    return V2SelectionNormalizationResult(
      normalized: normalized,
      normalizedChanged: changed,
    );
  }
}
