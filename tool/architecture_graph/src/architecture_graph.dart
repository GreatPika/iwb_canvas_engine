import 'dart:io';

import 'package:yaml/yaml.dart';

const architectureGraphPath = 'docs/architecture/architecture_graph.yaml';

final class ExpectedArchitectureGraph {
  const ExpectedArchitectureGraph({
    required this.schemaVersion,
    required this.phases,
    required this.coverage,
    required this.nodes,
    required this.edges,
    required this.placeholders,
    required this.forbiddenEdges,
    required this.views,
    required this.sourceCoverage,
  });

  final int schemaVersion;
  final List<ArchitecturePhase> phases;
  final ArchitectureCoverage coverage;
  final List<ArchitectureNode> nodes;
  final List<ArchitectureEdge> edges;
  final List<ArchitecturePlaceholder> placeholders;
  final List<ArchitectureForbiddenEdge> forbiddenEdges;
  final List<ArchitectureView> views;
  final List<ArchitectureSourceCoverage> sourceCoverage;

  Set<String> get phaseIds => phases.map((phase) => phase.id).toSet();

  ArchitecturePhase phaseById(String id) {
    return phases.firstWhere((phase) => phase.id == id);
  }
}

final class ArchitecturePhase {
  const ArchitecturePhase({
    required this.id,
    required this.title,
    required this.status,
    required this.sourceDocs,
  });

  final String id;
  final String title;
  final String status;
  final List<SourceDoc> sourceDocs;
}

final class ArchitectureCoverage {
  const ArchitectureCoverage({
    required this.publicSurfaces,
    required this.architectureOwners,
    required this.sensitiveThrows,
    required this.placeholders,
    required this.ignored,
  });

  final List<String> publicSurfaces;
  final List<String> architectureOwners;
  final List<SensitiveThrowCoverage> sensitiveThrows;
  final List<PlaceholderCoverage> placeholders;
  final List<String> ignored;
}

final class SensitiveThrowCoverage {
  const SensitiveThrowCoverage({
    required this.owner,
    required this.under,
    required this.exception,
  });

  final String owner;
  final String under;
  final String exception;
}

final class PlaceholderCoverage {
  const PlaceholderCoverage({required this.under});

  final String under;
}

final class SourceDoc {
  const SourceDoc({required this.path, this.line, this.stableAnchor = false});

  final String path;
  final int? line;
  final bool stableAnchor;
}

final class ArchitectureNode {
  const ArchitectureNode({
    required this.id,
    required this.label,
    required this.kind,
    required this.owner,
    required this.phaseIntroduced,
    required this.phaseRequiredBy,
    required this.status,
    required this.coverageScope,
    required this.sourceDocs,
    required this.evidence,
    required this.actual,
    this.isolationAllowances = const [],
  });

  final String id;
  final String label;
  final String kind;
  final String owner;
  final String phaseIntroduced;
  final String phaseRequiredBy;
  final String status;
  final String coverageScope;
  final List<SourceDoc> sourceDocs;
  final List<String> evidence;
  final ActualExpectation actual;
  final List<ArchitectureIsolationAllowance> isolationAllowances;
}

final class ArchitectureEdge {
  const ArchitectureEdge({
    required this.id,
    required this.from,
    required this.to,
    required this.kind,
    required this.phaseRequiredBy,
    required this.status,
    required this.sourceDocs,
    required this.evidence,
    required this.actual,
  });

  final String id;
  final String from;
  final String to;
  final String kind;
  final String phaseRequiredBy;
  final String status;
  final List<SourceDoc> sourceDocs;
  final List<String> evidence;
  final ActualExpectation actual;
}

final class ArchitecturePlaceholder {
  const ArchitecturePlaceholder({
    required this.id,
    required this.node,
    required this.member,
    required this.path,
    required this.phaseRequiredBy,
    required this.status,
    required this.sourceDocs,
    required this.evidence,
  });

