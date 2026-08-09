import 'dart:ui' as ui show Picture, Size;

import 'package:flutter/foundation.dart' show internal;

/// An application-owned vector Picture prepared for synchronous use.
final class CanvasPreparedVector {
  CanvasPreparedVector._({
    required ui.Picture picture,
    required this.intrinsicSize,
  }) : _picture = picture;

  ui.Picture? _picture;

  /// The intrinsic vector extent captured during preparation.
  final ui.Size intrinsicSize;

  /// Releases the owned Picture once; later calls do nothing.
  void dispose() {
    final picture = _picture;
    if (picture == null) {
      return;
    }
    _picture = null;
    picture.dispose();
  }
}

@internal
CanvasPreparedVector createCanvasPreparedVector({
  required ui.Picture picture,
  required ui.Size intrinsicSize,
}) {
  return CanvasPreparedVector._(picture: picture, intrinsicSize: intrinsicSize);
}

@internal
ui.Picture liveCanvasPreparedVectorPicture(CanvasPreparedVector prepared) {
  final picture = prepared._picture;
  if (picture == null) {
    throw StateError('The prepared vector has been disposed.');
  }
  return picture;
}
