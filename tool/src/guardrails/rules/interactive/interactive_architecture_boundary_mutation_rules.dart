part of 'mutation_boundary_rules.dart';

Future<GuardrailViolation?> _checkInteractiveInteractionRuntimeBoundary(
  GuardrailContext context,
) async {
  final file = _interactiveArchitectureFile(
    context,
    'internal/scene_controller_interaction_runtime.dart',
  );
  final filePath = _repoRelPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  final resolved = await _resolveInteractiveUnitOrFail(
    context: context,
    file: file,
    filePath: filePath,
  );
  final createRuntime = _findTopLevelFunctionByName(
    resolved.unit.declarations,
    'createSceneControllerInteractionRuntime',
  );
  final createMutationBoundary = _findTopLevelFunctionByName(
    resolved.unit.declarations,
    '_createMutationBoundary',
  );
  final createSelectionActions = _findTopLevelFunctionByName(
    resolved.unit.declarations,
    '_createSelectionActions',
  );
  final createInteractiveRuntime = _findTopLevelFunctionByName(
    resolved.unit.declarations,
    '_createInteractiveRuntime',
  );
  final interactionRuntimeClass = _findClassByName(
    resolved.unit.declarations,
    'SceneControllerInteractionRuntime',
  );
  final handlePointerFromSession =
      _findExtensionMethodOnType(
        resolved.unit,
        'SceneControllerInteractionRuntime',
        'handlePointerFromSession',
      ) ??
      (interactionRuntimeClass == null
          ? null
          : _findMethodByName(
              interactionRuntimeClass.members,
              'handlePointerFromSession',
            ));
  final handleDoubleTapFromSession =
      _findExtensionMethodOnType(
        resolved.unit,
        'SceneControllerInteractionRuntime',
        'handleDoubleTapFromSession',
      ) ??
      (interactionRuntimeClass == null
          ? null
          : _findMethodByName(
              interactionRuntimeClass.members,
              'handleDoubleTapFromSession',
            ));
  final mutationBoundaryFilePath = _repoRelPath(
    context,
    _interactiveArchitectureFile(
      context,
      'internal/scene_controller_mutation_boundary.dart',
    ),
  );
  final selectionActionsFilePath = _repoRelPath(
    context,
    _interactiveArchitectureFile(
      context,
      'internal/interactive_selection_actions.dart',
    ),
  );
  if (!_hasImport(
        parsed,
        '../../controller/scene_controller_committed_mutation_access.dart',
      ) ||
      !_hasImport(parsed, 'scene_controller_mutation_boundary.dart') ||
      createRuntime == null ||
      createMutationBoundary == null ||
      createSelectionActions == null ||
      createInteractiveRuntime == null ||
      handlePointerFromSession == null ||
      handleDoubleTapFromSession == null ||
      !_methodContainsOrderedStatementsWithForbiddenOutsideSequence(
        handlePointerFromSession,
        orderedMatchers: <bool Function(Statement)>[
          (statement) => _statementInvokesLocalMethod(
            statement,
            methodName: '_ensureKnownPointerSessionToken',
          ),
          (statement) => _statementInvokesOwnedMethod(
            statement,
            context: context,
            filePath: null,
            ownerName: 'InteractiveRuntime',
            methodName: 'handlePointerFromSession',
            targetSegments: <String>['runtime'],
          ),
        ],
        forbiddenBeforeCompletion: <bool Function(Statement)>[
          (statement) => _statementInvokesOwnedMethod(
            statement,
            context: context,
            filePath: null,
            ownerName: 'InteractiveRuntime',
            methodName: 'handlePointerFromSession',
          ),
        ],
        forbiddenAfterCompletion: <bool Function(Statement)>[
          (statement) => _statementInvokesOwnedMethod(
            statement,
            context: context,
            filePath: null,
            ownerName: 'InteractiveRuntime',
            methodName: 'handlePointerFromSession',
          ),
        ],
      ) ||
      !_methodContainsOrderedStatementsWithForbiddenOutsideSequence(
        handleDoubleTapFromSession,
        orderedMatchers: <bool Function(Statement)>[
          (statement) => _statementInvokesLocalMethod(
            statement,
            methodName: '_ensureKnownPointerSessionToken',
          ),
          (statement) => _statementInvokesOwnedMethod(
            statement,
            context: context,
            filePath: null,
            ownerName: 'InteractiveRuntime',
            methodName: 'handleDoubleTapFromSession',
            targetSegments: <String>['runtime'],
          ),
        ],
        forbiddenBeforeCompletion: <bool Function(Statement)>[
          (statement) => _statementInvokesOwnedMethod(
            statement,
            context: context,
            filePath: null,
            ownerName: 'InteractiveRuntime',
            methodName: 'handleDoubleTapFromSession',
          ),
        ],
        forbiddenAfterCompletion: <bool Function(Statement)>[
          (statement) => _statementInvokesOwnedMethod(
            statement,
            context: context,
            filePath: null,
            ownerName: 'InteractiveRuntime',
            methodName: 'handleDoubleTapFromSession',
          ),
        ],
      ) ||
      !_functionInvokesOwnedTopLevelFunction(
        createRuntime,
        context: context,
        filePath: filePath,
        functionName: '_createMutationBoundary',
      ) ||
      !_functionInvokesOwnedTopLevelFunction(
        createRuntime,
        context: context,
        filePath: filePath,
        functionName: '_createSelectionActions',
      ) ||
      !_functionInvokesOwnedTopLevelFunction(
        createRuntime,
        context: context,
        filePath: filePath,
        functionName: '_createInteractiveRuntime',
      ) ||
      !_functionCreatesOwnedType(
        createMutationBoundary,
        context: context,
        filePath: mutationBoundaryFilePath,
        typeName: 'SceneControllerMutationBoundary',
      ) ||
      !_functionHasParameterTypeFromAllowedFiles(
        createSelectionActions,
        context: context,
        parameterName: 'mutationBoundary',
        typeName: 'SceneControllerMutationBoundary',
        allowedFilePaths: <String>{mutationBoundaryFilePath},
      ) ||
      !_functionCreatesOwnedType(
        createSelectionActions,
        context: context,
        filePath: selectionActionsFilePath,
        typeName: 'InteractiveSelectionActions',
      ) ||
      !_functionHasParameterTypeFromAllowedFiles(
        createInteractiveRuntime,
        context: context,
        parameterName: 'mutationBoundary',
        typeName: 'SceneControllerMutationBoundary',
        allowedFilePaths: <String>{mutationBoundaryFilePath},
      ) ||
      !_functionReferencesOwnedExecutable(
        createInteractiveRuntime,
        context: context,
        filePath: mutationBoundaryFilePath,
        ownerName: 'SceneControllerMutationBoundary',
        elementName: 'setSelection',
      ) ||
      !_functionReferencesOwnedExecutable(
        createInteractiveRuntime,
        context: context,
        filePath: mutationBoundaryFilePath,
        ownerName: 'SceneControllerMutationBoundary',
        elementName: 'clearSelection',
      ) ||
      !_functionReferencesOwnedExecutable(
        createInteractiveRuntime,
        context: context,
        filePath: mutationBoundaryFilePath,
        ownerName: 'SceneControllerMutationBoundary',
        elementName: 'commitMoveSelection',
      ) ||
      !_functionReferencesOwnedExecutable(
        createInteractiveRuntime,
        context: context,
        filePath: mutationBoundaryFilePath,
        ownerName: 'SceneControllerMutationBoundary',
        elementName: 'commitDrawStroke',
      ) ||
      !_functionReferencesOwnedExecutable(
        createInteractiveRuntime,
        context: context,
        filePath: mutationBoundaryFilePath,
        ownerName: 'SceneControllerMutationBoundary',
        elementName: 'commitDrawLineFromWorldSegment',
      ) ||
      !_functionReferencesOwnedExecutable(
        createInteractiveRuntime,
        context: context,
        filePath: mutationBoundaryFilePath,
        ownerName: 'SceneControllerMutationBoundary',
        elementName: 'commitEraseNodes',
      ) ||
      _unitContainsQualifiedPrefix(parsed.unit, <String>[
        'request',
        'storeController',
        'commands',
      ]) ||
      _unitContainsQualifiedPrefix(parsed.unit, <String>[
        'request',
        'storeController',
        'draw',
      ])) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: SceneControllerInteractionRuntime '
          'must route committed selection/draw callbacks through '
          'SceneControllerMutationBoundary.',
    );
  }
  return null;
}

