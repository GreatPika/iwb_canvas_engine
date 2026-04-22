import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../support/guardrail_context.dart';
import '../../support/guardrail_ast_utils.dart' show lineForOffset;
import '../../core/guardrail_element_utils.dart' as element_utils;
import '../../core/guardrail_rule.dart';
import '../../core/guardrail_rule_metadata.dart';
import '../../core/guardrail_run_state.dart';
import '../../core/guardrail_violation.dart';
import '../../core/guardrail_runner_support.dart';

final GuardrailRule modelArchitectureGuardrailRule = GuardrailRule(
  metadata: const GuardrailRuleMetadata(
    id: 'model-architecture',
    invariantIds: <String>[
      'INV-ENG-MODEL-ARCHITECTURE-BOUNDARY',
      'INV-ENG-VALIDATED-IMPORT-MATERIALIZATION-BOUNDARY',
      'INV-ENG-RUNTIME-SCENE-STRUCTURE-OWNER',
      'INV-ENG-RUNTIME-NODE-VALUE-OWNERS',
    ],
    area: 'model',
    description:
        'Checks model-layer file ownership, runtime owner boundaries, and '
        'mutation restrictions.',
  ),
  run: _runModelArchitectureGuardrailRule,
);

const Set<String> _restrictedModelOwnerModules = <String>{
  '/lib/src/model/document_locator.dart',
  '/lib/src/model/document_node_patch.dart',
  '/lib/src/model/document_node_patch_common.dart',
  '/lib/src/model/document_node_patch_image.dart',
  '/lib/src/model/document_node_patch_line.dart',
  '/lib/src/model/document_node_patch_path.dart',
  '/lib/src/model/document_node_patch_rect.dart',
  '/lib/src/model/document_node_patch_stroke.dart',
  '/lib/src/model/document_node_patch_text.dart',
  '/lib/src/model/document_scene_edit.dart',
  '/lib/src/model/document_scene_insert.dart',
  '/lib/src/model/document_selection.dart',
  '/lib/src/model/scene_builder.dart',
  '/lib/src/model/scene_builder_decode_image.dart',
  '/lib/src/model/scene_builder_decode_json.dart',
  '/lib/src/model/scene_builder_decode_layers.dart',
  '/lib/src/model/scene_builder_decode_line.dart',
  '/lib/src/model/scene_builder_decode_node_common.dart',
  '/lib/src/model/scene_builder_decode_node_family.dart',
  '/lib/src/model/scene_builder_decode_path.dart',
  '/lib/src/model/scene_builder_decode_rect.dart',
  '/lib/src/model/scene_builder_decode_scene.dart',
  '/lib/src/model/scene_builder_decode_scene_metadata.dart',
  '/lib/src/model/scene_builder_decode_stroke.dart',
  '/lib/src/model/scene_builder_decode_text.dart',
  '/lib/src/model/scene_builder_json_parse.dart',
  '/lib/src/model/scene_builder_json_require.dart',
  '/lib/src/model/scene_import_draft.dart',
  '/lib/src/model/scene_import_draft_from_snapshot.dart',
  '/lib/src/model/scene_from_import_draft.dart',
  '/lib/src/model/scene_from_snapshot.dart',
  '/lib/src/model/scene_policy.dart',
  '/lib/src/model/scene_snapshot_from_scene.dart',
  '/lib/src/model/scene_validation_path_surface.dart',
  '/lib/src/model/scene_node_boundary_mapping_common.dart',
  '/lib/src/model/scene_node_boundary_mapping.dart',
  '/lib/src/model/scene_node_boundary_mapping_image.dart',
  '/lib/src/model/scene_node_boundary_mapping_line.dart',
  '/lib/src/model/scene_node_boundary_mapping_path.dart',
  '/lib/src/model/scene_node_boundary_mapping_rect.dart',
  '/lib/src/model/scene_node_boundary_mapping_stroke.dart',
  '/lib/src/model/scene_node_boundary_mapping_text.dart',
  '/lib/src/model/scene_value_validation_node.dart',
  '/lib/src/model/scene_value_validation_palette_grid.dart',
  '/lib/src/model/scene_value_validation_primitives.dart',
  '/lib/src/model/scene_value_validation_support.dart',
  '/lib/src/model/scene_value_validation_scene.dart',
};

