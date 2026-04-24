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
  final clearSceneSelectionState =
      _findExtensionMethodOnType(
        resolved.unit,
        'SceneControllerInteractionRuntime',
        'clearSceneSelectionState',
      ) ??
      (interactionRuntimeClass == null
          ? null
          : _findMethodByName(
              interactionRuntimeClass.members,
              'clearSceneSelectionState',
            ));
  final rotateSelection =
      _findExtensionMethodOnType(
        resolved.unit,
        'SceneControllerInteractionRuntime',
        'rotateSelection',
      ) ??
      (interactionRuntimeClass == null
          ? null
          : _findMethodByName(
              interactionRuntimeClass.members,
              'rotateSelection',
            ));
  final flipSelectionVertical =
      _findExtensionMethodOnType(
        resolved.unit,
        'SceneControllerInteractionRuntime',
        'flipSelectionVertical',
      ) ??
      (interactionRuntimeClass == null
          ? null
          : _findMethodByName(
              interactionRuntimeClass.members,
              'flipSelectionVertical',
            ));
  final flipSelectionHorizontal =
      _findExtensionMethodOnType(
        resolved.unit,
        'SceneControllerInteractionRuntime',
        'flipSelectionHorizontal',
      ) ??
      (interactionRuntimeClass == null
          ? null
          : _findMethodByName(
              interactionRuntimeClass.members,
              'flipSelectionHorizontal',
            ));
  final deleteSelection =
      _findExtensionMethodOnType(
        resolved.unit,
        'SceneControllerInteractionRuntime',
        'deleteSelection',
      ) ??
      (interactionRuntimeClass == null
          ? null
          : _findMethodByName(
              interactionRuntimeClass.members,
              'deleteSelection',
            ));
  final mutationBoundaryFilePath = _repoRelPath(
    context,
    _interactiveArchitectureFile(
      context,
      'internal/scene_controller_mutation_boundary.dart',
    ),
  );
  if (!_hasImport(
        parsed,
        '../../controller/scene_controller_committed_mutation_access.dart',
      ) ||
      !_hasImport(parsed, 'scene_controller_mutation_boundary.dart') ||
      _hasImport(parsed, 'interactive_selection_actions.dart') ||
      _unitContainsIdentifier(parsed.unit, 'InteractiveSelectionActions') ||
      _unitContainsIdentifier(parsed.unit, '_createSelectionActions') ||
      createRuntime == null ||
      createMutationBoundary == null ||
      createInteractiveRuntime == null ||
      handlePointerFromSession == null ||
      handleDoubleTapFromSession == null ||
      clearSceneSelectionState == null ||
      rotateSelection == null ||
      flipSelectionVertical == null ||
      flipSelectionHorizontal == null ||
      deleteSelection == null ||
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
        functionName: '_createInteractiveRuntime',
      ) ||
      !_functionCreatesOwnedType(
        createMutationBoundary,
        context: context,
        filePath: mutationBoundaryFilePath,
        typeName: 'SceneControllerMutationBoundary',
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
      !_methodReferencesOwnedExecutable(
        clearSceneSelectionState,
        context: context,
        filePath: mutationBoundaryFilePath,
        ownerName: 'SceneControllerMutationBoundary',
        elementName: 'clearScene',
      ) ||
      !_methodReferencesOwnedExecutable(
        rotateSelection,
        context: context,
        filePath: mutationBoundaryFilePath,
        ownerName: 'SceneControllerMutationBoundary',
        elementName: 'rotateSelection',
      ) ||
      !_methodReferencesOwnedExecutable(
        flipSelectionVertical,
        context: context,
        filePath: mutationBoundaryFilePath,
        ownerName: 'SceneControllerMutationBoundary',
        elementName: 'flipSelectionVertical',
      ) ||
      !_methodReferencesOwnedExecutable(
        flipSelectionHorizontal,
        context: context,
        filePath: mutationBoundaryFilePath,
        ownerName: 'SceneControllerMutationBoundary',
        elementName: 'flipSelectionHorizontal',
      ) ||
      !_methodReferencesOwnedExecutable(
        deleteSelection,
        context: context,
        filePath: mutationBoundaryFilePath,
        ownerName: 'SceneControllerMutationBoundary',
        elementName: 'deleteSelection',
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
