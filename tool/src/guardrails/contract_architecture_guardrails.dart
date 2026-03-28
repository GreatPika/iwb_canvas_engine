import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../guardrail_support/guardrail_ast_utils.dart';
import '../guardrail_support/guardrail_context.dart';
import '../guardrail_support/guardrail_path_utils.dart';
import 'public_surface_guardrails.dart';

const String _contractInternalDir = '/lib/src/contract/internal/';

const Set<String> _allowedContractInternalSurfaces = <String>{
  '/lib/src/contract/internal/node_boundary_schema.dart',
  '/lib/src/contract/internal/snapshot_fast_path.dart',
};

const Set<String> _removedResidualContractFiles = <String>{
  '/lib/src/contract/internal/node_boundary_schema_patch.part.dart',
  '/lib/src/contract/internal/node_boundary_schema_spec.part.dart',
  '/lib/src/contract/internal/node_boundary_schema_snapshot.part.dart',
  '/lib/src/contract/internal/node_boundary_schema_primitives.part.dart',
  '/lib/src/contract/internal/snapshot_fast_path.part.dart',
  '/lib/src/contract/internal/node_spec_fast_path.part.dart',
  '/lib/src/contract/internal/node_patch_fast_path.part.dart',
};

Future<List<GuardrailViolation>> runContractArchitectureGuardrails({
  required GuardrailContext context,
}) async {
  final violations = <GuardrailViolation>[];

  final contractFiles = _collectDartFiles(
    Directory(
      '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
      'src${Platform.pathSeparator}contract',
    ),
  );
  for (final file in contractFiles) {
    final violation = _checkContractFile(context, file);
    if (violation != null) {
      violations.add(violation);
      return violations;
    }
  }

  final removedResidualViolation = _checkRemovedResidualContractFiles(context);
  if (removedResidualViolation != null) {
    violations.add(removedResidualViolation);
    return violations;
  }

  final libFiles = _collectDartFiles(
    Directory(
      '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
      'src',
    ),
  );
  for (final file in libFiles) {
    final violation = _checkNonContractDirectiveBoundaries(context, file);
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

GuardrailViolation? _checkContractFile(GuardrailContext context, File file) {
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
            'contract architecture violation: lib/src/contract/** must stay '
            'part-free after final architecture closure.',
      );
    }
  }

  return null;
}

GuardrailViolation? _checkNonContractDirectiveBoundaries(
  GuardrailContext context,
  File file,
) {
  final filePosixPath = _repoRelPath(context, file);
  if (!filePosixPath.startsWith('/lib/src/')) {
    return null;
  }
  if (filePosixPath.startsWith('/lib/src/contract/')) {
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
      if (target == null || !target.startsWith(_contractInternalDir)) {
        continue;
      }
      if (_allowedContractInternalSurfaces.contains(target)) {
        continue;
      }
      return GuardrailViolation(
        filePath: filePosixPath,
        line: lineForOffset(parsed, uriRef.offset),
        message:
            'contract architecture violation: non-contract code must import '
            'canonical contract surfaces instead of importing or re-exporting '
            'internal contract module '
            '${target.substring(_contractInternalDir.length)}.',
      );
    }
  }

  return null;
}

GuardrailViolation? _checkRemovedResidualContractFiles(
  GuardrailContext context,
) {
  for (final filePosixPath in _removedResidualContractFiles) {
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
          'contract architecture violation: removed residual seam '
          '${filePosixPath.substring('/lib/src/contract/internal/'.length)} '
          'must not reappear after step 55 closure.',
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
    onFailure: _onContractGuardrailParseFailure,
  );
}

Never _onContractGuardrailParseFailure({
  required String filePathForDiag,
  required String resultType,
}) {
  throw GuardrailToolFailure(
    GuardrailViolation(
      filePath: filePathForDiag,
      line: 1,
      message:
          'contract architecture violation: failed to parse $filePathForDiag '
          '($resultType).',
    ),
  );
}