  final String id;
  final String node;
  final String member;
  final String path;
  final String phaseRequiredBy;
  final String status;
  final List<SourceDoc> sourceDocs;
  final List<String> evidence;
}

final class ArchitectureForbiddenEdge {
  const ArchitectureForbiddenEdge({
    required this.id,
    required this.from,
    required this.to,
    required this.kind,
    required this.phaseRequiredBy,
    required this.status,
    required this.sourceDocs,
    required this.evidence,
  });

  final String id;
  final String from;
  final String to;
  final String kind;
  final String phaseRequiredBy;
  final String status;
  final List<SourceDoc> sourceDocs;
  final List<String> evidence;
}

final class ArchitectureView {
  const ArchitectureView({
    required this.id,
    required this.title,
    required this.kind,
    required this.output,
    required this.sourceDocs,
    this.excludedNodeKinds = const [],
  });

  final String id;
  final String title;
  final String kind;
  final String output;
  final List<SourceDoc> sourceDocs;
  final List<String> excludedNodeKinds;
}

final class ArchitectureIsolationAllowance {
  const ArchitectureIsolationAllowance({
    required this.views,
    required this.sourceDocs,
    required this.reason,
  });

  final List<String> views;
  final List<SourceDoc> sourceDocs;
  final String reason;
}

final class ArchitectureSourceCoverage {
  const ArchitectureSourceCoverage({
    required this.sectionId,
    required this.disposition,
    required this.graphIds,
    required this.reason,
    required this.successorSource,
  });

  final String sectionId;
  final String disposition;
  final List<String> graphIds;
  final String? reason;
  final String? successorSource;
}

final class ActualExpectation {
  const ActualExpectation({
    this.declarations = const [],
    this.exports = const [],
    this.imports = const [],
    this.implementedInterfaces = const [],
    this.compositionFields = const [],
    this.delegationMembers = const [],
    this.delegationTargets = const [],
    this.sensitiveThrowOwner,
    this.sensitiveThrowRoutes = const [],
  });

  const ActualExpectation.empty()
    : declarations = const [],
      exports = const [],
      imports = const [],
      implementedInterfaces = const [],
      compositionFields = const [],
      delegationMembers = const [],
      delegationTargets = const [],
      sensitiveThrowOwner = null,
      sensitiveThrowRoutes = const [];

  final List<String> declarations;
  final List<String> exports;
  final List<String> imports;
  final List<String> implementedInterfaces;
  final List<String> compositionFields;
  final List<String> delegationMembers;
  final List<String> delegationTargets;
  final String? sensitiveThrowOwner;
  final List<String> sensitiveThrowRoutes;
}

final class ArchitectureGraphDiagnostic {
  const ArchitectureGraphDiagnostic({
    required this.id,
    required this.path,
    required this.message,
  });

  final String id;
  final String path;
  final String message;

  @override
  String toString() => '$id: $path: $message';
}

ExpectedArchitectureGraph loadExpectedArchitectureGraph({
  String path = architectureGraphPath,
}) {
  final file = File(path);
  final yaml = loadYaml(file.readAsStringSync());
  final root = _normalizeMap(yaml, path);

  return ExpectedArchitectureGraph(
    schemaVersion: _requiredInt(root, 'schemaVersion', path),
    phases: _requiredMaps(
      root,
      'phases',
      path,
    ).map((entry) => _phase(entry, '$path/phases')).toList(),
    coverage: _coverage(_requiredMap(root, 'coverage', path), '$path/coverage'),
    nodes: _requiredMaps(
      root,
      'nodes',
      path,
    ).map((entry) => _node(entry, '$path/nodes')).toList(),
    edges: _requiredMaps(
      root,
      'edges',
      path,
    ).map((entry) => _edge(entry, '$path/edges')).toList(),
    placeholders: _requiredMaps(
      root,
      'placeholders',
      path,
    ).map((entry) => _placeholder(entry, '$path/placeholders')).toList(),
    forbiddenEdges: _requiredMaps(
      root,
      'forbiddenEdges',
      path,
    ).map((entry) => _forbiddenEdge(entry, '$path/forbiddenEdges')).toList(),
    views: _requiredMaps(
      root,
      'views',
      path,
    ).map((entry) => _view(entry, '$path/views')).toList(),
    sourceCoverage: _requiredMaps(
      root,
      'sourceCoverage',
      path,
    ).map((entry) => _sourceCoverage(entry, '$path/sourceCoverage')).toList(),
  );
}

