import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import 'guardrail_violation.dart';
import 'repository_paths.dart';

const ownerDagGuardrailId = 'core.owner_dag_import_boundaries';

Future<List<GuardrailViolation>> checkOwnerDagImportBoundaries() async {
  final violations = ownerDagSelectionViolations();

  for (final file in dartFilesUnder('lib')) {
    final path = relativePath(file);
    final unit = parseFile(
      path: file.path,
      featureSet: FeatureSet.latestLanguageVersion(),
    ).unit;
    violations.addAll(ownerDagViolationsForFile(path: path, unit: unit));
  }

  return violations;
}

List<GuardrailViolation> checkOwnerDagFile({
  required String path,
  required String content,
}) {
  final unit = parseString(
    content: content,
    path: path,
    featureSet: FeatureSet.latestLanguageVersion(),
  ).unit;

  return ownerDagViolationsForFile(path: path, unit: unit);
}

List<GuardrailViolation> ownerDagSelectionViolations({
  List<OwnerEdge> allowedEdges = ownerDagAllowedEdges,
}) {
  return [
    for (final cycle in ownerDagCycles(allowedEdges: allowedEdges))
      GuardrailViolation(
        guardrailId: ownerDagGuardrailId,
        path: 'tool/guardrails/src/owner_dag_import_checks.dart',
        message: 'owner DAG allowed edge cycle: ${cycle.join(' -> ')}',
      ),
  ];
}

List<List<String>> ownerDagCycles({
  List<OwnerEdge> allowedEdges = ownerDagAllowedEdges,
}) {
  final graph = {for (final owner in ownerDagOwners) owner.name: <String>{}};

  for (final edge in allowedEdges) {
    if (edge.source != edge.target) {
      graph[edge.source.name]?.add(edge.target.name);
    }
  }

  return _OwnerDagCycleFinder(graph).findCycles();
}

List<GuardrailViolation> ownerDagViolationsForFile({
  required String path,
  required CompilationUnit unit,
}) {
  final sourceOwner = ownerForPath(path);
  if (sourceOwner == null) {
    return const [];
  }

  final violations = <GuardrailViolation>[];
  for (final directive in unit.directives) {
    for (final reference in _directiveReferences(directive)) {
      final target = _targetPath(path, reference.uri);
      final targetOwner = target == null ? null : ownerForPath(target);
      if (target == null || targetOwner == null) {
        continue;
      }

      final query = OwnerEdgeQuery(
        sourcePath: path,
        sourceOwner: sourceOwner,
        targetPath: target,
        targetOwner: targetOwner,
        directiveKind: reference.kind,
      );
      if (_isAllowedOwnerEdge(query)) {
        continue;
      }

      violations.add(
        GuardrailViolation(
          guardrailId: ownerDagGuardrailId,
          path: path,
          message:
              '${sourceOwner.name} owner may not reference '
              '${targetOwner.name} owner through ${reference.kind} '
              '${reference.uri}',
        ),
      );
    }
  }

  return violations;
}

Iterable<({String kind, String uri})> _directiveReferences(
  Directive directive,
) {
  switch (directive) {
    case ImportDirective(:final uri, :final configurations):
      return _literalReferences('import', uri, configurations);
    case ExportDirective(:final uri, :final configurations):
      return _literalReferences('export', uri, configurations);
    case LibraryDirective() || PartDirective() || PartOfDirective():
      return const [];
  }
}

Iterable<({String kind, String uri})> _literalReferences(
  String kind,
  StringLiteral uri,
  NodeList<Configuration> configurations,
) sync* {
  final value = uri.stringValue;
  if (value != null) {
    yield (kind: kind, uri: value);
  }

  for (final configuration in configurations) {
    final value = configuration.uri.stringValue;
    if (value != null) {
      yield (kind: kind, uri: value);
    }
  }
}

Owner? ownerForPath(String path) {
  for (final owner in ownerDagOwners) {
    if (owner.matches(path)) {
      return owner;
    }
  }

  return null;
}

