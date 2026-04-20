part of 'mutation_boundary_rules.dart';

Future<GuardrailViolation?> _checkInteractiveViewRuntimeBoundary(
  GuardrailContext context,
) async {
  final file = _interactiveArchitectureFile(
    context,
    'internal/scene_controller_scene_view_runtime.dart',
  );
  final filePath = _repoRelPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  final resolved = await _resolveInteractiveUnitOrFail(
    context: context,
    file: file,
    filePath: filePath,
  );
  final runtimeClass = _findClassByName(
    resolved.unit.declarations,
    'SceneControllerSceneViewRuntime',
  );
  final renderStateClass = _findClassByName(
    resolved.unit.declarations,
    'SceneControllerSceneViewRenderState',
  );
  final createPointerSession = runtimeClass == null
      ? null
      : _findMethodByName(runtimeClass.members, 'createPointerSession');
  final interactionRuntimeFilePath = _repoRelPath(
    context,
    _interactiveArchitectureFile(
      context,
      'internal/scene_controller_interaction_runtime.dart',
    ),
  );
  final pointerSessionFilePath = _repoRelPath(
    context,
    _interactiveArchitectureFile(
      context,
      'internal/scene_controller_pointer_session.dart',
    ),
  );
  if (runtimeClass == null ||
      renderStateClass == null ||
      !_classImplements(runtimeClass, 'SceneViewRuntime') ||
      !_classImplements(renderStateClass, 'SceneViewRenderState') ||
      createPointerSession == null ||
      !_methodReturnsInterfaceType(
        createPointerSession,
        interfaceName: 'SceneViewPointerSession',
      ) ||
      !_methodInvokesOwnedMethod(
        createPointerSession,
        context: context,
        filePath: interactionRuntimeFilePath,
        ownerName: 'SceneControllerInteractionRuntime',
        methodName: 'createPointerSessionToken',
      ) ||
      !_methodCreatesOwnedType(
        createPointerSession,
        context: context,
        filePath: pointerSessionFilePath,
        typeName: 'SceneControllerPointerSession',
      ) ||
      !_methodReferencesOwnedExecutable(
        createPointerSession,
        context: context,
        filePath: interactionRuntimeFilePath,
        ownerName: 'SceneControllerInteractionRuntime',
        elementName: 'detachPointerSession',
      ) ||
      !_methodReferencesOwnedExecutable(
        createPointerSession,
        context: context,
        filePath: interactionRuntimeFilePath,
        ownerName: 'SceneControllerInteractionRuntime',
        elementName: 'releasePointerSessionToken',
      ) ||
      !_methodReferencesOwnedExecutable(
        createPointerSession,
        context: context,
        filePath: interactionRuntimeFilePath,
        ownerName: 'SceneControllerInteractionRuntime',
        elementName: 'handlePointerFromSession',
      ) ||
      !_methodReferencesOwnedExecutable(
        createPointerSession,
        context: context,
        filePath: interactionRuntimeFilePath,
        ownerName: 'SceneControllerInteractionRuntime',
        elementName: 'handleDoubleTapFromSession',
      ) ||
      _unitContainsIdentifier(parsed.unit, 'SceneControllerPointerSemantics') ||
      _unitContainsIdentifier(parsed.unit, 'createPointerSemanticsBridge') ||
      _unitContainsIdentifier(
        parsed.unit,
        '_DisposedSceneViewPointerSession',
      )) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: SceneControllerSceneViewRuntime must '
          'own the render-state adapter and pointer-session factory.',
    );
  }
  return null;
}

Future<GuardrailViolation?> _checkPointerSessionBoundary(
  GuardrailContext context,
) async {
  final file = _interactiveArchitectureFile(
    context,
    'internal/scene_controller_pointer_session.dart',
  );
  final filePath = _repoRelPath(context, file);
  final resolved = await _resolveInteractiveUnitOrFail(
    context: context,
    file: file,
    filePath: filePath,
  );
  final pointerSessionClass = _findClassByName(
    resolved.unit.declarations,
    'SceneControllerPointerSession',
  );
  if (pointerSessionClass == null ||
      !_classImplements(pointerSessionClass, 'SceneViewPointerSession') ||
      _unitContainsIdentifier(resolved.unit, 'SceneControllerInteraction') ||
      _unitContainsIdentifier(resolved.unit, '_readInteraction') ||
      _unitContainsIdentifier(resolved.unit, 'runtimeType') ||
      _classHasFieldNamed(pointerSessionClass, 'owner') ||
      _classHasFieldNamed(pointerSessionClass, 'session') ||
      _classHasFieldNamed(pointerSessionClass, 'context')) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: pointer session must stay owned by '
          'SceneControllerPointerSession.',
    );
  }
  return null;
}

