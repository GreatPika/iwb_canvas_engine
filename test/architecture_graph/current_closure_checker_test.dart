import 'dart:io';

import 'package:test/test.dart';

import '../../tool/architecture_graph/src/actual_graph.dart';
import '../../tool/architecture_graph/src/architecture_graph.dart';
import '../../tool/architecture_graph/src/current_closure.dart';

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
    _registerUnknownSeamTest();
    _registerCurrentSourceRepairInventoryTest();
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
  test('fails missing required nodes and edges for the current closure', () {
    final report = checkArchitectureClosure(
      expected: _fixtureGraph(),
      actual: _actualGraph(),
    );

    expect(_ids(report), contains('fixture.required_node'));
    expect(_ids(report), contains('fixture.required_edge'));
  });
}

void _registerFutureObligationTest() {
  test('requires all listed obligations in current closure', () {
    final report = checkArchitectureClosure(
      expected: _fixtureGraph(),
      actual: _actualGraph(),
    );

    expect(_ids(report), contains('fixture.future_edge'));
    expect(_ids(report), contains('fixture.future_node'));
  });
}

void _registerClosedPlaceholderTest() {
  test('fails tracked and untracked public placeholders', () {
    final report = checkArchitectureClosure(
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
    );

    expect(
      _ids(report),
      contains('runtime.canvas_runtime.camera.current_placeholder'),
    );
    expect(
      _ids(report),
      contains('placeholder.untracked.FixtureFacade.unknown'),
    );
  });
}

void _registerFuturePlaceholderTest() {
  test('fails deferred public placeholders in current closure', () {
    final report = checkArchitectureClosure(
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
    );

    expect(_ids(report), contains('fixture.future_edge'));
    expect(_ids(report), contains('fixture.current_placeholder'));
  });
}

void _registerForbiddenEdgeTest() {
  test('fails forbidden edges when current closure is closed', () {
    final report = checkArchitectureClosure(
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
    );

    expect(_ids(report), contains('fixture.forbidden_runtime_import'));
  });
}

void _registerUnknownSeamTest() {
  test('fails unknown architecture seams inside declared coverage', () {
    final report = checkArchitectureClosure(
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
    );

    expect(_ids(report), contains('architecture.unknown.ExtraRuntimeSeam'));
  });
}

void _registerProductionClosureTest() {
  test('production graph closes current obligations', () {
    final expected = loadExpectedArchitectureGraph();
    final actual = extractActualArchitectureGraph(expectedGraph: expected);
    final report = checkArchitectureClosure(expected: expected, actual: actual);

    expect(_ids(report), isEmpty);
  });
}

void _registerCurrentSourceRepairInventoryTest() {
  test('current graph keeps repaired facade and diagnostics scope', () {
    final expected = loadExpectedArchitectureGraph();

    expect(
      expected.edges.map((edge) => edge.id),
      contains('interaction.engine.reliability_events.report_to_diagnostics'),
    );

    _expectFacadePlaceholdersRetired(expected.placeholders);
    _expectFacadeRoutesDocumentCurrentOwners(expected.edges);
    _expectDiagnosticsScope(expected.edges);
    _expectDeferredDiagnosticsRoutesAreNotGraphBacked();
  });
}

void _expectFacadePlaceholdersRetired(
  Iterable<ArchitecturePlaceholder> placeholders,
) {
  final byId = {for (final placeholder in placeholders) placeholder.id};

  expect(byId, isNot(contains('api.canvas_runtime.tools.current_placeholder')));
  expect(
    byId,
    isNot(
      contains(
        'api.canvas_runtime.context_action_requests.current_placeholder',
      ),
    ),
  );
}

void _expectFacadeRoutesDocumentCurrentOwners(
  Iterable<ArchitectureEdge> edges,
) {
  final byId = {for (final edge in edges) edge.id: edge};

  expect(
    byId['api.canvas_runtime.tools.routes_to_runtime_tools']?.evidence.join(
      ' ',
    ),
    contains('P11 owns later draw production behavior behind the port'),
  );
  expect(
    byId['eraser_context.request.produces_context_action_requests']?.evidence
        .join(' '),
    contains('RuntimeRoot emits accepted P12 context-action requests'),
  );
}

void _expectDiagnosticsScope(Iterable<ArchitectureEdge> edges) {
  final byId = {for (final edge in edges) edge.id: edge};

  expect(
    byId,
    isNot(
      contains('geometry.spatial_index.corrupted_rows.report_to_diagnostics'),
    ),
  );
  expect(
    byId,
    isNot(contains('runtime.root.observer_failures.report_to_diagnostics')),
  );
  expect(
    byId['interaction.engine.reliability_events.report_to_diagnostics']?.status,
    'required',
  );
  expect(
    byId['interaction.engine.reliability_events.report_to_diagnostics']
        ?.actual
        .delegationTargets,
    contains('InteractionDiagnosticsSink'),
  );
}