const Set<String> _guardedRuntimeNodeOwnerFiles = <String>{
  '/lib/src/core/scene_node.dart',
  '/lib/src/core/box_nodes.dart',
  '/lib/src/core/vector_nodes.dart',
  '/lib/src/core/path_node.dart',
  '/lib/src/core/text_node_layout_state.dart',
};

const Map<String, Set<String>>
_guardedRuntimeOwnerClassesByFile = <String, Set<String>>{
  '/lib/src/core/scene_node.dart': <String>{'SceneNode'},
  '/lib/src/core/box_nodes.dart': <String>{'ImageNode', 'TextNode', 'RectNode'},
  '/lib/src/core/vector_nodes.dart': <String>{'StrokeNode', 'LineNode'},
  '/lib/src/core/path_node.dart': <String>{'PathNode'},
  '/lib/src/core/text_node_layout_state.dart': <String>{'TextNodeLayoutState'},
};

const Set<String> _guardedRuntimeNodeMutableFields = <String>{
  'transform',
  'hitPadding',
  'imageId',
  'size',
  'naturalSize',
  'text',
  'fontSize',
  'fontFamily',
  'maxWidth',
  'lineHeight',
  'start',
  'end',
  'thickness',
  'strokeWidth',
  'svgPathData',
};

const Set<String> _guardedSceneLayersMutationMethods = <String>{
  'add',
  'insert',
  'remove',
  'removeAt',
  'removeLast',
  'removeRange',
  'removeWhere',
  'retainWhere',
  'clear',
  'fillRange',
  'replaceRange',
  'setAll',
  'sort',
  'shuffle',
};

const Set<String> _removedResidualModelFiles = <String>{
  '/lib/src/model/scene_node_boundary_mapping_support.dart',
};

Future<List<GuardrailViolation>> runModelArchitectureGuardrails({
  required GuardrailContext context,
}) async {
  final violations = <GuardrailViolation>[];

  final modelFiles = collectSortedLibSrcDartFiles(
    context,
    relativePath: 'model',
  );
  final modelFileViolation = firstViolationInFiles(
    modelFiles,
    (file) => _checkModelFile(context, file),
  );
  if (modelFileViolation != null) {
    violations.add(modelFileViolation);
    return violations;
  }

  final removedResidualViolation = checkRemovedResidualFiles(
    context: context,
    removedResidualFiles: _removedResidualModelFiles,
    trimPrefix: '/lib/src/model/',
    messageForTail: (tail) =>
        'model architecture violation: removed residual seam $tail must not reappear after step 48 closure.',
  );
  if (removedResidualViolation != null) {
    violations.add(removedResidualViolation);
    return violations;
  }

  final controllerFiles = collectSortedLibSrcDartFiles(
    context,
    relativePath: 'controller',
  );
  final controllerViolation = await firstAsyncViolationInFiles(
    controllerFiles,
    (file) => _checkControllerStructuralMutationGuardrail(context, file),
  );
  if (controllerViolation != null) {
    violations.add(controllerViolation);
    return violations;
  }

  final coreFiles = collectSortedLibSrcDartFiles(context, relativePath: 'core');
  final runtimeOwnerViolation = firstViolationInFiles(
    coreFiles,
    (file) => _checkRuntimeNodeOwnerFieldGuardrail(context, file),
  );
  if (runtimeOwnerViolation != null) {
    violations.add(runtimeOwnerViolation);
    return violations;
  }

  final libFiles = collectSortedLibSrcDartFiles(context);
  final directiveViolation = firstViolationInFiles(
    libFiles,
    (file) => _checkNonModelDirectiveBoundaries(context, file),
  );
  if (directiveViolation != null) {
    violations.add(directiveViolation);
    return violations;
  }

  return violations;
}

Future<List<GuardrailViolation>> _runModelArchitectureGuardrailRule(
  GuardrailContext context,
  GuardrailRunState state,
) {
  return runModelArchitectureGuardrails(context: context);
}

