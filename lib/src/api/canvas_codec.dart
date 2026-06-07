import 'dart:convert';

import '../codec/schema_v1_encoder.dart';
import 'canvas_document.dart';

/// Public API v1 declaration for [canvasSchemaVersionWrite].
const int canvasSchemaVersionWrite = 1;

/// Public API v1 declaration for [canvasSchemaVersionsRead].
const Set<int> canvasSchemaVersionsRead = {1};

/// Public API v1 declaration for [encodeCanvasDocument].
Map<String, Object?> encodeCanvasDocument(CanvasDocument document) =>
    encodeSchemaV1Document(document);

/// Public API v1 declaration for [encodeCanvasDocumentToJson].
String encodeCanvasDocumentToJson(CanvasDocument document) =>
    jsonEncode(encodeCanvasDocument(document));
