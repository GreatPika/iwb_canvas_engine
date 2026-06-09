import 'dart:io';

import 'package:test/test.dart';

import '../../tool/architecture_graph/src/architecture_graph.dart';

void main() {
  group('expected graph shape', () {
    _registerGraphValidationTest();
    _registerNoPhaseMetadataTest();
    _registerClosureIdsTest();
    _registerCoverageCategoryTest();
    _registerSourceDocumentTest();
  });
  group('schema diagnostics', () {
    _registerEnumDiagnosticTest();
    _registerViewKindDiagnosticTest();
    _registerDuplicateGraphIdTest();
    _registerMissingSourceDocTest();
    _registerMissingCitationTest();
    _registerMissingAnchorLineTest();
    _registerOutOfBoundsAnchorTest();
    _registerMalformedCoverageTest();
    _registerRepositoryRelativeCoveragePathTest();
  });
  group('source coverage diagnostics', () {
    _registerSourceCoverageCompletenessTest();
    _registerMissingSourceCoverageTest();
    _registerUnknownCoverageGraphIdTest();
    _registerEmptyCoverageGraphIdsTest();
    _registerMissingGraphEntryCoverageTest();
    _registerCoverageDispositionTextTest();
    _registerRegistryPhaseMetadataIgnoredTest();
  });
}

void _registerGraphValidationTest() {
  test('expected architecture graph parses and validates', () {
    final graph = loadExpectedArchitectureGraph();
    final diagnostics = validateExpectedArchitectureGraph(graph);

    expect(diagnostics, isEmpty);
  });
}

void _registerNoPhaseMetadataTest() {
  test('expected architecture graph has no phase inventory metadata', () {
    final graph = loadExpectedArchitectureGraph();
    final source = File(architectureGraphPath).readAsStringSync();

    expect(source, isNot(contains('\nphases:')));
    expect(source, isNot(contains('phaseIntroduced')));
    expect(source, isNot(contains('phaseRequiredBy')));
    expect(
      graph.views.map((view) => view.output),
      isNot(contains('docs/diagrams/generated/current_phase.mmd')),
    );
    expect(
      graph.views.map((view) => view.output),
      isNot(contains('docs/diagrams/generated/future_target.mmd')),
    );
  });
}

void _registerClosureIdsTest() {
  test('expected architecture graph owns P3 and P4 closure ids', () {
    final graph = loadExpectedArchitectureGraph();

    expect(
      graph.edges.map((edge) => edge.id),
      contains('codec.schema_v1.failures.report_to_diagnostics'),
    );
    expect(
      graph.placeholders.map((placeholder) => placeholder.id),
      contains('runtime.canvas_runtime.camera.current_placeholder'),
    );
  });
}

void _registerCoverageCategoryTest() {
  test('expected architecture graph has explicit coverage categories', () {
    final graph = loadExpectedArchitectureGraph();

    expect(
      graph.coverage.publicSurfaces,
      contains('lib/iwb_canvas_engine.dart'),
    );
    expect(graph.coverage.architectureOwners, contains('lib/src/runtime/**'));
    expect(
      graph.coverage.architectureOwners,
      isNot(contains('lib/src/tools/**')),
    );
    expect(graph.coverage.sensitiveThrows.single.owner, 'codec.schema_v1');
    expect(graph.coverage.placeholders.single.under, 'lib/src/api/**');
    expect(graph.coverage.ignored, contains('**/fixtures/**'));
  });
}

void _registerSourceDocumentTest() {
  test('source document paths exist but line evidence is not mandatory', () {
    final graph = loadExpectedArchitectureGraph();
    final sourceDocs = [
      for (final node in graph.nodes) ...node.sourceDocs,
      for (final edge in graph.edges) ...edge.sourceDocs,
      for (final placeholder in graph.placeholders) ...placeholder.sourceDocs,
      for (final edge in graph.forbiddenEdges) ...edge.sourceDocs,
      for (final view in graph.views) ...view.sourceDocs,
    ];

    expect(sourceDocs, isNotEmpty);
    expect(sourceDocs.any((sourceDoc) => sourceDoc.line == null), isTrue);
    for (final sourceDoc in sourceDocs) {
      expect(File(sourceDoc.path).existsSync(), isTrue, reason: sourceDoc.path);
    }
  });
}

