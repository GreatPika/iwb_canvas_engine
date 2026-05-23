import 'dart:io';

import 'package:test/test.dart';

import '../../tool/architecture_graph/src/architecture_graph.dart';

void main() {
  group('expected graph shape', () {
    _registerGraphValidationTest();
    _registerPhaseInventoryTest();
    _registerClosureIdsTest();
    _registerCoverageCategoryTest();
    _registerSourceDocumentTest();
  });
  group('schema diagnostics', () {
    _registerEnumDiagnosticTest();
    _registerPhaseReferenceDiagnosticTest();
    _registerDuplicateGraphIdTest();
    _registerMissingSourceDocTest();
    _registerMissingCitationTest();
    _registerMissingAnchorLineTest();
    _registerOutOfBoundsAnchorTest();
    _registerMalformedCoverageTest();
  });
  group('source coverage diagnostics', () {
    _registerSourceCoverageCompletenessTest();
    _registerMissingSourceCoverageTest();
    _registerUnknownCoverageGraphIdTest();
    _registerEmptyCoverageGraphIdsTest();
    _registerMissingGraphEntryCoverageTest();
    _registerCoverageDispositionTextTest();
  });
}

void _registerGraphValidationTest() {
  test('expected architecture graph parses and validates', () {
    final graph = loadExpectedArchitectureGraph();
    final diagnostics = validateExpectedArchitectureGraph(graph);

    expect(diagnostics, isEmpty);
  });
}

void _registerPhaseInventoryTest() {
  test('expected architecture graph models all phases uniformly', () {
    final graph = loadExpectedArchitectureGraph();

    expect(graph.phaseIds, {
      for (var index = 0; index <= 14; index++) 'P$index',
    });
    expect(graph.phaseById('P14').status, 'measurement');
    expect(
      graph.nodes.map((node) => node.phaseRequiredBy).toSet(),
      contains('P14'),
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
      contains('runtime.canvas_runtime.camera.closed_phase_placeholder'),
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
    expect(graph.coverage.sensitiveThrows.single.owner, 'codec.schema_v1');
    expect(graph.coverage.placeholders.single.under, 'lib/src/api/**');
    expect(graph.coverage.ignored, contains('**/fixtures/**'));
  });
}

void _registerSourceDocumentTest() {
  test('source document paths exist but line evidence is not mandatory', () {
    final graph = loadExpectedArchitectureGraph();
    final sourceDocs = [
      for (final phase in graph.phases) ...phase.sourceDocs,
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
    final graph = _graphWith(
      phases: [
        ArchitecturePhase(
          id: 'P0',
          title: 'Invalid',
          status: 'invalid',
          sourceDocs: _validGraph().phases.first.sourceDocs,
        ),
        ..._validGraph().phases.skip(1),
      ],
    );

    expect(_diagnosticIds(graph), contains('enum.value'));
  });
}

void _registerPhaseReferenceDiagnosticTest() {
  test('schema validation rejects unknown phase references', () {
    final graph = _validGraph();
    final invalidNode = _nodeWith(graph.nodes.first, phaseRequiredBy: 'P99');

    expect(
      _diagnosticIds(_graphWith(nodes: [invalidNode, ...graph.nodes.skip(1)])),
      contains('phase.reference'),
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

Set<String> _diagnosticIds(ExpectedArchitectureGraph graph) {
  return validateExpectedArchitectureGraph(
    graph,
  ).map((diagnostic) => diagnostic.id).toSet();
}

ExpectedArchitectureGraph _graphWith({
  List<ArchitecturePhase>? phases,
  ArchitectureCoverage? coverage,
  List<ArchitectureNode>? nodes,
  List<ArchitectureSourceCoverage>? sourceCoverage,
}) {
  final graph = _validGraph();

  return ExpectedArchitectureGraph(
    schemaVersion: graph.schemaVersion,
    phases: phases ?? graph.phases,
    coverage: coverage ?? graph.coverage,
    nodes: nodes ?? graph.nodes,
    edges: graph.edges,
    placeholders: graph.placeholders,
    forbiddenEdges: graph.forbiddenEdges,
    views: graph.views,
    sourceCoverage: sourceCoverage ?? graph.sourceCoverage,
  );
}

// This fixture helper keeps schema-case variation local to the test data.
// ignore: number-of-parameters
ArchitectureNode _nodeWith(
  ArchitectureNode node, {
  String? id,
  String? phaseRequiredBy,
  List<SourceDoc>? sourceDocs,
  List<String>? evidence,
}) {
  return ArchitectureNode(
    id: id ?? node.id,
    label: node.label,
    kind: node.kind,
    owner: node.owner,
    phaseIntroduced: node.phaseIntroduced,
    phaseRequiredBy: phaseRequiredBy ?? node.phaseRequiredBy,
    status: node.status,
    coverageScope: node.coverageScope,
    sourceDocs: sourceDocs ?? node.sourceDocs,
    evidence: evidence ?? node.evidence,
    actual: node.actual,
    isolationAllowances: node.isolationAllowances,
  );
}
