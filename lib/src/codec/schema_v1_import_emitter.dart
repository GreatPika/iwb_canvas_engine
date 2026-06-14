// Schema v1 import emitter is the compatibility entry point for import-event
// callers. The canonical schema v1 wire reader lives in schema_v1_reader.dart.

import '../contracts/internal/schema_v1_import_events.dart';
import '../diagnostics/diagnostics_hub.dart';
import 'schema_v1_reader.dart';

void importSchemaV1DocumentFromJson(
  String json,
  SchemaV1ImportSink sink, {
  DiagnosticsHub? diagnostics,
}) {
  readSchemaV1DocumentFromJson(json, sink, diagnostics: diagnostics);
}

void importSchemaV1DocumentFromJsonIntoIsolatedSink(
  String json,
  IsolatedSchemaV1ImportSink sink, {
  DiagnosticsHub? diagnostics,
}) {
  readSchemaV1DocumentFromJsonIntoIsolatedSink(
    json,
    sink,
    diagnostics: diagnostics,
  );
}

void importSchemaV1Document(
  Map<String, Object?> json,
  SchemaV1ImportSink sink, {
  DiagnosticsHub? diagnostics,
}) {
  readSchemaV1Document(json, sink, diagnostics: diagnostics);
}

void importSchemaV1DocumentIntoIsolatedSink(
  Map<String, Object?> json,
  IsolatedSchemaV1ImportSink sink, {
  DiagnosticsHub? diagnostics,
}) {
  readSchemaV1DocumentIntoIsolatedSink(json, sink, diagnostics: diagnostics);
}
