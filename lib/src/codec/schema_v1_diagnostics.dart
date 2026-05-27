import '../contracts/public/canvas_errors.dart';
import '../diagnostics/diagnostics_hub.dart';

CanvasDataException recordSchemaV1FailureDiagnostic(
  DiagnosticsHub? hub,
  CanvasDataException exception,
) => hub.recordSchemaV1FailureDiagnostic(exception);

extension _SchemaV1DiagnosticsHub on DiagnosticsHub? {
  CanvasDataException recordSchemaV1FailureDiagnostic(
    CanvasDataException exception,
  ) {
    final hub = this;
    if (hub == null) {
      return exception;
    }

    hub.record(
      DiagnosticEvent(
        code: exception.code,
        severity: DiagnosticSeverity.error,
        source: DiagnosticSource.codec,
        path: exception.path,
        details: () => {
          'message': exception.message,
          if (exception.details.isNotEmpty) 'details': exception.details,
        },
      ),
    );

    return exception;
  }
}
