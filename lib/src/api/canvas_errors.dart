enum CanvasDataErrorCode { invalidDocument, unsupportedVersion }

final class CanvasDataException implements Exception {
  const CanvasDataException(this.code, this.message);

  final CanvasDataErrorCode code;
  final String message;
}