GuardrailViolation? _checkModelFile(GuardrailContext context, File file) {
  return checkOwnedLayerFile(
    context: context,
    file: file,
    failureFormatter: _formatModelParseFailure,
    partDirectiveBanMessage:
        'model architecture violation: lib/src/model/** must stay part-free after final architecture closure.',
    extraCheck: (parsed, filePosixPath) {
      final validatedImportProofOwnerViolation =
          _checkValidatedImportProofOwner(parsed, filePosixPath);
      if (validatedImportProofOwnerViolation != null) {
        return validatedImportProofOwnerViolation;
      }
      if (filePosixPath != '/lib/src/model/document.dart') {
        if (filePosixPath == '/lib/src/model/scene_policy.dart') {
          return _checkScenePolicyImportDiagnosticOwnership(
            parsed,
            filePosixPath,
          );
        }
        if (filePosixPath == '/lib/src/model/scene_from_snapshot.dart') {
          return _checkSceneImportSnapshotFacadeOwnership(
            parsed,
            filePosixPath,
          );
        }
        if (filePosixPath == '/lib/src/model/scene_from_import_draft.dart') {
          return _checkValidatedImportMaterializationBoundary(
                parsed,
                filePosixPath,
              ) ??
              _checkForbiddenRawSnapshotMaterialization(parsed, filePosixPath);
        }
        if (filePosixPath ==
            '/lib/src/model/scene_value_validation_scene.dart') {
          return _checkForbiddenRawSnapshotMaterialization(
            parsed,
            filePosixPath,
          );
        }
        return null;
      }
      return checkDirectiveBoundaryViolation(
        context: context,
        parsed: parsed,
        filePosixPath: filePosixPath,
        isForbiddenTarget: (target) =>
            target == '/lib/src/model/scene_builder.dart',
        messageForTarget: (_) =>
            'model architecture violation: document.dart must consume scene_from_snapshot.dart / scene_snapshot_from_scene.dart directly and must not import scene_builder.dart.',
      );
    },
  );
}

GuardrailViolation? _checkSceneImportSnapshotFacadeOwnership(
  ParsedUnitResult parsed,
  String filePosixPath,
) {
  for (final declaration in parsed.unit.declarations) {
    if (declaration is! FunctionDeclaration) {
      continue;
    }
    if (declaration.name.lexeme != 'sceneFromSnapshot') {
      continue;
    }
    return GuardrailViolation(
      filePath: filePosixPath,
      line: lineForOffset(parsed, declaration.name.offset),
      message:
          'model architecture violation: scene_from_snapshot.dart must expose only sceneImportFromSnapshot(...) and must not reintroduce sceneFromSnapshot(...).',
    );
  }
  return null;
}

GuardrailViolation? _checkValidatedImportProofOwner(
  ParsedUnitResult parsed,
  String filePosixPath,
) {
  const ownerPath = '/lib/src/model/scene_policy.dart';
  for (final declaration in parsed.unit.declarations) {
    if (declaration is! ClassDeclaration) {
      continue;
    }
    if (declaration.name.lexeme != 'ValidatedSceneImportDraft') {
      continue;
    }
    if (filePosixPath == ownerPath) {
      return null;
    }
    return GuardrailViolation(
      filePath: filePosixPath,
      line: lineForOffset(parsed, declaration.name.offset),
      message:
          'model architecture violation: scene_policy.dart must remain the only owner that declares ValidatedSceneImportDraft and mints import proof.',
    );
  }
  return null;
}

GuardrailViolation? _checkValidatedImportMaterializationBoundary(
  ParsedUnitResult parsed,
  String filePosixPath,
) {
  for (final declaration in parsed.unit.declarations) {
    if (declaration is! FunctionDeclaration) {
      continue;
    }
    final parameterList = declaration.functionExpression.parameters;
    if (parameterList == null || parameterList.parameters.isEmpty) {
      continue;
    }
    final firstParameter = parameterList.parameters.first;
    if (!_isRawSceneImportDraftParameter(firstParameter)) {
      continue;
    }
    if (declaration.name.lexeme == 'sceneImportFromDraft') {
      continue;
    }
    return GuardrailViolation(
      filePath: filePosixPath,
      line: lineForOffset(parsed, firstParameter.offset),
      message:
          'model architecture violation: scene_from_import_draft.dart must materialize scenes only from ValidatedSceneImportDraft.',
    );
  }
  return null;
}