String? _targetPath(String sourcePath, String uri) {
  if (uri.startsWith('package:iwb_canvas_engine/')) {
    return _normalizeRepoPath(
      'lib/${uri.substring('package:iwb_canvas_engine/'.length)}',
    );
  }
  if (uri.startsWith('dart:') || uri.startsWith('package:')) {
    return null;
  }
  if (Uri.tryParse(uri)?.hasScheme ?? false) {
    return null;
  }

  final sourceDirectory = sourcePath.substring(0, sourcePath.lastIndexOf('/'));

  return _normalizeRepoPath('$sourceDirectory/$uri');
}

String _normalizeRepoPath(String path) {
  final parts = <String>[];
  for (final segment in path.split('/')) {
    if (segment.isEmpty || segment == '.') {
      continue;
    }
    if (segment == '..') {
      if (parts.isNotEmpty) {
        parts.removeLast();
      }
      continue;
    }
    parts.add(segment);
  }

  return parts.join('/');
}

bool _isAllowedOwnerEdge(OwnerEdgeQuery query) {
  if (query.sourceOwner == query.targetOwner) {
    return true;
  }

  return ownerDagAllowedEdges.any((edge) => edge.allows(query));
}

final class Owner {
  const Owner({required this.name, required this.prefixes});

  final String name;
  final List<String> prefixes;

  bool matches(String path) => prefixes.any(path.startsWith);
}

final class OwnerEdge {
  const OwnerEdge({
    required this.source,
    required this.target,
    this.sourcePath,
    this.targetPath,
    this.directiveKinds = const {'import'},
  });

  final Owner source;
  final Owner target;
  final String? sourcePath;
  final String? targetPath;
  final Set<String> directiveKinds;

  bool allows(OwnerEdgeQuery query) {
    return query.sourceOwner == source &&
        query.targetOwner == target &&
        directiveKinds.contains(query.directiveKind) &&
        (sourcePath == null || sourcePath == query.sourcePath) &&
        (targetPath == null || targetPath == query.targetPath);
  }
}

final class OwnerEdgeQuery {
  const OwnerEdgeQuery({
    required this.sourcePath,
    required this.sourceOwner,
    required this.targetPath,
    required this.targetOwner,
    required this.directiveKind,
  });

  final String sourcePath;
  final Owner sourceOwner;
  final String targetPath;
  final Owner targetOwner;
  final String directiveKind;
}

const apiOwner = Owner(
  name: 'api',
  prefixes: ['lib/src/api/', 'lib/iwb_canvas_engine.dart'],
);
const contractsPublicOwner = Owner(
  name: 'contracts/public',
  prefixes: ['lib/src/contracts/public/'],
);
const contractsInternalOwner = Owner(
  name: 'contracts/internal',
  prefixes: ['lib/src/contracts/internal/'],
);
const runtimeOwner = Owner(name: 'runtime', prefixes: ['lib/src/runtime/']);
const editOwner = Owner(name: 'edit', prefixes: ['lib/src/edit/']);
const storeOwner = Owner(name: 'store', prefixes: ['lib/src/store/']);
const selectionOwner = Owner(
  name: 'selection',
  prefixes: ['lib/src/selection/'],
);
const codecOwner = Owner(name: 'codec', prefixes: ['lib/src/codec/']);
const diagnosticsOwner = Owner(
  name: 'diagnostics',
  prefixes: ['lib/src/diagnostics/'],
);
const resourcesOwner = Owner(
  name: 'resources',
  prefixes: ['lib/src/resources/'],
);
const frameOwner = Owner(name: 'frame', prefixes: ['lib/src/frame/']);
const interactionOwner = Owner(
  name: 'interaction',
  prefixes: ['lib/src/interaction/'],
);
const spatialOwner = Owner(name: 'spatial', prefixes: ['lib/src/spatial/']);
const flutterBridgeOwner = Owner(
  name: 'flutter_bridge',
  prefixes: ['lib/src/flutter_bridge/'],
);

const ownerDagOwners = [
  contractsPublicOwner,
  contractsInternalOwner,
  apiOwner,
  runtimeOwner,
  editOwner,
  storeOwner,
  selectionOwner,
  codecOwner,
  diagnosticsOwner,
  resourcesOwner,
  frameOwner,
  interactionOwner,
  spatialOwner,
  flutterBridgeOwner,
];

