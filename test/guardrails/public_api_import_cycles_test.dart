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

  test('live source graph and metadata seam are clean', () async {
    expect(await checkNoPublicApiImportCycles(), isEmpty);

    for (final path in _metadataOnlyPublicApiConsumers) {
      final content = File('$repositoryRoot/$path').readAsStringSync();
      expect(content, contains("import 'canvas_metadata.dart';"));
      expect(content, isNot(contains("import 'canvas_document.dart';")));
    }

    final decoder = File(
      '$repositoryRoot/lib/src/codec/schema_v1_decoder.dart',
    ).readAsStringSync();
    expect(decoder, contains("import '../api/canvas_metadata.dart';"));
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

const _metadataOnlyPublicApiConsumers = [
  'lib/src/api/canvas_element.dart',
  'lib/src/api/canvas_element_update.dart',
  'lib/src/api/canvas_resource.dart',
];

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