GuardrailViolation? _checkForbiddenRawSnapshotMaterialization(
  ParsedUnitResult parsed,
  String filePosixPath,
) {
  final offset = parsed.content.indexOf('materializeNodeSnapshot(');
  if (offset < 0) {
    return null;
  }
  return GuardrailViolation(
    filePath: filePosixPath,
    line: lineForOffset(parsed, offset),
    message:
        'model architecture violation: validated import and draft validation paths must not materialize raw public snapshot wrappers from raw backing.',
  );
}

GuardrailViolation? _checkScenePolicyImportDiagnosticOwnership(
  ParsedUnitResult parsed,
  String filePosixPath,
) {
  final visitor = _ScenePolicyImportDiagnosticOwnershipVisitor();
  parsed.unit.accept(visitor);
  final violation = visitor.firstViolation;
  if (violation == null) {
    return null;
  }
  return GuardrailViolation(
    filePath: filePosixPath,
    line: lineForOffset(parsed, violation.offset),
    message:
        'model architecture violation: scene_policy.dart must not own direct import-range diagnostics; keep import diagnostic paths inside scene_value_validation*.dart owners.',
  );
}

Future<GuardrailViolation?> _checkControllerStructuralMutationGuardrail(
  GuardrailContext context,
  File file,
) async {
  final filePosixPath = repoRelPathForFile(context, file);
  if (!filePosixPath.startsWith('/lib/src/controller/')) {
    return null;
  }

  final resolved = await context.getResolvedUnitResult(file.absolute.path);
  if (resolved == null) {
    return null;
  }
  final visitor = _ControllerLayerMutationVisitor(context: context);
  resolved.unit.accept(visitor);

  final violation = visitor.firstViolation;
  if (violation == null) {
    return null;
  }
  return GuardrailViolation(
    filePath: filePosixPath,
    line: resolved.lineInfo.getLocation(violation.offset).lineNumber,
    message:
        'model architecture violation: controller code must not mutate scene.layers directly via ${violation.operationLabel}; use model-owned scene layer mutation helpers instead.',
  );
}

GuardrailViolation? _checkRuntimeNodeOwnerFieldGuardrail(
  GuardrailContext context,
  File file,
) {
  final filePosixPath = repoRelPathForFile(context, file);
  if (!_guardedRuntimeNodeOwnerFiles.contains(filePosixPath)) {
    return null;
  }

  final parsed = parseGuardrailUnitOrThrow(
    context: context,
    file: file,
    filePosixPath: filePosixPath,
    failureFormatter: _formatModelParseFailure,
  );
  final guardedClasses =
      _guardedRuntimeOwnerClassesByFile[filePosixPath] ?? const <String>{};

  for (final declaration
      in parsed.unit.declarations.whereType<ClassDeclaration>()) {
    if (!guardedClasses.contains(declaration.name.lexeme)) {
      continue;
    }
    for (final member in declaration.members.whereType<FieldDeclaration>()) {
      for (final variable in member.fields.variables) {
        final fieldName = variable.name.lexeme;
        if (!_guardedRuntimeNodeMutableFields.contains(fieldName)) {
          continue;
        }
        return GuardrailViolation(
          filePath: filePosixPath,
          line: parsed.lineInfo.getLocation(variable.name.offset).lineNumber,
          message:
              'model architecture violation: constrained runtime field $fieldName must not be stored as a direct core-owner field; keep it behind a validated getter/setter owner surface.',
        );
      }
    }
  }

  return null;
}

GuardrailViolation? _checkNonModelDirectiveBoundaries(
  GuardrailContext context,
  File file,
) {
  return checkExternalDirectiveBoundaryFile(
    context: context,
    file: file,
    ownedPathPrefix: '/lib/src/model/',
    failureFormatter: _formatModelParseFailure,
    isForbiddenTarget: _restrictedModelOwnerModules.contains,
    messageForTarget: (target) =>
        'model architecture violation: non-model code must use the canonical model facades instead of importing or re-exporting internal owner module ${target.substring('/lib/src/model/'.length)}.',
  );
}