const ownerDagAllowedEdges = [
  OwnerEdge(source: contractsInternalOwner, target: contractsPublicOwner),
  OwnerEdge(
    source: apiOwner,
    target: contractsPublicOwner,
    directiveKinds: {'import', 'export'},
  ),
  OwnerEdge(
    source: apiOwner,
    target: runtimeOwner,
    sourcePath: 'lib/src/api/canvas_runtime.dart',
    targetPath: 'lib/src/runtime/runtime_root.dart',
  ),
  OwnerEdge(
    source: apiOwner,
    target: codecOwner,
    sourcePath: 'lib/src/api/canvas_codec.dart',
    targetPath: 'lib/src/codec/schema_v1_encoder.dart',
  ),
  OwnerEdge(
    source: apiOwner,
    target: codecOwner,
    sourcePath: 'lib/src/api/canvas_codec.dart',
    targetPath: 'lib/src/codec/schema_v1_decoder.dart',
  ),
  OwnerEdge(source: runtimeOwner, target: contractsPublicOwner),
  OwnerEdge(source: runtimeOwner, target: contractsInternalOwner),
  OwnerEdge(source: runtimeOwner, target: editOwner),
  OwnerEdge(source: runtimeOwner, target: selectionOwner),
  OwnerEdge(source: runtimeOwner, target: storeOwner),
  OwnerEdge(source: editOwner, target: contractsPublicOwner),
  OwnerEdge(source: editOwner, target: contractsInternalOwner),
  OwnerEdge(source: editOwner, target: storeOwner),
  OwnerEdge(source: editOwner, target: codecOwner),
  OwnerEdge(source: editOwner, target: diagnosticsOwner),
  OwnerEdge(source: storeOwner, target: contractsPublicOwner),
  OwnerEdge(source: selectionOwner, target: contractsPublicOwner),
  OwnerEdge(source: selectionOwner, target: contractsInternalOwner),
  OwnerEdge(source: codecOwner, target: contractsPublicOwner),
  OwnerEdge(source: codecOwner, target: diagnosticsOwner),
  OwnerEdge(source: diagnosticsOwner, target: contractsPublicOwner),
  OwnerEdge(source: resourcesOwner, target: contractsPublicOwner),
  OwnerEdge(source: resourcesOwner, target: contractsInternalOwner),
  OwnerEdge(source: frameOwner, target: contractsPublicOwner),
  OwnerEdge(source: frameOwner, target: contractsInternalOwner),
  OwnerEdge(source: interactionOwner, target: contractsPublicOwner),
  OwnerEdge(source: interactionOwner, target: contractsInternalOwner),
  OwnerEdge(source: spatialOwner, target: contractsPublicOwner),
  OwnerEdge(source: spatialOwner, target: contractsInternalOwner),
  OwnerEdge(source: flutterBridgeOwner, target: contractsPublicOwner),
  OwnerEdge(source: flutterBridgeOwner, target: contractsInternalOwner),
];

final class _OwnerDagCycleFinder {
  _OwnerDagCycleFinder(this._graph);

  final Map<String, Set<String>> _graph;
  final Set<String> _visiting = {};
  final Set<String> _visited = {};
  final List<String> _path = [];
  final List<List<String>> _cycles = [];

  List<List<String>> findCycles() {
    final nodes = _graph.keys.toList()..sort();
    for (final node in nodes) {
      if (!_visited.contains(node)) {
        _visit(node);
      }
    }

    return _cycles;
  }

  void _visit(String node) {
    _visiting.add(node);
    _path.add(node);

    final edges = (_graph[node] ?? const <String>{}).toList()..sort();
    for (final target in edges) {
      if (_visiting.contains(target)) {
        _cycles.add(_cycleEndingAt(target));
      } else if (!_visited.contains(target)) {
        _visit(target);
      }
    }

    _path.removeLast();
    _visiting.remove(node);
    _visited.add(node);
  }

  List<String> _cycleEndingAt(String target) {
    final start = _path.indexOf(target);

    return [..._path.skip(start), target];
  }
}
