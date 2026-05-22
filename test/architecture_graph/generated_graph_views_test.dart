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
      contains('release_measurement'),
    );
    expect(
      first['docs/diagrams/generated/actual_vs_expected_diff.mmd'],
      contains('runtime_canvas_runtime_camera_closed_phase_placeholder'),
    );
    expect(
      first['docs/diagrams/generated/actual_vs_expected_diff.mmd'],
      contains('linkStyle'),
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
      contains('Missing required link'),
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
}
