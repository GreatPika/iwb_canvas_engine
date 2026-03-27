import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';

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
  '/lib/src/model/document_selection.dart',
  '/lib/src/model/scene_builder.dart',
  '/lib/src/model/scene_builder_decode_image.dart',
  '/lib/src/model/scene_builder_decode_json.dart',
  '/lib/src/model/scene_builder_decode_line.dart',
  '/lib/src/model/scene_builder_decode_node_common.dart',
  '/lib/src/model/scene_builder_decode_node_family.dart',
  '/lib/src/model/scene_builder_decode_path.dart',
  '/lib/src/model/scene_builder_decode_rect.dart',
  '/lib/src/model/scene_builder_decode_scene.dart',
  '/lib/src/model/scene_builder_decode_stroke.dart',
  '/lib/src/model/scene_builder_decode_text.dart',
  '/lib/src/model/scene_builder_json_parse.dart',
  '/lib/src/model/scene_builder_json_require.dart',
  '/lib/src/model/scene_from_snapshot.dart',
  '/lib/src/model/scene_policy.dart',
  '/lib/src/model/scene_snapshot_from_scene.dart',
  '/lib/src/model/scene_node_boundary_mapping_common.dart',
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
