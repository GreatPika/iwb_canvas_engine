import 'package:test/test.dart';

import '../../tool/guardrails/src/owner_dag_import_checks.dart';

void main() {
  _testProductionOwnerDag();
  _testSelectedDagAcyclic();
  _testOwnerFixtureEdges();
  _testConditionalFixtureEdges();
  _testExportFixtureEdges();
  _testRootBarrelFixtureEdges();
  _testPackageDotSegmentFixtureEdges();
  _testRequiredForbiddenEdges();
  _testOwnerFixtureMatrix();
}

void _testProductionOwnerDag() {
  test('production sources obey the selected owner DAG', () async {
    expect(await checkOwnerDagImportBoundaries(), isEmpty);
  });
}

void _testSelectedDagAcyclic() {
  test('selected owner edge table remains acyclic', () {
    expect(ownerDagSelectionViolations(), isEmpty);

    final cyclicEdges = [
      const OwnerEdge(source: runtimeOwner, target: editOwner),
      const OwnerEdge(source: editOwner, target: runtimeOwner),
    ];
    final violations = ownerDagSelectionViolations(allowedEdges: cyclicEdges);

    expect(violations, hasLength(1));
    expect(violations.single.guardrailId, ownerDagGuardrailId);
    expect(violations.single.message, contains('runtime'));
    expect(violations.single.message, contains('edit'));
  });
}

void _testOwnerFixtureEdges() {
  test('table-driven owner fixtures cover allowed and rejected edges', () {
    for (final fixture in _fixtures) {
      final violations = checkOwnerDagFile(
        path: fixture.sourcePath,
        content: fixture.content,
      );

      if (fixture.allowed) {
        expect(violations, isEmpty, reason: fixture.label);
      } else {
        expect(violations, contains(isA<Object>()), reason: fixture.label);
        expect(
          violations.map((violation) => violation.guardrailId),
          everyElement(ownerDagGuardrailId),
          reason: fixture.label,
        );
      }
    }
  });
}

void _testConditionalFixtureEdges() {
  test('conditional directives cannot hide rejected owner edges', () {
    final importViolations = checkOwnerDagFile(
      path: 'lib/src/runtime/bad_conditional.dart',
      content:
          "import '../contracts/public/canvas_ids.dart' "
          "if (dart.library.ui) '../api/canvas_ids.dart';\n",
    );
    final exportViolations = checkOwnerDagFile(
      path: 'lib/src/api/bad_conditional.dart',
      content:
          "export '../contracts/public/canvas_ids.dart' "
          "if (dart.library.ui) "
          "'../contracts/internal/document_facts_port.dart';\n",
    );

    expect(importViolations, hasLength(1));
    expect(importViolations.single.guardrailId, ownerDagGuardrailId);
    expect(exportViolations, hasLength(1));
    expect(exportViolations.single.guardrailId, ownerDagGuardrailId);
  });
}

void _testExportFixtureEdges() {
  test('export directives follow the same owner DAG', () {
    final allowed = checkOwnerDagFile(
      path: 'lib/src/api/canvas_ids.dart',
      content: "export '../contracts/public/canvas_ids.dart';\n",
    );
    final forbidden = checkOwnerDagFile(
      path: 'lib/src/api/bad_internal_export.dart',
      content: "export '../contracts/internal/document_facts_port.dart';\n",
    );

    expect(allowed, isEmpty);
    expect(forbidden, hasLength(1));
    expect(forbidden.single.guardrailId, ownerDagGuardrailId);
  });
}

void _testRootBarrelFixtureEdges() {
  test(
    'implementation owners cannot use the root barrel as a type library',
    () {
      final packageImport = checkOwnerDagFile(
        path: 'lib/src/runtime/bad_root_barrel.dart',
        content: "import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';\n",
      );
      final relativeImport = checkOwnerDagFile(
        path: 'lib/src/runtime/bad_root_barrel.dart',
        content: "import '../../iwb_canvas_engine.dart';\n",
      );

      expect(packageImport, hasLength(1));
      expect(packageImport.single.guardrailId, ownerDagGuardrailId);
      expect(relativeImport, hasLength(1));
      expect(relativeImport.single.guardrailId, ownerDagGuardrailId);
    },
  );
}

