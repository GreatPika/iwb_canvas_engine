import '../contracts/internal/frame_facts_port.dart';

final class SpatialCandidateHandleMapper {
  FrameFactsPort? _frame;
  int _structuralRevision = 0;

  void bind(FrameFactsPort frame, int structuralRevision) {
    _frame = frame;
    _structuralRevision = structuralRevision;
  }

  FrameElementHandle call(FrameElementHandle handle) {
    final current = _frame?.elementHandleForId(_structuralRevision, handle.id);
    if (current == null) {
      throw StateError('missing spatial query handle: ${handle.id.value}');
    }
    if (handle.structuralRevision == _structuralRevision) {
      if (handle.generation != current.generation ||
          handle.orderToken != current.orderToken) {
        throw StateError('stale spatial query handle: ${handle.id.value}');
      }

      return handle;
    }

    return current;
  }
}
