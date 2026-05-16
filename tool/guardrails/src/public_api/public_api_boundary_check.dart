import 'dart:io';

import '../guardrail_definition.dart';
import 'public_api_name_inventory.dart';
import 'public_export_surface_reader.dart';
import 'public_signature_type_check.dart';
import 'resolved_public_surface_reader.dart';

final class PublicApiBoundaryCheck {
  PublicApiBoundaryCheck(this.root);

  final Directory root;

  Future<GuardrailCheckResult> publicExportsComplete() async {
    final expectedNames = readExpectedPublicNames(root);
    final structuralResult = PublicExportSurfaceReader(root).read();
    final resolvedResult = await ResolvedPublicSurfaceReader(root).read();
    final actualNames = resolvedResult.publicNames;
    final missingNames = expectedNames.names.difference(actualNames).toList()
      ..sort();
    final extraNames = actualNames.difference(expectedNames.names).toList()
      ..sort();
    final violations = <String>[
      ...expectedNames.violations,
      ...structuralResult.violations,
      ...resolvedResult.violations,
    ];

    for (final name in missingNames) {
      violations.add('Missing public export: $name');
    }

    for (final name in extraNames) {
      violations.add('Unexpected public export: $name');
    }

    return _result(violations);
  }

  Future<GuardrailCheckResult> publicTypesComplete() async {
    final structuralResult = PublicExportSurfaceReader(root).read();
    final resolvedResult = await ResolvedPublicSurfaceReader(root).read();
    final violations = <String>[
      ...structuralResult.violations,
      ...resolvedResult.violations,
      ...resolvedPublicTypeViolations(resolvedResult),
    ];

    return _result(violations);
  }

  Future<GuardrailCheckResult> noLegacyPublicTypes() async {
    final legacyNames = readLegacyPublicNames(root);
    final structuralResult = PublicExportSurfaceReader(root).read();
    final resolvedResult = await ResolvedPublicSurfaceReader(root).read();
    final exportedLegacyNames = resolvedResult.publicNames.intersection(
      legacyNames.names,
    );
    final violations = <String>[
      ...legacyNames.violations,
      ...structuralResult.violations,
      ...resolvedResult.violations,
    ];

    for (final name in exportedLegacyNames.toList()..sort()) {
      violations.add('Legacy public symbol exported: $name');
    }

    return _result(violations);
  }
}

GuardrailCheckResult _result(List<String> violations) {
  return violations.isEmpty
      ? GuardrailCheckResult.pass()
      : GuardrailCheckResult.fail(violations);
}