void _testPackageDotSegmentFixtureEdges() {
  test('package URI dot segments cannot hide rejected owner edges', () {
    final violations = checkOwnerDagFile(
      path: 'lib/src/runtime/bad_package_dot_segment.dart',
      content:
          "import 'package:iwb_canvas_engine/src/runtime/../api/"
          "canvas_document.dart';\n",
    );

    expect(violations, hasLength(1));
    expect(violations.single.guardrailId, ownerDagGuardrailId);
  });
}

void _testRequiredForbiddenEdges() {
  test('required negative owner edges stay rejected by the selected DAG', () {
    for (final edge in _requiredForbiddenEdges) {
      final violations = checkOwnerDagFile(
        path: _ownerFixtureSources[edge.source]!,
        content: _fixtureDirective(
          directiveKind: edge.directiveKind,
          sourcePath: _ownerFixtureSources[edge.source]!,
          targetPath: _ownerFixtureTargets[edge.target]!,
        ),
      );

      expect(violations, contains(isA<Object>()), reason: edge.label);
      expect(
        violations.map((violation) => violation.guardrailId),
        everyElement(ownerDagGuardrailId),
        reason: edge.label,
      );
    }
  });
}

void _testOwnerFixtureMatrix() {
  test('fixture matrix matches the selected DAG table', () {
    for (final source in _ownerFixtureSources.entries) {
      for (final target in _ownerFixtureTargets.entries) {
        expect(
          _fixtureFor(source.key, target.key, 'import')?.allowed,
          _OwnerDagFixture(
            sourceOwner: source.key,
            targetOwner: target.key,
            sourcePath: source.value,
            targetPath: target.value,
            directiveKind: 'import',
          ).allowed,
          reason: '${source.key} -> ${target.key}',
        );
      }
    }
  });
}

_OwnerDagFixture? _fixtureFor(
  String sourceOwner,
  String targetOwner,
  String directiveKind,
) {
  for (final fixture in _matrixFixtures) {
    if (fixture.sourceOwner == sourceOwner &&
        fixture.targetOwner == targetOwner &&
        fixture.directiveKind == directiveKind) {
      return fixture;
    }
  }

  return null;
}

final _fixtures = [..._matrixFixtures, ..._bridgeFixtures];

final _matrixFixtures = [
  for (final source in _ownerFixtureSources.entries)
    for (final target in _ownerFixtureTargets.entries)
      for (final directiveKind in _fixtureDirectiveKinds)
        _OwnerDagFixture(
          sourceOwner: source.key,
          targetOwner: target.key,
          sourcePath: source.value,
          targetPath: target.value,
          directiveKind: directiveKind,
        ),
];

const _bridgeFixtures = [
  _OwnerDagFixture(
    sourceOwner: 'api',
    targetOwner: 'runtime',
    sourcePath: 'lib/src/api/canvas_runtime.dart',
    targetPath: 'lib/src/runtime/runtime_root.dart',
    directiveKind: 'import',
    explicitAllowed: true,
  ),
  _OwnerDagFixture(
    sourceOwner: 'api',
    targetOwner: 'codec',
    sourcePath: 'lib/src/api/canvas_codec.dart',
    targetPath: 'lib/src/codec/schema_v1_encoder.dart',
    directiveKind: 'import',
    explicitAllowed: true,
  ),
  _OwnerDagFixture(
    sourceOwner: 'api',
    targetOwner: 'codec',
    sourcePath: 'lib/src/api/canvas_codec.dart',
    targetPath: 'lib/src/codec/schema_v1_decoder.dart',
    directiveKind: 'import',
    explicitAllowed: true,
  ),
];

const _fixtureDirectiveKinds = ['import', 'export'];

