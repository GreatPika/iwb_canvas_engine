part of 'mutation_boundary_rules.dart';

GuardrailViolation? _checkSceneViewRuntimeContract(GuardrailContext context) {
  final file = _interactiveArchitectureFile(
    context,
    '../contract/scene_view_runtime.dart',
  );
  final filePath = _repoRelPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  final source = file.readAsStringSync();
  final createPointerSession = _findClassMethodDeclaration(
    parsed,
    'SceneViewRuntime',
    'createPointerSession',
  );
  final detachMethod = _findClassMethodDeclaration(
    parsed,
    'SceneViewPointerSession',
    'detach',
  );
  if (!_hasClassLikeDeclaration(
        parsed,
        'SceneViewRuntime',
        requireInterface: true,
      ) ||
      !_hasClassLikeDeclaration(
        parsed,
        'SceneViewPointerSession',
        requireInterface: true,
      ) ||
      createPointerSession == null ||
      createPointerSession.isGetter ||
      !_methodHasReturnTypeName(
        createPointerSession,
        typeName: 'SceneViewPointerSession',
      ) ||
      detachMethod == null ||
      detachMethod.isGetter ||
      !_methodReturnsVoid(detachMethod) ||
      !_methodHasNoParameters(detachMethod) ||
      !RegExp(
        r'SceneViewPointerSession\s+createPointerSession\s*\(',
      ).hasMatch(source) ||
      !RegExp(r'void\s+detach\s*\(').hasMatch(source) ||
      _classOwnsMethod(parsed, 'SceneViewRuntime', 'handleControllerChanged') ||
      _classOwnsMethod(parsed, 'SceneViewRuntime', 'updateController')) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: SceneViewRuntime must remain the '
          'single internal runtime/session contract for view core.',
    );
  }
  return null;
}
