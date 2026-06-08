import 'dart:io';

import 'actual_graph.dart';
import 'architecture_graph.dart';
import 'current_closure.dart';

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
}) {
  final report = checkArchitectureClosure(expected: expected, actual: actual);

  return {
    for (final view in expected.views)
      view.output: _renderView(view, expected, report),
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
  for (final path in _orphanGeneratedViewPaths(
    views: views,
    repositoryRoot: repositoryRoot,
  )) {
    final file = File('$repositoryRoot/$path');
    file.deleteSync();
    changed.add(path);
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
  stale.addAll(
    _orphanGeneratedViewPaths(views: views, repositoryRoot: repositoryRoot),
  );

  return stale;
}

List<String> _orphanGeneratedViewPaths({
  required Map<String, String> views,
  required String repositoryRoot,
}) {
  final generatedDirectory = Directory(
    '$repositoryRoot/docs/diagrams/generated',
  );
  if (!generatedDirectory.existsSync()) {
    return const [];
  }

  final paths = <String>[];
  for (final file
      in generatedDirectory.listSync(recursive: true).whereType<File>()) {
    final path = _relativePath(file.path, repositoryRoot);
    if (path.endsWith('.mmd') && !views.containsKey(path)) {
      paths.add(path);
    }
  }

  return paths..sort();
}

String _renderView(
  ArchitectureView view,
  ExpectedArchitectureGraph expected,
  ArchitectureClosureReport report,
) {
  return switch (view.kind) {
    'expected_full' => _renderFullExpectedView(view, expected),
    'expected_release_verification' => _renderReleaseVerificationView(
      view,
      expected,
    ),
    'actual_vs_expected_diff' => _renderDiffView(
      title: view.title,
      expected: expected,
      report: report,
    ),
    _ => throw UnsupportedError('Unsupported graph view kind: ${view.kind}'),
  };
}

String _renderFullExpectedView(
  ArchitectureView view,
  ExpectedArchitectureGraph expected,
) {
  return _renderExpectedGraphView(
    _ExpectedViewRequest(
      viewId: view.id,
      title: view.title,
      nodes: _includedNodes(expected.nodes, view),
      edges: expected.edges,
      enforceConnectivity: true,
    ),
  );
}

String _renderReleaseVerificationView(
  ArchitectureView view,
  ExpectedArchitectureGraph expected,
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
  final buffer = _header(request.title);
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
    required this.enforceConnectivity,
  });

  final String viewId;
  final String title;
  final List<ArchitectureNode> nodes;
  final List<ArchitectureEdge> edges;
  final bool enforceConnectivity;
}

void _writeExpectedNodes(StringBuffer buffer, List<ArchitectureNode> nodes) {
  for (final node in _sortedNodes(nodes)) {
    buffer.writeln('  ${_mermaidId(node.id)}["${_label(node.label)}"]');
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

List<ArchitectureNode> _sortedNodes(List<ArchitectureNode> nodes) {
  return nodes.toList()..sort((left, right) => left.id.compareTo(right.id));
}

List<ArchitectureEdge> _sortedEdges(List<ArchitectureEdge> edges) {
  return edges.toList()..sort((left, right) => left.id.compareTo(right.id));
}

List<ArchitectureClosureViolation> _sortedViolations(
  List<ArchitectureClosureViolation> violations,
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
  required ArchitectureClosureReport report,
}) {
  final violationIds = report.violations
      .map((violation) => violation.graphId)
      .toSet();
  final buffer = _header(title);
  _writeDiffNodes(buffer, expected.nodes, violationIds);
  final linkStyles = <String>[];
  _writeDiffEdges(
    _DiffEdgeWriteRequest(
      buffer: buffer,
      edges: expected.edges,
      violationIds: violationIds,
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
) {
  for (final node in _sortedNodes(nodes)) {
    final className = violationIds.contains(node.id) ? 'violation' : 'ok';
    buffer.writeln(
      '  ${_mermaidId(node.id)}["${_label(node.label)}"]:::$className',
    );
  }
}

void _writeDiffEdges(_DiffEdgeWriteRequest request) {
  var linkIndex = 0;
  for (final edge in _sortedEdges(request.edges)) {
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
    required this.linkStyles,
  });

  final StringBuffer buffer;
  final List<ArchitectureEdge> edges;
  final Set<String> violationIds;
  final List<String> linkStyles;
}

void _writeViolationNodes(
  StringBuffer buffer,
  List<ArchitectureClosureViolation> violations,
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

StringBuffer _header(String title) {
  final buffer = StringBuffer()
    ..writeln('%% GENERATED FILE. Do not edit by hand.')
    ..writeln('%% Source: docs/architecture/architecture_graph.yaml')
    ..writeln('%% View: $title');

  return buffer..writeln('flowchart LR');
}

String _label(String label) => _escape(label);

String _edgeLabel(ArchitectureEdge edge) {
  return _edgeKindLabel(edge.kind);
}

String _edgeKindLabel(String kind) {
  return _edgeKindLabels[kind] ?? kind.replaceAll('_', ' ');
}

String _violationLabel(String status) {
  return switch (status) {
    'missing_required_node' => 'Missing required box',
    'missing_required_edge' => 'Missing required link',
    'forbidden_edge' => 'Forbidden link exists',
    'current_placeholder' => 'Placeholder remains',
    'untracked_placeholder' => 'Untracked placeholder',
    'unknown_architecture_seam' => 'Unknown architecture box',
    _ => status.replaceAll('_', ' '),
  };
}

List<String> _violationTargets(
  ArchitectureClosureViolation violation,
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

String _relativePath(String path, String repositoryRoot) {
  final rootPrefix = '${Directory(repositoryRoot).absolute.path}/';
  final absolutePath = File(path).absolute.path;

  return absolutePath.startsWith(rootPrefix)
      ? absolutePath.replaceFirst(rootPrefix, '')
      : path;
}
