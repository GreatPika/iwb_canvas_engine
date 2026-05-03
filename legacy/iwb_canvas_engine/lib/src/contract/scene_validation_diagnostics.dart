import 'scene_data_exception.dart';

/// Internal typed-validation diagnostics mapped onto public scene data errors.
class SceneDataDiagnosticDescriptor {
  SceneDataDiagnosticDescriptor._({
    required this.code,
    required this.template,
    this.args = const <String, Object?>{},
  });

  factory SceneDataDiagnosticDescriptor.maxItems({required int maxItems}) {
    return SceneDataDiagnosticDescriptor._(
      code: SceneDataErrorCode.invalidValue,
      template: 'maxItems',
      args: <String, Object?>{'maxItems': maxItems},
    );
  }

  factory SceneDataDiagnosticDescriptor.maxPoints({required int maxPoints}) {
    return SceneDataDiagnosticDescriptor._(
      code: SceneDataErrorCode.invalidValue,
      template: 'maxPoints',
      args: <String, Object?>{'maxPoints': maxPoints},
    );
  }

  factory SceneDataDiagnosticDescriptor.fieldMustBeFinite({String? fieldName}) {
    return SceneDataDiagnosticDescriptor._(
      code: SceneDataErrorCode.invalidValue,
      template: 'fieldMustBeFinite',
      args: fieldName == null
          ? const <String, Object?>{}
          : <String, Object?>{'fieldName': fieldName},
    );
  }

  factory SceneDataDiagnosticDescriptor.fieldMustNotBeEmpty() {
    return SceneDataDiagnosticDescriptor._(
      code: SceneDataErrorCode.invalidValue,
      template: 'fieldMustNotBeEmpty',
    );
  }

  factory SceneDataDiagnosticDescriptor.fieldMaxLength({
    required int maxLength,
  }) {
    return SceneDataDiagnosticDescriptor._(
      code: SceneDataErrorCode.invalidValue,
      template: 'fieldMaxLength',
      args: <String, Object?>{'maxLength': maxLength},
    );
  }

  factory SceneDataDiagnosticDescriptor.fieldMustBeSafeInteger({
    required int limit,
  }) {
    return SceneDataDiagnosticDescriptor._(
      code: SceneDataErrorCode.invalidValue,
      template: 'fieldMustBeSafeInteger',
      args: <String, Object?>{'limit': limit},
    );
  }

  factory SceneDataDiagnosticDescriptor.fieldMustBeGreaterThan({
    required num limit,
  }) {
    return SceneDataDiagnosticDescriptor._(
      code: SceneDataErrorCode.invalidValue,
      template: 'fieldMustBeGreaterThan',
      args: <String, Object?>{'limit': limit},
    );
  }

  factory SceneDataDiagnosticDescriptor.fieldMustBeAtLeast({
    required num limit,
  }) {
    return SceneDataDiagnosticDescriptor._(
      code: SceneDataErrorCode.invalidValue,
      template: 'fieldMustBeAtLeast',
      args: <String, Object?>{'limit': limit},
    );
  }

  factory SceneDataDiagnosticDescriptor.fieldMustBeAtLeastWhenFlagEnabled({
    required num limit,
    required String enabledField,
  }) {
    return SceneDataDiagnosticDescriptor._(
      code: SceneDataErrorCode.invalidValue,
      template: 'fieldMustBeAtLeastWhenFlagEnabled',
      args: <String, Object?>{'limit': limit, 'enabledField': enabledField},
    );
  }

  factory SceneDataDiagnosticDescriptor.outOfRange({
    required num min,
    required num max,
  }) {
    return SceneDataDiagnosticDescriptor._(
      code: SceneDataErrorCode.outOfRange,
      template: 'outOfRange',
      args: <String, Object?>{'min': min, 'max': max},
    );
  }

  factory SceneDataDiagnosticDescriptor.fieldMustBeValidSvgPathData() {
    return SceneDataDiagnosticDescriptor._(
      code: SceneDataErrorCode.invalidValue,
      template: 'fieldMustBeValidSvgPathData',
    );
  }

  factory SceneDataDiagnosticDescriptor.fieldMustBeInvertible() {
    return SceneDataDiagnosticDescriptor._(
      code: SceneDataErrorCode.invalidValue,
      template: 'fieldMustBeInvertible',
    );
  }

  final SceneDataErrorCode code;
  final String template;
  final Map<String, Object?> args;

  SceneDataException toException({required String path, Object? source}) {
    return SceneDataException.boundary(
      code: code,
      path: path,
      details: _detailsForPath(path),
      source: source,
    );
  }

  Map<String, Object?> _detailsForPath(String path) {
    final details = <String, Object?>{'template': template, ...args};
    if (template == 'fieldMustBeFinite' && !details.containsKey('fieldName')) {
      details['fieldName'] = _sceneDataPathTail(path) ?? path;
    }
    return details;
  }
}

/// Internal argument error carrying a structured validation descriptor.
class SceneValidationArgumentError extends ArgumentError {
  SceneValidationArgumentError.value(
    Object? super.invalidValue,
    super.name,
    Object? super.message, {
    this.diagnostic,
  }) : super.value();

  final SceneDataDiagnosticDescriptor? diagnostic;
}

String? _sceneDataPathTail(String path) {
  final separator = path.lastIndexOf('.');
  if (separator >= 0 && separator + 1 < path.length) {
    return path.substring(separator + 1);
  }
  final bracket = path.lastIndexOf('[');
  if (bracket > 0) {
    return path.substring(0, bracket);
  }
  return null;
}
