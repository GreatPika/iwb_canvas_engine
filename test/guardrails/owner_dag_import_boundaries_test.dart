import 'package:test/test.dart';

import '../../tool/guardrails/src/owner_dag_import_checks.dart';

void main() {
  _testSelectedDagAcyclic();
  _testOwnerFixtureEdges();
  _testConditionalFixtureEdges();
  _testExportFixtureEdges();
  _testRootBarrelFixtureEdges();
  _testPackageDotSegmentFixtureEdges();
  _testUnownedProductionSourceFixture();
  _testRequiredForbiddenEdges();
  _testOwnerFixtureInventory();
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
  test('production owner edges admit generated positive fixtures', () {
    for (final fixture in _allowedOwnerFixtures) {
      final violations = checkOwnerDagFile(
        path: fixture.sourcePath,
        content: fixture.content,
      );

      expect(violations, isEmpty, reason: fixture.label);
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
  test('owner files cannot use the root barrel as a type library', () {
    final packageImport = checkOwnerDagFile(
      path: 'lib/src/runtime/bad_root_barrel.dart',
      content: "import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';\n",
    );
    final relativeImport = checkOwnerDagFile(
      path: 'lib/src/runtime/bad_root_barrel.dart',
      content: "import '../../iwb_canvas_engine.dart';\n",
    );

    final apiPackageImport = checkOwnerDagFile(
      path: 'lib/src/api/bad_root_barrel.dart',
      content: "import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';\n",
    );
    final apiRelativeImport = checkOwnerDagFile(
      path: 'lib/src/api/bad_root_barrel.dart',
      content: "import '../../iwb_canvas_engine.dart';\n",
    );

    expect(packageImport, hasLength(1));
    expect(packageImport.single.guardrailId, ownerDagGuardrailId);
    expect(relativeImport, hasLength(1));
    expect(relativeImport.single.guardrailId, ownerDagGuardrailId);
    expect(apiPackageImport, hasLength(1));
    expect(apiPackageImport.single.guardrailId, ownerDagGuardrailId);
    expect(apiRelativeImport, hasLength(1));
    expect(apiRelativeImport.single.guardrailId, ownerDagGuardrailId);
  });
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

void _testUnownedProductionSourceFixture() {
  test('unowned lib/src production sources fail closed', () {
    final violations = checkOwnerDagFile(
      path: 'lib/src/tools/reintroduced_tool.dart',
      content: 'final value = 1;\n',
    );

    expect(violations, hasLength(1));
    expect(violations.single.guardrailId, ownerDagGuardrailId);
    expect(violations.single.message, contains('not assigned'));
  });
}

void _testRequiredForbiddenEdges() {
  test('required negative owner edges stay rejected by the selected DAG', () {
    for (final edge in _requiredForbiddenEdges) {
      final violations = checkOwnerDagFile(
        path: _negativeOwnerFixtureSource(edge.source),
        content: _fixtureDirective(
          directiveKind: edge.directiveKind,
          sourcePath: _negativeOwnerFixtureSource(edge.source),
          targetPath: _canonicalOwnerFixtureTargets[edge.target]!,
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

void _testOwnerFixtureInventory() {
  test('owner fixtures cover every selected owner', () {
    final ownerNames = ownerDagOwners.map((owner) => owner.name).toSet();

    expect(_canonicalOwnerFixtureSources.keys.toSet(), ownerNames);
    expect(_canonicalOwnerFixtureTargets.keys.toSet(), ownerNames);
    for (final entry in _canonicalOwnerFixtureSources.entries) {
      expect(ownerForPath(entry.value)?.name, entry.key);
    }
    for (final entry in _canonicalOwnerFixtureTargets.entries) {
      expect(ownerForPath(entry.value)?.name, entry.key);
    }
  });
}

final _allowedOwnerFixtures = [
  for (final edge in ownerDagAllowedEdges)
    for (final directiveKind in edge.directiveKinds)
      _OwnerDagFixture(
        sourceOwner: edge.source.name,
        targetOwner: edge.target.name,
        sourcePath:
            edge.sourcePath ?? _canonicalOwnerFixtureSources[edge.source.name]!,
        targetPath:
            edge.targetPath ?? _canonicalOwnerFixtureTargets[edge.target.name]!,
        directiveKind: directiveKind,
      ),
];

const _canonicalOwnerFixtureSources = {
  'api': 'lib/src/api/canvas_runtime.dart',
  'contracts/public': 'lib/src/contracts/public/canvas_document.dart',
  'contracts/internal': 'lib/src/contracts/internal/document_facts_port.dart',
  'runtime': 'lib/src/runtime/runtime_root.dart',
  'edit': 'lib/src/edit/edit_kernel.dart',
  'store': 'lib/src/store/document_store_kernel.dart',
  'selection': 'lib/src/selection/selection_kernel.dart',
  'codec': 'lib/src/codec/schema_v1_decoder.dart',
  'diagnostics': 'lib/src/diagnostics/diagnostics_hub.dart',
  'resources': 'lib/src/resources/resource_kernel.dart',
  'frame': 'lib/src/frame/frame_engine.dart',
  'interaction': 'lib/src/interaction/interaction_engine.dart',
  'spatial': 'lib/src/geometry/spatial_kernel.dart',
  'surface': 'lib/src/surface/canvas_surface_widget.dart',
};

const _canonicalOwnerFixtureTargets = {
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
  'frame': 'lib/src/frame/frame_engine.dart',
  'interaction': 'lib/src/interaction/interaction_engine.dart',
  'spatial': 'lib/src/geometry/spatial_kernel.dart',
  'surface': 'lib/src/surface/canvas_surface_widget.dart',
};

const _requiredForbiddenEdges = [
  _RequiredForbiddenEdge(source: 'api', target: 'runtime'),
  _RequiredForbiddenEdge(source: 'api', target: 'edit'),
  _RequiredForbiddenEdge(source: 'api', target: 'store'),
  _RequiredForbiddenEdge(source: 'api', target: 'selection'),
  _RequiredForbiddenEdge(source: 'api', target: 'codec'),
  _RequiredForbiddenEdge(source: 'api', target: 'diagnostics'),
  _RequiredForbiddenEdge(source: 'api', target: 'resources'),
  _RequiredForbiddenEdge(source: 'api', target: 'frame'),
  _RequiredForbiddenEdge(source: 'api', target: 'interaction'),
  _RequiredForbiddenEdge(source: 'api', target: 'spatial'),
  _RequiredForbiddenEdge(source: 'api', target: 'surface'),
  _RequiredForbiddenEdge(source: 'runtime', target: 'api'),
  _RequiredForbiddenEdge(source: 'runtime', target: 'spatial'),
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
  });

  final String sourceOwner;
  final String targetOwner;
  final String sourcePath;
  final String targetPath;
  final String directiveKind;

  String get label => '$sourceOwner $directiveKind -> $targetOwner';

  String get content {
    return _fixtureDirective(
      directiveKind: directiveKind,
      sourcePath: sourcePath,
      targetPath: targetPath,
    );
  }
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

String _negativeOwnerFixtureSource(String ownerName) {
  final owner = ownerDagOwners.singleWhere((owner) => owner.name == ownerName);

  return '${owner.prefixes.first}owner_dag_negative_fixture.dart';
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
