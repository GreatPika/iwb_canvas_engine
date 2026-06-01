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
  _testOwnerFixtureInventory();
  _testOwnerPolicyInventory();
  _testOwnerPolicyMatrix();
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

void _testOwnerFixtureInventory() {
  test('owner fixtures cover every selected owner', () {
    final ownerNames = ownerDagOwners.map((owner) => owner.name).toSet();

    expect(_ownerFixtureSources.keys.toSet(), ownerNames);
    expect(_ownerFixtureTargets.keys.toSet(), ownerNames);
    for (final entry in _ownerFixtureSources.entries) {
      expect(ownerForPath(entry.value)?.name, entry.key);
    }
    for (final entry in _ownerFixtureTargets.entries) {
      expect(ownerForPath(entry.value)?.name, entry.key);
    }
  });
}

void _testOwnerPolicyInventory() {
  test('allowed owner edges match the independent policy table', () {
    expect(
      ownerDagAllowedEdges.map(_allowedEdgeKey).toSet(),
      _expectedAllowedOwnerEdges.map(_expectedEdgeKey).toSet(),
    );
  });
}

void _testOwnerPolicyMatrix() {
  test('selected owner DAG matches the independent policy table', () {
    for (final fixture in _fixtures) {
      expect(
        _selectedDagAllows(fixture),
        fixture.allowed,
        reason: fixture.label,
      );
    }
  });
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
  ),
  _OwnerDagFixture(
    sourceOwner: 'api',
    targetOwner: 'runtime',
    sourcePath: 'lib/src/api/canvas_runtime_frame_bridge.dart',
    targetPath: 'lib/src/runtime/runtime_root.dart',
    directiveKind: 'import',
  ),
  _OwnerDagFixture(
    sourceOwner: 'api',
    targetOwner: 'frame',
    sourcePath: 'lib/src/api/canvas_surface.dart',
    targetPath: 'lib/src/frame/main_frame_painter.dart',
    directiveKind: 'import',
  ),
  _OwnerDagFixture(
    sourceOwner: 'api',
    targetOwner: 'frame',
    sourcePath: 'lib/src/api/canvas_surface.dart',
    targetPath: 'lib/src/frame/overlay_frame_painter.dart',
    directiveKind: 'import',
  ),
  _OwnerDagFixture(
    sourceOwner: 'api',
    targetOwner: 'codec',
    sourcePath: 'lib/src/api/canvas_codec.dart',
    targetPath: 'lib/src/codec/schema_v1_encoder.dart',
    directiveKind: 'import',
  ),
  _OwnerDagFixture(
    sourceOwner: 'api',
    targetOwner: 'codec',
    sourcePath: 'lib/src/api/canvas_codec.dart',
    targetPath: 'lib/src/codec/schema_v1_decoder.dart',
    directiveKind: 'import',
  ),
  _OwnerDagFixture(
    sourceOwner: 'runtime',
    targetOwner: 'spatial',
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/geometry/spatial_kernel.dart',
    directiveKind: 'import',
  ),
  _OwnerDagFixture(
    sourceOwner: 'runtime',
    targetOwner: 'frame',
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/frame/captured_frame.dart',
    directiveKind: 'import',
  ),
  _OwnerDagFixture(
    sourceOwner: 'runtime',
    targetOwner: 'frame',
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/frame/frame_engine.dart',
    directiveKind: 'import',
  ),
  _OwnerDagFixture(
    sourceOwner: 'runtime',
    targetOwner: 'frame',
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/frame/frame_paint_output.dart',
    directiveKind: 'import',
  ),
  _OwnerDagFixture(
    sourceOwner: 'frame',
    targetOwner: 'spatial',
    sourcePath: 'lib/src/frame/captured_frame.dart',
    targetPath: 'lib/src/geometry/spatial_query_result.dart',
    directiveKind: 'import',
  ),
  _OwnerDagFixture(
    sourceOwner: 'frame',
    targetOwner: 'spatial',
    sourcePath: 'lib/src/frame/frame_capture_service.dart',
    targetPath: 'lib/src/geometry/spatial_query_policy.dart',
    directiveKind: 'import',
  ),
  _OwnerDagFixture(
    sourceOwner: 'frame',
    targetOwner: 'spatial',
    sourcePath: 'lib/src/frame/frame_capture_service.dart',
    targetPath: 'lib/src/geometry/spatial_query_result.dart',
    directiveKind: 'import',
  ),
  _OwnerDagFixture(
    sourceOwner: 'frame',
    targetOwner: 'spatial',
    sourcePath: 'lib/src/frame/frame_engine.dart',
    targetPath: 'lib/src/geometry/spatial_kernel.dart',
    directiveKind: 'import',
  ),
  _OwnerDagFixture(
    sourceOwner: 'frame',
    targetOwner: 'spatial',
    sourcePath: 'lib/src/frame/ordinary_paint_planner.dart',
    targetPath: 'lib/src/geometry/geometry_policy.dart',
    directiveKind: 'import',
  ),
  _OwnerDagFixture(
    sourceOwner: 'frame',
    targetOwner: 'spatial',
    sourcePath: 'lib/src/frame/ordinary_paint_planner.dart',
    targetPath: 'lib/src/geometry/spatial_query_result.dart',
    directiveKind: 'import',
  ),
  _OwnerDagFixture(
    sourceOwner: 'frame',
    targetOwner: 'spatial',
    sourcePath: 'lib/src/frame/render_element_record.dart',
    targetPath: 'lib/src/geometry/geometry_policy.dart',
    directiveKind: 'import',
  ),
  _OwnerDagFixture(
    sourceOwner: 'frame',
    targetOwner: 'spatial',
    sourcePath: 'lib/src/frame/selected_move_supplement_planner.dart',
    targetPath: 'lib/src/geometry/spatial_query_policy.dart',
    directiveKind: 'import',
  ),
  _OwnerDagFixture(
    sourceOwner: 'frame',
    targetOwner: 'spatial',
    sourcePath: 'lib/src/frame/selected_move_supplement_planner.dart',
    targetPath: 'lib/src/geometry/spatial_query_result.dart',
    directiveKind: 'import',
  ),
  _OwnerDagFixture(
    sourceOwner: 'frame',
    targetOwner: 'resources',
    sourcePath: 'lib/src/frame/frame_paint_output.dart',
    targetPath: 'lib/src/resources/resource_resolver_adapter.dart',
    directiveKind: 'import',
  ),
  _OwnerDagFixture(
    sourceOwner: 'frame',
    targetOwner: 'resources',
    sourcePath: 'lib/src/frame/main_frame_painter.dart',
    targetPath: 'lib/src/resources/resource_resolver_adapter.dart',
    directiveKind: 'import',
  ),
  _OwnerDagFixture(
    sourceOwner: 'frame',
    targetOwner: 'resources',
    sourcePath: 'lib/src/frame/paint_asset_binding_service.dart',
    targetPath: 'lib/src/resources/resource_resolver_adapter.dart',
    directiveKind: 'import',
  ),
  _OwnerDagFixture(
    sourceOwner: 'frame',
    targetOwner: 'resources',
    sourcePath: 'lib/src/frame/paint_asset_binding_service.dart',
    targetPath: 'lib/src/resources/surface_resource_session.dart',
    directiveKind: 'import',
  ),
];

