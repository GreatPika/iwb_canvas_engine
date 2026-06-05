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
  'frame_facts_provider': 'provides FrameFactsPort',
  'resource_boundary': 'resolves resources through',
  'resource_invalidation': 'invalidates resource session through',
  'ui_boundary': 'drives public runtime ports',
  'tool_commit': 'commits through',
  'preview_intent_boundary': 'produces preview intents',
  'tool_lifecycle_delegation': 'delegates lifecycle decisions to',
  'lifecycle_request_delegation':
      'delegates lifecycle and request decisions to',
  'hit_test_boundary': 'queries hits through',
  'interaction_target_geometry_boundary':
      'uses interaction target geometry through',
  'action_stream_boundary': 'emits user actions',
  'verification_scope': 'is verified by',
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

String _renderView(
  ArchitectureView view,
  ExpectedArchitectureGraph expected,
  PhaseClosureReport report,
  String selectedPhase,
) {
  return switch (view.kind) {
    'expected_full' => _renderFullExpectedView(view, expected, selectedPhase),
    'expected_current_phase' => _renderCurrentPhaseView(
      view,
      expected,
      selectedPhase,
    ),
    'expected_future' => _renderFutureExpectedView(
      view,
      expected,
      selectedPhase,
    ),
    'expected_release_verification' => _renderReleaseVerificationView(
      view,
      expected,
      selectedPhase,
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

String _renderFullExpectedView(
  ArchitectureView view,
  ExpectedArchitectureGraph expected,
  String selectedPhase,
) {
  return _renderExpectedGraphView(
    _ExpectedViewRequest(
      viewId: view.id,
      title: view.title,
      nodes: _includedNodes(expected.nodes, view),
      edges: expected.edges,
      selectedPhase: selectedPhase,
      enforceConnectivity: true,
    ),
  );
}

String _renderCurrentPhaseView(
  ArchitectureView view,
  ExpectedArchitectureGraph expected,
  String selectedPhase,
) {
  return _renderExpectedGraphView(
    _ExpectedViewRequest(
      viewId: view.id,
      title: view.title,
      nodes: _includedNodes(
        expected.nodes,
        view,
      ).where(_isRequiredBy(selectedPhase)).toList(),
      edges: _edgesBeforeOrAt(expected.edges, selectedPhase),
      selectedPhase: selectedPhase,
      enforceConnectivity: false,
    ),
  );
}

String _renderFutureExpectedView(
  ArchitectureView view,
  ExpectedArchitectureGraph expected,
  String selectedPhase,
) {
  final futureEdges = _futureEdges(expected.edges, selectedPhase);

  return _renderExpectedGraphView(
    _ExpectedViewRequest(
      viewId: view.id,
      title: view.title,
      nodes: _futureNodesWithEdgeEndpoints(
        _includedNodes(expected.nodes, view),
        futureEdges,
        selectedPhase,
      ),
      edges: futureEdges,
      selectedPhase: selectedPhase,
      enforceConnectivity: true,
    ),
  );
}

String _renderReleaseVerificationView(
  ArchitectureView view,
  ExpectedArchitectureGraph expected,
  String selectedPhase,
) {
  return _renderExpectedGraphView(
    _ExpectedViewRequest(
      viewId: view.id,
      title: view.title,
      nodes: _includedNodes(
        expected.nodes,
        view,
      ).where((node) => node.status == 'measurement').toList(),
      edges: expected.edges
          .where((edge) => edge.status == 'measurement')
          .toList(),
      selectedPhase: selectedPhase,
      enforceConnectivity: true,
    ),
  );
}

String _renderExpectedGraphView(_ExpectedViewRequest request) {
  if (request.enforceConnectivity) {
    _checkRenderedConnectivity(
      viewId: request.viewId,
      nodes: request.nodes,
      edges: request.edges,
    );
  }
  final buffer = _header(
    request.title,
    request.selectedPhase,
    note: _expectedViewNote(request.viewId),
  );
  _writeExpectedNodes(buffer, request.nodes);
  _writeExpectedEdges(buffer, request.nodes, request.edges);

  return buffer.toString();
}

final class _ExpectedViewRequest {
  const _ExpectedViewRequest({
    required this.viewId,
    required this.title,
    required this.nodes,
    required this.edges,
    required this.selectedPhase,
    required this.enforceConnectivity,
  });

  final String viewId;
  final String title;
  final List<ArchitectureNode> nodes;
  final List<ArchitectureEdge> edges;
  final String selectedPhase;
  final bool enforceConnectivity;
}

void _writeExpectedNodes(StringBuffer buffer, List<ArchitectureNode> nodes) {
  for (final node in _sortedNodes(nodes)) {
    buffer.writeln(
      '  ${_mermaidId(node.id)}["${_label(node.label, node.phaseRequiredBy)}"]',
    );
  }
}

void _writeExpectedEdges(
  StringBuffer buffer,
  List<ArchitectureNode> nodes,
  List<ArchitectureEdge> edges,
) {
  final nodeIds = nodes.map((node) => node.id).toSet();
  for (final edge in _sortedEdges(edges).where((edge) {
    return nodeIds.contains(edge.from) && nodeIds.contains(edge.to);
  })) {
    buffer.writeln(
      '  ${_mermaidId(edge.from)} -->|${_edgeLabel(edge)}| ${_mermaidId(edge.to)}',
    );
  }
}

List<ArchitectureNode> _includedNodes(
  List<ArchitectureNode> nodes,
  ArchitectureView view,
) {
  final excludedKinds = view.excludedNodeKinds.toSet();

  return nodes
      .where((node) => !excludedKinds.contains(node.kind))
      .toList(growable: false);
}

bool Function(ArchitectureNode) _isRequiredBy(String selectedPhase) {
  return (node) =>
      _phaseIndex(node.phaseRequiredBy) <= _phaseIndex(selectedPhase);
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

List<ArchitectureNode> _activeNodes(
  List<ArchitectureNode> nodes,
  String selectedPhase,
) {
  return nodes.where(_isRequiredBy(selectedPhase)).toList();
}

List<ArchitectureEdge> _edgesBeforeOrAt(
  List<ArchitectureEdge> edges,
  String selectedPhase,
) {
  return edges.where((edge) {
    return _phaseIndex(edge.phaseRequiredBy) <= _phaseIndex(selectedPhase);
  }).toList();
}

List<ArchitectureEdge> _futureEdges(
  List<ArchitectureEdge> edges,
  String selectedPhase,
) {
  return edges.where((edge) {
    return _phaseIndex(edge.phaseRequiredBy) > _phaseIndex(selectedPhase);
  }).toList();
}

List<ArchitectureNode> _sortedNodes(List<ArchitectureNode> nodes) {
  return nodes.toList()..sort((left, right) => left.id.compareTo(right.id));
}

List<ArchitectureEdge> _sortedEdges(List<ArchitectureEdge> edges) {
  return edges.toList()..sort((left, right) => left.id.compareTo(right.id));
}

List<PhaseClosureViolation> _sortedViolations(
  List<PhaseClosureViolation> violations,
) {
  return violations.toList()
    ..sort((left, right) => left.graphId.compareTo(right.graphId));
}

void _checkRenderedConnectivity({
  required String viewId,
  required List<ArchitectureNode> nodes,
  required List<ArchitectureEdge> edges,
}) {
  final nodeIds = nodes.map((node) => node.id).toSet();
  final connectedNodeIds = <String>{};
  for (final edge in edges) {
    if (nodeIds.contains(edge.from) && nodeIds.contains(edge.to)) {
      connectedNodeIds
        ..add(edge.from)
        ..add(edge.to);
    }
  }

  final isolatedNodes = nodes.where((node) {
    return !connectedNodeIds.contains(node.id) &&
        !_allowsIsolation(node, viewId);
  }).toList();
  if (isolatedNodes.isEmpty) {
    return;
  }

  final ids = isolatedNodes.map((node) => node.id).join(', ');
  throw StateError(
    'Generated graph view $viewId contains unexplained isolated nodes: $ids',
  );
}

bool _allowsIsolation(ArchitectureNode node, String viewId) {
  return node.isolationAllowances.any(
    (allowance) => allowance.views.contains(viewId),
  );
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
  _writeDiffNodes(buffer, expected.nodes, violationIds, selectedPhase);
  final linkStyles = <String>[];
  _writeDiffEdges(
    _DiffEdgeWriteRequest(
      buffer: buffer,
      edges: expected.edges,
      violationIds: violationIds,
      selectedPhase: selectedPhase,
      linkStyles: linkStyles,
    ),
  );
  _writeViolationNodes(buffer, report.violations, expected);
  _writeDiffClassDefs(buffer, linkStyles);

  return buffer.toString();
}

void _writeDiffNodes(
  StringBuffer buffer,
  List<ArchitectureNode> nodes,
  Set<String> violationIds,
  String selectedPhase,
) {
  for (final node in _sortedNodes(_activeNodes(nodes, selectedPhase))) {
    final className = violationIds.contains(node.id) ? 'violation' : 'ok';
    buffer.writeln(
      '  ${_mermaidId(node.id)}["${_label(node.label, node.phaseRequiredBy)}"]:::$className',
    );
  }
}

void _writeDiffEdges(_DiffEdgeWriteRequest request) {
  var linkIndex = 0;
  for (final edge in _sortedEdges(
    _edgesBeforeOrAt(request.edges, request.selectedPhase),
  )) {
    request.buffer.writeln(
      '  ${_mermaidId(edge.from)} -->|${_edgeLabel(edge)}| ${_mermaidId(edge.to)}',
    );
    if (request.violationIds.contains(edge.id)) {
      request.linkStyles.add(
        '  linkStyle $linkIndex stroke:#dc2626,stroke-width:3px,color:#7f1d1d',
      );
    }
    linkIndex++;
  }
}

final class _DiffEdgeWriteRequest {
  const _DiffEdgeWriteRequest({
    required this.buffer,
    required this.edges,
    required this.violationIds,
    required this.selectedPhase,
    required this.linkStyles,
  });

  final StringBuffer buffer;
  final List<ArchitectureEdge> edges;
  final Set<String> violationIds;
  final String selectedPhase;
  final List<String> linkStyles;
}

void _writeViolationNodes(
  StringBuffer buffer,
  List<PhaseClosureViolation> violations,
  ExpectedArchitectureGraph expected,
) {
  for (final violation in _sortedViolations(violations)) {
    final violationNode = _mermaidId('violation.${violation.graphId}');
    buffer.writeln(
      '  $violationNode["${_violationLabel(violation.status)}"]:::violation',
    );
    for (final target in _violationTargets(violation, expected)) {
      buffer.writeln('  $violationNode -.-> ${_mermaidId(target)}');
    }
  }
}

void _writeDiffClassDefs(StringBuffer buffer, List<String> linkStyles) {
  buffer
    ..writeln('  classDef ok fill:#f8fafc,stroke:#64748b,color:#0f172a')
    ..writeln('  classDef violation fill:#fee2e2,stroke:#dc2626,color:#7f1d1d');
  for (final linkStyle in linkStyles) {
    buffer.writeln(linkStyle);
  }
}

String? _expectedViewNote(String viewId) {
  return switch (viewId) {
    'full_architecture' =>
      'Includes current architecture plus all planned future and measurement-scope graph nodes. Use current_phase.mmd for implemented selected-phase state.',
    'future_target' =>
      'Shows future planned edges after the selected phase plus their endpoint nodes for context.',
    _ => null,
  };
}

StringBuffer _header(String title, String selectedPhase, {String? note}) {
  final buffer = StringBuffer()
    ..writeln('%% GENERATED FILE. Do not edit by hand.')
    ..writeln('%% Source: docs/architecture/architecture_graph.yaml')
    ..writeln('%% View: $title')
    ..writeln('%% Selected phase: $selectedPhase');
  if (note != null) {
    buffer.writeln('%% Note: $note');
  }

  return buffer..writeln('flowchart LR');
}

String _label(String label, String phaseRequiredBy) {
  return '${_escape(label)}<br/>required by $phaseRequiredBy';
}

String _edgeLabel(ArchitectureEdge edge) {
  final label = _edgeKindLabel(edge.kind);
  if (edge.status == 'future') {
    return 'planned $label by ${edge.phaseRequiredBy}';
  }

  return '$label by ${edge.phaseRequiredBy}';
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
  return int.tryParse(phase.replaceFirst('P', '')) ?? -1;
}

String _relativePath(String path, String repositoryRoot) {
  final rootPrefix = '${Directory(repositoryRoot).absolute.path}/';
  final absolutePath = File(path).absolute.path;

  return absolutePath.startsWith(rootPrefix)
      ? absolutePath.replaceFirst(rootPrefix, '')
      : path;
}
