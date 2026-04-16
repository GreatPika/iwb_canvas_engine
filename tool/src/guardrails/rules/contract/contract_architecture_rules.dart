import 'dart:io';

import '../../support/guardrail_context.dart';
import '../../core/guardrail_violation.dart';
import '../../core/guardrail_runner_support.dart';

const String _contractInternalDir = '/lib/src/contract/internal/';
const String _contractPathPrefix = '/lib/src/contract/';

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

  final contractFiles = collectSortedDartFiles(
    Directory(
      '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}src${Platform.pathSeparator}contract',
    ),
  );
  for (final file in contractFiles) {
    final violation = _checkContractFile(context, file);
    if (violation != null) {
      violations.add(violation);
      return violations;
    }
  }

  final removedResidualViolation = checkRemovedResidualFiles(
    context: context,
    removedResidualFiles: _removedResidualContractFiles,
    trimPrefix: _contractInternalDir,
    messageForTail: (tail) =>
        'contract architecture violation: removed residual seam $tail must not reappear after step 55 closure.',
  );
  if (removedResidualViolation != null) {
    violations.add(removedResidualViolation);
    return violations;
  }

  final libFiles = collectSortedDartFiles(
    Directory(
      '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}src',
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

GuardrailViolation? _checkContractFile(GuardrailContext context, File file) {
  final filePosixPath = repoRelPathForFile(context, file);
  final parsed = parseGuardrailUnitOrThrow(
    context: context,
    file: file,
    filePosixPath: filePosixPath,
    failureFormatter: _formatContractParseFailure,
  );

  return checkPartDirectiveBan(
    parsed: parsed,
    filePosixPath: filePosixPath,
    violationMessage:
        'contract architecture violation: lib/src/contract/** must stay part-free after final architecture closure.',
  );
}

GuardrailViolation? _checkNonContractDirectiveBoundaries(
  GuardrailContext context,
  File file,
) {
  final filePosixPath = repoRelPathForFile(context, file);
  if (!filePosixPath.startsWith('/lib/src/') ||
      filePosixPath.startsWith(_contractPathPrefix)) {
    return null;
  }

  final parsed = parseGuardrailUnitOrThrow(
    context: context,
    file: file,
    filePosixPath: filePosixPath,
    failureFormatter: _formatContractParseFailure,
  );

  return checkDirectiveBoundaryViolation(
    context: context,
    parsed: parsed,
    filePosixPath: filePosixPath,
    isForbiddenTarget: (target) =>
        target.startsWith(_contractInternalDir) &&
        !_allowedContractInternalSurfaces.contains(target),
    messageForTarget: (target) =>
        'contract architecture violation: non-contract code must import canonical contract surfaces instead of importing or re-exporting internal contract module ${target.substring(_contractInternalDir.length)}.',
  );
}

String _formatContractParseFailure({
  required String filePathForDiag,
  required String resultType,
}) {
  return 'contract architecture violation: failed to parse $filePathForDiag ($resultType).';
}
