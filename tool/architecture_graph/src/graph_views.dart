import 'dart:io';

import 'actual_graph.dart';
import 'architecture_graph.dart';
import 'phase_closure.dart';

const _edgeKindLabels = {
  'exports': 'exports',
  'composes': 'owns and creates',
  'facade_port': 'public API forwards to',
  'data_boundary': 'uses public data',
  'diagnostic_route': 'reports errors to',
  'mutation_boundary': 'changes data through',
  'query_boundary': 'reads data through',
  'read_port': 'reads from',
  'resource_boundary': 'resolves resources through',
  'ui_boundary': 'is shown through',
};

Map<String, String> renderGraphViews({
  required ExpectedArchitectureGraph expected,
  required ActualArchitectureGraph actual,
  required String selectedPhase,
}) {
  final report = checkPhaseClosure(
    expected: expected,
    actual: actual,
    selectedPhase: selectedPhase,
  );

  return {
    for (final view in expected.views)
      view.output: _renderView(view, expected, report, selectedPhase),
  };
}

List<String> writeGraphViews({
  required Map<String, String> views,
  String repositoryRoot = '.',
}) {
  final changed = <String>[];
  for (final entry in views.entries) {
    final file = File('$repositoryRoot/${entry.key}');
    file.parent.createSync(recursive: true);
    final oldContent = file.existsSync() ? file.readAsStringSync() : null;
    if (oldContent != entry.value) {
      changed.add(entry.key);
      file.writeAsStringSync(entry.value);
    }
  }

  return changed;
}

List<String> checkGraphViews({
  required Map<String, String> views,
  String repositoryRoot = '.',
}) {
  final stale = <String>[];
  for (final entry in views.entries) {
    final file = File('$repositoryRoot/${entry.key}');
    if (!file.existsSync() || file.readAsStringSync() != entry.value) {
      stale.add(entry.key);
    }
  }
  final generatedDirectory = Directory(
    '$repositoryRoot/docs/diagrams/generated',
  );
  if (generatedDirectory.existsSync()) {
    for (final file
        in generatedDirectory.listSync(recursive: true).whereType<File>()) {
      final path = _relativePath(file.path, repositoryRoot);
      if (path.endsWith('.mmd') && !views.containsKey(path)) {
        stale.add(path);
      }
    }
  }

  return stale;
}

String _renderExpectedView({
  required String title,
  required List<ArchitectureNode> nodes,
  required List<ArchitectureEdge> edges,
  required String selectedPhase,
}) {
  final nodeIds = nodes.map((node) => node.id).toSet();
  final buffer = _header(title, selectedPhase);
  for (final node
      in nodes.toList()..sort((left, right) => left.id.compareTo(right.id))) {
    buffer.writeln(
      '  ${_mermaidId(node.id)}["${_label(node.label, node.phaseRequiredBy)}"]',
    );
  }
  for (final edge in edges.where((edge) {
    return nodeIds.contains(edge.from) && nodeIds.contains(edge.to);
  }).toList()..sort((left, right) => left.id.compareTo(right.id))) {
    buffer.writeln(
      '  ${_mermaidId(edge.from)} -->|${_edgeLabel(edge)}| ${_mermaidId(edge.to)}',
    );
  }

  return buffer.toString();
}

String _renderView(
  ArchitectureView view,
  ExpectedArchitectureGraph expected,
  PhaseClosureReport report,
  String selectedPhase,
) {
  return switch (view.kind) {
    'expected_full' => _renderExpectedView(
      title: view.title,
      nodes: expected.nodes,
      edges: expected.edges,
      selectedPhase: selectedPhase,
    ),
    'expected_current_phase' => _renderExpectedView(
      title: view.title,
      nodes: expected.nodes
          .where(
            (node) =>
                _phaseIndex(node.phaseRequiredBy) <= _phaseIndex(selectedPhase),
          )
          .toList(),
      edges: expected.edges
          .where(
            (edge) =>
                _phaseIndex(edge.phaseRequiredBy) <= _phaseIndex(selectedPhase),
          )
          .toList(),
      selectedPhase: selectedPhase,
    ),
    'expected_future' => _renderExpectedView(
      title: view.title,
      nodes: _futureNodesWithEdgeEndpoints(
        expected.nodes,
        expected.edges
            .where(
              (edge) =>
                  _phaseIndex(edge.phaseRequiredBy) >
                  _phaseIndex(selectedPhase),
            )
            .toList(),
        selectedPhase,
      ),
      edges: expected.edges
          .where(
            (edge) =>
                _phaseIndex(edge.phaseRequiredBy) > _phaseIndex(selectedPhase),
          )
          .toList(),
      selectedPhase: selectedPhase,
    ),
    'actual_vs_expected_diff' => _renderDiffView(
      title: view.title,
      expected: expected,
      report: report,
      selectedPhase: selectedPhase,
    ),
    _ => throw UnsupportedError('Unsupported graph view kind: ${view.kind}'),
  };
}

