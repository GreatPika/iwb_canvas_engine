part of 'mutation_boundary_rules.dart';

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
  final overlayPainterFilePath = _repoRelPath(
    context,
    _interactiveArchitectureFile(
      context,
      '../view/scene_view_interactive_overlay_painter.dart',
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
      !_hasImport(parsed, 'scene_view_interactive_overlay_painter.dart') ||
      !_hasImport(parsed, 'scene_view_render_surface.dart') ||
      _hasTopLevelOwner(parsed, 'SceneViewInteractivePointerHost') ||
      _hasTopLevelOwner(parsed, 'SceneViewInteractiveOverlayPainter') ||
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
        filePath: overlayPainterFilePath,
        typeName: 'SceneViewInteractiveOverlayPainter',
      ) ||
      !_methodUsesOwnedTypeArgSource(
        buildMethod,
        ownerClass: hostClass,
        context: context,
        filePath: overlayPainterFilePath,
        typeName: 'SceneViewInteractiveOverlayPainter',
        argName: 'overlayPreviewRead',
        sourceSegments: const <String>['_activeRuntime', 'overlayPreviewRead'],
      ) ||
      !_methodCreatesOwnedType(
        buildMethod,
        context: context,
        filePath: renderSurfaceFilePath,
        typeName: 'SceneViewRenderSurface',
      ) ||
      !_methodUsesOwnedTypeArgSource(
        buildMethod,
        ownerClass: hostClass,
        context: context,
        filePath: renderSurfaceFilePath,
        typeName: 'SceneViewRenderSurface',
        argName: 'mainSceneRenderRead',
        sourceSegments: const <String>['_activeRuntime', 'mainSceneRenderRead'],
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