String _formatModelParseFailure({
  required String filePathForDiag,
  required String resultType,
}) {
  return 'model architecture violation: failed to parse Dart file for guardrail analysis (result: $resultType).';
}

final class _ControllerLayerMutationVisitor extends RecursiveAstVisitor<void> {
  _ControllerLayerMutationVisitor({required this.context});

  final GuardrailContext context;
  _ControllerLayerMutationOccurrence? firstViolation;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    firstViolation ??= _matchControllerLayerMutation(node, context: context);
    if (firstViolation != null) {
      return;
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    firstViolation ??= _matchControllerLayerAssignment(node, context: context);
    if (firstViolation != null) {
      return;
    }
    super.visitAssignmentExpression(node);
  }
}

final class _ScenePolicyImportDiagnosticOwnershipVisitor
    extends RecursiveAstVisitor<void> {
  _ScenePolicyImportDiagnosticOwnershipOccurrence? firstViolation;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (firstViolation != null) {
      return;
    }
    final target = node.target;
    if (target is SimpleIdentifier &&
        target.name == 'SceneDataException' &&
        node.methodName.name == 'outOfRange') {
      firstViolation = _ScenePolicyImportDiagnosticOwnershipOccurrence(
        offset: node.offset,
      );
      return;
    }
    super.visitMethodInvocation(node);
  }
}

final class _ScenePolicyImportDiagnosticOwnershipOccurrence {
  const _ScenePolicyImportDiagnosticOwnershipOccurrence({required this.offset});

  final int offset;
}

bool _isRawSceneImportDraftParameter(FormalParameter parameter) {
  if (parameter is DefaultFormalParameter) {
    return _isRawSceneImportDraftParameter(parameter.parameter);
  }
  final TypeAnnotation? parameterType = switch (parameter) {
    SimpleFormalParameter(:final type) => type,
    _ => null,
  };
  if (parameterType is! NamedType) {
    return false;
  }
  return parameterType.name.lexeme == 'SceneImportDraft';
}

_ControllerLayerMutationOccurrence? _matchControllerLayerMutation(
  MethodInvocation node, {
  required GuardrailContext context,
}) {
  final methodName = node.methodName.name;
  if (!_guardedSceneLayersMutationMethods.contains(methodName)) {
    return null;
  }
  final target =
      node.target ?? node.thisOrAncestorOfType<CascadeExpression>()?.target;
  if (target == null || !_isSceneLayersAccess(target, context: context)) {
    return null;
  }
  return _ControllerLayerMutationOccurrence(
    operationLabel: '.$methodName(...)',
    offset: node.methodName.offset,
  );
}

_ControllerLayerMutationOccurrence? _matchControllerLayerAssignment(
  AssignmentExpression node, {
  required GuardrailContext context,
}) {
  final leftHandSide = node.leftHandSide;
  if (leftHandSide is! IndexExpression) {
    return null;
  }
  final target = leftHandSide.target;
  if (target == null || !_isSceneLayersAccess(target, context: context)) {
    return null;
  }
  return _ControllerLayerMutationOccurrence(
    operationLabel: '[]=',
    offset: node.operator.offset,
  );
}

bool _isSceneLayersAccess(
  Expression expression, {
  required GuardrailContext context,
}) {
  final unwrapped = switch (expression) {
    ParenthesizedExpression(:final expression) => expression,
    _ => expression,
  };
  final receiver = switch (unwrapped) {
    PropertyAccess(:final target, :final propertyName)
        when target != null && propertyName.name == 'layers' =>
      target,
    PrefixedIdentifier(:final prefix, :final identifier)
        when identifier.name == 'layers' =>
      prefix,
    _ => null,
  };
  if (receiver == null) {
    return false;
  }

  final type = receiver.staticType;
  final element = type?.element;
  if (element == null || element.displayName != 'Scene') {
    return false;
  }

  return element_utils.repoRelPathForElement(
        element: element,
        context: context,
        requireLibPrefix: true,
      ) ==
      '/lib/src/core/scene.dart';
}

final class _ControllerLayerMutationOccurrence {
  const _ControllerLayerMutationOccurrence({
    required this.operationLabel,
    required this.offset,
  });

  final String operationLabel;
  final int offset;
}
