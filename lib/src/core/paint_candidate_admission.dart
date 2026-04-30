import 'dart:ui';

bool admitsPaintCandidate({
  required Rect queryRect,
  required Rect paintBoundsWorld,
}) {
  return queryRect.overlaps(paintBoundsWorld);
}
