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

Future<GuardrailViolation?> _checkRuntimeHostBoundary(
  GuardrailContext context,
) async {
  final file = _interactiveArchitectureFile(
    context,
    '../view/scene_view_runtime_host.dart',
  );
  final filePath = _repoRelPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  final resolved = await _resolveInteractiveUnitOrFail(
    context: context,
    file: file,
    filePath: filePath,
  );
  final hostClass = _findClassByName(
    resolved.unit.declarations,
    '_SceneViewRuntimeHostState',
  );
  final initState = hostClass == null
      ? null
      : _findMethodByName(hostClass.members, 'initState');
  final didUpdateWidget = hostClass == null
      ? null
      : _findMethodByName(hostClass.members, 'didUpdateWidget');
  final buildMethod = hostClass == null
      ? null
      : _findMethodByName(hostClass.members, 'build');
  final createReplacement = hostClass == null
      ? null
      : _findMethodByName(
          hostClass.members,
          '_createReplacementPointerSession',
        );
  final renderSurfaceFilePath = _repoRelPath(
    context,
    _interactiveArchitectureFile(
      context,
      '../view/scene_view_render_surface.dart',
    ),
  );
  final pointerHostFilePath = _repoRelPath(
    context,
    _interactiveArchitectureFile(
      context,
      '../view/scene_view_interactive_pointer_host.dart',
    ),
  );
  final controllerFilePath = _repoRelPath(
    context,
    _interactiveArchitectureFile(context, 'scene_controller.dart'),
  );
  if (hostClass == null ||
      !_hasImport(parsed, '../contract/scene_view_runtime.dart') ||
      !_hasImport(parsed, 'scene_view_interactive_pointer_host.dart') ||
      !_hasImport(parsed, 'scene_view_render_surface.dart') ||
      _hasTopLevelOwner(parsed, 'SceneViewInteractivePointerHost') ||
      _hasTopLevelOwner(parsed, 'SceneViewRenderSurface') ||
      initState == null ||
      didUpdateWidget == null ||
      buildMethod == null ||
      createReplacement == null ||
      _nodeReferencesOwnedElement(
        resolved.unit,
        context: context,
        filePath: controllerFilePath,
        elementName: 'SceneController',
      ) ||
      _classHasFieldTypeFromAllowedFiles(
        hostClass,
        context: context,
        typeName: 'SceneController',
        allowedFilePaths: <String>{controllerFilePath},
      ) ||
      _constructorHasParameterTypeFromAllowedFiles(
        hostClass,
        context: context,
        parameterName: 'controller',
        typeName: 'SceneController',
        allowedFilePaths: <String>{controllerFilePath},
      ) ||
      !_classHasFieldNamed(hostClass, '_pointerHost') ||
      !_classHasFieldNamed(hostClass, '_activeRuntime') ||
      !_methodCreatesOwnedType(
        initState,
        context: context,
        filePath: pointerHostFilePath,
        typeName: 'SceneViewInteractivePointerHost',
      ) ||
      !_methodInvokesOwnedMethod(
        initState,
        context: context,
        filePath: null,
        ownerName: 'SceneViewRuntime',
        methodName: 'createPointerSession',
      ) ||
      !_methodReturnsInterfaceType(
        createReplacement,
        interfaceName: 'SceneViewPointerSession',
      ) ||
      !_methodInvokesOwnedMethod(
        createReplacement,
        context: context,
        filePath: null,
        ownerName: 'SceneViewRuntime',
        methodName: 'createPointerSession',
      ) ||
      !_methodInvokesOwnedMethod(
        didUpdateWidget,
        context: context,
        filePath: filePath,
        ownerName: '_SceneViewRuntimeHostState',
        methodName: '_createReplacementPointerSession',
      ) ||
      !_methodInvokesOwnedMethod(
        didUpdateWidget,
        context: context,
        filePath: pointerHostFilePath,
        ownerName: 'SceneViewInteractivePointerHost',
        methodName: 'replacePointerSession',
      ) ||
      !_methodContainsOrderedStatementsWithForbiddenOutsideSequence(
        didUpdateWidget,
        orderedMatchers: <bool Function(Statement)>[
          (statement) => _statementIsEarlyReturnIfQualifiedEquality(
            statement,
            leftSegments: const <String>['_activeRuntime'],
            rightSegments: const <String>['widget', 'runtime'],
          ),
          (statement) => _statementDeclaresVariableNamedFromOwnedMethodWithArgs(
            statement,
            variableName: 'nextPointerSession',
            context: context,
            filePath: filePath,
            ownerName: '_SceneViewRuntimeHostState',
            methodName: '_createReplacementPointerSession',
            argSegments: <String>['widget', 'runtime'],
          ),
          (statement) => _statementInvokesOwnedMethodWithArgs(
            statement,
            context: context,
            filePath: pointerHostFilePath,
            ownerName: 'SceneViewInteractivePointerHost',
            methodName: 'replacePointerSession',
            argSegments: <String>['nextPointerSession'],
            targetSegments: <String>['_pointerHost'],
          ),
          (statement) => _statementAssignsFieldFromOwnedGetter(
            statement,
            fieldName: '_activeRuntime',
            rhsSegments: <String>['widget', 'runtime'],
          ),
        ],
        forbiddenBeforeCompletion: <bool Function(Statement)>[
          (statement) => _statementInvokesOwnedMethodWithArgs(
            statement,
            context: context,
            filePath: filePath,
            ownerName: '_SceneViewRuntimeHostState',
            methodName: '_createReplacementPointerSession',
            argSegments: <String>['widget', 'runtime'],
          ),
          (statement) => _statementDeclaresVariableNamedFromOwnedMethodWithArgs(
            statement,
            variableName: 'nextPointerSession',
            context: context,
            filePath: filePath,
            ownerName: '_SceneViewRuntimeHostState',
            methodName: '_createReplacementPointerSession',
            argSegments: <String>['widget', 'runtime'],
          ),
          (statement) => _statementInvokesOwnedMethod(
            statement,
            context: context,
            filePath: pointerHostFilePath,
            ownerName: 'SceneViewInteractivePointerHost',
            methodName: 'replacePointerSession',
          ),
          (statement) => _statementAssignsFieldNamed(
            statement,
            fieldName: '_activeRuntime',
          ),
        ],
        forbiddenAfterCompletion: <bool Function(Statement)>[
          (statement) => _statementInvokesOwnedMethod(
            statement,
            context: context,
            filePath: pointerHostFilePath,
            ownerName: 'SceneViewInteractivePointerHost',
            methodName: 'replacePointerSession',
          ),
          (statement) => _statementAssignsFieldNamed(
            statement,
            fieldName: '_activeRuntime',
          ),
        ],
      ) ||
      !_methodAssignsFieldFromOwnedGetter(
        didUpdateWidget,
        fieldName: '_activeRuntime',
        rhsSegments: <String>['widget', 'runtime'],
      ) ||
      _unitContainsIdentifier(resolved.unit, '_requestedRuntime') ||
      _unitContainsQualifiedPrefix(resolved.unit, <String>[
        'FlutterError',
        'reportError',
      ]) ||
      !_methodCreatesOwnedType(
        buildMethod,
        context: context,
        filePath: renderSurfaceFilePath,
        typeName: 'SceneViewRenderSurface',
      ) ||
      !_methodUsesSceneViewRenderSurfaceArgSource(
        buildMethod,
        ownerClass: hostClass,
        argName: 'renderState',
        sourceSegments: const <String>['_activeRuntime', 'renderState'],
      )) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: SceneViewRuntimeHost must remain the '
          'active-runtime and pointer-host owner for the view boundary.',
    );
  }
  return null;
}

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
