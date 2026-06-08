import 'dart:io';

import 'package:test/test.dart';

import '../../tool/architecture_graph/src/actual_graph.dart';
import '../../tool/architecture_graph/src/architecture_graph.dart';
import '../../tool/architecture_graph/src/graph_views.dart';

void main() {
  group('rendered views', () {
    _registerRenderedViewsTest();
  });
  group('reproducibility', () {
    _registerCheckedInViewsTest();
    _registerOrphanViewTest();
  });
  group('connectivity guard', () {
    _registerIsolatedNodeTest();
  });
}

void _registerRenderedViewsTest() {
  test('renders deterministic expected-only and diff graph views', () {
    final expected = loadExpectedArchitectureGraph();
    final actual = extractActualArchitectureGraph(expectedGraph: expected);
    final first = renderGraphViews(expected: expected, actual: actual);
    final second = renderGraphViews(expected: expected, actual: actual);

    expect(first, second);
    expect(
      first.keys.toSet(),
      expected.views.map((view) => view.output).toSet(),
    );
    _expectCurrentViews(first);
    _expectRetiredViewsAbsent(first);
    _expectReleaseView(first);
    _expectDiffView(first);
    _expectNoSelectedPhaseMetadata(first);
  });
}

void _expectCurrentViews(Map<String, String> views) {
  expect(
    views['docs/diagrams/generated/full_architecture.mmd'],
    contains('api_canvas_runtime'),
  );
  expect(
    views['docs/diagrams/generated/full_architecture.mmd'],
    contains('load_document_pipeline'),
  );
  expect(
    views['docs/diagrams/generated/full_architecture.mmd'],
    contains('edit_kernel'),
  );
  expect(
    views['docs/diagrams/generated/full_architecture.mmd'],
    contains('public API forwards to'),
  );
  expect(
    views['docs/diagrams/generated/full_architecture.mmd'],
    contains('resource_kernel'),
  );
  expect(
    views['docs/diagrams/generated/full_architecture.mmd'],
    contains('eraser_context_request'),
  );
  expect(
    views['docs/diagrams/generated/full_architecture.mmd'],
    contains('flutter_surface'),
  );
  expect(
    views['docs/diagrams/generated/full_architecture.mmd'],
    isNot(contains(r'\n')),
  );
  expect(
    views['docs/diagrams/generated/full_architecture.mmd'],
    isNot(contains('facade_port P4')),
  );
}

void _expectRetiredViewsAbsent(Map<String, String> views) {
  expect(
    views.keys,
    isNot(contains('docs/diagrams/generated/current_phase.mmd')),
  );
  expect(
    views.keys,
    isNot(contains('docs/diagrams/generated/future_target.mmd')),
  );
}

void _expectReleaseView(Map<String, String> views) {
  expect(
    views['docs/diagrams/generated/release_verification.mmd'],
    contains('release_measurement'),
  );
}

void _expectDiffView(Map<String, String> views) {
  expect(
    views['docs/diagrams/generated/actual_vs_expected_diff.mmd'],
    isNot(contains('violation_')),
  );
  expect(
    views['docs/diagrams/generated/actual_vs_expected_diff.mmd'],
    isNot(contains('linkStyle')),
  );
  expect(
    views['docs/diagrams/generated/actual_vs_expected_diff.mmd'],
    isNot(contains('Missing required link')),
  );
}

void _registerCheckedInViewsTest() {
  test('checked-in generated graph views are current', () {
    final expected = loadExpectedArchitectureGraph();
    final actual = extractActualArchitectureGraph(expectedGraph: expected);
    final views = renderGraphViews(expected: expected, actual: actual);

    for (final entry in views.entries) {
      expect(
        File(entry.key).readAsStringSync(),
        entry.value,
        reason: entry.key,
      );
    }
  });
}

void _registerOrphanViewTest() {
  test('reproducibility check reports orphan generated Mermaid files', () {
    final directory = Directory.systemTemp.createTempSync('graph_views_');
    try {
      final expected = loadExpectedArchitectureGraph();
      final actual = extractActualArchitectureGraph(expectedGraph: expected);
      final views = renderGraphViews(expected: expected, actual: actual);
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
}

void _registerIsolatedNodeTest() {
  test('full and future graph views reject unexplained isolated nodes', () {
    final expected = loadExpectedArchitectureGraph();
    final actual = extractActualArchitectureGraph(expectedGraph: expected);
    final graph = _graphWith(
      expected,
      nodes: [...expected.nodes, _isolatedNode(expected)],
    );

    expect(
      () => renderGraphViews(expected: graph, actual: actual),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('test.isolated_node'),
        ),
      ),
    );

    final allowedGraph = _graphWith(
      expected,
      nodes: [...expected.nodes, _fullAllowedNode(expected)],
    );
    expect(
      () => renderGraphViews(expected: allowedGraph, actual: actual),
      returnsNormally,
    );
  });
}

ArchitectureNode _isolatedNode(ExpectedArchitectureGraph expected) {
  return ArchitectureNode(
    id: 'test.isolated_node',
    label: 'Isolated test node',
    kind: 'test_owner',
    owner: 'test',
    status: 'required',
    coverageScope: 'architectureOwners',
    sourceDocs: expected.nodes.first.sourceDocs,
    evidence: const ['Constructed negative fixture.'],
    actual: const ActualExpectation.empty(),
  );
}

ArchitectureNode _fullAllowedNode(ExpectedArchitectureGraph expected) {
  return ArchitectureNode(
    id: 'test.current_isolated_node',
    label: 'Current isolated test node',
    kind: 'test_owner',
    owner: 'test',
    status: 'required',
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
}

ExpectedArchitectureGraph _graphWith(
  ExpectedArchitectureGraph graph, {
  List<ArchitectureNode>? nodes,
}) {
  return ExpectedArchitectureGraph(
    schemaVersion: graph.schemaVersion,
    coverage: graph.coverage,
    nodes: nodes ?? graph.nodes,
    edges: graph.edges,
    placeholders: graph.placeholders,
    forbiddenEdges: graph.forbiddenEdges,
    views: graph.views,
    sourceCoverage: graph.sourceCoverage,
  );
}

void _expectNoSelectedPhaseMetadata(Map<String, String> views) {
  for (final entry in views.entries) {
    expect(entry.value, isNot(contains('Selected phase')), reason: entry.key);
    expect(entry.value, isNot(contains('required by P')), reason: entry.key);
    expect(entry.value, isNot(contains(' by P')), reason: entry.key);
  }
}
