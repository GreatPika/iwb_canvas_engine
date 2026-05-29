import '../contracts/internal/frame_facts_port.dart';
import '../contracts/internal/touched_set.dart';
import '../contracts/public/canvas_ids.dart';
import 'geometry_policy.dart';
import 'spatial_entry.dart';

Map<CanvasElementId, SpatialEntry>? spatialEntriesForFrame({
  required FrameFactsPort frame,
  required GeometryPolicy geometryPolicy,
}) {
  final structuralRevision = frame.frameRevisions.structuralRevision;
  final entries = <CanvasElementId, SpatialEntry>{};
  for (final handle in frame.elementHandles(structuralRevision)) {
    final entry = spatialEntryFor(
      frame: frame,
      handle: handle,
      geometryPolicy: geometryPolicy,
    );
    if (entry == null) {
      return null;
    }
    entries[entry.id] = entry;
  }

  return entries;
}

List<SpatialEntry> spatialAdditionsForTouches({
  required FrameFactsPort frame,
  required TouchedSet touchedSet,
  required GeometryPolicy geometryPolicy,
}) {
  final additions = <SpatialEntry>[];
  final structuralRevision = frame.frameRevisions.structuralRevision;
  for (final id in touchedSet.elementIds) {
    if (_isPureRemoval(touchedSet, id)) {
      continue;
    }
    final handle = frame.elementHandleForId(structuralRevision, id);
    if (handle == null) {
      throw StateError('missing spatial handle: ${id.value}');
    }
    final entry = spatialEntryFor(
      frame: frame,
      handle: handle,
      geometryPolicy: geometryPolicy,
    );
    if (entry == null) {
      throw StateError('stale spatial entry: ${id.value}');
    }
    additions.add(entry);
  }

  return additions;
}

bool _isPureRemoval(TouchedSet touchedSet, CanvasElementId id) {
  return touchedSet.removedElementIds.contains(id) &&
      !touchedSet.addedElementIds.contains(id) &&
      !touchedSet.updatedElementIds.contains(id) &&
      !touchedSet.transformedElementIds.contains(id) &&
      !touchedSet.geometryElementIds.contains(id) &&
      !touchedSet.visualElementIds.contains(id);
}
