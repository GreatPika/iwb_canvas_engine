import '../codec/schema_v1_decoder.dart';
import 'canvas_document.dart';

const int canvasSchemaVersionWrite = 1;
const Set<int> canvasSchemaVersionsRead = {1};

Map<String, Object?> encodeCanvasDocument(CanvasDocument document) =>
    throw UnimplementedError();

String encodeCanvasDocumentToJson(CanvasDocument document) =>
    throw UnimplementedError();

CanvasDocument decodeCanvasDocument(Map<String, Object?> json) =>
    decodeSchemaV1Document(json);

CanvasDocument decodeCanvasDocumentFromJson(String json) =>
    decodeSchemaV1DocumentFromJson(json);
