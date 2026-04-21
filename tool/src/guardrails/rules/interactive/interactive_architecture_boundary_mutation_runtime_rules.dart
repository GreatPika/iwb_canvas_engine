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