List<ArchitectureGraphDiagnostic> validateExpectedArchitectureGraph(
  ExpectedArchitectureGraph graph, {
  String repositoryRoot = '.',
}) {
  return ArchitectureGraphValidator(
    graph: graph,
    repositoryRoot: repositoryRoot,
  ).validate();
}

final class ArchitectureGraphValidator {
  ArchitectureGraphValidator({
    required this.graph,
    required this.repositoryRoot,
  });

  final ExpectedArchitectureGraph graph;
  final String repositoryRoot;

  final List<ArchitectureGraphDiagnostic> _diagnostics = [];
  final Set<String> _ids = {};

  List<ArchitectureGraphDiagnostic> validate() {
    _schemaVersion();
    _phases();
    _coverage();
    _nodes();
    _edges();
    _placeholders();
    _forbiddenEdges();
    _views();
    _sourceCoverage();

    return _diagnostics;
  }

  void _schemaVersion() {
    if (graph.schemaVersion != 1) {
      _add('schema.version', architectureGraphPath, 'schemaVersion must be 1');
    }
  }

  void _phases() {
    final expectedIds = [for (var index = 0; index <= 14; index++) 'P$index'];
    final actualIds = graph.phases.map((phase) => phase.id).toList();
    if (!_sameOrderedValues(actualIds, expectedIds)) {
      _add('phase.inventory', architectureGraphPath, 'phases must be P0-P14');
    }
    for (final phase in graph.phases) {
      _allowed(phase.status, const {
        'closed',
        'future',
        'measurement',
      }, phase.id);
      _sourceDocs(phase.sourceDocs, phase.id);
    }
  }

  void _coverage() {
    _requiredNonEmpty(graph.coverage.publicSurfaces, 'coverage.publicSurfaces');
    for (final path in graph.coverage.publicSurfaces) {
      _requiredText(path, 'coverage.publicSurfaces');
    }
    _requiredNonEmpty(
      graph.coverage.architectureOwners,
      'coverage.architectureOwners',
    );
    for (final path in graph.coverage.architectureOwners) {
      _requiredText(path, 'coverage.architectureOwners');
    }
    _requiredNonEmpty(
      graph.coverage.sensitiveThrows,
      'coverage.sensitiveThrows',
    );
    for (final entry in graph.coverage.sensitiveThrows) {
      _requiredText(entry.owner, 'coverage.sensitiveThrows.owner');
      _requiredText(entry.under, 'coverage.sensitiveThrows.under');
      _requiredText(entry.exception, 'coverage.sensitiveThrows.exception');
    }
    _requiredNonEmpty(graph.coverage.placeholders, 'coverage.placeholders');
    for (final entry in graph.coverage.placeholders) {
      _requiredText(entry.under, 'coverage.placeholders.under');
    }
    _requiredNonEmpty(graph.coverage.ignored, 'coverage.ignored');
    for (final path in graph.coverage.ignored) {
      _requiredText(path, 'coverage.ignored');
    }
  }

