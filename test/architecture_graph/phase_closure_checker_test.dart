import 'dart:io';

import 'package:test/test.dart';

import '../../tool/architecture_graph/src/actual_graph.dart';
import '../../tool/architecture_graph/src/architecture_graph.dart';
import '../../tool/architecture_graph/src/phase_closure.dart';

void main() {
  group('required obligations', () {
    _registerMissingRequiredObligationTest();
    _registerFutureObligationTest();
  });
  group('placeholders', () {
    _registerClosedPlaceholderTest();
    _registerFuturePlaceholderTest();
  });
  group('evidence matching', () {
    _registerCompositionEvidenceTest();
    _registerBlockBodyDelegationExtractionTest();
    _registerWrongOwnerCompositionTest();
    _registerWrongOwnerDeclarationTest();
    _registerInterfaceEvidenceTest();
    _registerUnrelatedOwnerCompositionTest();
  });
  group('diagnostic routes', () {
    _registerDiagnosticRouteTest();
  });
  group('architecture inventory', () {
    _registerForbiddenEdgeTest();
    _registerContractLayerForbiddenEdgeTest();
    _registerUnknownSeamTest();
    _registerP10SourceRepairInventoryTest();
    _registerProductionClosureTest();
  });
}

void _registerBlockBodyDelegationExtractionTest() {
  test('extracts delegation from member parameter calls in block bodies', () {
    final temp = Directory.systemTemp.createTempSync('architecture_graph_');
    try {
      final file = File(
        '${temp.path}/lib/src/frame/paint_asset_binding_service.dart',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('''
final class SurfaceResourceSession {
  void beginFrameResourcePass() {}
}

final class PaintAssetBindingService {
  void bind(SurfaceResourceSession session) {
    session.beginFrameResourcePass();
  }
}
''');

      final actual = extractActualArchitectureGraphFromPaths(
        repositoryRoot: temp.path,
        paths: const ['lib/src/frame/paint_asset_binding_service.dart'],
        options: const ActualGraphExtractionOptions(
          delegationMembers: {'PaintAssetBindingService.bind'},
          delegationTargetTypes: {'SurfaceResourceSession'},
        ),
      );

      expect(
        actual.delegations,
        contains(
          isA<DelegationFact>()
              .having(
                (fact) => fact.member,
                'member',
                'PaintAssetBindingService.bind',
              )
              .having((fact) => fact.target, 'target', 'session')
              .having(
                (fact) => fact.targetType,
                'targetType',
                'SurfaceResourceSession',
              ),
        ),
      );
    } finally {
      temp.deleteSync(recursive: true);
    }
  });
}

void _registerMissingRequiredObligationTest() {
  test('fails missing required nodes and edges for the selected phase', () {
    final report = checkPhaseClosure(
      expected: _fixtureGraph(),
      actual: _actualGraph(),
      selectedPhase: 'P4',
    );

    expect(_ids(report), contains('fixture.required_node'));
    expect(_ids(report), contains('fixture.required_edge'));
  });
}

void _registerFutureObligationTest() {
  test('requires future obligations when selected phase reaches them', () {
    final report = checkPhaseClosure(
      expected: _fixtureGraph(),
      actual: _actualGraph(),
      selectedPhase: 'P5',
    );

    expect(_ids(report), contains('fixture.future_edge'));
    expect(_ids(report), contains('fixture.future_node'));
  });
}

void _registerClosedPlaceholderTest() {
  test('fails closed-phase and untracked public placeholders', () {
    final report = checkPhaseClosure(
      expected: _fixtureGraph(),
      actual: _actualGraph(
        placeholders: const [
          PlaceholderFact(
            path: 'lib/src/api/facade.dart',
            line: 10,
            member: 'FixtureFacade.camera',
            throwType: 'UnimplementedError',
          ),
          PlaceholderFact(
            path: 'lib/src/api/facade.dart',
            line: 11,
            member: 'FixtureFacade.unknown',
            throwType: 'UnimplementedError',
          ),
        ],
      ),
      selectedPhase: 'P4',
    );

    expect(
      _ids(report),
      contains('runtime.canvas_runtime.camera.closed_phase_placeholder'),
    );
    expect(
      _ids(report),
      contains('placeholder.untracked.FixtureFacade.unknown'),
    );
  });
}

void _registerFuturePlaceholderTest() {
  test('allows future placeholders and deferred edges before their phase', () {
    final report = checkPhaseClosure(
      expected: _fixtureGraph(),
      actual: _actualGraph(
        declarations: const [
          DeclarationFact(
            path: 'lib/src/api/facade.dart',
            line: 1,
            name: 'FixtureFacade',
            kind: 'class',
          ),
          DeclarationFact(
            path: 'lib/src/runtime/root.dart',
            line: 1,
            name: 'FixtureRuntime',
            kind: 'class',
          ),
        ],
        placeholders: const [
          PlaceholderFact(
            path: 'lib/src/api/facade.dart',
            line: 12,
            member: 'FixtureFacade.future',
            throwType: 'UnimplementedError',
          ),
        ],
      ),
      selectedPhase: 'P4',
    );

    expect(_ids(report), isNot(contains('fixture.future_edge')));
    expect(_ids(report), isNot(contains('fixture.future_placeholder')));
  });
}

void _registerForbiddenEdgeTest() {
  test('fails forbidden edges when selected phase is closed', () {
    final report = checkPhaseClosure(
      expected: _fixtureGraph(),
      actual: _actualGraph(
        imports: const [
          ImportFact(
            path: 'lib/src/codec/a.dart',
            line: 1,
            uri: 'lib/src/runtime/b.dart',
          ),
        ],
      ),
      selectedPhase: 'P4',
    );

    expect(_ids(report), contains('fixture.forbidden_runtime_import'));
  });
}

void _registerContractLayerForbiddenEdgeTest() {
  test('step 38 required forbidden edges are present and executable', () {
    final expected = loadExpectedArchitectureGraph();
    _expectRequiredForbiddenEdgesMatchClosedGraph(expected);
    final requiredForbiddenEdges = _requiredStep38ForbiddenEdges(expected);
    final actual = _withImports(
      extractActualArchitectureGraph(expectedGraph: expected),
      _forbiddenEdgeProbeImports(expected, requiredForbiddenEdges),
    );
    final report = checkPhaseClosure(
      expected: expected,
      actual: actual,
      selectedPhase: 'P6',
    );

    expect(
      _ids(report),
      containsAll(_requiredStep38ForbiddenGraphEdges.map((edge) => edge.id)),
    );
  });
}

void _registerUnknownSeamTest() {
  test('fails unknown architecture seams inside declared coverage', () {
    final report = checkPhaseClosure(
      expected: _fixtureGraph(),
      actual: _actualGraph(
        declarations: const [
          DeclarationFact(
            path: 'lib/src/runtime/extra.dart',
            line: 1,
            name: 'ExtraRuntimeSeam',
            kind: 'class',
          ),
        ],
      ),
      selectedPhase: 'P4',
    );

    expect(_ids(report), contains('architecture.unknown.ExtraRuntimeSeam'));
  });
}

void _registerProductionClosureTest() {
  test('production graph closes selected P6 obligations', () {
    final expected = loadExpectedArchitectureGraph();
    final actual = extractActualArchitectureGraph(expectedGraph: expected);
    final report = checkPhaseClosure(
      expected: expected,
      actual: actual,
      selectedPhase: 'P6',
    );

    expect(_ids(report), isEmpty);
  });
}

void _registerP10SourceRepairInventoryTest() {
  test(
    'P10 source repair splits facade placeholders and diagnostics scope',
    () {
      final expected = loadExpectedArchitectureGraph();
      final placeholders = {
        for (final placeholder in expected.placeholders)
          placeholder.id: placeholder,
      };
      final edges = {for (final edge in expected.edges) edge.id: edge};

      expect(
        placeholders,
        isNot(contains('api.canvas_runtime.tools.future_placeholder')),
      );
      expect(
        placeholders,
        isNot(
          contains(
            'api.canvas_runtime.context_action_requests.future_placeholder',
          ),
        ),
      );
      expect(
        edges['api.canvas_runtime.tools.routes_to_runtime_tools']?.evidence
            .join(' '),
        contains('P11 owns later draw production behavior behind the port'),
      );
      expect(
        edges['eraser_text.request.produces_context_action_requests']?.evidence
            .join(' '),
        contains('P12 owns request-producing context-action behavior'),
      );
      expect(
        edges['geometry.spatial_index.corrupted_rows.report_to_diagnostics']
            ?.phaseRequiredBy,
        isNot('P10'),
      );
      expect(
        edges['interaction.engine.reliability_events.report_to_diagnostics']
            ?.status,
        'required',
      );
      expect(
        edges['interaction.engine.reliability_events.report_to_diagnostics']
            ?.actual
            .delegationTargets,
        contains('InteractionDiagnosticsSink'),
      );
    },
  );
}

void _registerCompositionEvidenceTest() {
  test('passes required non-placeholder edge when evidence exists', () {
    final report = checkPhaseClosure(
      expected: _fixtureGraph(),
      actual: _actualGraph(
        declarations: const [
          DeclarationFact(
            path: 'lib/src/runtime/root.dart',
            line: 1,
            name: 'FixtureRuntime',
            kind: 'class',
          ),
        ],
        compositionFields: const [
          CompositionFieldFact(
            path: 'lib/src/api/facade.dart',
            line: 2,
            declaration: 'FixtureFacade',
            field: '_runtime',
            type: 'FixtureRuntime',
          ),
        ],
      ),
      selectedPhase: 'P4',
    );

    expect(_ids(report), isNot(contains('fixture.required_edge')));
  });
}

void _registerWrongOwnerCompositionTest() {
  test(
    'does not close an edge with evidence from another class in the owner path',
    () {
      final report = checkPhaseClosure(
        expected: _fixtureGraph(),
        actual: _actualGraph(
          declarations: const [
            DeclarationFact(
              path: 'lib/src/api/facade.dart',
              line: 1,
              name: 'FixtureFacade',
              kind: 'class',
            ),
            DeclarationFact(
              path: 'lib/src/runtime/root.dart',
              line: 1,
              name: 'FixtureRuntime',
              kind: 'class',
            ),
          ],
          compositionFields: const [
            CompositionFieldFact(
              path: 'lib/src/api/facade.dart',
              line: 2,
              declaration: 'OtherFacade',
              field: '_runtime',
              type: 'FixtureRuntime',
            ),
          ],
        ),
        selectedPhase: 'P4',
      );

      expect(_ids(report), contains('fixture.required_edge'));
    },
  );
}

void _registerWrongOwnerDeclarationTest() {
  test(
    'does not close a required node with declarations from another owner',
    () {
      final report = checkPhaseClosure(
        expected: _fixtureGraph(),
        actual: _actualGraph(
          declarations: const [
            DeclarationFact(
              path: 'lib/src/codec/wrong.dart',
              line: 1,
              name: 'FixtureRuntime',
              kind: 'class',
            ),
          ],
        ),
        selectedPhase: 'P4',
      );

      expect(_ids(report), contains('fixture.required_node'));
    },
  );
}

void _registerInterfaceEvidenceTest() {
  test('compares implemented interface expectations', () {
    final missingReport = checkPhaseClosure(
      expected: _fixtureGraph(),
      actual: _actualGraph(
        declarations: const [
          DeclarationFact(
            path: 'lib/src/runtime/root.dart',
            line: 1,
            name: 'FixtureRuntime',
            kind: 'class',
          ),
        ],
      ),
      selectedPhase: 'P4',
    );
    final passingReport = checkPhaseClosure(
      expected: _fixtureGraph(),
      actual: _actualGraph(
        declarations: const [
          DeclarationFact(
            path: 'lib/src/runtime/root.dart',
            line: 1,
            name: 'FixtureRuntime',
            kind: 'class',
          ),
        ],
        implementedInterfaces: const [
          ImplementedInterfaceFact(
            path: 'lib/src/runtime/root.dart',
            line: 2,
            declaration: 'FixtureRuntime',
            interface: 'FixturePort',
          ),
        ],
      ),
      selectedPhase: 'P4',
    );

    expect(_ids(missingReport), contains('fixture.required_node'));
    expect(_ids(passingReport), isNot(contains('fixture.required_node')));
  });
}

void _registerUnrelatedOwnerCompositionTest() {
  test('does not close an edge with evidence from an unrelated owner path', () {
    final report = checkPhaseClosure(
      expected: _fixtureGraph(),
      actual: _actualGraph(
        declarations: const [
          DeclarationFact(
            path: 'lib/src/runtime/root.dart',
            line: 1,
            name: 'FixtureRuntime',
            kind: 'class',
          ),
        ],
        compositionFields: const [
          CompositionFieldFact(
            path: 'lib/src/runtime/unrelated.dart',
            line: 2,
            declaration: 'UnrelatedRuntime',
            field: '_runtime',
            type: 'FixtureRuntime',
          ),
        ],
      ),
      selectedPhase: 'P4',
    );

    expect(_ids(report), contains('fixture.required_edge'));
  });
}

void _registerDiagnosticRouteTest() {
  test('requires sensitive throwing members to call the declared route', () {
    final expected = _fixtureGraphWithDiagnosticRoute();
    final missingRoute = _missingDiagnosticRouteReport(expected);
    final routed = _routedDiagnosticRouteReport(expected);

    expect(_ids(missingRoute), contains('fixture.codec_reports_diagnostics'));
    expect(_ids(routed), isNot(contains('fixture.codec_reports_diagnostics')));
  });
}

PhaseClosureReport _missingDiagnosticRouteReport(
  ExpectedArchitectureGraph expected,
) {
  return checkPhaseClosure(
    expected: expected,
    actual: _actualGraph(
      exceptionThrows: const [_diagnosticExceptionThrow],
      delegations: const [_diagnosticRouteDelegation],
    ),
    selectedPhase: 'P4',
  );
}

PhaseClosureReport _routedDiagnosticRouteReport(
  ExpectedArchitectureGraph expected,
) {
  return checkPhaseClosure(
    expected: expected,
    actual: _actualGraph(
      exceptionThrows: const [_diagnosticExceptionThrow],
      delegations: const [_diagnosticRouteDelegation],
      memberCalls: const [_diagnosticRouteCall],
    ),
    selectedPhase: 'P4',
  );
}

const _diagnosticExceptionThrow = ExceptionThrowFact(
  path: 'lib/src/codec/decoder.dart',
  line: 10,
  exception: 'FixtureException',
  owner: 'fixture.codec',
  member: 'decodeFixture',
);

const _diagnosticRouteDelegation = DelegationFact(
  path: 'lib/src/codec/decoder.dart',
  line: 20,
  member: 'recordFixtureRoute',
  target: 'hub',
  targetType: 'FixtureDiagnostics',
);

const _diagnosticRouteCall = MemberCallFact(
  path: 'lib/src/codec/decoder.dart',
  line: 11,
  member: 'decodeFixture',
  target: 'recordFixtureRoute',
);

Set<String> _ids(PhaseClosureReport report) {
  return report.violations.map((violation) => violation.graphId).toSet();
}

void _expectRequiredForbiddenEdgesMatchClosedGraph(
  ExpectedArchitectureGraph expected,
) {
  final closedForbiddenIds = {
    for (final edge in expected.forbiddenEdges)
      if (_phaseIndex(edge.phaseRequiredBy) <= _phaseIndex('P6')) edge.id,
  };
  final requiredIds = {
    for (final edge in _requiredStep38ForbiddenGraphEdges) edge.id,
  };

  expect(requiredIds, closedForbiddenIds);
}

List<ArchitectureForbiddenEdge> _requiredStep38ForbiddenEdges(
  ExpectedArchitectureGraph expected,
) {
  final edges = {for (final edge in expected.forbiddenEdges) edge.id: edge};

  return [
    for (final required in _requiredStep38ForbiddenGraphEdges)
      _requiredStep38ForbiddenEdge(edges, required),
  ];
}

ArchitectureForbiddenEdge _requiredStep38ForbiddenEdge(
  Map<String, ArchitectureForbiddenEdge> edges,
  _RequiredForbiddenGraphEdge required,
) {
  final edge = edges[required.id];
  if (edge == null) {
    throw StateError('Missing Step 38 forbidden graph edge ${required.id}');
  }

  expect(edge.from, required.from, reason: required.id);
  expect(edge.to, required.to, reason: required.id);

  return edge;
}

const _requiredStep38ForbiddenGraphEdges = [
  _RequiredForbiddenGraphEdge(
    id: 'runtime.root.forbidden_api_dependency',
    from: 'runtime.root',
    to: 'api.public_surface',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'edit.kernel.forbidden_api_dependency',
    from: 'edit.kernel',
    to: 'api.public_surface',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'store.document_kernel.forbidden_api_dependency',
    from: 'store.document_kernel',
    to: 'api.public_surface',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'selection.kernel.forbidden_api_dependency',
    from: 'selection.kernel',
    to: 'api.public_surface',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'codec.schema_v1.forbidden_api_dependency',
    from: 'codec.schema_v1',
    to: 'api.public_surface',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'diagnostics.hub.forbidden_api_dependency',
    from: 'diagnostics.hub',
    to: 'api.public_surface',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'load_document.pipeline.forbidden_api_dependency',
    from: 'load_document.pipeline',
    to: 'api.public_surface',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'resource.kernel.forbidden_api_dependency',
    from: 'resource.kernel',
    to: 'api.public_surface',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'resource.surface_session.forbidden_api_dependency',
    from: 'resource.surface_session',
    to: 'api.public_surface',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'geometry.spatial_index.forbidden_api_dependency',
    from: 'geometry.spatial_index',
    to: 'api.public_surface',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'frame.renderer.forbidden_api_dependency',
    from: 'frame.renderer',
    to: 'api.public_surface',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'interaction.engine.forbidden_api_dependency',
    from: 'interaction.engine',
    to: 'api.public_surface',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'draw.tools.forbidden_api_dependency',
    from: 'draw.tools',
    to: 'api.public_surface',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'eraser_text.request.forbidden_api_dependency',
    from: 'eraser_text.request',
    to: 'api.public_surface',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'flutter.surface.forbidden_api_dependency',
    from: 'flutter.surface',
    to: 'api.public_surface',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.public.forbidden_api_dependency',
    from: 'contracts.public',
    to: 'api.public_surface',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.internal_ports.forbidden_api_dependency',
    from: 'contracts.internal_ports',
    to: 'api.public_surface',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.public.forbidden_runtime_dependency',
    from: 'contracts.public',
    to: 'runtime.root',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.public.forbidden_edit_dependency',
    from: 'contracts.public',
    to: 'edit.kernel',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.public.forbidden_store_dependency',
    from: 'contracts.public',
    to: 'store.document_kernel',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.public.forbidden_selection_dependency',
    from: 'contracts.public',
    to: 'selection.kernel',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.public.forbidden_codec_dependency',
    from: 'contracts.public',
    to: 'codec.schema_v1',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.public.forbidden_diagnostics_dependency',
    from: 'contracts.public',
    to: 'diagnostics.hub',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.public.forbidden_resource_kernel_dependency',
    from: 'contracts.public',
    to: 'resource.kernel',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.public.forbidden_surface_session_dependency',
    from: 'contracts.public',
    to: 'resource.surface_session',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.public.forbidden_frame_dependency',
    from: 'contracts.public',
    to: 'frame.renderer',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.public.forbidden_interaction_dependency',
    from: 'contracts.public',
    to: 'interaction.engine',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.public.forbidden_tools_dependency',
    from: 'contracts.public',
    to: 'draw.tools',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.public.forbidden_spatial_dependency',
    from: 'contracts.public',
    to: 'geometry.spatial_index',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.public.forbidden_flutter_surface_dependency',
    from: 'contracts.public',
    to: 'flutter.surface',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.internal_ports.forbidden_runtime_dependency',
    from: 'contracts.internal_ports',
    to: 'runtime.root',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.internal_ports.forbidden_edit_dependency',
    from: 'contracts.internal_ports',
    to: 'edit.kernel',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.internal_ports.forbidden_store_dependency',
    from: 'contracts.internal_ports',
    to: 'store.document_kernel',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.internal_ports.forbidden_selection_dependency',
    from: 'contracts.internal_ports',
    to: 'selection.kernel',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.internal_ports.forbidden_codec_dependency',
    from: 'contracts.internal_ports',
    to: 'codec.schema_v1',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.internal_ports.forbidden_diagnostics_dependency',
    from: 'contracts.internal_ports',
    to: 'diagnostics.hub',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.internal_ports.forbidden_resource_kernel_dependency',
    from: 'contracts.internal_ports',
    to: 'resource.kernel',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.internal_ports.forbidden_surface_session_dependency',
    from: 'contracts.internal_ports',
    to: 'resource.surface_session',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.internal_ports.forbidden_frame_dependency',
    from: 'contracts.internal_ports',
    to: 'frame.renderer',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.internal_ports.forbidden_interaction_dependency',
    from: 'contracts.internal_ports',
    to: 'interaction.engine',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.internal_ports.forbidden_tools_dependency',
    from: 'contracts.internal_ports',
    to: 'draw.tools',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.internal_ports.forbidden_spatial_dependency',
    from: 'contracts.internal_ports',
    to: 'geometry.spatial_index',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'contracts.internal_ports.forbidden_flutter_surface_dependency',
    from: 'contracts.internal_ports',
    to: 'flutter.surface',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'resource.kernel.forbidden_runtime_dependency',
    from: 'resource.kernel',
    to: 'runtime.root',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'resource.kernel.forbidden_frame_dependency',
    from: 'resource.kernel',
    to: 'frame.renderer',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'resource.surface_session.forbidden_runtime_dependency',
    from: 'resource.surface_session',
    to: 'runtime.root',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'resource.surface_session.forbidden_frame_dependency',
    from: 'resource.surface_session',
    to: 'frame.renderer',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'selection.kernel.forbidden_runtime_dependency',
    from: 'selection.kernel',
    to: 'runtime.root',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'codec.schema_v1.forbidden_runtime_dependency',
    from: 'codec.schema_v1',
    to: 'runtime.root',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'codec.schema_v1.forbidden_store_dependency',
    from: 'codec.schema_v1',
    to: 'store.document_kernel',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'codec.schema_v1.forbidden_edit_dependency',
    from: 'codec.schema_v1',
    to: 'edit.kernel',
  ),
  _RequiredForbiddenGraphEdge(
    id: 'codec.schema_v1.forbidden_frame_dependency',
    from: 'codec.schema_v1',
    to: 'frame.renderer',
  ),
];

final class _RequiredForbiddenGraphEdge {
  const _RequiredForbiddenGraphEdge({
    required this.id,
    required this.from,
    required this.to,
  });

  final String id;
  final String from;
  final String to;
}

List<ImportFact> _forbiddenEdgeProbeImports(
  ExpectedArchitectureGraph expected,
  List<ArchitectureForbiddenEdge> edges,
) {
  final nodes = {for (final node in expected.nodes) node.id: node};

  return [
    for (final (index, edge) in edges.indexed)
      ImportFact(
        path: _samplePathForNode(nodes[edge.from]!),
        line: index + 1,
        uri: _samplePathForNode(nodes[edge.to]!),
      ),
  ];
}

String _samplePathForNode(ArchitectureNode node) {
  final path = _ownerForbiddenProbePaths[node.owner];
  if (path == null) {
    throw StateError('Missing forbidden-edge probe path for ${node.owner}');
  }

  return path;
}

const _ownerForbiddenProbePaths = {
  'api': 'lib/src/api/forbidden_probe.dart',
  'contracts_public': 'lib/src/contracts/public/forbidden_probe.dart',
  'contracts_internal': 'lib/src/contracts/internal/forbidden_probe.dart',
  'codec': 'lib/src/codec/forbidden_probe.dart',
  'diagnostics': 'lib/src/diagnostics/forbidden_probe.dart',
  'runtime': 'lib/src/runtime/forbidden_probe.dart',
  'store': 'lib/src/store/forbidden_probe.dart',
  'selection': 'lib/src/selection/forbidden_probe.dart',
  'edit': 'lib/src/edit/forbidden_probe.dart',
  'load_document': 'lib/src/edit/staged_document_load.dart',
  'resource': 'lib/src/resources/forbidden_probe.dart',
  'spatial': 'lib/src/geometry/forbidden_probe.dart',
  'frame': 'lib/src/frame/forbidden_probe.dart',
  'interaction': 'lib/src/interaction/forbidden_probe.dart',
  'tools': 'lib/src/tools/forbidden_probe.dart',
  'surface': 'lib/src/surface/forbidden_probe.dart',
};

int _phaseIndex(String phase) {
  if (!phase.startsWith('P')) {
    return -1;
  }

  return int.parse(phase.substring(1));
}

ExpectedArchitectureGraph _fixtureGraph() {
  return ExpectedArchitectureGraph(
    schemaVersion: 1,
    phases: _fixturePhases(),
    coverage: _fixtureCoverage(),
    nodes: _fixtureNodes(),
    edges: _fixtureEdges(),
    placeholders: _fixturePlaceholders(),
    forbiddenEdges: _fixtureForbiddenEdges(),
    views: const [],
    sourceCoverage: const [],
  );
}

List<ArchitecturePhase> _fixturePhases() {
  return [
    for (var index = 0; index <= 14; index++)
      ArchitecturePhase(
        id: 'P$index',
        title: 'P$index',
        status: index <= 4 ? 'closed' : 'future',
        sourceDocs: const [SourceDoc(path: 'docs/architecture/README.md')],
      ),
  ];
}

ArchitectureCoverage _fixtureCoverage() {
  return const ArchitectureCoverage(
    publicSurfaces: ['lib/src/api/**'],
    architectureOwners: ['lib/src/runtime/**', 'lib/src/codec/**'],
    sensitiveThrows: [
      SensitiveThrowCoverage(
        owner: 'fixture.codec',
        under: 'lib/src/codec/**',
        exception: 'FixtureException',
      ),
    ],
    placeholders: [PlaceholderCoverage(under: 'lib/src/api/**')],
    ignored: ['**/fixtures/**'],
  );
}

List<ArchitectureNode> _fixtureNodes() {
  return [
    _fixtureRuntimeNode(),
    _fixtureApiNode(),
    _fixtureCodecNode(),
    _fixtureFutureNode(),
  ];
}

ArchitectureNode _fixtureRuntimeNode() {
  return const ArchitectureNode(
    id: 'fixture.required_node',
    label: 'Fixture runtime',
    kind: 'runtime_owner',
    owner: 'runtime',
    phaseIntroduced: 'P4',
    phaseRequiredBy: 'P4',
    status: 'required',
    coverageScope: 'architectureOwners',
    sourceDocs: [SourceDoc(path: 'docs/architecture/README.md')],
    evidence: ['fixture'],
    actual: ActualExpectation(
      declarations: ['FixtureRuntime'],
      implementedInterfaces: ['FixturePort'],
    ),
  );
}

ArchitectureNode _fixtureApiNode() {
  return const ArchitectureNode(
    id: 'fixture.api',
    label: 'Fixture facade',
    kind: 'facade',
    owner: 'api',
    phaseIntroduced: 'P4',
    phaseRequiredBy: 'P4',
    status: 'required',
    coverageScope: 'publicSurfaces',
    sourceDocs: [SourceDoc(path: 'docs/architecture/README.md')],
    evidence: ['fixture'],
    actual: ActualExpectation(declarations: ['FixtureFacade']),
  );
}

ArchitectureNode _fixtureCodecNode() {
  return const ArchitectureNode(
    id: 'fixture.codec',
    label: 'Fixture codec',
    kind: 'codec_owner',
    owner: 'codec',
    phaseIntroduced: 'P3',
    phaseRequiredBy: 'P3',
    status: 'required',
    coverageScope: 'architectureOwners',
    sourceDocs: [SourceDoc(path: 'docs/architecture/README.md')],
    evidence: ['fixture'],
    actual: ActualExpectation.empty(),
  );
}

ArchitectureNode _fixtureFutureNode() {
  return const ArchitectureNode(
    id: 'fixture.future_node',
    label: 'Future owner',
    kind: 'future_owner',
    owner: 'runtime',
    phaseIntroduced: 'P5',
    phaseRequiredBy: 'P5',
    status: 'future',
    coverageScope: 'architectureOwners',
    sourceDocs: [SourceDoc(path: 'docs/architecture/README.md')],
    evidence: ['fixture'],
    actual: ActualExpectation(declarations: ['FutureRuntime']),
  );
}

List<ArchitectureEdge> _fixtureEdges() {
  return const [
    ArchitectureEdge(
      id: 'fixture.required_edge',
      from: 'fixture.api',
      to: 'fixture.required_node',
      kind: 'composes',
      phaseRequiredBy: 'P4',
      status: 'required',
      sourceDocs: [SourceDoc(path: 'docs/architecture/README.md')],
      evidence: ['fixture'],
      actual: ActualExpectation(compositionFields: ['FixtureRuntime']),
    ),
    ArchitectureEdge(
      id: 'fixture.future_edge',
      from: 'fixture.api',
      to: 'fixture.required_node',
      kind: 'future',
      phaseRequiredBy: 'P5',
      status: 'future',
      sourceDocs: [SourceDoc(path: 'docs/architecture/README.md')],
      evidence: ['fixture'],
      actual: ActualExpectation(compositionFields: ['FutureRuntime']),
    ),
  ];
}

List<ArchitecturePlaceholder> _fixturePlaceholders() {
  return const [
    ArchitecturePlaceholder(
      id: 'runtime.canvas_runtime.camera.closed_phase_placeholder',
      node: 'fixture.api',
      member: 'FixtureFacade.camera',
      path: 'lib/src/api/facade.dart',
      phaseRequiredBy: 'P4',
      status: 'forbidden_after_phase',
      sourceDocs: [SourceDoc(path: 'docs/architecture/README.md')],
      evidence: ['fixture'],
    ),
    ArchitecturePlaceholder(
      id: 'fixture.future_placeholder',
      node: 'fixture.api',
      member: 'FixtureFacade.future',
      path: 'lib/src/api/facade.dart',
      phaseRequiredBy: 'P5',
      status: 'deferred_until_phase',
      sourceDocs: [SourceDoc(path: 'docs/architecture/README.md')],
      evidence: ['fixture'],
    ),
  ];
}

List<ArchitectureForbiddenEdge> _fixtureForbiddenEdges() {
  return const [
    ArchitectureForbiddenEdge(
      id: 'fixture.forbidden_runtime_import',
      from: 'fixture.codec',
      to: 'fixture.required_node',
      kind: 'forbidden_import',
      phaseRequiredBy: 'P4',
      status: 'forbidden',
      sourceDocs: [SourceDoc(path: 'docs/architecture/README.md')],
      evidence: ['fixture'],
    ),
  ];
}

ExpectedArchitectureGraph _fixtureGraphWithDiagnosticRoute() {
  final graph = _fixtureGraph();

  return ExpectedArchitectureGraph(
    schemaVersion: graph.schemaVersion,
    phases: graph.phases,
    coverage: graph.coverage,
    nodes: graph.nodes,
    edges: [
      ...graph.edges,
      const ArchitectureEdge(
        id: 'fixture.codec_reports_diagnostics',
        from: 'fixture.codec',
        to: 'fixture.required_node',
        kind: 'diagnostic_route',
        phaseRequiredBy: 'P4',
        status: 'required',
        sourceDocs: [SourceDoc(path: 'docs/architecture/README.md')],
        evidence: ['fixture'],
        actual: ActualExpectation(
          delegationMembers: ['recordFixtureRoute'],
          delegationTargets: ['FixtureDiagnostics'],
          sensitiveThrowOwner: 'fixture.codec',
          sensitiveThrowRoutes: ['recordFixtureRoute'],
        ),
      ),
    ],
    placeholders: graph.placeholders,
    forbiddenEdges: graph.forbiddenEdges,
    views: graph.views,
    sourceCoverage: graph.sourceCoverage,
  );
}

// The fixture builder keeps fact lists independent so each test states only the
// evidence it contributes without introducing a mutable builder layer.
// ignore: number-of-parameters
ActualArchitectureGraph _actualGraph({
  List<ImportFact> imports = const [],
  List<DeclarationFact> declarations = const [],
  List<CompositionFieldFact> compositionFields = const [],
  List<PlaceholderFact> placeholders = const [],
  List<ImplementedInterfaceFact> implementedInterfaces = const [],
  List<ExceptionThrowFact> exceptionThrows = const [],
  List<DelegationFact> delegations = const [],
  List<MemberCallFact> memberCalls = const [],
}) {
  return ActualArchitectureGraph(
    exports: const [],
    imports: imports,
    declarations: declarations,
    implementedInterfaces: implementedInterfaces,
    compositionFields: compositionFields,
    placeholders: placeholders,
    exceptionThrows: exceptionThrows,
    delegations: delegations,
    memberCalls: memberCalls,
  );
}

ActualArchitectureGraph _withImports(
  ActualArchitectureGraph actual,
  List<ImportFact> imports,
) {
  return ActualArchitectureGraph(
    exports: actual.exports,
    imports: [...actual.imports, ...imports],
    declarations: actual.declarations,
    implementedInterfaces: actual.implementedInterfaces,
    compositionFields: actual.compositionFields,
    placeholders: actual.placeholders,
    exceptionThrows: actual.exceptionThrows,
    delegations: actual.delegations,
    memberCalls: actual.memberCalls,
  );
}