GuardrailViolation? _checkEligibilityPolicyBoundary(GuardrailContext context) {
  final file = _interactiveArchitectureFile(
    context,
    'interaction_eligibility_policy.dart',
  );
  final filePath = _repoRelPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  if (!_unitContainsIdentifier(parsed.unit, '_snapshotBoundsWorld') ||
      _hasImport(parsed, '../model/document.dart') ||
      _unitContainsIdentifier(parsed.unit, 'txnNodeFromSnapshot')) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: interaction_eligibility_policy must '
          'stay model-free and avoid document.dart materialization helpers.',
    );
  }
  return null;
}

Future<GuardrailViolation?> _checkSceneMutationShellBoundary(
  GuardrailContext context,
) async {
  final file = _interactiveArchitectureFile(
    context,
    'internal/scene_controller_scene_mutations.dart',
  );
  final filePath = _repoRelPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  final ownerClass = _findClassDeclaration(
    parsed.unit,
    'SceneControllerSceneMutations',
  );
  if (ownerClass == null ||
      !_classHasFieldNamed(ownerClass, 'mutations') ||
      !_unitContainsQualifiedPrefix(parsed.unit, <String>['mutations']) ||
      _unitContainsIdentifier(parsed.unit, 'storeController') ||
      _unitContainsQualifiedPrefix(parsed.unit, <String>['core', 'write'])) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: SceneControllerSceneMutations must '
          'delegate committed scene writes through '
          'SceneControllerMutationBoundary.',
    );
  }
  return null;
}

