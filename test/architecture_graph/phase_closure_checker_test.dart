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
    _registerProductionClosureTest();
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
  test('production graph forbidden edges cover contract DAG boundaries', () {
    final expected = loadExpectedArchitectureGraph();
    final activeForbiddenEdges = _activeForbiddenEdges(expected);
    final actual = _withImports(
      extractActualArchitectureGraph(expectedGraph: expected),
      _forbiddenEdgeProbeImports(expected, activeForbiddenEdges),
    );
    final report = checkPhaseClosure(
      expected: expected,
      actual: actual,
      selectedPhase: 'P6',
    );

    expect(
      _ids(report),
      containsAll(activeForbiddenEdges.map((edge) => edge.id)),
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

List<ArchitectureForbiddenEdge> _activeForbiddenEdges(
  ExpectedArchitectureGraph expected,
) {
  return expected.forbiddenEdges.where((edge) {
    return _fixturePhaseIndex(edge.phaseRequiredBy) <= _fixturePhaseIndex('P6');
  }).toList();
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

int _fixturePhaseIndex(String phase) {
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
