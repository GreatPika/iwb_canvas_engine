import '../contracts/public/canvas_ids.dart';

/// The existing named, last, then default destination policy for content adds.
///
/// Selection is deliberately separate from installing a missing layer so
/// callers can retain its result without mutating committed or edit-local
/// structure.
final class ContentLayerDestination {
  const ContentLayerDestination._(this.layerId, {required this.exists});

  /// Selects a destination from current placement facts without mutating them.
  factory ContentLayerDestination.resolve({
    required bool requestedLayerExists,
    CanvasLayerId? requestedLayerId,
    CanvasLayerId? lastLayerId,
  }) {
    if (requestedLayerId != null) {
      return ContentLayerDestination._(
        requestedLayerId,
        exists: requestedLayerExists,
      );
    }
    if (lastLayerId != null) {
      return ContentLayerDestination._(lastLayerId, exists: true);
    }
    return ContentLayerDestination._(
      CanvasLayerId('default-layer'),
      exists: false,
    );
  }

  final CanvasLayerId layerId;
  final bool exists;
}