const _expectedAllowedOwnerEdges = [
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'contracts/internal',
    targetOwner: 'contracts/public',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'api',
    targetOwner: 'contracts/public',
    directiveKinds: {'import', 'export'},
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'api',
    targetOwner: 'runtime',
    sourcePath: 'lib/src/api/canvas_runtime.dart',
    targetPath: 'lib/src/runtime/runtime_root.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'api',
    targetOwner: 'runtime',
    sourcePath: 'lib/src/api/canvas_runtime_frame_bridge.dart',
    targetPath: 'lib/src/runtime/runtime_root.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'api',
    targetOwner: 'frame',
    sourcePath: 'lib/src/api/canvas_surface.dart',
    targetPath: 'lib/src/frame/main_frame_painter.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'api',
    targetOwner: 'frame',
    sourcePath: 'lib/src/api/canvas_surface.dart',
    targetPath: 'lib/src/frame/overlay_frame_painter.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'api',
    targetOwner: 'codec',
    sourcePath: 'lib/src/api/canvas_codec.dart',
    targetPath: 'lib/src/codec/schema_v1_encoder.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'api',
    targetOwner: 'codec',
    sourcePath: 'lib/src/api/canvas_codec.dart',
    targetPath: 'lib/src/codec/schema_v1_decoder.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'runtime',
    targetOwner: 'contracts/public',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'runtime',
    targetOwner: 'contracts/internal',
  ),
  _ExpectedAllowedOwnerEdge(sourceOwner: 'runtime', targetOwner: 'edit'),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'runtime',
    targetOwner: 'spatial',
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/geometry/spatial_kernel.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'runtime',
    targetOwner: 'resources',
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/resources/resource_kernel.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'runtime',
    targetOwner: 'frame',
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/frame/captured_frame.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'runtime',
    targetOwner: 'frame',
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/frame/frame_engine.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'runtime',
    targetOwner: 'frame',
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/frame/frame_paint_output.dart',
  ),
  _ExpectedAllowedOwnerEdge(sourceOwner: 'runtime', targetOwner: 'selection'),
  _ExpectedAllowedOwnerEdge(sourceOwner: 'runtime', targetOwner: 'store'),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'runtime',
    targetOwner: 'interaction',
    sourcePath: 'lib/src/runtime/runtime_root.dart',
    targetPath: 'lib/src/interaction/interaction_engine.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'edit',
    targetOwner: 'contracts/public',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'edit',
    targetOwner: 'contracts/internal',
  ),
  _ExpectedAllowedOwnerEdge(sourceOwner: 'edit', targetOwner: 'store'),
  _ExpectedAllowedOwnerEdge(sourceOwner: 'edit', targetOwner: 'codec'),
  _ExpectedAllowedOwnerEdge(sourceOwner: 'edit', targetOwner: 'diagnostics'),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'store',
    targetOwner: 'contracts/public',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'selection',
    targetOwner: 'contracts/public',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'selection',
    targetOwner: 'contracts/internal',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'codec',
    targetOwner: 'contracts/public',
  ),
  _ExpectedAllowedOwnerEdge(sourceOwner: 'codec', targetOwner: 'diagnostics'),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'diagnostics',
    targetOwner: 'contracts/public',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'resources',
    targetOwner: 'contracts/public',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'resources',
    targetOwner: 'contracts/internal',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'frame',
    targetOwner: 'contracts/public',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'frame',
    targetOwner: 'contracts/internal',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'frame',
    targetOwner: 'spatial',
    sourcePath: 'lib/src/frame/captured_frame.dart',
    targetPath: 'lib/src/geometry/spatial_query_result.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'frame',
    targetOwner: 'spatial',
    sourcePath: 'lib/src/frame/frame_capture_service.dart',
    targetPath: 'lib/src/geometry/spatial_query_policy.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'frame',
    targetOwner: 'spatial',
    sourcePath: 'lib/src/frame/frame_capture_service.dart',
    targetPath: 'lib/src/geometry/spatial_query_result.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'frame',
    targetOwner: 'spatial',
    sourcePath: 'lib/src/frame/frame_engine.dart',
    targetPath: 'lib/src/geometry/spatial_kernel.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'frame',
    targetOwner: 'spatial',
    sourcePath: 'lib/src/frame/frame_spatial_paint_admission.dart',
    targetPath: 'lib/src/geometry/spatial_query_result.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'frame',
    targetOwner: 'spatial',
    sourcePath: 'lib/src/frame/ordinary_paint_planner.dart',
    targetPath: 'lib/src/geometry/geometry_policy.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'frame',
    targetOwner: 'spatial',
    sourcePath: 'lib/src/frame/ordinary_paint_planner.dart',
    targetPath: 'lib/src/geometry/spatial_query_result.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'frame',
    targetOwner: 'spatial',
    sourcePath: 'lib/src/frame/render_element_record.dart',
    targetPath: 'lib/src/geometry/geometry_policy.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'frame',
    targetOwner: 'spatial',
    sourcePath: 'lib/src/frame/selected_move_supplement_planner.dart',
    targetPath: 'lib/src/geometry/spatial_query_policy.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'frame',
    targetOwner: 'spatial',
    sourcePath: 'lib/src/frame/selected_move_supplement_planner.dart',
    targetPath: 'lib/src/geometry/spatial_query_result.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'frame',
    targetOwner: 'resources',
    sourcePath: 'lib/src/frame/frame_paint_output.dart',
    targetPath: 'lib/src/resources/resource_resolver_adapter.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'frame',
    targetOwner: 'resources',
    sourcePath: 'lib/src/frame/main_frame_painter.dart',
    targetPath: 'lib/src/resources/resource_resolver_adapter.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'frame',
    targetOwner: 'resources',
    sourcePath: 'lib/src/frame/paint_asset_binding_service.dart',
    targetPath: 'lib/src/resources/resource_resolver_adapter.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'frame',
    targetOwner: 'resources',
    sourcePath: 'lib/src/frame/paint_asset_binding_service.dart',
    targetPath: 'lib/src/resources/surface_resource_session.dart',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'interaction',
    targetOwner: 'contracts/public',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'interaction',
    targetOwner: 'contracts/internal',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'spatial',
    targetOwner: 'contracts/public',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'spatial',
    targetOwner: 'contracts/internal',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'tools',
    targetOwner: 'contracts/public',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'tools',
    targetOwner: 'contracts/internal',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'surface',
    targetOwner: 'contracts/public',
  ),
  _ExpectedAllowedOwnerEdge(
    sourceOwner: 'surface',
    targetOwner: 'contracts/internal',
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
  'spatial': 'lib/src/geometry/spatial_kernel.dart',
  'tools': 'lib/src/tools/draw_tool_kernel.dart',
  'surface': 'lib/src/surface/flutter_surface.dart',
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
  _RequiredForbiddenEdge(source: 'api', target: 'tools'),
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
  });

  final String sourceOwner;
  final String targetOwner;
  final String sourcePath;
  final String targetPath;
  final String directiveKind;

  String get label => '$sourceOwner $directiveKind -> $targetOwner';

  bool get allowed => _expectedOwnerPolicyAllows(this);

  String get content {
    return _fixtureDirective(
      directiveKind: directiveKind,
      sourcePath: sourcePath,
      targetPath: targetPath,
    );
  }
}

