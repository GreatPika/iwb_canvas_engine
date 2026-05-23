import 'dart:io';

import 'package:test/test.dart';

import '../../tool/architecture_graph/src/actual_graph.dart';
import '../../tool/architecture_graph/src/architecture_graph.dart';
import '../../tool/architecture_graph/src/graph_views.dart';

void main() {
  test('renders deterministic expected-only and diff graph views', () {
    final expected = loadExpectedArchitectureGraph();
    final actual = extractActualArchitectureGraph(expectedGraph: expected);
    final first = renderGraphViews(
      expected: expected,
      actual: actual,
      selectedPhase: 'P4',
    );
    final second = renderGraphViews(
      expected: expected,
      actual: actual,
      selectedPhase: 'P4',
    );

    expect(first, second);
    expect(
      first.keys.toSet(),
      expected.views.map((view) => view.output).toSet(),
    );
    expect(
      first['docs/diagrams/generated/full_architecture.mmd'],
      contains('api_canvas_runtime'),
    );
    expect(
      first['docs/diagrams/generated/current_phase.mmd'],
      isNot(contains('edit_kernel')),
    );
    expect(
      first['docs/diagrams/generated/future_target.mmd'],
      contains('edit_kernel'),
    );
    expect(
      first['docs/diagrams/generated/future_target.mmd'],
      contains('store_document_kernel'),
    );
    expect(
      first['docs/diagrams/generated/future_target.mmd'],
      contains('draw_tools'),
    );
    expect(
      first['docs/diagrams/generated/future_target.mmd'],
      isNot(contains('release_measurement')),
    );
    expect(
      first['docs/diagrams/generated/release_verification.mmd'],
      contains('release_measurement'),
    );
    expect(
      first['docs/diagrams/generated/actual_vs_expected_diff.mmd'],
      isNot(contains('violation_')),
    );
    expect(
      first['docs/diagrams/generated/actual_vs_expected_diff.mmd'],
      isNot(contains('linkStyle')),
    );
    expect(
      first['docs/diagrams/generated/current_phase.mmd'],
      contains('public API forwards to by P4'),
    );
    expect(
      first['docs/diagrams/generated/current_phase.mmd'],
      isNot(contains(r'\n')),
    );
    expect(
      first['docs/diagrams/generated/current_phase.mmd'],
      isNot(contains('facade_port P4')),
    );
    expect(
      first['docs/diagrams/generated/actual_vs_expected_diff.mmd'],
      isNot(contains('Missing required link')),
    );
  });

  test('checked-in generated graph views are current', () {
    final expected = loadExpectedArchitectureGraph();
    final actual = extractActualArchitectureGraph(expectedGraph: expected);
    final views = renderGraphViews(
      expected: expected,
      actual: actual,
      selectedPhase: 'P4',
    );

    for (final entry in views.entries) {
      expect(
        File(entry.key).readAsStringSync(),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('reproducibility check reports orphan generated Mermaid files', () {
    final directory = Directory.systemTemp.createTempSync('graph_views_');
    try {
      final expected = loadExpectedArchitectureGraph();
      final actual = extractActualArchitectureGraph(expectedGraph: expected);
      final views = renderGraphViews(
        expected: expected,
        actual: actual,
        selectedPhase: 'P4',
      );
      writeGraphViews(views: views, repositoryRoot: directory.path);
      File('${directory.path}/docs/diagrams/generated/old/orphan.mmd')
        ..createSync(recursive: true)
        ..writeAsStringSync('flowchart LR');

      expect(
        checkGraphViews(views: views, repositoryRoot: directory.path),
        contains('docs/diagrams/generated/old/orphan.mmd'),
      );
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('full and future graph views reject unexplained isolated nodes', () {
    final expected = loadExpectedArchitectureGraph();
    final actual = extractActualArchitectureGraph(expectedGraph: expected);
    final isolatedNode = ArchitectureNode(
      id: 'test.isolated_node',
      label: 'Isolated test node',
      kind: 'test_owner',
      owner: 'test',
      phaseIntroduced: 'P5',
      phaseRequiredBy: 'P5',
      status: 'future',
      coverageScope: 'architectureOwners',
      sourceDocs: expected.nodes.first.sourceDocs,
      evidence: const ['Constructed negative fixture.'],
      actual: const ActualExpectation.empty(),
    );
    final graph = _graphWith(
      expected,
      nodes: [...expected.nodes, isolatedNode],
    );

    expect(
      () => renderGraphViews(
        expected: graph,
        actual: actual,
        selectedPhase: 'P4',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('test.isolated_node'),
        ),
      ),
    );

    final fullAllowedNode = ArchitectureNode(
      id: 'test.future_isolated_node',
      label: 'Future isolated test node',
      kind: 'test_owner',
      owner: 'test',
      phaseIntroduced: 'P5',
      phaseRequiredBy: 'P5',
      status: 'future',
      coverageScope: 'architectureOwners',
      sourceDocs: expected.nodes.first.sourceDocs,
      evidence: const ['Constructed negative fixture.'],
      actual: const ActualExpectation.empty(),
      isolationAllowances: [
        ArchitectureIsolationAllowance(
          views: const ['full_architecture'],
          sourceDocs: expected.nodes.first.sourceDocs,
          reason: 'Constructed allowance for the full-view branch only.',
        ),
      ],
    );
    final futureGraph = _graphWith(
      expected,
      nodes: [...expected.nodes, fullAllowedNode],
    );

    expect(
      () => renderGraphViews(
        expected: futureGraph,
        actual: actual,
        selectedPhase: 'P4',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('future_target'),
            contains('test.future_isolated_node'),
          ),
        ),
      ),
    );
  });
}

ExpectedArchitectureGraph _graphWith(
  ExpectedArchitectureGraph graph, {
  List<ArchitectureNode>? nodes,
}) {
  return ExpectedArchitectureGraph(
    schemaVersion: graph.schemaVersion,
    phases: graph.phases,
    coverage: graph.coverage,
    nodes: nodes ?? graph.nodes,
    edges: graph.edges,
    placeholders: graph.placeholders,
    forbiddenEdges: graph.forbiddenEdges,
    views: graph.views,
    sourceCoverage: graph.sourceCoverage,
  );
}
