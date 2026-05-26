import '../api/canvas_errors.dart';
import '../diagnostics/diagnostics_hub.dart';
import 'schema_v1_diagnostics.dart';

void validateSchemaV1Root(
  Map<String, Object?> json, {
  DiagnosticsHub? diagnostics,
}) {
  final version = json['schemaVersion'];
  if (version is! int || version != 1) {
    throw recordSchemaV1FailureDiagnostic(
      diagnostics,
      CanvasDataException(
        code: version == null
            ? CanvasDataErrorCode.missingField
            : CanvasDataErrorCode.unsupportedSchemaVersion,
        message: 'schemaVersion must be 1.',
        path: r'$.schemaVersion',
        details: {'actual': version},
      ),
    );
  }
}