  void _nodes() {
    final coverageScopes = {'publicSurfaces', 'architectureOwners'};
    for (final node in graph.nodes) {
      _unique(node.id);
      _phaseRef(node.phaseIntroduced, node.id);
      _phaseRef(node.phaseRequiredBy, node.id);
      _allowed(node.status, const {
        'required',
        'future',
        'measurement',
      }, node.id);
      _allowed(node.coverageScope, coverageScopes, node.id);
      _requiredText(node.label, '${node.id}.label');
      _requiredText(node.kind, '${node.id}.kind');
      _requiredText(node.owner, '${node.id}.owner');
      _sourceDocs(node.sourceDocs, node.id);
      _requiredNonEmpty(node.evidence, '${node.id}.evidence');
      for (final allowance in node.isolationAllowances) {
        _requiredNonEmpty(
          allowance.views,
          '${node.id}.isolationAllowances.views',
        );
        for (final view in allowance.views) {
          _requiredText(view, '${node.id}.isolationAllowances.views');
        }
        _sourceDocs(allowance.sourceDocs, node.id);
        _requiredText(
          allowance.reason,
          '${node.id}.isolationAllowances.reason',
        );
      }
    }
  }

  void _edges() {
    final nodeIds = graph.nodes.map((node) => node.id).toSet();
    for (final edge in graph.edges) {
      _unique(edge.id);
      _phaseRef(edge.phaseRequiredBy, edge.id);
      _nodeRef(edge.from, nodeIds, edge.id);
      _nodeRef(edge.to, nodeIds, edge.id);
      _allowed(edge.status, const {'required', 'future'}, edge.id);
      _requiredText(edge.kind, '${edge.id}.kind');
      _sourceDocs(edge.sourceDocs, edge.id);
      _requiredNonEmpty(edge.evidence, '${edge.id}.evidence');
    }
  }

  void _placeholders() {
    final nodeIds = graph.nodes.map((node) => node.id).toSet();
    for (final placeholder in graph.placeholders) {
      _unique(placeholder.id);
      _nodeRef(placeholder.node, nodeIds, placeholder.id);
      _phaseRef(placeholder.phaseRequiredBy, placeholder.id);
      _allowed(placeholder.status, const {
        'forbidden_after_phase',
        'deferred_until_phase',
      }, placeholder.id);
      _requiredText(placeholder.member, '${placeholder.id}.member');
      _requiredText(placeholder.path, '${placeholder.id}.path');
      _sourceDocs(placeholder.sourceDocs, placeholder.id);
      _requiredNonEmpty(placeholder.evidence, '${placeholder.id}.evidence');
    }
  }

  void _forbiddenEdges() {
    final nodeIds = graph.nodes.map((node) => node.id).toSet();
    for (final edge in graph.forbiddenEdges) {
      _unique(edge.id);
      _phaseRef(edge.phaseRequiredBy, edge.id);
      _nodeRef(edge.from, nodeIds, edge.id);
      _nodeRef(edge.to, nodeIds, edge.id);
      _allowed(edge.status, const {'forbidden'}, edge.id);
      _sourceDocs(edge.sourceDocs, edge.id);
      _requiredNonEmpty(edge.evidence, '${edge.id}.evidence');
    }
  }

  void _views() {
    for (final view in graph.views) {
      _unique(view.id);
      _allowed(view.kind, const {
        'expected_full',
        'expected_current_phase',
        'expected_future',
        'expected_release_verification',
        'actual_vs_expected_diff',
      }, view.id);
      _requiredText(view.title, '${view.id}.title');
      _requiredText(view.output, '${view.id}.output');
      _sourceDocs(view.sourceDocs, view.id);
      for (final kind in view.excludedNodeKinds) {
        _requiredText(kind, '${view.id}.excludedNodeKinds');
      }
    }
  }