GuardrailViolation? _checkPointerSessionTokenBoundary(
  GuardrailContext context,
) {
  final file = _interactiveArchitectureFile(
    context,
    'internal/pointer_session_token.dart',
  );
  final filePath = _repoRelPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  final tokenClass = _findClassDeclaration(parsed.unit, 'PointerSessionToken');
  if (tokenClass == null ||
      _classOwnsMethodDeclaration(tokenClass, '==') ||
      _classOwnsGetterOrMethod(tokenClass, 'hashCode') ||
      _classOwnsMethodDeclaration(tokenClass, 'toJson')) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: PointerSessionToken must remain an '
          'opaque internal nominal token.',
    );
  }
  return null;
}

Future<GuardrailViolation?> _checkPointerHostBoundary(
  GuardrailContext context,
) async {
  final file = _interactiveArchitectureFile(
    context,
    '../view/scene_view_interactive_pointer_host.dart',
  );
  final filePath = _repoRelPath(context, file);
  final resolved = await _resolveInteractiveUnitOrFail(
    context: context,
    file: file,
    filePath: filePath,
  );
  final runtimeClass = _findClassByName(
    resolved.unit.declarations,
    '_SceneViewInteractivePointerRuntime',
  );
  final replaceMethod = runtimeClass == null
      ? null
      : _findMethodByName(runtimeClass.members, 'replacePointerSession');
  final disposeMethod = runtimeClass == null
      ? null
      : _findMethodByName(runtimeClass.members, 'dispose');
  if (runtimeClass == null ||
      replaceMethod == null ||
      disposeMethod == null ||
      !_methodHasParameterType(
        replaceMethod,
        parameterName: 'next',
        typeName: 'SceneViewPointerSession',
      ) ||
      !_methodInvokesOwnedMethod(
        replaceMethod,
        context: context,
        filePath: null,
        ownerName: 'SceneViewPointerSession',
        methodName: 'detach',
      ) ||
      !_methodInvokesOwnedMethod(
        replaceMethod,
        context: context,
        filePath: null,
        ownerName: 'SceneViewPointerSession',
        methodName: 'dispose',
      ) ||
      !_methodInvokesOwnedMethod(
        replaceMethod,
        context: context,
        filePath: null,
        ownerName: 'SceneViewPointerRouter',
        methodName: 'reset',
      ) ||
      !_methodContainsOrderedStatements(
        replaceMethod,
        <bool Function(Statement)>[
          (statement) => _statementInvokesOwnedMethod(
            statement,
            context: context,
            filePath: null,
            ownerName: 'SceneViewPointerSession',
            methodName: 'detach',
          ),
          (statement) => _statementInvokesOwnedMethod(
            statement,
            context: context,
            filePath: null,
            ownerName: 'SceneViewPointerSession',
            methodName: 'dispose',
          ),
          (statement) => _statementInvokesOwnedMethod(
            statement,
            context: context,
            filePath: null,
            ownerName: 'SceneViewPointerRouter',
            methodName: 'reset',
          ),
          (statement) => _statementAssignsFieldNamed(
            statement,
            fieldName: '_pointerSession',
          ),
        ],
      ) ||
      !_methodInvokesOwnedMethod(
        disposeMethod,
        context: context,
        filePath: null,
        ownerName: 'SceneViewPointerSession',
        methodName: 'detach',
      ) ||
      !_methodInvokesOwnedMethod(
        disposeMethod,
        context: context,
        filePath: null,
        ownerName: 'SceneViewPointerSession',
        methodName: 'dispose',
      ) ||
      !_methodContainsOrderedStatements(
        disposeMethod,
        <bool Function(Statement)>[
          (statement) => _statementInvokesOwnedMethod(
            statement,
            context: context,
            filePath: null,
            ownerName: 'SceneViewPointerSession',
            methodName: 'detach',
          ),
          (statement) => _statementInvokesOwnedMethod(
            statement,
            context: context,
            filePath: null,
            ownerName: 'SceneViewPointerSession',
            methodName: 'dispose',
          ),
        ],
      ) ||
      _unitContainsIdentifier(resolved.unit, 'SceneController') ||
      _unitContainsIdentifier(resolved.unit, 'createPointerSemanticsBridge') ||
      _unitContainsIdentifier(resolved.unit, 'PointerInputTracker') ||
      _unitContainsIdentifier(resolved.unit, '_PendingTapFlushScheduler') ||
      _unitContainsIdentifier(resolved.unit, '_pendingPointerSettings') ||
      _unitContainsIdentifier(
        resolved.unit,
        '_SceneViewPointerSessionFactory',
      )) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: SceneViewInteractivePointerHost must '
          'remain a raw routing/lifecycle shell over pointer sessions.',
    );
  }
  return null;
}
