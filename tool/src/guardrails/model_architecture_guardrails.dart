import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import '../guardrail_support/guardrail_ast_utils.dart';
import '../guardrail_support/guardrail_context.dart';
import '../guardrail_support/guardrail_path_utils.dart';
import 'public_surface_guardrails.dart';

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
  '/lib/src/model/scene_value_validation_top_level.dart',
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

Future<List<GuardrailViolation>> runModelArchitectureGuardrails({
  required GuardrailContext context,
}) async {
  final violations = <GuardrailViolation>[];

  final modelFiles = _collectDartFiles(
    Directory(
      '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
      'src${Platform.pathSeparator}model',
    ),
  );
  for (final file in modelFiles) {
    final violation = _checkModelFile(context, file);
    if (violation != null) {
      violations.add(violation);
      return violations;
    }
  }

  final removedResidualViolation = _checkRemovedModelResidualFiles(context);
  if (removedResidualViolation != null) {
    violations.add(removedResidualViolation);
    return violations;
  }

  final controllerFiles = _collectDartFiles(
    Directory(
      '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
      'src${Platform.pathSeparator}controller',
    ),
  );
  for (final file in controllerFiles) {
    final violation = await _checkControllerStructuralMutationGuardrail(
      context,
      file,
    );
    if (violation != null) {
      violations.add(violation);
      return violations;
    }
  }

  final coreFiles = _collectDartFiles(
    Directory(
      '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
      'src${Platform.pathSeparator}core',
    ),
  );
  for (final file in coreFiles) {
    final violation = _checkRuntimeNodeOwnerFieldGuardrail(context, file);
    if (violation != null) {
      violations.add(violation);
      return violations;
    }
  }

  final libFiles = _collectDartFiles(
    Directory(
      '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
      'src',
    ),
  );
  for (final file in libFiles) {
    final violation = _checkNonModelDirectiveBoundaries(context, file);
    if (violation != null) {
      violations.add(violation);
      return violations;
    }
  }

  return violations;
}

List<File> _collectDartFiles(Directory directory) {
  if (!directory.existsSync()) {
    return const <File>[];
  }

  final files =
      directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return files;
}

GuardrailViolation? _checkModelFile(GuardrailContext context, File file) {
  final filePosixPath = _repoRelPath(context, file);
  final parsed = _parseUnit(
    context: context,
    file: file,
    filePosixPath: filePosixPath,
  );

  for (final directive in parsed.unit.directives) {
    if (directive is PartDirective || directive is PartOfDirective) {
      return GuardrailViolation(
        filePath: filePosixPath,
        line: lineForOffset(parsed, directive.offset),
        message:
            'model architecture violation: lib/src/model/** must stay part-free '
            'after final architecture closure.',
      );
    }
  }

  if (filePosixPath == '/lib/src/model/document.dart') {
    for (final directive
        in parsed.unit.directives.whereType<ImportDirective>()) {
      for (final uriRef in collectDirectiveUriRefs(directive)) {
        final target = resolveToRepoRelTargetPosix(
          targetPosix: uriRef.uri,
          packageName: context.packageName,
          fileDirRepoRelPosix: posixDirname(filePosixPath),
        );
        if (target == '/lib/src/model/scene_builder.dart') {
          return GuardrailViolation(
            filePath: filePosixPath,
            line: lineForOffset(parsed, uriRef.offset),
            message:
                'model architecture violation: document.dart must consume '
                'scene_from_snapshot.dart / scene_snapshot_from_scene.dart '
                'directly and must not import scene_builder.dart.',
          );
        }
      }
    }
  }

  return null;
}

Future<GuardrailViolation?> _checkControllerStructuralMutationGuardrail(
  GuardrailContext context,
  File file,
) async {
  final filePosixPath = _repoRelPath(context, file);
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
        'model architecture violation: controller code must not mutate '
        'scene.layers directly via ${violation.operationLabel}; use the '
        'model-owned layer insertion helpers instead.',
  );
}