Future<GuardrailViolation?> _checkSelectionMutationShellBoundary(
  GuardrailContext context,
) async {
  final file = _interactiveArchitectureFile(
    context,
    'internal/scene_controller_selection_mutations.dart',
  );
  final filePath = _repoRelPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  final ownerClass = _findClassDeclaration(
    parsed.unit,
    'SceneControllerSelectionMutations',
  );
  if (ownerClass == null ||
      !_classHasFieldNamed(ownerClass, 'mutations') ||
      !_unitContainsQualifiedPrefix(parsed.unit, <String>['mutations']) ||
      _unitContainsIdentifier(parsed.unit, 'storeController')) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: SceneControllerSelectionMutations must '
          'delegate committed selection writes through '
          'SceneControllerMutationBoundary.',
    );
  }
  return null;
}

Future<GuardrailViolation?> _checkSelectionActionsBoundary(
  GuardrailContext context,
) async {
  final file = _interactiveArchitectureFile(
    context,
    'internal/interactive_selection_actions.dart',
  );
  final filePath = _repoRelPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  final ownerClass = _findClassDeclaration(
    parsed.unit,
    'InteractiveSelectionActions',
  );
  if (ownerClass == null ||
      !_classHasFieldNamed(ownerClass, 'mutations') ||
      !_unitContainsQualifiedPrefix(parsed.unit, <String>['mutations']) ||
      _unitContainsQualifiedPrefix(parsed.unit, <String>['core', 'write']) ||
      _unitContainsQualifiedPrefix(parsed.unit, <String>['core', 'commands'])) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: InteractiveSelectionActions must '
          'remain a thin routing shell over SceneControllerMutationBoundary.',
    );
  }
  return null;
}

