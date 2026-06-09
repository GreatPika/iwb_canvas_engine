import 'dart:io';

import 'package:yaml/yaml.dart';

const architectureGraphPath = 'docs/architecture/architecture_graph.yaml';

final class ExpectedArchitectureGraph {
  const ExpectedArchitectureGraph({
    required this.schemaVersion,
    required this.coverage,
    required this.nodes,
    required this.edges,
    required this.placeholders,
    required this.forbiddenEdges,
    required this.views,
    required this.sourceCoverage,
  });

  final int schemaVersion;
  final ArchitectureCoverage coverage;
  final List<ArchitectureNode> nodes;
  final List<ArchitectureEdge> edges;
  final List<ArchitecturePlaceholder> placeholders;
  final List<ArchitectureForbiddenEdge> forbiddenEdges;
  final List<ArchitectureView> views;
  final List<ArchitectureSourceCoverage> sourceCoverage;
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
    required this.status,
    required this.sourceDocs,
    required this.evidence,
    required this.actual,
  });

  final String id;
  final String from;
  final String to;
  final String kind;
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
    required this.status,
    required this.sourceDocs,
    required this.evidence,
  });

  final String id;
  final String node;
  final String member;
  final String path;
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
    required this.status,
    required this.sourceDocs,
    required this.evidence,
  });

  final String id;
  final String from;
  final String to;
  final String kind;
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