void _registerEnumDiagnosticTest() {
  test('schema validation rejects unsupported enum values', () {
    final graph = _validGraph();
    final invalidNode = _invalidStatusNode(graph.nodes.first);

    expect(
      _diagnosticIds(_graphWith(nodes: [invalidNode, ...graph.nodes.skip(1)])),
      contains('enum.value'),
    );
  });
}

void _registerViewKindDiagnosticTest() {
  test('schema validation rejects old selected-phase view kinds', () {
    final graph = _validGraph();
    final invalidView = ArchitectureView(
      id: 'invalid.current_phase',
      title: 'Invalid selected phase view',
      kind: 'expected_current_phase',
      output: 'docs/diagrams/generated/current_phase.mmd',
      sourceDocs: graph.views.first.sourceDocs,
    );

    expect(
      _diagnosticIds(_graphWith(views: [invalidView, ...graph.views])),
      contains('enum.value'),
    );
  });
}

void _registerDuplicateGraphIdTest() {
  test('schema validation rejects duplicate graph ids', () {
    final graph = _validGraph();
    final duplicate = _nodeWith(graph.nodes.last, id: graph.nodes.first.id);

    expect(
      _diagnosticIds(_graphWith(nodes: [...graph.nodes, duplicate])),
      contains('graph.id.duplicate'),
    );
  });
}

void _registerMissingSourceDocTest() {
  test('schema validation rejects missing source documents', () {
    final graph = _validGraph();
    final invalidNode = _nodeWith(
      graph.nodes.first,
      sourceDocs: const [SourceDoc(path: 'docs/missing.md')],
    );

    expect(
      _diagnosticIds(_graphWith(nodes: [invalidNode, ...graph.nodes.skip(1)])),
      contains('source_doc.path'),
    );
  });
}

void _registerMissingCitationTest() {
  test('schema validation rejects obligations without citations', () {
    final graph = _validGraph();
    final invalidNode = _nodeWith(
      graph.nodes.first,
      sourceDocs: const [],
      evidence: const [],
    );

    expect(
      _diagnosticIds(_graphWith(nodes: [invalidNode, ...graph.nodes.skip(1)])),
      contains('required.non_empty'),
    );
  });
}

void _registerMissingAnchorLineTest() {
  test('schema validation rejects stable anchors without a line', () {
    final graph = _validGraph();
    final invalidNode = _nodeWith(
      graph.nodes.first,
      sourceDocs: const [
        SourceDoc(
          path: 'docs/architecture/00_architecture_overview.md',
          stableAnchor: true,
        ),
      ],
    );

    expect(
      _diagnosticIds(_graphWith(nodes: [invalidNode, ...graph.nodes.skip(1)])),
      contains('source_doc.anchor'),
    );
  });
}

void _registerOutOfBoundsAnchorTest() {
  test(
    'schema validation rejects stable anchors outside source file bounds',
    () {
      final graph = _validGraph();
      final invalidNode = _nodeWith(
        graph.nodes.first,
        sourceDocs: const [
          SourceDoc(
            path: 'docs/architecture/00_architecture_overview.md',
            line: 1000000,
            stableAnchor: true,
          ),
        ],
      );

      expect(
        _diagnosticIds(
          _graphWith(nodes: [invalidNode, ...graph.nodes.skip(1)]),
        ),
        contains('source_doc.anchor'),
      );
    },
  );
}

