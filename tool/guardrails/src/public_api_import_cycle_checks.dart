import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import 'guardrail_violation.dart';
import 'repository_paths.dart';

const _guardrailId = 'api.no_public_api_import_cycles';
const _publicApiDirectory = 'lib/src/api';
const _publicContractsDirectory = 'lib/src/contracts/public';
const _packageImportPrefix = 'package:iwb_canvas_engine/';

Future<List<GuardrailViolation>> checkNoPublicApiImportCycles() async {
  final sources = <String, String>{};
  await _readSourcesUnder(_publicApiDirectory, sources);
  await _readSourcesUnder(_publicContractsDirectory, sources);

  return checkPublicApiImportCyclesInSources(sources);
}

Future<void> _readSourcesUnder(
  String directoryPath,
  Map<String, String> sources,
) async {
  final directory = Directory('$repositoryRoot/$directoryPath');
  await for (final entity in directory.list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    final repoPath = _repoRelativePath(entity.path);
    sources[repoPath] = await entity.readAsString();
  }
}

List<GuardrailViolation> checkPublicApiImportCyclesInSources(
  Map<String, String> sources, {
  List<PublicApiImportCycleAllowlistEntry> allowlist = const [],
}) {
  final allowlistViolations = _allowlistViolations(allowlist);
  if (allowlistViolations.isNotEmpty) {
    return allowlistViolations;
  }

  final publicReachabilitySources = Map.fromEntries(
    sources.entries.where((entry) => _isPublicReachabilitySource(entry.key)),
  );
  final graph = {
    for (final path in publicReachabilitySources.keys) path: <String>{},
  };

  for (final entry in publicReachabilitySources.entries) {
    for (final directiveUri in _directiveUris(
      path: entry.key,
      content: entry.value,
    )) {
      final target = resolvePublicApiImportTarget(
        importerPath: entry.key,
        importUri: directiveUri,
      );
      if (target != null && publicReachabilitySources.containsKey(target)) {
        graph[entry.key]!.add(target);
      }
    }
  }

  return [
    for (final cycle in _findImportCycles(graph))
      GuardrailViolation(
        guardrailId: _guardrailId,
        path: cycle.first,
        message: 'public API import cycle: ${cycle.join(' -> ')}',
      ),
  ];
}

String? resolvePublicApiImportTarget({
  required String importerPath,
  required String importUri,
}) {
  if (importUri.startsWith('dart:') || importUri.startsWith('package:')) {
    if (!importUri.startsWith(_packageImportPrefix)) {
      return null;
    }

    final packagePath = importUri.substring(_packageImportPrefix.length);

    return _publicReachabilityTargetOrNull('lib/$packagePath');
  }

  if (Uri.tryParse(importUri)?.hasScheme ?? false) {
    return null;
  }

  return _publicReachabilityTargetOrNull(
    _normalizeRepoPath('${_directoryName(importerPath)}/$importUri'),
  );
}

final class PublicApiImportCycleAllowlistEntry {
  const PublicApiImportCycleAllowlistEntry({
    required this.cycleId,
    required this.ownerPhase,
    required this.reason,
    required this.removalCondition,
  });

  final String cycleId;
  final String ownerPhase;
  final String reason;
  final String removalCondition;
}

List<String> _directiveUris({required String path, required String content}) {
  final parseResult = parseString(content: content, path: path);

  return [
    for (final directive in parseResult.unit.directives)
      ..._directiveUriLiterals(directive),
  ];
}

List<String> _directiveUriLiterals(Directive directive) {
  return switch (directive) {
    ImportDirective(:final uri, :final configurations) => _literalDirectiveUris(
      uri,
      configurations,
    ),
    ExportDirective(:final uri, :final configurations) => _literalDirectiveUris(
      uri,
      configurations,
    ),
    _ => const [],
  };
}

List<String> _literalDirectiveUris(
  StringLiteral uri,
  NodeList<Configuration> configurations,
) {
  return [
    ?uri.stringValue,
    for (final configuration in configurations) ?configuration.uri.stringValue,
  ];
}

List<GuardrailViolation> _allowlistViolations(
  List<PublicApiImportCycleAllowlistEntry> allowlist,
) {
  return [
    for (final entry in allowlist)
      GuardrailViolation(
        guardrailId: _guardrailId,
        path: 'tool/guardrails/src/public_api_import_cycle_checks.dart',
        message: _allowlistMessage(entry),
      ),
  ];
}