List<ArchitectureNode> _futureNodesWithEdgeEndpoints(
  List<ArchitectureNode> nodes,
  List<ArchitectureEdge> futureEdges,
  String selectedPhase,
) {
  final endpointIds = {
    for (final edge in futureEdges) edge.from,
    for (final edge in futureEdges) edge.to,
  };

  return nodes.where((node) {
    return _phaseIndex(node.phaseRequiredBy) > _phaseIndex(selectedPhase) ||
        endpointIds.contains(node.id);
  }).toList();
}

String _renderDiffView({
  required String title,
  required ExpectedArchitectureGraph expected,
  required PhaseClosureReport report,
  required String selectedPhase,
}) {
  final violationIds = report.violations
      .map((violation) => violation.graphId)
      .toSet();
  final buffer = _header(title, selectedPhase);
  final activeNodes = expected.nodes.where((node) {
    return _phaseIndex(node.phaseRequiredBy) <= _phaseIndex(selectedPhase);
  }).toList()..sort((left, right) => left.id.compareTo(right.id));
  for (final node in activeNodes) {
    final className = violationIds.contains(node.id) ? 'violation' : 'ok';
    buffer.writeln(
      '  ${_mermaidId(node.id)}["${_label(node.label, node.phaseRequiredBy)}"]:::$className',
    );
  }
  final linkStyles = <String>[];
  var linkIndex = 0;
  for (final edge in expected.edges.where((edge) {
    return _phaseIndex(edge.phaseRequiredBy) <= _phaseIndex(selectedPhase);
  }).toList()..sort((left, right) => left.id.compareTo(right.id))) {
    buffer.writeln(
      '  ${_mermaidId(edge.from)} -->|${_edgeLabel(edge)}| ${_mermaidId(edge.to)}',
    );
    if (violationIds.contains(edge.id)) {
      linkStyles.add(
        '  linkStyle $linkIndex stroke:#dc2626,stroke-width:3px,color:#7f1d1d',
      );
    }
    linkIndex++;
  }
  for (final violation
      in report.violations.toList()
        ..sort((left, right) => left.graphId.compareTo(right.graphId))) {
    final violationNode = _mermaidId('violation.${violation.graphId}');
    buffer.writeln(
      '  $violationNode["${_violationLabel(violation.status)}"]:::violation',
    );
    for (final target in _violationTargets(violation, expected)) {
      buffer.writeln('  $violationNode -.-> ${_mermaidId(target)}');
    }
  }
  buffer
    ..writeln('  classDef ok fill:#f8fafc,stroke:#64748b,color:#0f172a')
    ..writeln('  classDef violation fill:#fee2e2,stroke:#dc2626,color:#7f1d1d');
  for (final linkStyle in linkStyles) {
    buffer.writeln(linkStyle);
  }

  return buffer.toString();
}

StringBuffer _header(String title, String selectedPhase) {
  return StringBuffer()
    ..writeln('%% GENERATED FILE. Do not edit by hand.')
    ..writeln('%% Source: docs/architecture/architecture_graph.yaml')
    ..writeln('%% View: $title')
    ..writeln('%% Selected phase: $selectedPhase')
    ..writeln('flowchart LR');
}

String _label(String label, String phaseRequiredBy) {
  return '${_escape(label)}<br/>required by $phaseRequiredBy';
}

String _edgeLabel(ArchitectureEdge edge) {
  return '${_edgeKindLabel(edge.kind)} by ${edge.phaseRequiredBy}';
}

String _edgeKindLabel(String kind) {
  return _edgeKindLabels[kind] ?? kind.replaceAll('_', ' ');
}

String _violationLabel(String status) {
  return switch (status) {
    'missing_required_node' => 'Missing required box',
    'missing_required_edge' => 'Missing required link',
    'forbidden_edge' => 'Forbidden link exists',
    'closed_phase_placeholder' => 'Old placeholder remains',
    'expired_placeholder_deferral' => 'Placeholder is overdue',
    'untracked_placeholder' => 'Untracked placeholder',
    'unknown_architecture_seam' => 'Unknown architecture box',
    'unknown_phase' => 'Unknown phase',
    _ => status.replaceAll('_', ' '),
  };
}

List<String> _violationTargets(
  PhaseClosureViolation violation,
  ExpectedArchitectureGraph expected,
) {
  for (final edge in expected.edges) {
    if (edge.id == violation.graphId) {
      return [edge.from, edge.to];
    }
  }
  for (final placeholder in expected.placeholders) {
    if (placeholder.id == violation.graphId) {
      return [placeholder.node];
    }
  }
  if (expected.nodes.any((node) => node.id == violation.graphId)) {
    return [violation.graphId];
  }

  return const [];
}

String _escape(String value) {
  return value.replaceAll('"', '\\"');
}

String _mermaidId(String id) {
  return id.replaceAll(RegExp('[^A-Za-z0-9_]'), '_');
}

int _phaseIndex(String phase) {
  return int.tryParse(phase.substring(1)) ?? -1;
}

String _relativePath(String path, String repositoryRoot) {
  final rootPrefix = '${Directory(repositoryRoot).absolute.path}/';
  final absolutePath = File(path).absolute.path;

  return absolutePath.startsWith(rootPrefix)
      ? absolutePath.substring(rootPrefix.length)
      : path;
}
