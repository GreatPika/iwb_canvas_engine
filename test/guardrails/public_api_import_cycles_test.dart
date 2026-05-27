import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_import_cycle_checks.dart';
import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test('fixture import-cycle detection', () {
    expect(checkPublicApiImportCyclesInSources(_acyclicSources), isEmpty);
    _expectImportResolution();
    _expectCycleDiagnostics();
    _expectConditionalImportCycles();
    _expectDiagnosticsFollowRealEdges();
    _expectSelfCycleDiagnostics();
    _expectAllowlistStructureRequired();
  });

  test('live source graph and contract wrapper seams are clean', () async {
    expect(await checkNoPublicApiImportCycles(), isEmpty);

    for (final path in _metadataOnlyPublicContractConsumers) {
      final content = File('$repositoryRoot/$path').readAsStringSync();
      expect(content, contains("import 'canvas_metadata.dart';"));
      expect(content, isNot(contains("import 'canvas_document.dart';")));
    }

    final decoder = File(
      '$repositoryRoot/lib/src/codec/schema_v1_decoder.dart',
    ).readAsStringSync();
    expect(
      decoder,
      contains("import '../contracts/public/canvas_metadata.dart';"),
    );

    for (final entry in _publicApiContractWrappers.entries) {
      final content = File('$repositoryRoot/${entry.key}').readAsStringSync();
      expect(content.trim(), "export '../contracts/public/${entry.value}';");
    }
  });
}

void _expectImportResolution() {
  expect(
    resolvePublicApiImportTarget(
      importerPath: 'lib/src/api/a.dart',
      importUri: 'nested/b.dart',
    ),
    'lib/src/api/nested/b.dart',
  );
  expect(
    resolvePublicApiImportTarget(
      importerPath: 'lib/src/api/nested/b.dart',
      importUri: '../a.dart',
    ),
    'lib/src/api/a.dart',
  );
  expect(
    resolvePublicApiImportTarget(
      importerPath: 'lib/src/api/a.dart',
      importUri: 'package:iwb_canvas_engine/src/api/c.dart',
    ),
    'lib/src/api/c.dart',
  );
  expect(
    resolvePublicApiImportTarget(
      importerPath: 'lib/src/api/a.dart',
      importUri: 'package:collection/collection.dart',
    ),
    isNull,
  );
}

const _acyclicSources = {
  'lib/src/api/a.dart': "import 'b.dart';",
  'lib/src/api/b.dart': "import 'package:iwb_canvas_engine/src/api/c.dart';",
  'lib/src/api/c.dart': '',
  'lib/src/internal/ignored.dart': "import '../api/a.dart';",
};

const _metadataOnlyPublicContractConsumers = [
  'lib/src/contracts/public/canvas_element.dart',
  'lib/src/contracts/public/canvas_element_update.dart',
  'lib/src/contracts/public/canvas_resource.dart',
];

const _publicApiContractWrappers = {
  'lib/src/api/canvas_actions.dart': 'canvas_actions.dart',
  'lib/src/api/canvas_contract_limits.dart': 'canvas_contract_limits.dart',
  'lib/src/api/canvas_diagnostic_policy_limits.dart':
      'canvas_diagnostic_policy_limits.dart',
  'lib/src/api/canvas_diagnostics.dart': 'canvas_diagnostics.dart',
  'lib/src/api/canvas_document.dart': 'canvas_document.dart',
  'lib/src/api/canvas_element.dart': 'canvas_element.dart',
  'lib/src/api/canvas_element_update.dart': 'canvas_element_update.dart',
  'lib/src/api/canvas_error_details_sanitizer.dart':
      'canvas_error_details_sanitizer.dart',
  'lib/src/api/canvas_errors.dart': 'canvas_errors.dart',
  'lib/src/api/canvas_field_update.dart': 'canvas_field_update.dart',
  'lib/src/api/canvas_geometry.dart': 'canvas_geometry.dart',
  'lib/src/api/canvas_ids.dart': 'canvas_ids.dart',
  'lib/src/api/canvas_metadata.dart': 'canvas_metadata.dart',
  'lib/src/api/canvas_pointer.dart': 'canvas_pointer.dart',
  'lib/src/api/canvas_preview.dart': 'canvas_preview.dart',
  'lib/src/api/canvas_resource.dart': 'canvas_resource.dart',
  'lib/src/api/canvas_tools.dart': 'canvas_tools.dart',
  'lib/src/api/canvas_transform_admission.dart':
      'canvas_transform_admission.dart',
  'lib/src/api/canvas_value_equality.dart': 'canvas_value_equality.dart',
  'lib/src/api/canvas_value_validators.dart': 'canvas_value_validators.dart',
};