  void _sourceCoverage() {
    final registrySections = _selectedRegistrySections();
    final registryIds = registrySections.map((section) => section.id).toSet();
    final coveredSections = <String>{};
    final graphIds = _allGraphIds();
    final graphBackedIds = <String>{};

    for (final coverage in graph.sourceCoverage) {
      if (!coveredSections.add(coverage.sectionId)) {
        _add(
          'source_coverage.duplicate',
          coverage.sectionId,
          'duplicate source coverage entry',
        );
      }
      if (!registryIds.contains(coverage.sectionId)) {
        _add(
          'source_coverage.section',
          coverage.sectionId,
          'unknown registry section id',
        );
      }
      _allowed(coverage.disposition, const {
        'graph_obligation',
        'non_graph_semantics',
        'superseded',
        'out_of_graph_scope',
      }, coverage.sectionId);
      switch (coverage.disposition) {
        case 'graph_obligation':
          _requiredNonEmpty(
            coverage.graphIds,
            '${coverage.sectionId}.graphIds',
          );
          for (final graphId in coverage.graphIds) {
            if (!graphIds.contains(graphId)) {
              _add(
                'source_coverage.graph_id',
                coverage.sectionId,
                'unknown graph id: $graphId',
              );
            } else {
              graphBackedIds.add(graphId);
            }
          }
        case 'non_graph_semantics' || 'out_of_graph_scope':
          _requiredText(coverage.reason ?? '', '${coverage.sectionId}.reason');
        case 'superseded':
          _requiredText(
            coverage.successorSource ?? '',
            '${coverage.sectionId}.successorSource',
          );
      }
    }

    for (final section in registrySections) {
      if (!coveredSections.contains(section.id)) {
        _add(
          'source_coverage.missing_section',
          section.id,
          'missing source coverage for ${section.file}',
        );
      }
    }
    for (final graphId in graphIds) {
      if (!graphBackedIds.contains(graphId)) {
        _add(
          'source_coverage.missing_graph_entry',
          graphId,
          'graph entry is not mapped to a registry section',
        );
      }
    }
  }

  Set<String> _allGraphIds() {
    return {
      for (final node in graph.nodes) node.id,
      for (final edge in graph.edges) edge.id,
      for (final placeholder in graph.placeholders) placeholder.id,
      for (final edge in graph.forbiddenEdges) edge.id,
      for (final view in graph.views) view.id,
    };
  }

  List<_RegistrySection> _selectedRegistrySections() {
    final file = File('$repositoryRoot/docs/_registry/sections.yaml');
    final yaml = loadYaml(file.readAsStringSync());
    final entries = _normalizeYaml(yaml);
    if (entries is! List<Object?>) {
      throw const FormatException('Expected registry section list.');
    }

    return entries
        .map((entry) => _registrySection(_normalizeMap(entry, 'sections')))
        .where((section) {
          return section.file.startsWith('docs/architecture/') ||
              section.file.startsWith('docs/contracts/') ||
              section.file.startsWith('docs/verification/') ||
              section.phases.any(_isKnownPhase);
        })
        .toList();
  }

  void _unique(String id) {
    if (!_ids.add(id)) {
      _add('graph.id.duplicate', architectureGraphPath, 'duplicate id: $id');
    }
  }

  void _phaseRef(String id, String owner) {
    if (!graph.phaseIds.contains(id)) {
      _add('phase.reference', owner, 'unknown phase: $id');
    }
  }

  void _nodeRef(String id, Set<String> nodeIds, String owner) {
    if (!nodeIds.contains(id)) {
      _add('node.reference', owner, 'unknown node: $id');
    }
  }

  void _allowed(String value, Set<String> values, String owner) {
    if (!values.contains(value)) {
      _add('enum.value', owner, 'unsupported value: $value');
    }
  }

  void _sourceDocs(List<SourceDoc> sourceDocs, String owner) {
    _requiredNonEmpty(sourceDocs, '$owner.sourceDocs');
    for (final sourceDoc in sourceDocs) {
      final file = File('$repositoryRoot/${sourceDoc.path}');
      if (!file.existsSync()) {
        _add('source_doc.path', owner, 'missing sourceDoc: ${sourceDoc.path}');
      }
      if (sourceDoc.stableAnchor && sourceDoc.line == null) {
        _add('source_doc.anchor', owner, 'stableAnchor requires line');
      }
      final stableAnchorLine = sourceDoc.line;
      if (sourceDoc.stableAnchor &&
          stableAnchorLine != null &&
          file.existsSync()) {
        final lineCount = file.readAsLinesSync().length;
        if (stableAnchorLine < 1 || stableAnchorLine > lineCount) {
          _add(
            'source_doc.anchor',
            owner,
            'stableAnchor line $stableAnchorLine is outside ${sourceDoc.path}',
          );
        }
      }
    }
  }