GuardrailViolation? _checkRuntimeNodeOwnerFieldGuardrail(
  GuardrailContext context,
  File file,
) {
  final filePosixPath = _repoRelPath(context, file);
  if (!_guardedRuntimeNodeOwnerFiles.contains(filePosixPath)) {
    return null;
  }

  final parsed = _parseUnit(
    context: context,
    file: file,
    filePosixPath: filePosixPath,
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
          line: lineForOffset(parsed, variable.name.offset),
          message:
              'model architecture violation: constrained runtime field '
              '$fieldName must not be stored as a direct core-owner field; '
              'keep it behind a validated getter/setter owner surface.',
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
  final filePosixPath = _repoRelPath(context, file);
  if (!filePosixPath.startsWith('/lib/src/')) {
    return null;
  }
  if (filePosixPath.startsWith('/lib/src/model/')) {
    return null;
  }

  final parsed = _parseUnit(
    context: context,
    file: file,
    filePosixPath: filePosixPath,
  );

  for (final directive
      in parsed.unit.directives.whereType<UriBasedDirective>()) {
    for (final uriRef in collectDirectiveUriRefs(directive)) {
      final target = resolveToRepoRelTargetPosix(
        targetPosix: uriRef.uri,
        packageName: context.packageName,
        fileDirRepoRelPosix: posixDirname(filePosixPath),
      );
      if (target == null || !_restrictedModelOwnerModules.contains(target)) {
        continue;
      }
      return GuardrailViolation(
        filePath: filePosixPath,
        line: lineForOffset(parsed, uriRef.offset),
        message:
            'model architecture violation: non-model code must use the '
            'canonical model facades instead of importing or re-exporting '
            'internal owner module '
            '${target.substring('/lib/src/model/'.length)}.',
      );
    }
  }

  return null;
}

GuardrailViolation? _checkRemovedModelResidualFiles(GuardrailContext context) {
  const removedResidualFiles = <String>{
    '/lib/src/model/scene_node_boundary_mapping_support.dart',
  };

  for (final filePosixPath in removedResidualFiles) {
    final file = File(
      repoRelPosixToAbsPath(
        repoRelPosixPath: filePosixPath,
        rootAbsPosixPath: context.rootAbsPosixPath,
      ),
    );
    if (!file.existsSync()) {
      continue;
    }
    return GuardrailViolation(
      filePath: filePosixPath,
      line: 1,
      message:
          'model architecture violation: removed residual seam '
          '${filePosixPath.substring('/lib/src/model/'.length)} must not '
          'reappear after step 48 closure.',
    );
  }

  return null;
}

String _repoRelPath(GuardrailContext context, File file) {
  return toRepoRelPosixPath(
    absPosixPath: toPosixPath(file.absolute.path),
    rootAbsPosixPath: context.rootAbsPosixPath,
  );
}

ParsedUnitResult _parseUnit({
  required GuardrailContext context,
  required File file,
  required String filePosixPath,
}) {
  return parseUnitOrFail(
    context: context,
    absPath: file.absolute.path,
    filePathForDiag: filePosixPath,
    onFailure: _onModelGuardrailParseFailure,
  );
}

Never _onModelGuardrailParseFailure({
  required String filePathForDiag,
  required String resultType,
}) {
  throw GuardrailToolFailure(
    GuardrailViolation(
      filePath: filePathForDiag,
      line: 1,
      message:
          'model architecture violation: failed to parse Dart file for '
          'guardrail analysis (result: $resultType).',
    ),
  );
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

_ControllerLayerMutationOccurrence? _matchControllerLayerMutation(
  MethodInvocation node, {
  required GuardrailContext context,
}
) {
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
}
) {
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
        when target != null && propertyName.name == 'layers' => target,
    PrefixedIdentifier(:final prefix, :final identifier)
        when identifier.name == 'layers' => prefix,
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

  return _repoRelForElement(element: element, context: context) ==
      '/lib/src/core/scene.dart';
}

String? _repoRelForElement({
  required Element? element,
  required GuardrailContext context,
}) {
  if (element == null) {
    return null;
  }
  final source = element.firstFragment.libraryFragment?.source;
  if (source == null) {
    return null;
  }
  final absPosixPath = toPosixPath(source.fullName);
  if (!absPosixPath.startsWith('${context.rootAbsPosixPath}/')) {
    return null;
  }
  final repoRelPath = toRepoRelPosixPath(
    absPosixPath: absPosixPath,
    rootAbsPosixPath: context.rootAbsPosixPath,
  );
  return repoRelPath.startsWith('/lib/') ? repoRelPath : null;
}

final class _ControllerLayerMutationOccurrence {
  const _ControllerLayerMutationOccurrence({
    required this.operationLabel,
    required this.offset,
  });

  final String operationLabel;
  final int offset;
}