void _expectDeferredDiagnosticsRoutesAreNotGraphBacked() {
  final currentContracts = [
    File('docs/contracts/diagnostics.md').readAsStringSync(),
    File('docs/contracts/edit_kernel.md').readAsStringSync(),
  ].join('\n');

  expect(
    currentContracts,
    isNot(
      contains('geometry.spatial_index.corrupted_rows.report_to_diagnostics'),
    ),
  );
  expect(
    currentContracts,
    isNot(contains('runtime.root.observer_failures.report_to_diagnostics')),
  );
}

void _registerCompositionEvidenceTest() {
  test('passes required non-placeholder edge when evidence exists', () {
    final report = checkArchitectureClosure(
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
    );

    expect(_ids(report), isNot(contains('fixture.required_edge')));
  });
}

void _registerWrongOwnerCompositionTest() {
  test(
    'does not close an edge with evidence from another class in the owner path',
    () {
      final report = checkArchitectureClosure(
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
      );

      expect(_ids(report), contains('fixture.required_edge'));
    },
  );
}

void _registerWrongOwnerDeclarationTest() {
  test(
    'does not close a required node with declarations from another owner',
    () {
      final report = checkArchitectureClosure(
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
      );

      expect(_ids(report), contains('fixture.required_node'));
    },
  );
}

void _registerInterfaceEvidenceTest() {
  test('compares implemented interface expectations', () {
    final missingReport = checkArchitectureClosure(
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
    );
    final passingReport = checkArchitectureClosure(
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
    );

    expect(_ids(missingReport), contains('fixture.required_node'));
    expect(_ids(passingReport), isNot(contains('fixture.required_node')));
  });
}

void _registerUnrelatedOwnerCompositionTest() {
  test('does not close an edge with evidence from an unrelated owner path', () {
    final report = checkArchitectureClosure(
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

ArchitectureClosureReport _missingDiagnosticRouteReport(
  ExpectedArchitectureGraph expected,
) {
  return checkArchitectureClosure(
    expected: expected,
    actual: _actualGraph(
      exceptionThrows: const [_diagnosticExceptionThrow],
      delegations: const [_diagnosticRouteDelegation],
    ),
  );
}

ArchitectureClosureReport _routedDiagnosticRouteReport(
  ExpectedArchitectureGraph expected,
) {
  return checkArchitectureClosure(
    expected: expected,
    actual: _actualGraph(
      exceptionThrows: const [_diagnosticExceptionThrow],
      delegations: const [_diagnosticRouteDelegation],
      memberCalls: const [_diagnosticRouteCall],
    ),
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

Set<String> _ids(ArchitectureClosureReport report) {
  return report.violations.map((violation) => violation.graphId).toSet();
}

ExpectedArchitectureGraph _fixtureGraph() {
  return ExpectedArchitectureGraph(
    schemaVersion: 1,
    coverage: _fixtureCoverage(),
    nodes: _fixtureNodes(),
    edges: _fixtureEdges(),
    placeholders: _fixturePlaceholders(),
    forbiddenEdges: _fixtureForbiddenEdges(),
    views: const [],
    sourceCoverage: const [],
  );
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
    label: 'Current owner',
    kind: 'current_owner',
    owner: 'runtime',
    status: 'required',
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
      status: 'required',
      sourceDocs: [SourceDoc(path: 'docs/architecture/README.md')],
      evidence: ['fixture'],
      actual: ActualExpectation(compositionFields: ['FixtureRuntime']),
    ),
    ArchitectureEdge(
      id: 'fixture.future_edge',
      from: 'fixture.api',
      to: 'fixture.required_node',
      kind: 'composes',
      status: 'required',
      sourceDocs: [SourceDoc(path: 'docs/architecture/README.md')],
      evidence: ['fixture'],
      actual: ActualExpectation(compositionFields: ['FutureRuntime']),
    ),
  ];
}

List<ArchitecturePlaceholder> _fixturePlaceholders() {
  return const [
    ArchitecturePlaceholder(
      id: 'runtime.canvas_runtime.camera.current_placeholder',
      node: 'fixture.api',
      member: 'FixtureFacade.camera',
      path: 'lib/src/api/facade.dart',
      status: 'forbidden',
      sourceDocs: [SourceDoc(path: 'docs/architecture/README.md')],
      evidence: ['fixture'],
    ),
    ArchitecturePlaceholder(
      id: 'fixture.current_placeholder',
      node: 'fixture.api',
      member: 'FixtureFacade.future',
      path: 'lib/src/api/facade.dart',
      status: 'forbidden',
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
    coverage: graph.coverage,
    nodes: graph.nodes,
    edges: [
      ...graph.edges,
      const ArchitectureEdge(
        id: 'fixture.codec_reports_diagnostics',
        from: 'fixture.codec',
        to: 'fixture.required_node',
        kind: 'diagnostic_route',
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
