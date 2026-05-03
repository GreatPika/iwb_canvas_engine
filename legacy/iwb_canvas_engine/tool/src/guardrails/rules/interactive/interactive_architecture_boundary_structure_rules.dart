part of 'mutation_boundary_rules.dart';

GuardrailViolation? _checkInteractiveOwnerPresence(GuardrailContext context) {
  for (final spec in _interactiveOwnerSpecs) {
    final file = _interactiveArchitectureFile(context, spec.relativePath);
    if (!file.existsSync()) {
      return GuardrailViolation(
        filePath: _interactiveFilePosixPath(context, _interactiveFile(context)),
        line: 1,
        message:
            'interactive API violation: missing required split owner '
            '${spec.ownerName} at ${_repoRelPath(context, file)}.',
      );
    }
    final parsed = _parseArchitectureUnit(context, file);
    if (_hasTopLevelOwner(
      parsed,
      spec.ownerName,
      alternativeOwnerNames: spec.alternativeOwnerNames,
    )) {
      continue;
    }
    return GuardrailViolation(
      filePath: _repoRelPath(context, file),
      line: 1,
      message:
          'interactive API violation: missing required split owner '
          '${spec.ownerName} at ${_repoRelPath(context, file)}.',
    );
  }
  return null;
}

GuardrailViolation? _checkDeletedInteractiveResidualSeams(
  GuardrailContext context,
) {
  for (final filePath in _deletedInteractiveResidualFiles) {
    final file = File(
      repoRelPosixToAbsPath(
        repoRelPosixPath: filePath,
        rootAbsPosixPath: context.rootAbsPosixPath,
      ),
    );
    if (!file.existsSync()) {
      continue;
    }
    final detail = switch (filePath) {
      '/lib/src/interactive/internal/scene_controller_scene_access.dart' =>
        'SceneControllerSceneAccessAdapter is a deleted residual seam and '
            'must not exist.',
      '/lib/src/interactive/internal/scene_controller_selection_access.dart' =>
        'SceneControllerSelectionAccessAdapter is a deleted residual seam '
            'and must not exist.',
      '/lib/src/interactive/internal/scene_controller_facade_assembly.dart' =>
        'assembleSceneControllerFacade is a deleted residual seam and must '
            'not exist.',
      '/lib/src/interactive/internal/scene_controller_pointer_semantics.dart' =>
        'SceneControllerPointerSemantics is a deleted residual seam and '
            'must not exist.',
      '/lib/src/interactive/internal/interactive_selection_actions.dart' =>
        'InteractiveSelectionActions is a deleted routing shell and must '
            'not exist.',
      '/lib/src/interactive/internal/scene_controller_scene_mutations.dart' =>
        'SceneControllerSceneMutations is a deleted routing shell and must '
            'not exist.',
      '/lib/src/interactive/internal/scene_controller_selection_mutations.dart' =>
        'SceneControllerSelectionMutations is a deleted routing shell and '
            'must not exist.',
      '/lib/src/interactive/scene_view_pointer_semantics.dart' =>
        'SceneView pointer-semantics seam is deleted and must not exist.',
      _ => 'deleted residual seam must not exist ($filePath).',
    };
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message: 'interactive API violation: $detail',
    );
  }
  return null;
}

final class _InteractiveOwnerSpec {
  const _InteractiveOwnerSpec({
    required this.relativePath,
    required this.ownerName,
    this.alternativeOwnerNames = const <String>{},
  });

  final String relativePath;
  final String ownerName;
  final Set<String> alternativeOwnerNames;
}
