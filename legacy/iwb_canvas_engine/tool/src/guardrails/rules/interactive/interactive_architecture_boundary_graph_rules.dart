part of 'mutation_boundary_rules.dart';

const String _sceneControllerGraphAssemblyFilePath =
    '/lib/src/interactive/internal/scene_controller_graph.dart';
const String _committedMutationAccessAdapterFilePath =
    '/lib/src/controller/scene_controller_committed_mutation_access.dart';

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
  final storeControllerFilePath = _repoRelPath(
    context,
    _interactiveArchitectureFile(
      context,
      '../controller/scene_store_controller.dart',
    ),
  );
  final failures = <String>[];
  void requireCondition(bool condition, String name) {
    if (!condition) {
      failures.add(name);
    }
  }

  requireCondition(createGraph != null, 'createSceneControllerGraph');
  requireCondition(assembleGraph != null, '_assembleSceneControllerGraph');
  requireCondition(
    _hasTopLevelOwner(parsed, 'SceneControllerGraphHandle'),
    'SceneControllerGraphHandle',
  );
  requireCondition(
    !_hasTopLevelOwner(parsed, 'SceneControllerGraph'),
    'no SceneControllerGraph record',
  );
  requireCondition(
    !_hasTopLevelOwner(parsed, 'SceneStoreController'),
    'no local SceneStoreController',
  );
  requireCondition(
    !_hasTopLevelOwner(parsed, 'SceneControllerInteractionOwner'),
    'no local interaction owner',
  );
  requireCondition(
    !_hasTopLevelOwner(parsed, 'SceneControllerSelectionOwner'),
    'no local selection owner',
  );
  requireCondition(
    !_hasTopLevelOwner(parsed, 'SceneControllerSceneOwner'),
    'no local scene owner',
  );
  requireCondition(
    !_hasTopLevelOwner(parsed, 'SceneControllerSceneViewRuntime'),
    'no local view runtime',
  );
  requireCondition(
    !_hasTopLevelOwner(parsed, 'SceneControllerInternalAccessRegistration'),
    'no local internal access registration',
  );
  if (createGraph != null) {
    requireCondition(
      _functionInvokesOwnedTopLevelFunction(
        createGraph,
        context: context,
        filePath: filePath,
        functionName: '_assembleSceneControllerGraph',
      ),
      'factory invokes assembly',
    );
    requireCondition(
      _functionInvokesOwnedTopLevelFunction(
        createGraph,
        context: context,
        filePath: internalAccessFilePath,
        functionName: 'registerSceneControllerInternalAccess',
      ),
      'factory registers internal access',
    );
  }
  if (assembleGraph != null) {
    requireCondition(
      _functionCreatesOwnedType(
        assembleGraph,
        context: context,
        filePath: filePath,
        typeName: 'SceneControllerGraphHandle',
      ),
      'assembly creates graph handle',
    );
    requireCondition(
      _functionCreatesOwnedType(
        assembleGraph,
        context: context,
        filePath: storeControllerFilePath,
        typeName: 'SceneStoreController',
      ),
      'assembly creates store controller',
    );
    requireCondition(
      _functionCreatesOwnedType(
        assembleGraph,
        context: context,
        filePath: interactionOwnerFilePath,
        typeName: 'SceneControllerInteractionOwner',
      ),
      'assembly creates interaction owner',
    );
    requireCondition(
      _functionCreatesOwnedType(
        assembleGraph,
        context: context,
        filePath: selectionOwnerFilePath,
        typeName: 'SceneControllerSelectionOwner',
      ),
      'assembly creates selection owner',
    );
    requireCondition(
      _functionCreatesOwnedType(
        assembleGraph,
        context: context,
        filePath: sceneOwnerFilePath,
        typeName: 'SceneControllerSceneOwner',
      ),
      'assembly creates scene owner',
    );
    requireCondition(
      _functionCreatesOwnedType(
        assembleGraph,
        context: context,
        filePath: sceneViewRuntimeFilePath,
        typeName: 'SceneControllerSceneViewRuntime',
      ),
      'assembly creates view runtime',
    );
    requireCondition(
      _functionCreatesOwnedType(
        assembleGraph,
        context: context,
        filePath: internalAccessFilePath,
        typeName: 'SceneControllerInternalAccessRegistration',
      ),
      'assembly creates internal access registration',
    );
  }
  requireCondition(
    !_hasTopLevelFunction(parsed, 'sceneControllerGraphActions') &&
        !_hasTopLevelFunction(parsed, 'sceneControllerGraphEditTextRequests') &&
        !_hasTopLevelFunction(
          parsed,
          'sceneControllerGraphPreviewDeltaResolver',
        ) &&
        !_hasTopLevelFunction(
          parsed,
          'sceneControllerGraphEnsurePublicSideEffectAllowed',
        ) &&
        !_hasTopLevelFunction(parsed, 'sceneControllerGraphIsDisposed') &&
        !_hasTopLevelFunction(parsed, 'disposeSceneControllerGraph') &&
        !_hasTopLevelFunction(
          parsed,
          'detachSceneControllerGraphInternalAccess',
        ),
    'no graph helper bag',
  );
  requireCondition(
    !_unitContainsIdentifier(parsed.unit, 'createPointerSemanticsBridge') &&
        !_unitContainsIdentifier(
          parsed.unit,
          'SceneControllerPointerSemantics',
        ),
    'no pointer semantics bridge',
  );

  if (failures.isNotEmpty) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: SceneController graph must assemble '
          'view runtime and internal access outside the facade. '
          'Missing: ${failures.join(', ')}.',
    );
  }
  return null;
}

Future<GuardrailViolation?> _checkCommittedMutationAccessAdapterAssembly(
  GuardrailContext context,
) async {
  for (final file in collectSortedLibSrcDartFiles(context)) {
    final filePath = toRepoRelPosixPath(
      absPosixPath: toPosixPath(file.absolute.path),
      rootAbsPosixPath: context.rootAbsPosixPath,
    );
    if (filePath == _sceneControllerGraphAssemblyFilePath) {
      continue;
    }
    final resolved = await context.getResolvedUnitResult(file.absolute.path);
    if (resolved == null) {
      continue;
    }
    InstanceCreationExpression? violationNode;
    resolved.unit.accept(
      _ResolvedInvocationCollector(
        onMethodInvocation: (_) {},
        onFunctionInvocation: (_) {},
        onInstanceCreation: (candidate) {
          if (violationNode != null) {
            return;
          }
          if (_matchesOwnedConstructor(
            element: candidate.constructorName.element,
            context: context,
            filePath: _committedMutationAccessAdapterFilePath,
            ownerName: 'SceneStoreControllerCommittedMutationAccess',
          )) {
            violationNode = candidate;
          }
        },
      ),
    );
    final node = violationNode;
    if (node != null) {
      return GuardrailViolation(
        filePath: filePath,
        line: resolved.lineInfo.getLocation(node.offset).lineNumber,
        message:
            'interactive API violation: '
            'SceneStoreControllerCommittedMutationAccess must be assembled '
            'only by the SceneController graph composition root.',
      );
    }
  }
  return null;
}
