enum SceneValidationPathSurface { snapshot, jsonImport }

String sceneValidationIdentityField(
  SceneValidationPathSurface surface, {
  required String field,
  required String child,
}) {
  return switch (surface) {
    SceneValidationPathSurface.snapshot ||
    SceneValidationPathSurface.jsonImport => '$field.$child',
  };
}

String sceneValidationLineStartField(
  SceneValidationPathSurface surface, {
  required String field,
}) {
  return switch (surface) {
    SceneValidationPathSurface.snapshot => '$field.start',
    SceneValidationPathSurface.jsonImport => '$field.localA',
  };
}

String sceneValidationLineEndField(
  SceneValidationPathSurface surface, {
  required String field,
}) {
  return switch (surface) {
    SceneValidationPathSurface.snapshot => '$field.end',
    SceneValidationPathSurface.jsonImport => '$field.localB',
  };
}

String sceneValidationStrokePointsField(
  SceneValidationPathSurface surface, {
  required String field,
}) {
  return switch (surface) {
    SceneValidationPathSurface.snapshot => '$field.points',
    SceneValidationPathSurface.jsonImport => '$field.localPoints',
  };
}
