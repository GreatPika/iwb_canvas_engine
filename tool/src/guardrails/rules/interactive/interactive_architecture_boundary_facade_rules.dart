part of 'mutation_boundary_rules.dart';

Future<GuardrailViolation?> _checkInteractiveFacadeBoundary(
  GuardrailContext context,
) async {
  final file = _interactiveFile(context);
  final filePath = _interactiveFilePosixPath(context, file);
  final parsed = _parseArchitectureUnit(context, file);
  final resolved = await _resolveInteractiveUnitOrFail(
    context: context,
    file: file,
    filePath: filePath,
  );
  final interactiveClass = findClassDeclarationByName(
    resolved.unit.declarations,
    'SceneController',
  );
  final sceneControllerCtor = interactiveClass?.members
      .whereType<ConstructorDeclaration>()
      .firstOrNullSafe();
  final graphFilePath = _repoRelPath(
    context,
    _interactiveArchitectureFile(
      context,
      'internal/scene_controller_graph.dart',
    ),
  );
  if (interactiveClass == null) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: SceneController must remain a thin '
          'facade over the assembled controller graph.',
    );
  }
  if (_hasDisallowedTopLevelHelper(parsed)) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: SceneController must remain a thin '
          'facade over the assembled controller graph.',
    );
  }
  if (classImplementsNamedInterface(interactiveClass, 'SceneViewRenderState')) {
    return GuardrailViolation(
      filePath: filePath,
      line: _lineForResolvedOffset(resolved, interactiveClass.offset),
      message:
          'interactive API violation: SceneController must remain a thin '
          'facade over the assembled controller graph.',
    );
  }
  if (_hasTopLevelOwner(parsed, 'SceneControllerGraphRequest')) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: SceneController must remain a thin '
          'facade over the assembled controller graph.',
    );
  }
  if (_hasForbiddenImports(parsed, <String>{
    'internal/scene_controller_internal_access.dart',
    'internal/scene_controller_pointer_session.dart',
    'internal/interactive_draw_coordinator.dart',
    'internal/interactive_runtime.dart',
    'internal/interactive_event_dispatcher.dart',
  })) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: SceneController must remain a thin '
          'facade over the assembled controller graph.',
    );
  }
  if (_unitContainsIdentifier(parsed.unit, 'createPointerSemanticsBridge') ||
      _unitContainsIdentifier(parsed.unit, 'StreamController') ||
      _unitContainsIdentifier(parsed.unit, '_timestampCursorMs') ||
      _unitContainsQualifiedPrefix(parsed.unit, <String>[
        '_runtime',
        'handlePointer',
      ]) ||
      _unitContainsQualifiedPrefix(parsed.unit, <String>[
        '_runtime',
        'handleDoubleTap',
      ])) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: SceneController must remain a thin '
          'facade over the assembled controller graph.',
    );
  }
  final usesCanonicalGraphInitialization =
      (_classFieldInitializerInvokesOwnedTopLevelFunction(
            interactiveClass,
            fieldName: '_graph',
            context: context,
            filePath: graphFilePath,
            functionName: 'createSceneControllerGraph',
          ) &&
          _classFieldInitializerCreatesOwnedType(
            interactiveClass,
            fieldName: '_graph',
            context: context,
            filePath: graphFilePath,
            typeName: 'SceneControllerGraphRequest',
          )) ||
      (sceneControllerCtor != null &&
          _constructorAssignsFieldFromOwnedTopLevelFunction(
            sceneControllerCtor,
            fieldName: '_graph',
            context: context,
            filePath: graphFilePath,
            functionName: 'createSceneControllerGraph',
          ) &&
          _constructorCreatesOwnedType(
            sceneControllerCtor,
            context: context,
            filePath: graphFilePath,
            typeName: 'SceneControllerGraphRequest',
          ));
  if (!_hasImport(parsed, 'internal/scene_controller_graph.dart') ||
      !_hasImport(parsed, '../contract/scene_view_runtime.dart') ||
      !_hasTopLevelFunction(parsed, 'sceneControllerViewRuntimeOf') ||
      !usesCanonicalGraphInitialization) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: SceneController must remain a thin '
          'facade over the assembled controller graph.',
    );
  }

  final runtimeBridge = _findTopLevelFunctionByName(
    resolved.unit.declarations,
    'sceneControllerViewRuntimeOf',
  );
  if (runtimeBridge == null ||
      !_functionAccessesField(runtimeBridge, fieldName: '_graph')) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'interactive API violation: SceneController must remain a thin '
          'facade over the assembled controller graph.',
    );
  }

  final interactionFile = _interactiveArchitectureFile(
    context,
    'scene_controller_interaction.dart',
  );
  final interactionParsed = _parseArchitectureUnit(context, interactionFile);
  if (_containsTopLevelGetter(interactionParsed, 'snapshot') ||
      _classOrInterfaceOwnsGetter(interactionParsed, 'snapshot')) {
    return GuardrailViolation(
      filePath: _repoRelPath(context, interactionFile),
      line: 1,
      message:
          'interactive API violation: SceneControllerInteraction must not '
          'expose committed render-state through snapshot.',
    );
  }
  return null;
}
