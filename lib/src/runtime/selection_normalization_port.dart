import '../api/canvas_ids.dart';

abstract interface class SelectionNormalizationPort {
  Set<CanvasElementId> normalizeSelection(Iterable<CanvasElementId> ids);
  Set<CanvasElementId> allSelectableElementIds({required bool onlySelectable});
}
