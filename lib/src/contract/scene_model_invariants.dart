import 'scene_contract_limits.dart';

String? sceneStrokePointCountViolationMessage(int pointCount) {
  if (pointCount <= kMaxStrokePointsPerNode) {
    return null;
  }
  return 'must contain at most $kMaxStrokePointsPerNode points.';
}

void validateStrokePointCount(
  int pointCount, {
  required String name,
  Object? source,
}) {
  final message = sceneStrokePointCountViolationMessage(pointCount);
  if (message == null) {
    return;
  }
  throw ArgumentError.value(source ?? pointCount, name, _capitalize(message));
}

String? scenePaletteItemCountViolationMessage(int itemCount) {
  if (itemCount <= kMaxPaletteItems) {
    return null;
  }
  return 'must contain at most $kMaxPaletteItems items.';
}

void validatePaletteItemCount(
  int itemCount, {
  required String name,
  Object? source,
}) {
  final message = scenePaletteItemCountViolationMessage(itemCount);
  if (message == null) {
    return;
  }
  throw ArgumentError.value(source ?? itemCount, name, _capitalize(message));
}

String _capitalize(String message) {
  if (message.isEmpty) {
    return message;
  }
  return '${message[0].toUpperCase()}${message.substring(1)}';
}
