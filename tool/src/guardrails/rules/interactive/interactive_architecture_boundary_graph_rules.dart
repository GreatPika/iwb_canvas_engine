part of 'mutation_boundary_rules.dart';

Future<GuardrailViolation?> _checkInteractiveGraphAssembly(
  GuardrailContext context,
) async {
  final file = _interactiveArchitectureFile(
    context,
    'internal/scene_controller_graph.dart',
  );
  final filePath = _repoRelPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  final resolved = await _resolveInteractiveUnitOrFail(
    context: context,
    file: file,
    filePath: filePath,
  );
  final createGraph = _findTopLevelFunctionByName(
    resolved.unit.declarations,
    'createSceneControllerGraph',
  );
  final assembleGraph = _findTopLevelFunctionByName(
    resolved.unit.declarations,
    '_assembleSceneControllerGraph',
  );
  final internalAccessFilePath = _repoRelPath(
    context,
    _interactiveArchitectureFile(
      context,
      'internal/scene_controller_internal_access.dart',
    ),
  );
  final interactionOwnerFilePath = _repoRelPath(
    context,
    _interactiveArchitectureFile(context, 'scene_controller_interaction.dart'),
  );
  final selectionOwnerFilePath = _repoRelPath(
    context,
    _interactiveArchitectureFile(context, 'scene_controller_selection.dart'),
  );
  final sceneOwnerFilePath = _repoRelPath(
    context,
    _interactiveArchitectureFile(context, 'scene_controller_scene.dart'),
  );
  final sceneViewRuntimeFilePath = _repoRelPath(
    context,
    _interactiveArchitectureFile(
      context,
      'internal/scene_controller_scene_view_runtime.dart',
    ),
  );
  if (createGraph == null ||
      assembleGraph == null ||
      _hasTopLevelOwner(parsed, 'SceneControllerInteractionOwner') ||
      _hasTopLevelOwner(parsed, 'SceneControllerSelectionOwner') ||
      _hasTopLevelOwner(parsed, 'SceneControllerSceneOwner') ||
      _hasTopLevelOwner(parsed, 'SceneControllerSceneViewRuntime') ||
      _hasTopLevelOwner(parsed, 'SceneControllerInternalAccessRegistration') ||
      !_functionInvokesOwnedTopLevelFunction(
        createGraph,
        context: context,
        filePath: filePath,
        functionName: '_assembleSceneControllerGraph',
      ) ||
      !_functionInvokesOwnedTopLevelFunction(
        createGraph,
        context: context,
        filePath: internalAccessFilePath,
        functionName: 'registerSceneControllerInternalAccess',
      ) ||
      !_functionCreatesOwnedType(
        assembleGraph,
        context: context,
        filePath: interactionOwnerFilePath,
        typeName: 'SceneControllerInteractionOwner',
      ) ||
      !_functionCreatesOwnedType(
        assembleGraph,
        context: context,
        filePath: selectionOwnerFilePath,
        typeName: 'SceneControllerSelectionOwner',
      ) ||
      !_functionCreatesOwnedType(
        assembleGraph,
        context: context,
        filePath: sceneOwnerFilePath,
        typeName: 'SceneControllerSceneOwner',
      ) ||
      !_functionCreatesOwnedType(
        assembleGraph,
        context: context,
        filePath: sceneViewRuntimeFilePath,
        typeName: 'SceneControllerSceneViewRuntime',
      ) ||
      !_functionCreatesOwnedType(
        assembleGraph,
        context: context,
        filePath: internalAccessFilePath,
        typeName: 'SceneControllerInternalAccessRegistration',
      ) ||
      _unitContainsIdentifier(parsed.unit, 'createPointerSemanticsBridge') ||
      _unitContainsIdentifier(parsed.unit, 'SceneControllerPointerSemantics')) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: SceneController graph must assemble '
          'view runtime and internal access outside the facade.',
    );
  }
  return null;
}
