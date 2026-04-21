import 'dart:io';

import '../../support/guardrail_context.dart';
import '../../core/guardrail_rule.dart';
import '../../core/guardrail_rule_metadata.dart';
import '../../core/guardrail_run_state.dart';
import '../../core/guardrail_violation.dart';
import '../../core/guardrail_runner_support.dart';

final GuardrailRule contractArchitectureGuardrailRule = GuardrailRule(
  metadata: const GuardrailRuleMetadata(
    id: 'contract-architecture',
    invariantIds: <String>['INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY'],
    area: 'contract',
    description:
        'Protects contract-layer file ownership and internal surface import '
        'boundaries.',
  ),
  run: _runContractArchitectureGuardrailRule,
);

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

  final contractFiles = collectSortedLibSrcDartFiles(
    context,
    relativePath: 'contract',
  );
  final contractFileViolation = firstViolationInFiles(
    contractFiles,
    (file) => _checkContractFile(context, file),
  );
  if (contractFileViolation != null) {
    violations.add(contractFileViolation);
    return violations;
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

  final libFiles = collectSortedLibSrcDartFiles(context);
  final directiveViolation = firstViolationInFiles(
    libFiles,
    (file) => _checkNonContractDirectiveBoundaries(context, file),
  );
  if (directiveViolation != null) {
    violations.add(directiveViolation);
    return violations;
  }

  return violations;
}

Future<List<GuardrailViolation>> _runContractArchitectureGuardrailRule(
  GuardrailContext context,
  GuardrailRunState state,
) {
  return runContractArchitectureGuardrails(context: context);
}

GuardrailViolation? _checkContractFile(GuardrailContext context, File file) {
  return checkOwnedLayerFile(
    context: context,
    file: file,
    failureFormatter: _formatContractParseFailure,
    partDirectiveBanMessage:
        'contract architecture violation: lib/src/contract/** must stay part-free after final architecture closure.',
  );
}

GuardrailViolation? _checkNonContractDirectiveBoundaries(
  GuardrailContext context,
  File file,
) {
  return checkExternalDirectiveBoundaryFile(
    context: context,
    file: file,
    ownedPathPrefix: _contractPathPrefix,
    failureFormatter: _formatContractParseFailure,
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