final class _ExpectedAllowedOwnerEdge {
  const _ExpectedAllowedOwnerEdge({
    required this.sourceOwner,
    required this.targetOwner,
    this.sourcePath,
    this.targetPath,
    this.directiveKinds = const {'import'},
  });

  final String sourceOwner;
  final String targetOwner;
  final String? sourcePath;
  final String? targetPath;
  final Set<String> directiveKinds;

  bool allows(_OwnerDagFixture fixture) {
    return fixture.sourceOwner == sourceOwner &&
        fixture.targetOwner == targetOwner &&
        directiveKinds.contains(fixture.directiveKind) &&
        (sourcePath == null || sourcePath == fixture.sourcePath) &&
        (targetPath == null || targetPath == fixture.targetPath);
  }
}

String _allowedEdgeKey(OwnerEdge edge) {
  return [
    edge.source.name,
    edge.target.name,
    edge.sourcePath ?? '*',
    edge.targetPath ?? '*',
    _directiveKindKey(edge.directiveKinds),
  ].join('|');
}

String _expectedEdgeKey(_ExpectedAllowedOwnerEdge edge) {
  return [
    edge.sourceOwner,
    edge.targetOwner,
    edge.sourcePath ?? '*',
    edge.targetPath ?? '*',
    _directiveKindKey(edge.directiveKinds),
  ].join('|');
}

String _directiveKindKey(Set<String> directiveKinds) {
  return (directiveKinds.toList()..sort()).join(',');
}

bool _expectedOwnerPolicyAllows(_OwnerDagFixture fixture) {
  if (fixture.sourceOwner == fixture.targetOwner) {
    return true;
  }

  return _expectedAllowedOwnerEdges.any((edge) => edge.allows(fixture));
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