// The loader mirrors the top-level YAML schema in one visible construction so
// added sections change the schema boundary in exactly one auditable place.
// ignore: halstead-volume, source-lines-of-code
ExpectedArchitectureGraph loadExpectedArchitectureGraph({
  String path = architectureGraphPath,
}) {
  final file = File(path);
  final yaml = loadYaml(file.readAsStringSync());
  final root = _normalizeMap(yaml, path);

  return ExpectedArchitectureGraph(
    schemaVersion: _requiredInt(root, 'schemaVersion', path),
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

  List<ArchitectureGraphDiagnostic> validate() {
    final context = _ArchitectureGraphValidationContext(
      graph: graph,
      repositoryRoot: repositoryRoot,
    );
    _SchemaAndCoverageValidator(context).validate();
    _GraphEntryValidator(context).validate();
    _SourceCoverageValidator(context).validate();

    return context.diagnostics;
  }
}

final class _ArchitectureGraphValidationContext {
  _ArchitectureGraphValidationContext({
    required this.graph,
    required this.repositoryRoot,
  });

  final ExpectedArchitectureGraph graph;
  final String repositoryRoot;
  final List<ArchitectureGraphDiagnostic> diagnostics = [];
  final Set<String> ids = {};

  void unique(String id) {
    if (!ids.add(id)) {
      add('graph.id.duplicate', architectureGraphPath, 'duplicate id: $id');
    }
  }

  void nodeRef(String id, Set<String> nodeIds, String owner) {
    if (!nodeIds.contains(id)) {
      add('node.reference', owner, 'unknown node: $id');
    }
  }

  void allowed(String value, Set<String> values, String owner) {
    if (!values.contains(value)) {
      add('enum.value', owner, 'unsupported value: $value');
    }
  }

  void sourceDocs(List<SourceDoc> sourceDocs, String owner) {
    requiredNonEmpty(sourceDocs, '$owner.sourceDocs');
    for (final sourceDoc in sourceDocs) {
      final file = File('$repositoryRoot/${sourceDoc.path}');
      if (!file.existsSync()) {
        add('source_doc.path', owner, 'missing sourceDoc: ${sourceDoc.path}');
      }
      if (sourceDoc.stableAnchor && sourceDoc.line == null) {
        add('source_doc.anchor', owner, 'stableAnchor requires line');
      }
      final stableAnchorLine = sourceDoc.line;
      if (sourceDoc.stableAnchor &&
          stableAnchorLine != null &&
          file.existsSync()) {
        final lineCount = file.readAsLinesSync().length;
        if (stableAnchorLine < 1 || stableAnchorLine > lineCount) {
          add(
            'source_doc.anchor',
            owner,
            'stableAnchor line $stableAnchorLine is outside ${sourceDoc.path}',
          );
        }
      }
    }
  }

  void requiredNonEmpty(Iterable<Object> values, String path) {
    if (values.isEmpty) {
      add('required.non_empty', path, 'must not be empty');
    }
  }

  void requiredText(String value, String path) {
    if (value.trim().isEmpty) {
      add('required.text', path, 'must not be empty');
    }
  }

  void add(String id, String path, String message) {
    diagnostics.add(
      ArchitectureGraphDiagnostic(id: id, path: path, message: message),
    );
  }
}

final class _SchemaAndCoverageValidator {
  const _SchemaAndCoverageValidator(this.context);

  final _ArchitectureGraphValidationContext context;

  ExpectedArchitectureGraph get graph => context.graph;

  void validate() {
    _schemaVersion();
    _coverage();
  }

  void _schemaVersion() {
    if (graph.schemaVersion != 1) {
      context.add(
        'schema.version',
        architectureGraphPath,
        'schemaVersion must be 1',
      );
    }
  }

  void _coverage() {
    _textList(graph.coverage.publicSurfaces, 'coverage.publicSurfaces');
    _textList(graph.coverage.architectureOwners, 'coverage.architectureOwners');
    _coverageGlobsMatchProductionDartFiles(
      graph.coverage.publicSurfaces,
      'coverage.publicSurfaces',
    );
    _coverageGlobsMatchProductionDartFiles(
      graph.coverage.architectureOwners,
      'coverage.architectureOwners',
    );
    context.requiredNonEmpty(
      graph.coverage.sensitiveThrows,
      'coverage.sensitiveThrows',
    );
    for (final entry in graph.coverage.sensitiveThrows) {
      context.requiredText(entry.owner, 'coverage.sensitiveThrows.owner');
      context.requiredText(entry.under, 'coverage.sensitiveThrows.under');
      context.requiredText(
        entry.exception,
        'coverage.sensitiveThrows.exception',
      );
    }
    context.requiredNonEmpty(
      graph.coverage.placeholders,
      'coverage.placeholders',
    );
    for (final entry in graph.coverage.placeholders) {
      context.requiredText(entry.under, 'coverage.placeholders.under');
    }
    _textList(graph.coverage.ignored, 'coverage.ignored');
  }

  void _coverageGlobsMatchProductionDartFiles(
    List<String> values,
    String path,
  ) {
    for (final value in values) {
      if (value.trim().isEmpty) {
        continue;
      }
      if (!_coveragePatternMatchesProductionDartFile(
        value,
        repositoryRoot: context.repositoryRoot,
      )) {
        context.add(
          'coverage.empty_glob',
          path,
          '$value must match at least one production Dart file',
        );
      }
    }
  }

  void _textList(List<String> values, String path) {
    context.requiredNonEmpty(values, path);
    for (final value in values) {
      context.requiredText(value, path);
    }
  }
}

bool _coveragePatternMatchesProductionDartFile(
  String pattern, {
  required String repositoryRoot,
}) {
  final normalized = pattern.replaceAll('\\', '/');
  if (!normalized.contains('*')) {
    final file = File('$repositoryRoot/$normalized');

    return file.existsSync() && _isProductionDartPath(normalized);
  }
  if (normalized.endsWith('/**')) {
    final directoryPath = normalized.replaceFirst(RegExp(r'/\*\*$'), '');
    final directory = Directory('$repositoryRoot/$directoryPath');

    return _directoryContainsProductionDartFile(
      directory,
      repositoryRoot: repositoryRoot,
    );
  }
  if (normalized.endsWith('/*')) {
    final directoryPath = normalized.replaceFirst(RegExp(r'/\*$'), '');
    final directory = Directory('$repositoryRoot/$directoryPath');

    if (!directory.existsSync()) {
      return false;
    }

    return directory
        .listSync(followLinks: false)
        .whereType<File>()
        .map(
          (file) => _repositoryRelativePath(
            file.path,
            repositoryRoot: repositoryRoot,
          ),
        )
        .any(_isProductionDartPath);
  }

  return false;
}

bool _directoryContainsProductionDartFile(
  Directory directory, {
  required String repositoryRoot,
}) {
  if (!directory.existsSync()) {
    return false;
  }

  return directory
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .map(
        (file) =>
            _repositoryRelativePath(file.path, repositoryRoot: repositoryRoot),
      )
      .any(_isProductionDartPath);
}

String _repositoryRelativePath(String path, {required String repositoryRoot}) {
  final normalizedPath = path.replaceAll('\\', '/');
  final normalizedRoot = Directory(
    repositoryRoot,
  ).absolute.path.replaceAll('\\', '/');
  final rootPrefix = normalizedRoot.endsWith('/')
      ? normalizedRoot
      : '$normalizedRoot/';

  if (normalizedPath.startsWith(rootPrefix)) {
    return normalizedPath.replaceFirst(rootPrefix, '');
  }

  return normalizedPath;
}

bool _isProductionDartPath(String path) {
  final normalized = path.replaceAll('\\', '/');

  return normalized.endsWith('.dart') &&
      !normalized.startsWith('test/') &&
      !normalized.contains('/test/') &&
      !normalized.startsWith('fixtures/') &&
      !normalized.contains('/fixtures/');
}

final class _GraphEntryValidator {
  const _GraphEntryValidator(this.context);

  final _ArchitectureGraphValidationContext context;

  ExpectedArchitectureGraph get graph => context.graph;

  void validate() {
    _nodes();
    _edges();
    _placeholders();
    _forbiddenEdges();
    _views();
  }

  void _nodes() {
    final coverageScopes = {'publicSurfaces', 'architectureOwners'};
    for (final node in graph.nodes) {
      context.unique(node.id);
      context.allowed(node.status, const {
        'required',
        'future',
        'measurement',
      }, node.id);
      context.allowed(node.coverageScope, coverageScopes, node.id);
      context.requiredText(node.label, '${node.id}.label');
      context.requiredText(node.kind, '${node.id}.kind');
      context.requiredText(node.owner, '${node.id}.owner');
      context.sourceDocs(node.sourceDocs, node.id);
      context.requiredNonEmpty(node.evidence, '${node.id}.evidence');
      _isolationAllowances(node);
    }
  }

  void _isolationAllowances(ArchitectureNode node) {
    for (final allowance in node.isolationAllowances) {
      context.requiredNonEmpty(
        allowance.views,
        '${node.id}.isolationAllowances.views',
      );
      for (final view in allowance.views) {
        context.requiredText(view, '${node.id}.isolationAllowances.views');
      }
      context.sourceDocs(allowance.sourceDocs, node.id);
      context.requiredText(
        allowance.reason,
        '${node.id}.isolationAllowances.reason',
      );
    }
  }

  void _edges() {
    final nodeIds = graph.nodes.map((node) => node.id).toSet();
    for (final edge in graph.edges) {
      context.unique(edge.id);
      context.nodeRef(edge.from, nodeIds, edge.id);
      context.nodeRef(edge.to, nodeIds, edge.id);
      context.allowed(edge.status, const {'required', 'future'}, edge.id);
      context.requiredText(edge.kind, '${edge.id}.kind');
      context.sourceDocs(edge.sourceDocs, edge.id);
      context.requiredNonEmpty(edge.evidence, '${edge.id}.evidence');
    }
  }

  void _placeholders() {
    final nodeIds = graph.nodes.map((node) => node.id).toSet();
    for (final placeholder in graph.placeholders) {
      context.unique(placeholder.id);
      context.nodeRef(placeholder.node, nodeIds, placeholder.id);
      context.allowed(placeholder.status, const {'forbidden'}, placeholder.id);
      context.requiredText(placeholder.member, '${placeholder.id}.member');
      context.requiredText(placeholder.path, '${placeholder.id}.path');
      context.sourceDocs(placeholder.sourceDocs, placeholder.id);
      context.requiredNonEmpty(
        placeholder.evidence,
        '${placeholder.id}.evidence',
      );
    }
  }

  void _forbiddenEdges() {
    final nodeIds = graph.nodes.map((node) => node.id).toSet();
    for (final edge in graph.forbiddenEdges) {
      context.unique(edge.id);
      context.nodeRef(edge.from, nodeIds, edge.id);
      context.nodeRef(edge.to, nodeIds, edge.id);
      context.allowed(edge.status, const {'forbidden'}, edge.id);
      context.sourceDocs(edge.sourceDocs, edge.id);
      context.requiredNonEmpty(edge.evidence, '${edge.id}.evidence');
    }
  }

  void _views() {
    for (final view in graph.views) {
      context.unique(view.id);
      context.allowed(view.kind, const {
        'expected_full',
        'expected_release_verification',
        'actual_vs_expected_diff',
      }, view.id);
      context.requiredText(view.title, '${view.id}.title');
      context.requiredText(view.output, '${view.id}.output');
      context.sourceDocs(view.sourceDocs, view.id);
      for (final kind in view.excludedNodeKinds) {
        context.requiredText(kind, '${view.id}.excludedNodeKinds');
      }
    }
  }
}

final class _SourceCoverageValidator {
  const _SourceCoverageValidator(this.context);

  final _ArchitectureGraphValidationContext context;

  void _sourceCoverage() {
    final state = _SourceCoverageState(
      registrySections: _sourceCoverageRegistrySections(context.repositoryRoot),
      graphIds: _allGraphIds(context.graph),
    );
    for (final coverage in context.graph.sourceCoverage) {
      _coverageEntry(coverage, state);
    }
    _missingRegistrySections(state);
    _missingGraphEntries(state);
  }

  void _coverageEntry(
    ArchitectureSourceCoverage coverage,
    _SourceCoverageState state,
  ) {
    _coverageSection(coverage, state);
    context.allowed(coverage.disposition, const {
      'graph_obligation',
      'non_graph_semantics',
      'superseded',
      'out_of_graph_scope',
    }, coverage.sectionId);
    switch (coverage.disposition) {
      case 'graph_obligation':
        _graphObligationCoverage(coverage, state);
      case 'non_graph_semantics' || 'out_of_graph_scope':
        context.requiredText(
          coverage.reason ?? '',
          '${coverage.sectionId}.reason',
        );
      case 'superseded':
        context.requiredText(
          coverage.successorSource ?? '',
          '${coverage.sectionId}.successorSource',
        );
    }
  }

  void _coverageSection(
    ArchitectureSourceCoverage coverage,
    _SourceCoverageState state,
  ) {
    if (!state.coveredSections.add(coverage.sectionId)) {
      context.add(
        'source_coverage.duplicate',
        coverage.sectionId,
        'duplicate source coverage entry',
      );
    }
    if (!state.registryIds.contains(coverage.sectionId)) {
      context.add(
        'source_coverage.section',
        coverage.sectionId,
        'unknown registry section id',
      );
    }
  }

  void _graphObligationCoverage(
    ArchitectureSourceCoverage coverage,
    _SourceCoverageState state,
  ) {
    context.requiredNonEmpty(
      coverage.graphIds,
      '${coverage.sectionId}.graphIds',
    );
    for (final graphId in coverage.graphIds) {
      if (!state.graphIds.contains(graphId)) {
        context.add(
          'source_coverage.graph_id',
          coverage.sectionId,
          'unknown graph id: $graphId',
        );
      } else {
        state.graphBackedIds.add(graphId);
      }
    }
  }

  void _missingRegistrySections(_SourceCoverageState state) {
    for (final section in state.registrySections) {
      if (state.coveredSections.contains(section.id)) {
        continue;
      }
      context.add(
        'source_coverage.missing_section',
        section.id,
        'missing source coverage for ${section.file}',
      );
    }
  }

  void _missingGraphEntries(_SourceCoverageState state) {
    for (final graphId in state.graphIds) {
      if (state.graphBackedIds.contains(graphId)) {
        continue;
      }
      context.add(
        'source_coverage.missing_graph_entry',
        graphId,
        'graph entry is not mapped to a registry section',
      );
    }
  }

  void validate() {
    _sourceCoverage();
  }
}

Set<String> _allGraphIds(ExpectedArchitectureGraph graph) {
  return {
    for (final node in graph.nodes) node.id,
    for (final edge in graph.edges) edge.id,
    for (final placeholder in graph.placeholders) placeholder.id,
    for (final edge in graph.forbiddenEdges) edge.id,
    for (final view in graph.views) view.id,
  };
}

List<_RegistrySection> _sourceCoverageRegistrySections(String repositoryRoot) {
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
            section.file.startsWith('docs/verification/');
      })
      .toList();
}

final class _SourceCoverageState {
  _SourceCoverageState({required this.registrySections, required this.graphIds})
    : registryIds = registrySections.map((section) => section.id).toSet();

  final List<_RegistrySection> registrySections;
  final Set<String> registryIds;
  final Set<String> graphIds;
  final Set<String> coveredSections = {};
  final Set<String> graphBackedIds = {};
}

final class _RegistrySection {
  const _RegistrySection({required this.id, required this.file});

  final String id;
  final String file;
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
