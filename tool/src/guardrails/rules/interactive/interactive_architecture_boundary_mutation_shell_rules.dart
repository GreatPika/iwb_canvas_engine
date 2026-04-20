part of 'mutation_boundary_rules.dart';

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
