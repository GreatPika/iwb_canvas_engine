import 'canvas_document.dart';

final class CanvasRuntime {
  const CanvasRuntime();
}

final class CanvasRuntimeConfig {
  const CanvasRuntimeConfig();
}

Map<String, Object?> encodeCanvasDocument(CanvasDocument _) {
  return const <String, Object?>{};
}

String encodeCanvasDocumentToJson(CanvasDocument _) {
  return '{}';
}

CanvasDocument decodeCanvasDocument(Map<String, Object?> _) {
  return const CanvasDocument();
}

CanvasDocument decodeCanvasDocumentFromJson(String _) {
  return const CanvasDocument();
}

const int canvasSchemaVersionWrite = 1;

const List<int> canvasSchemaVersionsRead = <int>[1];