void _registerMalformedCoverageTest() {
  test('schema validation rejects malformed coverage entries', () {
    final graph = _validGraph();
    final invalidCoverage = ArchitectureCoverage(
      publicSurfaces: const [''],
      architectureOwners: graph.coverage.architectureOwners,
      sensitiveThrows: const [
        SensitiveThrowCoverage(owner: '', under: '', exception: ''),
      ],
      placeholders: const [PlaceholderCoverage(under: '')],
      ignored: graph.coverage.ignored,
    );

    expect(
      _diagnosticIds(_graphWith(coverage: invalidCoverage)),
      contains('required.text'),
    );
  });

  test('schema validation rejects empty production coverage globs', () {
    final graph = _graphWith(
      coverage: ArchitectureCoverage(
        publicSurfaces: const ['lib/iwb_canvas_engine.dart'],
        architectureOwners: const ['lib/src/missing_owner/**'],
        sensitiveThrows: _validGraph().coverage.sensitiveThrows,
        placeholders: _validGraph().coverage.placeholders,
        ignored: _validGraph().coverage.ignored,
      ),
    );

    expect(_diagnosticIds(graph), contains('coverage.empty_glob'));
  });
}

void _registerRepositoryRelativeCoveragePathTest() {
  test(
    'schema validation classifies production paths relative to repo root',
    () {
      _withTemporaryRepositoryUnderTestPath((repositoryRoot) {
        expect(
          _diagnosticIds(
            _minimalCoverageGraph(
              publicSurfaces: const ['lib/iwb_canvas_engine.dart'],
              architectureOwners: const ['lib/src/covered/**'],
            ),
            repositoryRoot: repositoryRoot.path,
          ),
          isNot(contains('coverage.empty_glob')),
        );
      });
    },
  );

  test('schema validation rejects repo-relative test coverage paths', () {
    _withTemporaryRepositoryUnderTestPath((repositoryRoot) {
      expect(
        _diagnosticIds(
          _minimalCoverageGraph(
            publicSurfaces: const ['test/foo.dart'],
            architectureOwners: const ['test/**'],
          ),
          repositoryRoot: repositoryRoot.path,
        ),
        contains('coverage.empty_glob'),
      );
    });
  });
}

void _registerSourceCoverageCompletenessTest() {
  test('expected graph source coverage is complete', () {
    final graph = loadExpectedArchitectureGraph();

    expect(_diagnosticIds(graph), isNot(contains('source_coverage.section')));
    expect(
      graph.sourceCoverage.map((coverage) => coverage.sectionId),
      containsAll([
        'section_02_architecture_model',
        'section_14_interaction_engine',
        'section_27_final_release_gates',
      ]),
    );
  });
}

void _registerMissingSourceCoverageTest() {
  test('schema validation rejects missing registry section coverage', () {
    final graph = loadExpectedArchitectureGraph();

    expect(
      _diagnosticIds(
        _graphWith(sourceCoverage: _withoutFirstSourceCoverage(graph)),
      ),
      contains('source_coverage.missing_section'),
    );
  });
}

void _registerUnknownCoverageGraphIdTest() {
  test('schema validation rejects unknown source coverage graph ids', () {
    final graph = loadExpectedArchitectureGraph();

    expect(
      _diagnosticIds(
        _graphWith(
          sourceCoverage: [
            _sourceCoverageWith(graph, graphIds: const ['missing.graph_id']),
            ...graph.sourceCoverage.skip(1),
          ],
        ),
      ),
      contains('source_coverage.graph_id'),
    );
  });
}

void _registerEmptyCoverageGraphIdsTest() {
  test('schema validation rejects empty graph-obligation coverage ids', () {
    final graph = loadExpectedArchitectureGraph();

    expect(
      _diagnosticIds(
        _graphWith(
          sourceCoverage: [
            _sourceCoverageWith(graph, graphIds: const []),
            ...graph.sourceCoverage.skip(1),
          ],
        ),
      ),
      contains('required.non_empty'),
    );
  });
}

void _registerMissingGraphEntryCoverageTest() {
  test('schema validation rejects graph entries without source coverage', () {
    final graph = loadExpectedArchitectureGraph();
    final extraNode = _nodeWith(graph.nodes.first, id: 'missing.coverage');

    expect(
      _diagnosticIds(_graphWith(nodes: [...graph.nodes, extraNode])),
      contains('source_coverage.missing_graph_entry'),
    );
  });
}