const _ownerFixtureSources = {
  'api': 'lib/src/api/bad.dart',
  'contracts/public': 'lib/src/contracts/public/bad.dart',
  'contracts/internal': 'lib/src/contracts/internal/bad.dart',
  'runtime': 'lib/src/runtime/bad.dart',
  'edit': 'lib/src/edit/bad.dart',
  'store': 'lib/src/store/bad.dart',
  'selection': 'lib/src/selection/bad.dart',
  'codec': 'lib/src/codec/bad.dart',
  'diagnostics': 'lib/src/diagnostics/bad.dart',
  'resources': 'lib/src/resources/bad.dart',
  'frame': 'lib/src/frame/bad.dart',
  'interaction': 'lib/src/interaction/bad.dart',
  'spatial': 'lib/src/geometry/bad.dart',
  'tools': 'lib/src/tools/bad.dart',
  'surface': 'lib/src/surface/bad.dart',
};

const _ownerFixtureTargets = {
  'api': 'lib/src/api/canvas_document.dart',
  'contracts/public': 'lib/src/contracts/public/canvas_document.dart',
  'contracts/internal': 'lib/src/contracts/internal/document_facts_port.dart',
  'runtime': 'lib/src/runtime/runtime_root.dart',
  'edit': 'lib/src/edit/edit_kernel.dart',
  'store': 'lib/src/store/document_store_kernel.dart',
  'selection': 'lib/src/selection/selection_kernel.dart',
  'codec': 'lib/src/codec/schema_v1_decoder.dart',
  'diagnostics': 'lib/src/diagnostics/diagnostics_hub.dart',
  'resources': 'lib/src/resources/resource_kernel.dart',
  'frame': 'lib/src/frame/frame_renderer.dart',
  'interaction': 'lib/src/interaction/interaction_engine.dart',
  'spatial': 'lib/src/geometry/spatial_index.dart',
  'tools': 'lib/src/tools/draw_tool_kernel.dart',
  'surface': 'lib/src/surface/flutter_surface.dart',
};

const _requiredForbiddenEdges = [
  _RequiredForbiddenEdge(source: 'runtime', target: 'api'),
  _RequiredForbiddenEdge(source: 'edit', target: 'api'),
  _RequiredForbiddenEdge(source: 'store', target: 'api'),
  _RequiredForbiddenEdge(source: 'selection', target: 'runtime'),
  _RequiredForbiddenEdge(source: 'codec', target: 'api'),
  _RequiredForbiddenEdge(source: 'diagnostics', target: 'api'),
  _RequiredForbiddenEdge(source: 'diagnostics', target: 'codec'),
  _RequiredForbiddenEdge(source: 'diagnostics', target: 'runtime'),
  _RequiredForbiddenEdge(source: 'diagnostics', target: 'store'),
  _RequiredForbiddenEdge(source: 'diagnostics', target: 'edit'),
  _RequiredForbiddenEdge(source: 'diagnostics', target: 'frame'),
  _RequiredForbiddenEdge(source: 'resources', target: 'runtime'),
  _RequiredForbiddenEdge(source: 'resources', target: 'frame'),
  _RequiredForbiddenEdge(source: 'edit', target: 'runtime'),
  _RequiredForbiddenEdge(source: 'store', target: 'runtime'),
  _RequiredForbiddenEdge(source: 'codec', target: 'runtime'),
  _RequiredForbiddenEdge(source: 'codec', target: 'store'),
  _RequiredForbiddenEdge(source: 'codec', target: 'edit'),
  _RequiredForbiddenEdge(source: 'codec', target: 'frame'),
  _RequiredForbiddenEdge(source: 'contracts/public', target: 'runtime'),
  _RequiredForbiddenEdge(source: 'contracts/public', target: 'api'),
  _RequiredForbiddenEdge(source: 'contracts/public', target: 'edit'),
  _RequiredForbiddenEdge(source: 'contracts/public', target: 'store'),
  _RequiredForbiddenEdge(source: 'contracts/public', target: 'selection'),
  _RequiredForbiddenEdge(source: 'contracts/public', target: 'codec'),
  _RequiredForbiddenEdge(source: 'contracts/public', target: 'diagnostics'),
  _RequiredForbiddenEdge(source: 'contracts/public', target: 'resources'),
  _RequiredForbiddenEdge(source: 'contracts/public', target: 'frame'),
  _RequiredForbiddenEdge(source: 'contracts/public', target: 'interaction'),
  _RequiredForbiddenEdge(source: 'contracts/public', target: 'spatial'),
  _RequiredForbiddenEdge(source: 'contracts/public', target: 'tools'),
  _RequiredForbiddenEdge(source: 'contracts/public', target: 'surface'),
  _RequiredForbiddenEdge(source: 'contracts/internal', target: 'runtime'),
  _RequiredForbiddenEdge(source: 'contracts/internal', target: 'api'),
  _RequiredForbiddenEdge(source: 'contracts/internal', target: 'edit'),
  _RequiredForbiddenEdge(source: 'contracts/internal', target: 'store'),
  _RequiredForbiddenEdge(source: 'contracts/internal', target: 'selection'),
  _RequiredForbiddenEdge(source: 'contracts/internal', target: 'codec'),
  _RequiredForbiddenEdge(source: 'contracts/internal', target: 'diagnostics'),
  _RequiredForbiddenEdge(source: 'contracts/internal', target: 'resources'),
  _RequiredForbiddenEdge(source: 'contracts/internal', target: 'frame'),
  _RequiredForbiddenEdge(source: 'contracts/internal', target: 'interaction'),
  _RequiredForbiddenEdge(source: 'contracts/internal', target: 'spatial'),
  _RequiredForbiddenEdge(source: 'contracts/internal', target: 'tools'),
  _RequiredForbiddenEdge(source: 'contracts/internal', target: 'surface'),
  _RequiredForbiddenEdge(
    source: 'api',
    target: 'contracts/internal',
    directiveKind: 'import',
  ),
  _RequiredForbiddenEdge(
    source: 'api',
    target: 'contracts/internal',
    directiveKind: 'export',
  ),
];

