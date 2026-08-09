import 'canvas_error_details_sanitizer.dart';

/// Public API v1 declaration for [CanvasDataErrorCode].
enum CanvasDataErrorCode {
  invalidJson,
  invalidVectorData,
  unsupportedSchemaVersion,
  missingField,
  invalidFieldType,
  forbiddenField,
  fieldMustNotBeEmpty,
  fieldMaxLength,
  fieldMustBeFinite,
  fieldMustBePositive,
  fieldMustBeNonNegative,
  fieldMustBeInRange,
  fieldMustBeInvertible,
  duplicateElementId,
  duplicateLayerId,
  duplicateResourceId,
  missingResourceReference,
  resourceKindMismatch,
  maxItems,
  maxNodes,
  maxRawJsonLength,
  invalidMetadata,
}

/// Public API v1 declaration for [CanvasDataException].
final class CanvasDataException implements Exception {
  factory CanvasDataException({
    required CanvasDataErrorCode code,
    required String message,
    String? path,
    Map<String, Object?> details = const {},
  }) {
    return CanvasDataException._(
      code: code,
      message: message,
      path: path,
      details: sanitizeCanvasErrorDetails(details),
    );
  }

  const CanvasDataException._({
    required this.code,
    required this.message,
    required this.path,
    required this.details,
  });

  final CanvasDataErrorCode code;
  final String message;
  final String? path;
  final Map<String, Object?> details;
}