void _registerCoverageDispositionTextTest() {
  test(
    'schema validation rejects disposition entries without required text',
    () {
      final graph = loadExpectedArchitectureGraph();

      expect(
        _diagnosticIds(
          _graphWith(
            sourceCoverage: [
              _reasonlessSourceCoverage(graph),
              ...graph.sourceCoverage.skip(1),
            ],
          ),
        ),
        contains('required.text'),
      );
      expect(
        _diagnosticIds(
          _graphWith(
            sourceCoverage: [
              _supersededSourceCoverageWithoutSuccessor(graph),
              ...graph.sourceCoverage.skip(1),
            ],
          ),
        ),
        contains('required.text'),
      );
    },
  );
}

void _registerRegistryPhaseMetadataIgnoredTest() {
  test('source coverage selection ignores registry phase metadata', () {
    final repository = Directory.systemTemp.createTempSync(
      'architecture_graph_registry_',
    );
    try {
      _writeSourceCoverageRegistryFixture(repository);

      expect(
        _diagnosticIds(
          _minimalSourceCoverageGraph,
          repositoryRoot: repository.path,
        ),
        isNot(contains('source_coverage.missing_section')),
      );
    } finally {
      repository.deleteSync(recursive: true);
    }
  });
}

ArchitectureSourceCoverage _reasonlessSourceCoverage(
  ExpectedArchitectureGraph graph,
) {
  return ArchitectureSourceCoverage(
    sectionId: graph.sourceCoverage.first.sectionId,
    disposition: 'non_graph_semantics',
    graphIds: const [],
    reason: '',
    successorSource: null,
  );
}

ArchitectureSourceCoverage _supersededSourceCoverageWithoutSuccessor(
  ExpectedArchitectureGraph graph,
) {
  return ArchitectureSourceCoverage(
    sectionId: graph.sourceCoverage.first.sectionId,
    disposition: 'superseded',
    graphIds: const [],
    reason: null,
    successorSource: '',
  );
}

List<ArchitectureSourceCoverage> _withoutFirstSourceCoverage(
  ExpectedArchitectureGraph graph,
) {
  return graph.sourceCoverage.skip(1).toList();
}

ArchitectureSourceCoverage _sourceCoverageWith(
  ExpectedArchitectureGraph graph, {
  required List<String> graphIds,
}) {
  return ArchitectureSourceCoverage(
    sectionId: graph.sourceCoverage.first.sectionId,
    disposition: 'graph_obligation',
    graphIds: graphIds,
    reason: null,
    successorSource: null,
  );
}

ExpectedArchitectureGraph _validGraph() => loadExpectedArchitectureGraph();

Set<String> _diagnosticIds(
  ExpectedArchitectureGraph graph, {
  String repositoryRoot = '.',
}) {
  return validateExpectedArchitectureGraph(
    graph,
    repositoryRoot: repositoryRoot,
  ).map((diagnostic) => diagnostic.id).toSet();
}

ExpectedArchitectureGraph _graphWith({
  ArchitectureCoverage? coverage,
  List<ArchitectureNode>? nodes,
  List<ArchitectureView>? views,
  List<ArchitectureSourceCoverage>? sourceCoverage,
}) {
  final graph = _validGraph();

  return ExpectedArchitectureGraph(
    schemaVersion: graph.schemaVersion,
    coverage: coverage ?? graph.coverage,
    nodes: nodes ?? graph.nodes,
    edges: graph.edges,
    placeholders: graph.placeholders,
    forbiddenEdges: graph.forbiddenEdges,
    views: views ?? graph.views,
    sourceCoverage: sourceCoverage ?? graph.sourceCoverage,
  );
}

ArchitectureNode _nodeWith(
  ArchitectureNode node, {
  String? id,
  List<SourceDoc>? sourceDocs,
  List<String>? evidence,
}) {
  return ArchitectureNode(
    id: id ?? node.id,
    label: node.label,
    kind: node.kind,
    owner: node.owner,
    status: node.status,
    coverageScope: node.coverageScope,
    sourceDocs: sourceDocs ?? node.sourceDocs,
    evidence: evidence ?? node.evidence,
    actual: node.actual,
    isolationAllowances: node.isolationAllowances,
  );
}

