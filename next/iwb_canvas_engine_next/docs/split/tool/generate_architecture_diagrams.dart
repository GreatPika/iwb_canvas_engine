import 'dart:io';

import 'package:yaml/yaml.dart';

void main(List<String> args) {
  final checkOnly = args.contains('--check');
  final manifest = _loadManifest();
  final errors = _validateArchitectureGraph(manifest);
  final diagrams = errors.isEmpty
      ? _renderDiagrams(manifest)
      : <String, String>{};

  for (final entry in diagrams.entries) {
    final file = File(entry.key);
    if (checkOnly) {
      if (!file.existsSync()) {
        errors.add('${entry.key} is missing');
        continue;
      }
      final actual = file.readAsStringSync();
      if (actual != entry.value) {
        errors.add('${entry.key} is stale');
      }
    } else {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(entry.value);
    }
  }

  if (errors.isNotEmpty) {
    stderr.writeln('Architecture diagram check failed:');
    for (final error in errors) {
      stderr.writeln('- $error');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln(
    checkOnly
        ? 'Architecture diagram check passed.'
        : 'Architecture diagrams generated.',
  );
}

YamlMap _loadManifest() {
  final file = File('docs/split/architecture/architecture.yaml');
  if (!file.existsSync()) {
    stderr.writeln('Missing docs/split/architecture/architecture.yaml');
    exitCode = 1;
    return loadYaml('{}') as YamlMap;
  }
  final value = loadYaml(file.readAsStringSync());
  if (value is YamlMap) {
    return value;
  }
  stderr.writeln('Architecture manifest must be a YAML map.');
  exitCode = 1;
  return loadYaml('{}') as YamlMap;
}

Map<String, String> _renderDiagrams(YamlMap manifest) {
  final targets = _list(manifest, 'diagram_targets');
  final rendered = <String, String>{};
  for (final target in targets) {
    final id = _string(target, 'id');
    final path = _string(target, 'planned_path');
    rendered[path] = switch (id) {
      'c4_context' => _renderContext(manifest),
      'c4_container' => _renderContainer(manifest),
      'c4_component_runtime' => _renderRuntimeComponents(manifest),
      _ => throw StateError('Unsupported generated diagram target $id'),
    };
  }
  return rendered;
}

String _renderContext(YamlMap manifest) {
  final actors = _list(manifest, 'external_actors');
  final owners = _list(manifest, 'runtime_owners');
  final dependencies = _list(manifest, 'allowed_dependencies');
  final publicApi = _ownerById(owners, 'PublicAPI');
  final runtimeRoot = _ownerById(owners, 'RuntimeRoot');
  final buffer = StringBuffer()
    ..writeln('C4Context')
    ..writeln('title iwb_canvas_engine_next system context')
    ..writeln();

  for (final actor in actors) {
    buffer.writeln(
      'System_Ext(${_id(actor)}, "${_label(actor)}", "${_summary(actor)}")',
    );
  }
  buffer
    ..writeln('System_Boundary(next_engine, "iwb_canvas_engine_next") {')
    ..writeln(
      '  System(${_id(publicApi)}, "${_label(publicApi)}", '
      '"${_summary(publicApi)}")',
    )
    ..writeln(
      '  System(${_id(runtimeRoot)}, "${_label(runtimeRoot)}", '
      '"${_summary(runtimeRoot)}")',
    )
    ..writeln('}');

  for (final dependency in dependencies) {
    final from = _string(dependency, 'from');
    final to = _string(dependency, 'to');
    final sourceInContext =
        _hasOwner(actors, from) || from == 'PublicAPI' || from == 'RuntimeRoot';
    final targetInContext =
        _hasOwner(actors, to) || to == 'PublicAPI' || to == 'RuntimeRoot';
    if (sourceInContext && targetInContext) {
      buffer.writeln(
        'Rel($from, $to, "${_optionalString(dependency, 'context_label', 'uses')}")',
      );
    }
  }

  return '${buffer.toString().trimRight()}\n';
}

String _renderContainer(YamlMap manifest) {
  final owners = _list(manifest, 'runtime_owners');
  final dependencies = _list(manifest, 'allowed_dependencies');
  final buffer = StringBuffer()
    ..writeln('C4Container')
    ..writeln('title iwb_canvas_engine_next container view')
    ..writeln('Person(Application, "Application", "Owns domain state")')
    ..writeln('System_Boundary(next_engine, "iwb_canvas_engine_next") {');

  for (final owner in owners) {
    buffer.writeln(
      '  Container(${_id(owner)}, "${_label(owner)}", '
      '"${_path(owner)}", "${_summary(owner)}")',
    );
  }

  buffer.writeln('}');
  for (final dependency in dependencies) {
    final from = _string(dependency, 'from');
    final to = _string(dependency, 'to');
    if (_hasOwner(owners, from) && _hasOwner(owners, to) ||
        from == 'Application' && _hasOwner(owners, to)) {
      buffer.writeln('Rel($from, $to, "uses")');
    }
  }

  return '${buffer.toString().trimRight()}\n';
}

String _renderRuntimeComponents(YamlMap manifest) {
  final owners = _list(manifest, 'runtime_owners');
  final dependencies = _list(manifest, 'allowed_dependencies');
  final publicApi = _ownerById(owners, 'PublicAPI');
  final runtimeRoot = _ownerById(owners, 'RuntimeRoot');
  final runtimeComponents = [
    for (final owner in owners)
      if (_id(owner) != 'PublicAPI' && _id(owner) != 'RuntimeRoot') owner,
  ];
  final buffer = StringBuffer()
    ..writeln('C4Component')
    ..writeln('title Runtime owner component view')
    ..writeln(
      'Container(${_id(publicApi)}, "${_label(publicApi)}", '
      '"${_path(publicApi)}", "${_summary(publicApi)}")',
    )
    ..writeln(
      'Container(${_id(runtimeRoot)}, "${_label(runtimeRoot)}", '
      '"${_path(runtimeRoot)}", "${_summary(runtimeRoot)}")',
    )
    ..writeln(
      'Container_Boundary(runtime_components, "RuntimeRoot internals") {',
    );

  for (final owner in runtimeComponents) {
    buffer.writeln(
      '  Component(${_id(owner)}, "${_label(owner)}", '
      '"${_path(owner)}", "${_summary(owner)}")',
    );
  }

  buffer.writeln('}');
  for (final dependency in dependencies) {
    final from = _string(dependency, 'from');
    final to = _string(dependency, 'to');
    if (!_hasOwner(owners, from) || !_hasOwner(owners, to)) {
      continue;
    }
    if (from == 'PublicAPI' && to == 'RuntimeRoot') {
      buffer.writeln('Rel($from, $to, "creates and drives")');
    } else if (from == 'RuntimeRoot' && _hasOwner(runtimeComponents, to)) {
      buffer.writeln('Rel($from, $to, "coordinates")');
    } else if (_hasOwner(runtimeComponents, from) &&
        _hasOwner(runtimeComponents, to)) {
      buffer.writeln('Rel($from, $to, "allowed")');
    }
  }

  return '${buffer.toString().trimRight()}\n';
}

List<String> _validateArchitectureGraph(YamlMap manifest) {
  final errors = <String>[];
  final actors = _list(manifest, 'external_actors');
  final owners = _list(manifest, 'runtime_owners');
  final allowed = _list(manifest, 'allowed_dependencies');
  final forbidden = _list(manifest, 'forbidden_dependencies');
  final knownIds = {
    for (final actor in actors) _id(actor),
    for (final owner in owners) _id(owner),
  };
  final runtimeIds = {for (final owner in owners) _id(owner)};
  final allowedPairs = <String>{};
  final forbiddenPairs = <String>{};

  for (final dependency in allowed) {
    final from = _string(dependency, 'from');
    final to = _string(dependency, 'to');
    final pair = '$from->$to';
    if (from == to) {
      errors.add('allowed dependency $pair is a self-dependency');
    }
    if (!knownIds.contains(from)) {
      errors.add('allowed dependency $pair uses unknown source $from');
    }
    if (!knownIds.contains(to)) {
      errors.add('allowed dependency $pair uses unknown target $to');
    }
    if (!allowedPairs.add(pair)) {
      errors.add('allowed dependency $pair is duplicated');
    }
  }

  for (final dependency in forbidden) {
    final from = _string(dependency, 'from');
    final to = _string(dependency, 'to');
    final pair = '$from->$to';
    if (from == to) {
      errors.add('forbidden dependency $pair is a self-dependency');
    }
    if (!knownIds.contains(from) && !from.contains('/')) {
      errors.add('forbidden dependency $pair uses unknown source $from');
    }
    if (!knownIds.contains(to) && !to.contains('/')) {
      errors.add('forbidden dependency $pair uses unknown target $to');
    }
    if (!forbiddenPairs.add(pair)) {
      errors.add('forbidden dependency $pair is duplicated');
    }
    if (allowedPairs.contains(pair)) {
      errors.add('dependency $pair is both allowed and forbidden');
    }
  }

  for (final actor in actors) {
    final id = _id(actor);
    final connected =
        allowedPairs.any(
          (pair) => pair.startsWith('$id->') || pair.endsWith('->$id'),
        ) ||
        forbiddenPairs.any(
          (pair) => pair.startsWith('$id->') || pair.endsWith('->$id'),
        );
    if (!connected) {
      errors.add('external actor $id is rendered without any relationship');
    }
  }

  final runtimeGraph = {for (final id in runtimeIds) id: <String>[]};
  for (final dependency in allowed) {
    final from = _string(dependency, 'from');
    final to = _string(dependency, 'to');
    if (runtimeIds.contains(from) && runtimeIds.contains(to)) {
      runtimeGraph[from]?.add(to);
    }
  }

  final cycle = _findCycle(runtimeGraph);
  if (cycle.isNotEmpty) {
    errors.add('runtime owner dependency cycle: ${cycle.join(' -> ')}');
  }

  return errors;
}

List<String> _findCycle(Map<String, List<String>> graph) {
  final states = <String, _VisitState>{};
  for (final node in graph.keys) {
    states[node] = _VisitState.unvisited;
  }

  for (final node in graph.keys) {
    if (states[node] == _VisitState.unvisited) {
      final cycle = _visit(node, graph, states, <String>[]);
      if (cycle.isNotEmpty) {
        return cycle;
      }
    }
  }
  return const [];
}

List<String> _visit(
  String node,
  Map<String, List<String>> graph,
  Map<String, _VisitState> states,
  List<String> path,
) {
  states[node] = _VisitState.visiting;
  final nextPath = [...path, node];

  for (final next in graph[node] ?? const <String>[]) {
    final state = states[next] ?? _VisitState.visited;
    if (state == _VisitState.visiting) {
      final cycleStart = nextPath.indexOf(next);
      if (cycleStart < 0) {
        return [...nextPath, next];
      }
      return [...nextPath.sublist(cycleStart), next];
    }
    if (state == _VisitState.unvisited) {
      final cycle = _visit(next, graph, states, nextPath);
      if (cycle.isNotEmpty) {
        return cycle;
      }
    }
  }

  states[node] = _VisitState.visited;
  return const [];
}

List<YamlMap> _list(YamlMap map, String field) {
  final value = map[field];
  if (value is! YamlList) {
    throw StateError('Missing YAML list field $field');
  }
  return [
    for (final item in value)
      if (item is YamlMap)
        item
      else
        throw StateError('$field entries must map'),
  ];
}

String _id(YamlMap map) => _string(map, 'id');

String _label(YamlMap map) => _escape(_string(map, 'label'));

String _path(YamlMap map) => _escape(_string(map, 'package_path'));

String _summary(YamlMap map) => _escape(_string(map, 'summary'));

String _string(YamlMap map, String field) {
  final value = map[field];
  if (value is String) {
    return value;
  }
  throw StateError('Missing string field $field');
}

String _optionalString(YamlMap map, String field, String fallback) {
  final value = map[field];
  if (value == null) {
    return fallback;
  }
  if (value is String) {
    return _escape(value);
  }
  throw StateError('$field must be a string when provided');
}

bool _hasOwner(List<YamlMap> owners, String id) =>
    owners.any((owner) => _id(owner) == id);

YamlMap _ownerById(List<YamlMap> owners, String id) =>
    owners.firstWhere((owner) => _id(owner) == id);

String _escape(String value) => value.replaceAll('"', r'\"');

enum _VisitState { unvisited, visiting, visited }
