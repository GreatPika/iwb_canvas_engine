part of 'mutation_boundary_rules.dart';

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
