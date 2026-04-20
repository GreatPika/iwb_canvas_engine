part of 'mutation_boundary_rules.dart';

Future<GuardrailViolation?> _checkSceneViewInteractiveBoundary(
  GuardrailContext context,
) async {
  final file = _interactiveArchitectureFile(
    context,
    '../view/scene_view_interactive.dart',
  );
  final filePath = _repoRelPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  final source = file.readAsStringSync();
  final resolved = await _resolveInteractiveUnitOrFail(
    context: context,
    file: file,
    filePath: filePath,
  );
  final interactiveClass = _findClassByName(
    resolved.unit.declarations,
    'SceneViewInteractive',
  );
  final buildMethod = interactiveClass == null
      ? null
      : _findMethodByName(interactiveClass.members, 'build');
  final controllerFilePath = _repoRelPath(
    context,
    _interactiveArchitectureFile(context, 'scene_controller.dart'),
  );
  final runtimeHostFilePath = _repoRelPath(
    context,
    _interactiveArchitectureFile(
      context,
      '../view/scene_view_runtime_host.dart',
    ),
  );
  if (!_hasImport(parsed, '../interactive/scene_controller.dart') ||
      !_hasImport(parsed, 'scene_view_runtime_host.dart') ||
      _hasImport(parsed, 'scene_view_render_surface.dart') ||
      interactiveClass == null ||
      buildMethod == null ||
      !_classHasFieldTypeFromAllowedFiles(
        interactiveClass,
        context: context,
        typeName: 'SceneController',
        allowedFilePaths: <String>{controllerFilePath},
      ) ||
      !_methodCreatesOwnedType(
        buildMethod,
        context: context,
        filePath: runtimeHostFilePath,
        typeName: 'SceneViewRuntimeHost',
      ) ||
      !_methodCreatesOwnedTypeWithNamedArgInvokingOwnedTopLevelFunction(
        buildMethod,
        ownerClass: interactiveClass,
        context: context,
        typeFilePath: runtimeHostFilePath,
        typeName: 'SceneViewRuntimeHost',
        argName: 'runtime',
        functionFilePath: controllerFilePath,
        functionName: 'sceneControllerViewRuntimeOf',
        functionArgSegments: const <String>['controller'],
      ) ||
      _methodCreatesTypeNamed(buildMethod, typeName: 'Listener') ||
      RegExp(r'(?<![A-Za-z0-9_])Listener\s*\(').hasMatch(source)) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: SceneViewInteractive must remain a '
          'thin public shell over SceneViewRuntimeHost.',
    );
  }
  return null;
}

Future<GuardrailViolation?> _checkRenderSurfaceBoundary(
  GuardrailContext context,
) async {
  final file = _interactiveArchitectureFile(
    context,
    '../view/scene_view_render_surface.dart',
  );
  final filePath = _repoRelPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  final resolved = await _resolveInteractiveUnitOrFail(
    context: context,
    file: file,
    filePath: filePath,
  );
  final widgetClass = _findClassByName(
    resolved.unit.declarations,
    'SceneViewRenderSurface',
  );
  final stateClass = _findClassByName(
    resolved.unit.declarations,
    'SceneViewRenderSurfaceState',
  );
  final initState = stateClass == null
      ? null
      : _findMethodByName(stateClass.members, 'initState');
  final didUpdateWidget = stateClass == null
      ? null
      : _findMethodByName(stateClass.members, 'didUpdateWidget');
  final disposeMethod = stateClass == null
      ? null
      : _findMethodByName(stateClass.members, 'dispose');
  final renderStateFilePaths = <String>{
    _repoRelPath(
      context,
      _interactiveArchitectureFile(
        context,
        '../contract/scene_view_render_state.dart',
      ),
    ),
    _repoRelPath(
      context,
      _interactiveArchitectureFile(
        context,
        '../contract/scene_view_runtime.dart',
      ),
    ),
  };
  final controllerFilePath = _repoRelPath(
    context,
    _interactiveArchitectureFile(context, 'scene_controller.dart'),
  );
  if (!(_hasImport(parsed, '../contract/scene_view_render_state.dart') ||
          _hasImport(parsed, '../contract/scene_view_runtime.dart')) ||
      widgetClass == null ||
      stateClass == null ||
      !_classHasOnlyUnnamedConstructor(widgetClass) ||
      _hasForbiddenImports(parsed, <String>{
        '../interactive/scene_controller.dart',
        '../controller/scene_store_controller.dart',
      }) ||
      _classHasFieldTypeFromAllowedFiles(
        widgetClass,
        context: context,
        typeName: 'SceneController',
        allowedFilePaths: <String>{controllerFilePath},
      ) ||
      _constructorHasParameterTypeFromAllowedFiles(
        widgetClass,
        context: context,
        parameterName: 'controller',
        typeName: 'SceneController',
        allowedFilePaths: <String>{controllerFilePath},
      ) ||
      !_classHasFieldTypeFromAllowedFiles(
        widgetClass,
        context: context,
        typeName: 'SceneViewRenderState',
        allowedFilePaths: renderStateFilePaths,
      ) ||
      !_constructorHasParameterTypeFromAllowedFiles(
        widgetClass,
        context: context,
        parameterName: 'renderState',
        typeName: 'SceneViewRenderState',
        allowedFilePaths: renderStateFilePaths,
      ) ||
      initState == null ||
      didUpdateWidget == null ||
      disposeMethod == null ||
      !_methodInvokesMethodOnQualifiedTarget(
        initState,
        targetSegments: const <String>['widget', '_renderState'],
        methodName: 'addListener',
      ) ||
      !_methodInvokesMethodOnQualifiedTarget(
        didUpdateWidget,
        targetSegments: const <String>['oldWidget', '_renderState'],
        methodName: 'removeListener',
      ) ||
      !_methodInvokesMethodOnQualifiedTarget(
        didUpdateWidget,
        targetSegments: const <String>['widget', '_renderState'],
        methodName: 'addListener',
      ) ||
      !_methodInvokesMethodOnQualifiedTarget(
        disposeMethod,
        targetSegments: const <String>['widget', '_renderState'],
        methodName: 'removeListener',
      )) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: SceneViewRenderSurface must remain a '
          'render-state-only view surface.',
    );
  }
  return null;
}
