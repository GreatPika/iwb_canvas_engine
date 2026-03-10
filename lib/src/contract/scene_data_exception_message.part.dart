part of 'scene_data_exception.dart';

String _deriveSceneDataMessage({
  required SceneDataErrorCode code,
  required String? path,
  required Map<String, Object?> details,
}) {
  final templateMessage = _deriveSceneDataTemplateMessage(
    template: details['template'],
    path: path,
    details: details,
  );
  if (templateMessage != null) {
    return templateMessage;
  }
  return _deriveSceneDataFallbackMessage(code: code, path: path);
}

String? _deriveSceneDataTemplateMessage({
  required Object? template,
  required String? path,
  required Map<String, Object?> details,
}) {
  if (template is! String) {
    return null;
  }
  return _deriveSceneDataJsonTemplateMessage(
        template: template,
        details: details,
      ) ??
      _deriveSceneDataFieldTemplateMessage(
        template: template,
        path: path,
        details: details,
      ) ??
      _deriveSceneDataDuplicateTemplateMessage(
        template: template,
        path: path,
      ) ??
      _deriveSceneDataLimitTemplateMessage(
        template: template,
        path: path,
        details: details,
      );
}

String? _deriveSceneDataJsonTemplateMessage({
  required String template,
  required Map<String, Object?> details,
}) {
  return switch (template) {
    'rootObject' => 'Root JSON must be an object.',
    'invalidJsonPayload' => 'Invalid scene JSON payload.',
    'jsonPayloadTooLarge' =>
      'Scene JSON payload must be <= ${details['maxLength'] ?? '?'} characters.',
    _ => null,
  };
}

String? _deriveSceneDataFieldTemplateMessage({
  required String template,
  required String? path,
  required Map<String, Object?> details,
}) {
  final pathLabel = _sceneDataPathLabel(path);
  final fieldName = details['fieldName'] ?? pathLabel;
  return _deriveSceneDataFieldShapeTemplateMessage(
        template: template,
        pathLabel: pathLabel,
        fieldName: fieldName,
        details: details,
      ) ??
      _deriveSceneDataFieldRangeTemplateMessage(
        template: template,
        pathLabel: pathLabel,
        details: details,
      );
}

String? _deriveSceneDataFieldShapeTemplateMessage({
  required String template,
  required String pathLabel,
  required Object fieldName,
  required Map<String, Object?> details,
}) {
  return switch (template) {
    'missingField' => 'Missing required field $pathLabel.',
    'fieldType' =>
      'Field $fieldName must be a ${details['expected'] ?? 'valid value'}.',
    'fieldMustNotBeEmpty' => 'Field $pathLabel must not be empty.',
    'fieldMaxLength' =>
      'Field $pathLabel length must be <= ${details['maxLength'] ?? '?'} characters.',
    'fieldMustBeFinite' => 'Field $fieldName must be finite.',
    'fieldMustBeInt' => 'Field $fieldName must be an int.',
    _ => null,
  };
}

String? _deriveSceneDataFieldRangeTemplateMessage({
  required String template,
  required String pathLabel,
  required Map<String, Object?> details,
}) {
  return switch (template) {
    'fieldMustBeGreaterThan' =>
      'Field $pathLabel must be > ${details['limit'] ?? '?'}.',
    'fieldMustBeAtLeast' =>
      'Field $pathLabel must be >= ${details['limit'] ?? '?'}.',
    'outOfRange' =>
      'Field $pathLabel must be within '
          '[${details['min'] ?? '?'}, ${details['max'] ?? '?'}].',
    _ => null,
  };
}

String? _deriveSceneDataDuplicateTemplateMessage({
  required String template,
  required String? path,
}) {
  return switch (template) {
    'duplicateNodeId' => 'Must be unique across scene layers.',
    'duplicateLayerId' =>
      'Field ${_sceneDataPathLabel(path)} must be unique across content layers.',
    _ => null,
  };
}

String? _deriveSceneDataLimitTemplateMessage({
  required String template,
  required String? path,
  required Map<String, Object?> details,
}) {
  return switch (template) {
    'maxItems' =>
      'Field ${_sceneDataPathLabel(path)} must contain at most '
          "${details['maxItems'] ?? '?'} items.",
    'maxNodes' =>
      'Scene must contain at most ${details['maxNodes'] ?? '?'} nodes.',
    _ => null,
  };
}

String _deriveSceneDataFallbackMessage({
  required SceneDataErrorCode code,
  required String? path,
}) {
  if (path != null) {
    return 'Field $path is invalid.';
  }
  return switch (code) {
    SceneDataErrorCode.invalidJson => 'Invalid scene JSON payload.',
    SceneDataErrorCode.unsupportedSchemaVersion =>
      'Unsupported scene schema version.',
    SceneDataErrorCode.missingField => 'Missing required field.',
    SceneDataErrorCode.invalidFieldType => 'Field has an invalid type.',
    SceneDataErrorCode.invalidValue => 'Field value is invalid.',
    SceneDataErrorCode.duplicateNodeId => 'Duplicate node id is not allowed.',
    SceneDataErrorCode.duplicateLayerId =>
      'Duplicate content layer id is not allowed.',
    SceneDataErrorCode.outOfRange => 'Field value is out of range.',
  };
}

String _sceneDataPathLabel(String? path) => path ?? '<unknown>';