Future<GuardrailViolation?> _checkMutationBoundaryOwner(
  GuardrailContext context,
) async {
  final file = _interactiveArchitectureFile(
    context,
    'internal/scene_controller_mutation_boundary.dart',
  );
  final filePath = _repoRelPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  final ownerClass = _findClassDeclaration(
    parsed.unit,
    'SceneControllerMutationBoundary',
  );
  final replaceSceneMethod = ownerClass == null
      ? null
      : _findMethodByName(ownerClass.members, 'replaceScene');
  if (ownerClass == null ||
      replaceSceneMethod == null ||
      _hasImport(parsed, '../../controller/scene_store_controller.dart') ||
      _unitContainsIdentifier(parsed.unit, 'storeController') ||
      !_unitContainsQualifiedPrefix(parsed.unit, <String>[
        'mutationAccess',
        'clearSceneExactResult',
      ]) ||
      !_unitContainsQualifiedPrefix(parsed.unit, <String>[
        'mutationAccess',
        'replaceSelection',
      ]) ||
      !_unitContainsQualifiedPrefix(parsed.unit, <String>[
        'mutationAccess',
        'clearSelection',
      ]) ||
      !_unitContainsQualifiedPrefix(parsed.unit, <String>[
        'mutationAccess',
        'deleteSelection',
      ]) ||
      !_unitContainsQualifiedPrefix(parsed.unit, <String>[
        'mutationAccess',
        'replaceScene',
      ]) ||
      !_unitContainsQualifiedPrefix(parsed.unit, <String>[
        'mutationAccess',
        'commitDrawStroke',
      ]) ||
      !_unitContainsQualifiedPrefix(parsed.unit, <String>[
        'mutationAccess',
        'commitDrawLineFromWorldSegment',
      ]) ||
      !_unitContainsQualifiedPrefix(parsed.unit, <String>[
        'mutationAccess',
        'commitEraseNodes',
      ]) ||
      !_unitContainsQualifiedPrefix(parsed.unit, <String>[
        'mutationAccess',
        'requestRepaint',
      ]) ||
      !_methodInvokesMethodOnQualifiedTargetWithNamedArg(
        replaceSceneMethod,
        targetSegments: const <String>['mutationAccess'],
        methodName: 'replaceScene',
        argName: 'beforeApply',
        expressionSegments: const <String>['interruptBeforeApply'],
      ) ||
      _unitContainsIdentifier(parsed.unit, 'txnSceneFromSnapshot') ||
      _unitContainsQualifiedPrefix(parsed.unit, <String>[
        'mutationAccess',
        'prepareSceneReplacement',
      ]) ||
      _unitContainsQualifiedPrefix(parsed.unit, <String>[
        'mutationAccess',
        'writePreparedSceneReplacement',
      ])) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: SceneControllerMutationBoundary must '
          'remain the canonical scene/selection write owner.',
    );
  }
  return null;
}

GuardrailViolation? _checkInternalAccessBoundary(GuardrailContext context) {
  final file = _interactiveArchitectureFile(
    context,
    'internal/scene_controller_internal_access.dart',
  );
  final filePath = _repoRelPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  if (!_hasTopLevelOwner(parsed, 'SceneControllerInternalAccessRegistration') ||
      !_hasTopLevelFunction(parsed, 'registerSceneControllerInternalAccess') ||
      !_hasTopLevelFunction(
        parsed,
        'unregisterSceneControllerInternalAccess',
      ) ||
      !_hasTopLevelFunction(parsed, 'sceneControllerInternalEpoch') ||
      !_hasTopLevelFunction(
        parsed,
        'sceneControllerInternalPreviewDeltaForNode',
      ) ||
      !_hasTopLevelFunction(
        parsed,
        'sceneControllerInternalSetBeforePointerDispatchHook',
      ) ||
      _unitContainsIdentifier(parsed.unit, 'SceneViewRuntime') ||
      _unitContainsIdentifier(parsed.unit, 'SceneViewPointerSession') ||
      _unitContainsIdentifier(parsed.unit, 'assembleSceneControllerFacade') ||
      _unitContainsIdentifier(parsed.unit, 'SceneControllerPointerSemantics')) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: internal interactive test/debug access '
          'must remain outside SceneController.',
    );
  }
  return null;
}
