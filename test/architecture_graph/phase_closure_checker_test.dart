import 'package:test/test.dart';

import '../../tool/architecture_graph/src/actual_graph.dart';
import '../../tool/architecture_graph/src/architecture_graph.dart';
import '../../tool/architecture_graph/src/phase_closure.dart';

void main() {
  test('fails missing required nodes and edges for the selected phase', () {
    final report = checkPhaseClosure(
      expected: _fixtureGraph(),
      actual: _actualGraph(),
      selectedPhase: 'P4',
    );

    expect(_ids(report), contains('fixture.required_node'));
    expect(_ids(report), contains('fixture.required_edge'));
  });

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

  test('requires future obligations when selected phase reaches them', () {
    final report = checkPhaseClosure(
      expected: _fixtureGraph(),
      actual: _actualGraph(),
      selectedPhase: 'P5',
    );

    expect(_ids(report), contains('fixture.future_edge'));
    expect(_ids(report), contains('fixture.future_node'));
  });

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

  test('reports known P3 and P4 drift ids in the production graph', () {
    final expected = loadExpectedArchitectureGraph();
    final actual = extractActualArchitectureGraph(expectedGraph: expected);
    final report = checkPhaseClosure(
      expected: expected,
      actual: actual,
      selectedPhase: 'P4',
    );

    expect(
      _ids(report),
      contains('runtime.canvas_runtime.camera.closed_phase_placeholder'),
    );
    expect(
      _ids(report),
      contains('codec.schema_v1.failures.report_to_diagnostics'),
    );
  });
}

Set<String> _ids(PhaseClosureReport report) {
  return report.violations.map((violation) => violation.graphId).toSet();
}

ExpectedArchitectureGraph _fixtureGraph() {
  return ExpectedArchitectureGraph(
    schemaVersion: 1,
    phases: [
      for (var index = 0; index <= 14; index++)
        ArchitecturePhase(
          id: 'P$index',
          title: 'P$index',
          status: index <= 4 ? 'closed' : 'future',
          sourceDocs: const [SourceDoc(path: 'docs/architecture/README.md')],
        ),
    ],
    coverage: const ArchitectureCoverage(
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
    ),
    nodes: const [
      ArchitectureNode(
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
      ),
      ArchitectureNode(
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
      ),
      ArchitectureNode(
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
      ),
      ArchitectureNode(
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
      ),
    ],
    edges: const [
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
    ],
    placeholders: const [
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
    ],
    forbiddenEdges: const [
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
    ],
    views: const [],
  );
}

ActualArchitectureGraph _actualGraph({
  List<ImportFact> imports = const [],
  List<DeclarationFact> declarations = const [],
  List<CompositionFieldFact> compositionFields = const [],
  List<PlaceholderFact> placeholders = const [],
  List<ImplementedInterfaceFact> implementedInterfaces = const [],
}) {
  return ActualArchitectureGraph(
    exports: const [],
    imports: imports,
    declarations: declarations,
    implementedInterfaces: implementedInterfaces,
    compositionFields: compositionFields,
    placeholders: placeholders,
    exceptionThrows: const [],
    delegations: const [],
  );
}