void _expectCycleDiagnostics() {
  final cyclic = checkPublicApiImportCyclesInSources({
    'lib/src/api/a.dart': "import 'b.dart';",
    'lib/src/api/b.dart': "import 'package:iwb_canvas_engine/src/api/c.dart';",
    'lib/src/api/c.dart': "import 'a.dart';",
  });

  expect(cyclic, hasLength(1));
  expect(cyclic.single.guardrailId, 'api.no_public_api_import_cycles');
  expect(cyclic.single.path, 'lib/src/api/a.dart');
  expect(
    cyclic.single.message,
    'public API import cycle: lib/src/api/a.dart -> '
    'lib/src/api/b.dart -> lib/src/api/c.dart -> lib/src/api/a.dart',
  );
}

void _expectConditionalImportCycles() {
  final cyclic = checkPublicApiImportCyclesInSources({
    'lib/src/api/a.dart':
        "import 'stub.dart' if (dart.library.ui) 'real.dart';",
    'lib/src/api/stub.dart': '',
    'lib/src/api/real.dart': "import 'a.dart';",
  });

  expect(cyclic, hasLength(1));
  expect(
    cyclic.single.message,
    'public API import cycle: lib/src/api/a.dart -> '
    'lib/src/api/real.dart -> lib/src/api/a.dart',
  );
}

void _expectDiagnosticsFollowRealEdges() {
  final cyclic = checkPublicApiImportCyclesInSources({
    'lib/src/api/a.dart': "import 'c.dart';",
    'lib/src/api/b.dart': "import 'a.dart';",
    'lib/src/api/c.dart': "import 'b.dart';",
  });

  expect(
    cyclic.single.message,
    'public API import cycle: lib/src/api/a.dart -> '
    'lib/src/api/c.dart -> lib/src/api/b.dart -> lib/src/api/a.dart',
  );
}

void _expectSelfCycleDiagnostics() {
  final selfCycle = checkPublicApiImportCyclesInSources({
    'lib/src/api/self.dart': "import 'self.dart';",
  });

  expect(selfCycle.single.message, contains('lib/src/api/self.dart'));
}

void _expectAllowlistStructureRequired() {
  final allowlistViolation = checkPublicApiImportCyclesInSources(
    const {},
    allowlist: const [
      PublicApiImportCycleAllowlistEntry(
        cycleId: '',
        ownerPhase: 'P2',
        reason: '',
        removalCondition: '',
      ),
    ],
  );

  expect(allowlistViolation, hasLength(1));
  expect(
    allowlistViolation.single.message,
    contains('missing owner phase, reason, or removal condition'),
  );

  final activeAllowlistViolation = checkPublicApiImportCyclesInSources(
    const {},
    allowlist: const [
      PublicApiImportCycleAllowlistEntry(
        cycleId: 'a-b',
        ownerPhase: 'P2',
        reason: 'Fixture cycle.',
        removalCondition: 'Remove fixture cycle.',
      ),
    ],
  );
  expect(
    activeAllowlistViolation.single.message,
    contains('allowlist entries are not active'),
  );
}