  void _requiredNonEmpty(Iterable<Object> values, String path) {
    if (values.isEmpty) {
      _add('required.non_empty', path, 'must not be empty');
    }
  }

  void _requiredText(String value, String path) {
    if (value.trim().isEmpty) {
      _add('required.text', path, 'must not be empty');
    }
  }

  void _add(String id, String path, String message) {
    _diagnostics.add(
      ArchitectureGraphDiagnostic(id: id, path: path, message: message),
    );
  }
}

final class _RegistrySection {
  const _RegistrySection({
    required this.id,
    required this.file,
    required this.phases,
  });

  final String id;
  final String file;
  final List<String> phases;
}

bool _sameOrderedValues(List<String> actual, List<String> expected) {
  if (actual.length != expected.length) {
    return false;
  }
  for (var index = 0; index < actual.length; index++) {
    if (actual[index] != expected[index]) {
      return false;
    }
  }

  return true;
}

ArchitecturePhase _phase(Map<String, Object?> yaml, String path) {
  return ArchitecturePhase(
    id: _requiredString(yaml, 'id', path),
    title: _requiredString(yaml, 'title', path),
    status: _requiredString(yaml, 'status', path),
    sourceDocs: _sourceDocs(yaml, path),
  );
}

ArchitectureCoverage _coverage(Map<String, Object?> yaml, String path) {
  return ArchitectureCoverage(
    publicSurfaces: _requiredStrings(yaml, 'publicSurfaces', path),
    architectureOwners: _requiredStrings(yaml, 'architectureOwners', path),
    sensitiveThrows: _requiredMaps(yaml, 'sensitiveThrows', path)
        .map(
          (entry) => SensitiveThrowCoverage(
            owner: _requiredString(entry, 'owner', path),
            under: _requiredString(entry, 'under', path),
            exception: _requiredString(entry, 'exception', path),
          ),
        )
        .toList(),
    placeholders: _requiredMaps(yaml, 'placeholders', path)
        .map(
          (entry) =>
              PlaceholderCoverage(under: _requiredString(entry, 'under', path)),
        )
        .toList(),
    ignored: _requiredStrings(yaml, 'ignored', path),
  );
}

ArchitectureNode _node(Map<String, Object?> yaml, String path) {
  return ArchitectureNode(
    id: _requiredString(yaml, 'id', path),
    label: _requiredString(yaml, 'label', path),
    kind: _requiredString(yaml, 'kind', path),
    owner: _requiredString(yaml, 'owner', path),
    phaseIntroduced: _requiredString(yaml, 'phaseIntroduced', path),
    phaseRequiredBy: _requiredString(yaml, 'phaseRequiredBy', path),
    status: _requiredString(yaml, 'status', path),
    coverageScope: _requiredString(yaml, 'coverageScope', path),
    sourceDocs: _sourceDocs(yaml, path),
    evidence: _requiredStrings(yaml, 'evidence', path),
    actual: _actualExpectation(yaml),
    isolationAllowances: _isolationAllowances(yaml, path),
  );
}

ArchitectureEdge _edge(Map<String, Object?> yaml, String path) {
  return ArchitectureEdge(
    id: _requiredString(yaml, 'id', path),
    from: _requiredString(yaml, 'from', path),
    to: _requiredString(yaml, 'to', path),
    kind: _requiredString(yaml, 'kind', path),
    phaseRequiredBy: _requiredString(yaml, 'phaseRequiredBy', path),
    status: _requiredString(yaml, 'status', path),
    sourceDocs: _sourceDocs(yaml, path),
    evidence: _requiredStrings(yaml, 'evidence', path),
    actual: _actualExpectation(yaml),
  );
}