final class _OwnerDagFixture {
  const _OwnerDagFixture({
    required this.sourceOwner,
    required this.targetOwner,
    required this.sourcePath,
    required this.targetPath,
    required this.directiveKind,
    this.explicitAllowed,
  });

  final String sourceOwner;
  final String targetOwner;
  final String sourcePath;
  final String targetPath;
  final String directiveKind;
  final bool? explicitAllowed;

  String get label => '$sourceOwner $directiveKind -> $targetOwner';

  bool get allowed => explicitAllowed ?? _selectedDagAllows(this);

  String get content {
    return _fixtureDirective(
      directiveKind: directiveKind,
      sourcePath: sourcePath,
      targetPath: targetPath,
    );
  }
}

bool _selectedDagAllows(_OwnerDagFixture fixture) {
  if (fixture.sourceOwner == fixture.targetOwner) {
    return true;
  }

  final sourceOwner = ownerForPath(fixture.sourcePath);
  final targetOwner = ownerForPath(fixture.targetPath);
  if (sourceOwner == null || targetOwner == null) {
    return false;
  }

  final query = OwnerEdgeQuery(
    sourcePath: fixture.sourcePath,
    sourceOwner: sourceOwner,
    targetPath: fixture.targetPath,
    targetOwner: targetOwner,
    directiveKind: fixture.directiveKind,
  );

  return ownerDagAllowedEdges.any((edge) => edge.allows(query));
}

final class _RequiredForbiddenEdge {
  const _RequiredForbiddenEdge({
    required this.source,
    required this.target,
    this.directiveKind = 'import',
  });

  final String source;
  final String target;
  final String directiveKind;

  String get label => '$source $directiveKind -> $target';
}

String _fixtureDirective({
  required String directiveKind,
  required String sourcePath,
  required String targetPath,
}) {
  return "$directiveKind '${_relativeImportUri(sourcePath, targetPath)}';\n";
}

String _relativeImportUri(String sourcePath, String targetPath) {
  final sourceParts = sourcePath.split('/')..removeLast();
  final targetParts = targetPath.split('/');
  while (sourceParts.isNotEmpty &&
      targetParts.isNotEmpty &&
      sourceParts.first == targetParts.first) {
    sourceParts.removeAt(0);
    targetParts.removeAt(0);
  }

  return [
    for (var i = 0; i < sourceParts.length; i += 1) '..',
    ...targetParts,
  ].join('/');
}
