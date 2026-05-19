import 'canvas_document.dart';

const int canvasSchemaVersionWrite = 1;
const Set<int> canvasSchemaVersionsRead = {1};

Map<String, Object?> encodeCanvasDocument(CanvasDocument document) =>
    throw UnimplementedError();

String encodeCanvasDocumentToJson(CanvasDocument document) =>
    throw UnimplementedError();

CanvasDocument decodeCanvasDocument(Map<String, Object?> json) =>
    throw UnimplementedError();

CanvasDocument decodeCanvasDocumentFromJson(String json) =>
    throw UnimplementedError();