ArchitecturePlaceholder _placeholder(Map<String, Object?> yaml, String path) {
  return ArchitecturePlaceholder(
    id: _requiredString(yaml, 'id', path),
    node: _requiredString(yaml, 'node', path),
    member: _requiredString(yaml, 'member', path),
    path: _requiredString(yaml, 'path', path),
    phaseRequiredBy: _requiredString(yaml, 'phaseRequiredBy', path),
    status: _requiredString(yaml, 'status', path),
    sourceDocs: _sourceDocs(yaml, path),
    evidence: _requiredStrings(yaml, 'evidence', path),
  );
}

ArchitectureForbiddenEdge _forbiddenEdge(
  Map<String, Object?> yaml,
  String path,
) {
  return ArchitectureForbiddenEdge(
    id: _requiredString(yaml, 'id', path),
    from: _requiredString(yaml, 'from', path),
    to: _requiredString(yaml, 'to', path),
    kind: _requiredString(yaml, 'kind', path),
    phaseRequiredBy: _requiredString(yaml, 'phaseRequiredBy', path),
    status: _requiredString(yaml, 'status', path),
    sourceDocs: _sourceDocs(yaml, path),
    evidence: _requiredStrings(yaml, 'evidence', path),
  );
}

ArchitectureView _view(Map<String, Object?> yaml, String path) {
  return ArchitectureView(
    id: _requiredString(yaml, 'id', path),
    title: _requiredString(yaml, 'title', path),
    kind: _requiredString(yaml, 'kind', path),
    output: _requiredString(yaml, 'output', path),
    sourceDocs: _sourceDocs(yaml, path),
    excludedNodeKinds: _optionalStrings(yaml, 'excludedNodeKinds'),
  );
}

ArchitectureSourceCoverage _sourceCoverage(
  Map<String, Object?> yaml,
  String path,
) {
  return ArchitectureSourceCoverage(
    sectionId: _requiredString(yaml, 'sectionId', path),
    disposition: _requiredString(yaml, 'disposition', path),
    graphIds: _optionalStrings(yaml, 'graphIds'),
    reason: _optionalString(yaml, 'reason'),
    successorSource: _optionalString(yaml, 'successorSource'),
  );
}

List<ArchitectureIsolationAllowance> _isolationAllowances(
  Map<String, Object?> yaml,
  String path,
) {
  return _optionalMaps(yaml, 'isolationAllowances').map((entry) {
    return ArchitectureIsolationAllowance(
      views: _requiredStrings(entry, 'views', path),
      sourceDocs: _sourceDocs(entry, path),
      reason: _requiredString(entry, 'reason', path),
    );
  }).toList();
}

_RegistrySection _registrySection(Map<String, Object?> yaml) {
  return _RegistrySection(
    id: _requiredString(yaml, 'id', 'docs/_registry/sections.yaml'),
    file: _requiredString(yaml, 'file', 'docs/_registry/sections.yaml'),
    phases: _requiredStrings(yaml, 'phases', 'docs/_registry/sections.yaml'),
  );
}

ActualExpectation _actualExpectation(Map<String, Object?> yaml) {
  final actual = _optionalMap(yaml, 'actual');
  if (actual == null) {
    return const ActualExpectation.empty();
  }

  return ActualExpectation(
    declarations: _optionalStrings(actual, 'declarations'),
    exports: _optionalStrings(actual, 'exports'),
    imports: _optionalStrings(actual, 'imports'),
    implementedInterfaces: _optionalStrings(actual, 'implementedInterfaces'),
    compositionFields: _optionalStrings(actual, 'compositionFields'),
    delegationMembers: _optionalStrings(actual, 'delegationMembers'),
    delegationTargets: _optionalStrings(actual, 'delegationTargets'),
    sensitiveThrowOwner: _optionalString(actual, 'sensitiveThrowOwner'),
    sensitiveThrowRoutes: _optionalStrings(actual, 'sensitiveThrowRoutes'),
  );
}

