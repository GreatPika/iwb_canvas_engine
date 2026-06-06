import '../public/canvas_ids.dart';

final class PreparedSelectionEffect {
  PreparedSelectionEffect(Iterable<CanvasElementId> elementIds)
    : elementIds = Set.unmodifiable(elementIds);

  final Set<CanvasElementId> elementIds;
}
