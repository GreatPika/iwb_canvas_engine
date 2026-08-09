import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_resource.dart';

// Both sparse and materialized transactions use these facts to preserve one
// resource-row outcome across their different backing representations.
bool elementReferencesResource(CanvasElement element, CanvasResourceId id) {
  return switch (element) {
    CanvasImageElement(:final resourceId) => resourceId == id,
    CanvasVectorElement(:final resourceId) => resourceId == id,
    _ => false,
  };
}

bool hasSameResourceFacts(CanvasResource left, CanvasResource right) {
  return switch ((left, right)) {
    (
      CanvasImageResource(mimeType: final leftMimeType),
      CanvasImageResource(mimeType: final rightMimeType),
    ) =>
      _haveSameBaseResourceFacts(left, right) && leftMimeType == rightMimeType,
    (CanvasVectorResource(), CanvasVectorResource()) =>
      _haveSameBaseResourceFacts(left, right),
    (CanvasImageResource(), CanvasVectorResource()) ||
    (CanvasVectorResource(), CanvasImageResource()) => false,
  };
}

bool _haveSameBaseResourceFacts(CanvasResource left, CanvasResource right) {
  return left.id == right.id &&
      left.source == right.source &&
      left.contentHash == right.contentHash &&
      left.byteLength == right.byteLength &&
      left.metadata == right.metadata;
}
