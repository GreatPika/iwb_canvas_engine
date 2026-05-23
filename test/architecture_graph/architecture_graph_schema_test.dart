import 'dart:io';

import 'package:test/test.dart';

import '../../tool/architecture_graph/src/architecture_graph.dart';

void main() {
  test('expected architecture graph parses and validates', () {
    final graph = loadExpectedArchitectureGraph();
    final diagnostics = validateExpectedArchitectureGraph(graph);

    expect(diagnostics, isEmpty);
  });

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

  test('schema validation rejects unknown phase references', () {
    final graph = _validGraph();
    final invalidNode = _nodeWith(graph.nodes.first, phaseRequiredBy: 'P99');

    expect(
      _diagnosticIds(_graphWith(nodes: [invalidNode, ...graph.nodes.skip(1)])),
      contains('phase.reference'),
    );
  });

  test('schema validation rejects duplicate graph ids', () {
    final graph = _validGraph();
    final duplicate = _nodeWith(graph.nodes.last, id: graph.nodes.first.id);

    expect(
      _diagnosticIds(_graphWith(nodes: [...graph.nodes, duplicate])),
      contains('graph.id.duplicate'),
    );
  });

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
    expect(
      _diagnosticIds(
        _graphWith(sourceCoverage: graph.sourceCoverage.skip(1).toList()),
      ),
      contains('source_coverage.missing_section'),
    );
    final invalidCoverage = ArchitectureSourceCoverage(
      sectionId: graph.sourceCoverage.first.sectionId,
      disposition: 'graph_obligation',
      graphIds: const ['missing.graph_id'],
      reason: null,
      successorSource: null,
    );
    final emptyGraphIdsCoverage = ArchitectureSourceCoverage(
      sectionId: graph.sourceCoverage.first.sectionId,
      disposition: 'graph_obligation',
      graphIds: const [],
      reason: null,
      successorSource: null,
    );

    expect(
      _diagnosticIds(
        _graphWith(
          sourceCoverage: [invalidCoverage, ...graph.sourceCoverage.skip(1)],
        ),
      ),
      contains('source_coverage.graph_id'),
    );
    expect(
      _diagnosticIds(
        _graphWith(
          sourceCoverage: [
            emptyGraphIdsCoverage,
            ...graph.sourceCoverage.skip(1),
          ],
        ),
      ),
      contains('required.non_empty'),
    );
    final extraNode = _nodeWith(graph.nodes.first, id: 'missing.coverage');

    expect(
      _diagnosticIds(_graphWith(nodes: [...graph.nodes, extraNode])),
      contains('source_coverage.missing_graph_entry'),
    );
    final reasonlessCoverage = ArchitectureSourceCoverage(
      sectionId: graph.sourceCoverage.first.sectionId,
      disposition: 'non_graph_semantics',
      graphIds: const [],
      reason: '',
      successorSource: null,
    );
    final supersededWithoutSuccessor = ArchitectureSourceCoverage(
      sectionId: graph.sourceCoverage.first.sectionId,
      disposition: 'superseded',
      graphIds: const [],
      reason: null,
      successorSource: '',
    );

    expect(
      _diagnosticIds(
        _graphWith(
          sourceCoverage: [reasonlessCoverage, ...graph.sourceCoverage.skip(1)],
        ),
      ),
      contains('required.text'),
    );
    expect(
      _diagnosticIds(
        _graphWith(
          sourceCoverage: [
            supersededWithoutSuccessor,
            ...graph.sourceCoverage.skip(1),
          ],
        ),
      ),
      contains('required.text'),
    );
  });
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