List<SourceDoc> _sourceDocs(Map<String, Object?> yaml, String path) {
  return _requiredMaps(yaml, 'sourceDocs', path).map((entry) {
    return SourceDoc(
      path: _requiredString(entry, 'path', path),
      line: _optionalInt(entry, 'line'),
      stableAnchor: _optionalBool(entry, 'stableAnchor') ?? false,
    );
  }).toList();
}

Map<String, Object?> _normalizeMap(Object? value, String path) {
  final normalized = _normalizeYaml(value);
  if (normalized is Map<String, Object?>) {
    return normalized;
  }
  throw FormatException('Expected map at $path.');
}

Object? _normalizeYaml(Object? value) {
  if (value is YamlMap) {
    return {
      for (final key in value.keys)
        if (key is String) key: _normalizeYaml(value[key]),
    };
  }
  if (value is YamlList) {
    return [for (final item in value) _normalizeYaml(item)];
  }

  return value;
}

Map<String, Object?> _requiredMap(
  Map<String, Object?> yaml,
  String key,
  String path,
) {
  final value = yaml[key];
  if (value is Map<String, Object?>) {
    return value;
  }
  throw FormatException('Expected map at $path/$key.');
}

Map<String, Object?>? _optionalMap(Map<String, Object?> yaml, String key) {
  final value = yaml[key];
  if (value == null) {
    return null;
  }
  if (value is Map<String, Object?>) {
    return value;
  }
  throw FormatException('Expected map at $key.');
}

List<Map<String, Object?>> _requiredMaps(
  Map<String, Object?> yaml,
  String key,
  String path,
) {
  final value = yaml[key];
  if (value is List<Object?>) {
    return value.map((entry) => _normalizeMap(entry, '$path/$key')).toList();
  }
  throw FormatException('Expected list at $path/$key.');
}

List<Map<String, Object?>> _optionalMaps(
  Map<String, Object?> yaml,
  String key,
) {
  final value = yaml[key];
  if (value == null) {
    return const [];
  }
  if (value is List<Object?>) {
    return value.map((entry) => _normalizeMap(entry, key)).toList();
  }
  throw FormatException('Expected list at $key.');
}

List<String> _requiredStrings(
  Map<String, Object?> yaml,
  String key,
  String path,
) {
  final value = yaml[key];
  if (value is List<Object?>) {
    return value.map((entry) {
      if (entry is String) {
        return entry;
      }
      throw FormatException('Expected string at $path/$key.');
    }).toList();
  }
  throw FormatException('Expected string list at $path/$key.');
}

List<String> _optionalStrings(Map<String, Object?> yaml, String key) {
  final value = yaml[key];
  if (value == null) {
    return const [];
  }
  if (value is List<Object?>) {
    return value.map((entry) {
      if (entry is String) {
        return entry;
      }
      throw FormatException('Expected string in $key.');
    }).toList();
  }
  throw FormatException('Expected string list at $key.');
}

String _requiredString(Map<String, Object?> yaml, String key, String path) {
  final value = yaml[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Expected string at $path/$key.');
}

String? _optionalString(Map<String, Object?> yaml, String key) {
  final value = yaml[key];
  if (value == null || value is String) {
    return value as String?;
  }
  throw FormatException('Expected string at $key.');
}

int _requiredInt(Map<String, Object?> yaml, String key, String path) {
  final value = yaml[key];
  if (value is int) {
    return value;
  }
  throw FormatException('Expected integer at $path/$key.');
}

int? _optionalInt(Map<String, Object?> yaml, String key) {
  final value = yaml[key];
  if (value == null || value is int) {
    return value as int?;
  }
  throw FormatException('Expected integer at $key.');
}

bool? _optionalBool(Map<String, Object?> yaml, String key) {
  final value = yaml[key];
  if (value == null || value is bool) {
    return value as bool?;
  }
  throw FormatException('Expected boolean at $key.');
}

bool _isKnownPhase(String value) {
  final match = RegExp(r'^P([0-9]|1[0-4])$').firstMatch(value);

  return match != null;
}
