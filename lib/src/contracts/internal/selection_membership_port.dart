import '../public/canvas_ids.dart';

abstract interface class SelectionMembershipPort {
  Set<CanvasElementId> normalizeSelection(Iterable<CanvasElementId> ids);
  Set<CanvasElementId> selectAllElementIds({required bool onlySelectable});
}
