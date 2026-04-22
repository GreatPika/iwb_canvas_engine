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
  final runtimeClass = findClassDeclarationByName(
    resolved.unit.declarations,
    'SceneControllerSceneViewRuntime',
  );
  final renderStateClass = findClassDeclarationByName(
    resolved.unit.declarations,
    'SceneControllerSceneViewRenderState',
  );
  final createPointerSession = runtimeClass == null
      ? null
      : findMethodDeclarationByName(
          runtimeClass.members,
          'createPointerSession',
        );
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
      !classImplementsNamedInterface(runtimeClass, 'SceneViewRuntime') ||
      !classImplementsNamedInterface(
        renderStateClass,
        'SceneViewRenderState',
      ) ||
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
      !_methodInvokesOwnedMethod(
        createPointerSession,
        context: context,
        filePath: interactionRuntimeFilePath,
        ownerName: 'SceneControllerInteractionRuntime',
        methodName: 'registerPointerSession',
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
  final pointerSessionClass = findClassDeclarationByName(
    resolved.unit.declarations,
    'SceneControllerPointerSession',
  );
  final detachMethod = pointerSessionClass == null
      ? null
      : findMethodDeclarationByName(pointerSessionClass.members, 'detach');
  final disposeMethod = pointerSessionClass == null
      ? null
      : findMethodDeclarationByName(pointerSessionClass.members, 'dispose');
  final implementsSession =
      pointerSessionClass != null &&
      classImplementsNamedInterface(
        pointerSessionClass,
        'SceneViewPointerSession',
      );
  final hasTracker = _unitContainsIdentifier(
    resolved.unit,
    'PointerInputTracker',
  );
  final hasScheduler = _unitContainsIdentifier(
    resolved.unit,
    '_PendingTapFlushScheduler',
  );
  final hasReleaseOwnedResources = _unitContainsIdentifier(
    resolved.unit,
    '_releaseOwnedResources',
  );
  final hasAddListener = _unitContainsQualifiedPrefix(resolved.unit, <String>[
    '_ownerListenable',
    'addListener',
  ]);
  final hasRemoveListener = _unitContainsQualifiedPrefix(
    resolved.unit,
    <String>['_ownerListenable', 'removeListener'],
  );
  final hasReleaseToken = _unitContainsIdentifier(
    resolved.unit,
    '_releasePointerSessionToken',
  );
  final detachFlow =
      detachMethod != null &&
      _methodContainsOrderedStatementsBeforeAnyForbidden(
        detachMethod,
        orderedMatchers: <bool Function(Statement)>[
          (statement) => _statementInvokesLocalMethod(
            statement,
            methodName: '_detachPointerSession',
          ),
          (statement) => _statementInvokesLocalMethod(
            statement,
            methodName: '_releaseOwnedResources',
          ),
        ],
        forbiddenBeforeCompletion: <bool Function(Statement)>[
          (statement) => _statementInvokesLocalMethod(
            statement,
            methodName: '_releaseOwnedResources',
          ),
        ],
      );
  final disposeFlow =
      disposeMethod != null &&
      _methodContainsOrderedStatementsBeforeAnyForbidden(
        disposeMethod,
        orderedMatchers: <bool Function(Statement)>[
          (statement) =>
              _statementInvokesLocalMethod(statement, methodName: 'detach'),
          (statement) => _statementInvokesLocalMethod(
            statement,
            methodName: 'dispose',
            targetSegments: <String>['_pendingTapFlushScheduler'],
          ),
        ],
        forbiddenBeforeCompletion: <bool Function(Statement)>[
          (statement) => _statementInvokesLocalMethod(
            statement,
            methodName: 'dispose',
            targetSegments: <String>['_pendingTapFlushScheduler'],
          ),
        ],
      );
  final hasInteractionLeak = _unitContainsIdentifier(
    resolved.unit,
    'SceneControllerInteraction',
  );
  final hasReadInteractionLeak = _unitContainsIdentifier(
    resolved.unit,
    '_readInteraction',
  );
  final hasRuntimeTypeLeak = _unitContainsIdentifier(
    resolved.unit,
    'runtimeType',
  );
  final hasOwnerField =
      pointerSessionClass != null &&
      _classHasFieldNamed(pointerSessionClass, 'owner');
  final hasSessionField =
      pointerSessionClass != null &&
      _classHasFieldNamed(pointerSessionClass, 'session');
  final hasContextField =
      pointerSessionClass != null &&
      _classHasFieldNamed(pointerSessionClass, 'context');
  if (pointerSessionClass == null ||
      !implementsSession ||
      detachMethod == null ||
      disposeMethod == null ||
      !hasTracker ||
      !hasScheduler ||
      !hasReleaseOwnedResources ||
      !hasAddListener ||
      !hasRemoveListener ||
      !hasReleaseToken ||
      !detachFlow ||
      !disposeFlow ||
      hasInteractionLeak ||
      hasReadInteractionLeak ||
      hasRuntimeTypeLeak ||
      hasOwnerField ||
      hasSessionField ||
      hasContextField) {
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
  final source = file.readAsStringSync();
  final tokenClass = _findClassDeclaration(parsed.unit, 'PointerSessionToken');
  if (tokenClass == null ||
      !_classIsFinal(tokenClass) ||
      !RegExp(r'final\s+class\s+PointerSessionToken\b').hasMatch(source) ||
      tokenClass.members.whereType<FieldDeclaration>().any(
        (field) => field.fields.variables.any(
          (variable) => !variable.name.lexeme.startsWith('_'),
        ),
      ) ||
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