ArchitectureNode _invalidStatusNode(ArchitectureNode node) {
  return ArchitectureNode(
    id: node.id,
    label: node.label,
    kind: node.kind,
    owner: node.owner,
    status: 'invalid',
    coverageScope: node.coverageScope,
    sourceDocs: node.sourceDocs,
    evidence: node.evidence,
    actual: node.actual,
    isolationAllowances: node.isolationAllowances,
  );
}

void _writeSourceCoverageRegistryFixture(Directory repository) {
  File('${repository.path}/docs/_registry/sections.yaml')
    ..createSync(recursive: true)
    ..writeAsStringSync('''
-
  id: section_current_architecture
  file: docs/architecture/current.md
-
  id: section_phase_only
  file: docs/implementation/phase_only.md
  phases:
    - P14
''');
  File('${repository.path}/docs/architecture/current.md')
    ..createSync(recursive: true)
    ..writeAsStringSync('current architecture source\n');
}

void _withTemporaryRepositoryUnderTestPath(void Function(Directory) callback) {
  final temporary = Directory.systemTemp.createTempSync(
    'architecture_graph_schema_',
  );
  try {
    final repositoryRoot = Directory('${temporary.path}/outer/test/repo')
      ..createSync(recursive: true);
    _writeSourceCoverageRegistryFixture(repositoryRoot);
    File('${repositoryRoot.path}/lib/iwb_canvas_engine.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('// public surface\n');
    File('${repositoryRoot.path}/lib/src/covered/owner.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('// owner\n');
    File('${repositoryRoot.path}/test/foo.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('// test-only\n');
    callback(repositoryRoot);
  } finally {
    temporary.deleteSync(recursive: true);
  }
}

ExpectedArchitectureGraph _minimalCoverageGraph({
  required List<String> publicSurfaces,
  required List<String> architectureOwners,
}) {
  return ExpectedArchitectureGraph(
    schemaVersion: _minimalSourceCoverageGraph.schemaVersion,
    coverage: ArchitectureCoverage(
      publicSurfaces: publicSurfaces,
      architectureOwners: architectureOwners,
      sensitiveThrows: _minimalSourceCoverageGraph.coverage.sensitiveThrows,
      placeholders: _minimalSourceCoverageGraph.coverage.placeholders,
      ignored: _minimalSourceCoverageGraph.coverage.ignored,
    ),
    nodes: _minimalSourceCoverageGraph.nodes,
    edges: _minimalSourceCoverageGraph.edges,
    placeholders: _minimalSourceCoverageGraph.placeholders,
    forbiddenEdges: _minimalSourceCoverageGraph.forbiddenEdges,
    views: _minimalSourceCoverageGraph.views,
    sourceCoverage: _minimalSourceCoverageGraph.sourceCoverage,
  );
}

const _minimalSourceCoverageGraph = ExpectedArchitectureGraph(
  schemaVersion: 1,
  coverage: ArchitectureCoverage(
    publicSurfaces: ['lib/iwb_canvas_engine.dart'],
    architectureOwners: ['lib/src/**'],
    sensitiveThrows: [
      SensitiveThrowCoverage(
        owner: 'test.owner',
        under: 'lib/src/**',
        exception: 'StateError',
      ),
    ],
    placeholders: [PlaceholderCoverage(under: 'lib/src/**')],
    ignored: ['test/**'],
  ),
  nodes: [
    ArchitectureNode(
      id: 'test.current',
      label: 'Current test owner',
      kind: 'test_owner',
      owner: 'test',
      status: 'required',
      coverageScope: 'architectureOwners',
      sourceDocs: [SourceDoc(path: 'docs/architecture/current.md')],
      evidence: ['Minimal current graph owner.'],
      actual: ActualExpectation.empty(),
      isolationAllowances: [],
    ),
  ],
  edges: [],
  placeholders: [],
  forbiddenEdges: [],
  views: [],
  sourceCoverage: [
    ArchitectureSourceCoverage(
      sectionId: 'section_current_architecture',
      disposition: 'graph_obligation',
      graphIds: ['test.current'],
      reason: null,
      successorSource: null,
    ),
  ],
);