String _allowlistMessage(PublicApiImportCycleAllowlistEntry entry) {
  if (entry.cycleId.trim().isEmpty ||
      entry.ownerPhase.trim().isEmpty ||
      entry.reason.trim().isEmpty ||
      entry.removalCondition.trim().isEmpty) {
    return 'public API import-cycle allowlist entry is missing owner phase, '
        'reason, or removal condition.';
  }

  return 'public API import-cycle allowlist entries are not active: '
      '${entry.cycleId}.';
}

List<List<String>> _findImportCycles(Map<String, Set<String>> graph) {
  final finder = _TarjanCycleFinder(graph);

  return finder.findCycles();
}

String? _publicReachabilityTargetOrNull(String path) {
  final normalized = _normalizeRepoPath(path);
  if (_isPublicReachabilitySource(normalized)) {
    return normalized;
  }

  return null;
}

bool _isPublicReachabilitySource(String path) {
  return path.endsWith('.dart') &&
      (path.startsWith('$_publicApiDirectory/') ||
          path.startsWith('$_publicContractsDirectory/'));
}

String _repoRelativePath(String path) {
  final prefix = '$repositoryRoot/';
  if (path.startsWith(prefix)) {
    return _normalizeRepoPath(path.substring(prefix.length));
  }

  return _normalizeRepoPath(path);
}

String _directoryName(String path) {
  final index = path.lastIndexOf('/');
  if (index == -1) {
    return '.';
  }

  return path.substring(0, index);
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

final class _TarjanCycleFinder {
  _TarjanCycleFinder(this._graph);

  final Map<String, Set<String>> _graph;
  final Map<String, int> _indexes = {};
  final Map<String, int> _lowLinks = {};
  final List<String> _stack = [];
  final Set<String> _onStack = {};
  final List<List<String>> _cycles = [];
  var _nextIndex = 0;

  List<List<String>> findCycles() {
    final nodes = _graph.keys.toList()..sort();
    for (final node in nodes) {
      if (!_indexes.containsKey(node)) {
        _visit(node);
      }
    }

    _cycles.sort((left, right) => left.first.compareTo(right.first));

    return _cycles;
  }

  void _visit(String node) {
    _indexes[node] = _nextIndex;
    _lowLinks[node] = _nextIndex;
    _nextIndex += 1;
    _stack.add(node);
    _onStack.add(node);

    final edges = (_graph[node] ?? const <String>{}).toList()..sort();
    for (final target in edges) {
      if (!_indexes.containsKey(target)) {
        _visit(target);
        _lowLinks[node] = _min(_lowLinks[node]!, _lowLinks[target]!);
      } else if (_onStack.contains(target)) {
        _lowLinks[node] = _min(_lowLinks[node]!, _indexes[target]!);
      }
    }

    if (_lowLinks[node] == _indexes[node]) {
      _recordComponent(node);
    }
  }

  void _recordComponent(String root) {
    final component = <String>[];
    while (true) {
      final node = _stack.removeLast();
      _onStack.remove(node);
      component.add(node);
      if (node == root) {
        break;
      }
    }
    component.sort();
    if (component.length > 1 ||
        _graph[component.single]?.contains(root) == true) {
      _cycles.add(_cyclePathForComponent(component));
    }
  }

  List<String> _cyclePathForComponent(List<String> component) {
    final sortedComponent = component.toList()..sort();
    if (sortedComponent.length == 1) {
      return [sortedComponent.single, sortedComponent.single];
    }

    final componentSet = sortedComponent.toSet();
    for (final start in sortedComponent) {
      final path = _findCyclePath(start: start, component: componentSet);
      if (path != null) {
        return path;
      }
    }

    return [...sortedComponent, sortedComponent.first];
  }

  List<String>? _findCyclePath({
    required String start,
    required Set<String> component,
  }) {
    final search = _CyclePathSearch(start: start, component: component);

    return _findCyclePathFrom(start, search);
  }

  List<String>? _findCyclePathFrom(String node, _CyclePathSearch search) {
    search.visited.add(node);
    search.path.add(node);

    final edges =
        (_graph[node] ?? const <String>{})
            .where(search.component.contains)
            .toList()
          ..sort();
    for (final target in edges) {
      if (target == search.start && search.path.length > 1) {
        return [...search.path, search.start];
      }
      if (!search.visited.contains(target)) {
        final cycle = _findCyclePathFrom(target, search);
        if (cycle != null) {
          return cycle;
        }
      }
    }

    search.path.removeLast();
    search.visited.remove(node);

    return null;
  }
}

final class _CyclePathSearch {
  _CyclePathSearch({required this.start, required this.component});

  final String start;
  final Set<String> component;
  final Set<String> visited = {};
  final List<String> path = [];
}

int _min(int left, int right) => left < right ? left : right;
