import 'dart:io';

import 'package:yaml/yaml.dart';

const benchmarkManifestPath = 'docs/_registry/benchmarks.yaml';

final class BenchmarkManifest {
  const BenchmarkManifest({
    required this.manifestVersion,
    required this.toolSchemaVersion,
    required this.releaseContour,
    required this.profiles,
    required this.budgetClasses,
    required this.memoryScopes,
    required this.cases,
    required this.postBaselineRegressionCaps,
    required this.bootstrapLegacyEquivalence,
  });

  final String manifestVersion;
  final int toolSchemaVersion;
  final BenchmarkReleaseContour releaseContour;
  final List<BenchmarkProfile> profiles;
  final List<BenchmarkBudgetClass> budgetClasses;
  final List<BenchmarkMemoryScope> memoryScopes;
  final List<BenchmarkCase> cases;
  final Map<String, num> postBaselineRegressionCaps;
  final Map<String, num> bootstrapLegacyEquivalence;

  Map<String, BenchmarkProfile> get profilesById => {
    for (final profile in profiles) profile.id: profile,
  };

  Map<String, BenchmarkCase> get casesById => {
    for (final benchmarkCase in cases) benchmarkCase.id: benchmarkCase,
  };

  static BenchmarkManifest load({String path = benchmarkManifestPath}) {
    return parse(File(path).readAsStringSync(), source: path);
  }

  static BenchmarkManifest parse(
    String yamlText, {
    String source = 'manifest',
  }) {
    final raw = loadYaml(yamlText);
    if (raw is! YamlMap) {
      throw const FormatException('benchmark manifest must be a YAML map');
    }
    return _BenchmarkManifestParser(raw, source).parse();
  }
}

final class BenchmarkReleaseContour {
  const BenchmarkReleaseContour({
    required this.runnerLabel,
    required this.osName,
    required this.osVersion,
    required this.flutterChannel,
    required this.flutterVersion,
  });

  final String runnerLabel;
  final String osName;
  final String osVersion;
  final String flutterChannel;
  final String flutterVersion;
}

final class BenchmarkProfile {
  const BenchmarkProfile({
    required this.id,
    required this.warmups,
    required this.repetitions,
    required this.iterations,
    required this.minimumMeasuredMs,
    required this.minimumSamples,
    required this.timingClaims,
    required this.scaleSelection,
  });

  final String id;
  final int warmups;
  final int repetitions;
  final int? iterations;
  final int minimumMeasuredMs;
  final int minimumSamples;
  final bool timingClaims;
  final String scaleSelection;
}

final class BenchmarkBudgetClass {
  const BenchmarkBudgetClass({required this.id, required this.absoluteCaps});

  final String id;
  final Map<String, Object?> absoluteCaps;
}

final class BenchmarkMemoryScope {
  const BenchmarkMemoryScope({required this.id, required this.caps});

  final String id;
  final Map<String, Object?> caps;
}

final class BenchmarkCase {
  const BenchmarkCase({
    required this.id,
    required this.classification,
    required this.budgetClasses,
    required this.memoryScope,
    required this.docsMetricsLabel,
    required this.requiredMetrics,
    required this.exactInvariants,
    required this.scales,
  });

  final String id;
  final String classification;
  final List<String> budgetClasses;
  final String memoryScope;
  final String docsMetricsLabel;
  final List<String> requiredMetrics;
  final List<BenchmarkExactInvariant> exactInvariants;
  final List<BenchmarkScale> scales;

  String get docsScaleLabel {
    final labels = scales.map((scale) => scale.label).toList();
    if (labels.length == 1) {
      return labels.single;
    }
    final tokens = [for (final label in labels) label.split(' ')];
    if (tokens.every((parts) => parts.length >= 3) &&
        tokens.map((parts) => parts.first).toSet().length == 1 &&
        tokens.map((parts) => parts.last).toSet().length == 1) {
      final first = tokens.first.first;
      final last = tokens.first.last;
      final middles = [
        for (final parts in tokens)
          parts.skip(1).take(parts.length - 2).join(' '),
      ];
      if (middles.every((middle) => middle.isNotEmpty)) {
        return '$first ${middles.join('/')} $last';
      }
    }
    return labels.join('/');
  }
}

final class BenchmarkScale {
  const BenchmarkScale({
    required this.id,
    required this.label,
    required this.profiles,
  });

  final String id;
  final String label;
  final List<String> profiles;
}

final class BenchmarkExactInvariant {
  const BenchmarkExactInvariant({
    required this.name,
    required this.metric,
    required this.expected,
    required this.max,
  });

  final String name;
  final String metric;
  final Object? expected;
  final num? max;
}

final class _BenchmarkManifestParser {
  _BenchmarkManifestParser(this.root, this.source);

  static const _classifications = {'equivalent_legacy', 'new_only'};

  final YamlMap root;
  final String source;

  BenchmarkManifest parse() {
    final profiles = _profiles();
    final profileIds = profiles.map((profile) => profile.id).toSet();
    final budgetClasses = _budgetClasses();
    final budgetClassIds = budgetClasses.map((budget) => budget.id).toSet();
    final memoryScopes = _memoryScopes();
    final memoryScopeIds = memoryScopes.map((scope) => scope.id).toSet();
    final cases = _cases(
      profileIds: profileIds,
      budgetClassIds: budgetClassIds,
      memoryScopeIds: memoryScopeIds,
    );

    return BenchmarkManifest(
      manifestVersion: _string(root, 'manifest_version', source),
      toolSchemaVersion: _int(root, 'tool_schema_version', source),
      releaseContour: _releaseContour(),
      profiles: profiles,
      budgetClasses: budgetClasses,
      memoryScopes: memoryScopes,
      cases: cases,
      postBaselineRegressionCaps: _numberMap(
        root,
        'post_baseline_regression_caps',
        source,
      ),
      bootstrapLegacyEquivalence: _numberMap(
        root,
        'bootstrap_legacy_equivalence',
        source,
      ),
    );
  }

  BenchmarkReleaseContour _releaseContour() {
    final contour = _map(root, 'release_contour', source);
    final releaseContour = BenchmarkReleaseContour(
      runnerLabel: _string(contour, 'runner_label', 'release_contour'),
      osName: _string(contour, 'os_name', 'release_contour'),
      osVersion: _string(contour, 'os_version', 'release_contour'),
      flutterChannel: _string(contour, 'flutter_channel', 'release_contour'),
      flutterVersion: _string(contour, 'flutter_version', 'release_contour'),
    );
    return releaseContour;
  }

  List<BenchmarkProfile> _profiles() {
    final profiles = <BenchmarkProfile>[];
    final seen = <String>{};

    for (final entry in _mapList(root, 'profiles', source)) {
      final id = _string(entry, 'id', 'profile');
      if (!seen.add(id)) {
        _fail('duplicate profile id $id');
      }
      profiles.add(
        BenchmarkProfile(
          id: id,
          warmups: _int(entry, 'warmups', 'profile $id'),
          repetitions: _int(entry, 'repetitions', 'profile $id'),
          iterations: _optionalInt(entry, 'iterations', 'profile $id'),
          minimumMeasuredMs:
              _optionalInt(entry, 'minimum_measured_ms', 'profile $id') ?? 0,
          minimumSamples:
              _optionalInt(entry, 'minimum_samples', 'profile $id') ?? 0,
          timingClaims: _bool(entry, 'timing_claims', 'profile $id'),
          scaleSelection: _string(entry, 'scale_selection', 'profile $id'),
        ),
      );
    }

    return profiles;
  }

  List<BenchmarkBudgetClass> _budgetClasses() {
    final classes = <BenchmarkBudgetClass>[];
    final seen = <String>{};
    for (final entry in _mapList(root, 'budget_classes', source)) {
      final id = _string(entry, 'id', 'budget class');
      if (!seen.add(id)) {
        _fail('duplicate budget class id $id');
      }
      classes.add(
        BenchmarkBudgetClass(
          id: id,
          absoluteCaps: _objectMap(entry, 'absolute_caps', 'budget class $id'),
        ),
      );
    }
    return classes;
  }

  List<BenchmarkMemoryScope> _memoryScopes() {
    final scopes = <BenchmarkMemoryScope>[];
    final seen = <String>{};
    for (final entry in _mapList(root, 'memory_scopes', source)) {
      final id = _string(entry, 'id', 'memory scope');
      if (!seen.add(id)) {
        _fail('duplicate memory scope id $id');
      }
      final caps = {
        for (final mapEntry in entry.entries)
          if (mapEntry.key != 'id')
            mapEntry.key.toString(): _plainYamlValue(mapEntry.value),
      };
      if (caps.isEmpty) {
        _fail('memory scope $id must declare caps');
      }
      scopes.add(BenchmarkMemoryScope(id: id, caps: caps));
    }
    return scopes;
  }

  List<BenchmarkCase> _cases({
    required Set<String> profileIds,
    required Set<String> budgetClassIds,
    required Set<String> memoryScopeIds,
  }) {
    final cases = <BenchmarkCase>[];
    final seen = <String>{};

    for (final entry in _mapList(root, 'cases', source)) {
      final id = _string(entry, 'id', 'benchmark case');
      if (!seen.add(id)) {
        _fail('duplicate benchmark case id $id');
      }
      final classification = _string(entry, 'classification', id);
      if (!_classifications.contains(classification)) {
        _fail('$id has unsupported classification $classification');
      }
      final budgetClasses = _stringList(entry, 'budget_classes', id);
      if (budgetClasses.isEmpty) {
        _fail('$id must declare budget classes');
      }
      _requireKnownValues(budgetClasses, budgetClassIds, '$id budget_classes');
      final memoryScope = _string(entry, 'memory_scope', id);
      if (!memoryScopeIds.contains(memoryScope)) {
        _fail('$id references unknown memory scope $memoryScope');
      }
      final requiredMetrics = _stringList(entry, 'required_metrics', id);
      if (requiredMetrics.isEmpty) {
        _fail('$id must declare required metrics');
      }
      final exactInvariants = _exactInvariants(entry, id);
      if (exactInvariants.isNotEmpty &&
          !budgetClasses.contains('exact_invariant')) {
        _fail(
          '$id must use exact_invariant when exact invariants are declared',
        );
      }
      for (final invariant in exactInvariants) {
        if (!requiredMetrics.contains(invariant.metric)) {
          _fail('$id exact invariant ${invariant.name} uses unknown metric');
        }
      }
      final scales = _scales(entry, id, profileIds);
      cases.add(
        BenchmarkCase(
          id: id,
          classification: classification,
          budgetClasses: budgetClasses,
          memoryScope: memoryScope,
          docsMetricsLabel: _string(entry, 'docs_metrics_label', id),
          requiredMetrics: requiredMetrics,
          exactInvariants: exactInvariants,
          scales: scales,
        ),
      );
    }

    return cases;
  }

  List<BenchmarkExactInvariant> _exactInvariants(YamlMap entry, String owner) {
    final invariants = <BenchmarkExactInvariant>[];
    final seen = <String>{};
    for (final invariant in _mapList(entry, 'exact_invariants', owner)) {
      final name = _string(invariant, 'name', '$owner exact invariant');
      final metric = _string(
        invariant,
        'metric',
        '$owner exact invariant $name',
      );
      if (!seen.add(name)) {
        _fail('$owner has duplicate exact invariant $name');
      }
      invariants.add(
        BenchmarkExactInvariant(
          name: name,
          metric: metric,
          expected: invariant['expected'],
          max: _optionalNumber(
            invariant,
            'max',
            '$owner exact invariant $name',
          ),
        ),
      );
    }
    return invariants;
  }

  List<BenchmarkScale> _scales(
    YamlMap entry,
    String owner,
    Set<String> profileIds,
  ) {
    final scales = <BenchmarkScale>[];
    final seen = <String>{};
    var smokeScaleCount = 0;
    for (final scale in _mapList(entry, 'scales', owner)) {
      final id = _string(scale, 'id', '$owner scale');
      if (!seen.add(id)) {
        _fail('$owner has duplicate scale $id');
      }
      final profiles = _stringList(scale, 'profiles', '$owner scale $id');
      _requireKnownValues(profiles, profileIds, '$owner scale $id profiles');
      if (!profiles.contains('dry_run')) {
        _fail('$owner scale $id must belong to dry_run');
      }
      if (!profiles.contains('release')) {
        _fail('$owner scale $id must belong to release');
      }
      if (profiles.contains('smoke')) {
        smokeScaleCount++;
      }
      scales.add(
        BenchmarkScale(
          id: id,
          label: _string(scale, 'label', '$owner scale $id'),
          profiles: profiles,
        ),
      );
    }
    if (scales.isEmpty) {
      _fail('$owner must declare scales');
    }
    if (smokeScaleCount == 0) {
      _fail('$owner must have at least one smoke scale');
    }
    return scales;
  }

  Never _fail(String message) {
    throw FormatException('$source: $message');
  }

  void _requireKnownValues(
    List<String> actual,
    Set<String> expected,
    String owner,
  ) {
    for (final value in actual) {
      if (!expected.contains(value)) {
        _fail('$owner references unknown value $value');
      }
    }
  }
}

String _string(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('$owner must have non-empty string field $field');
}

int _int(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value is int) {
    return value;
  }
  throw FormatException('$owner must have integer field $field');
}

int? _optionalInt(YamlMap map, String field, String owner) {
  if (!map.containsKey(field)) {
    return null;
  }
  return _int(map, field, owner);
}

num? _optionalNumber(YamlMap map, String field, String owner) {
  if (!map.containsKey(field)) {
    return null;
  }
  final value = map[field];
  if (value is num) {
    return value;
  }
  throw FormatException('$owner must have number field $field');
}

bool _bool(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value is bool) {
    return value;
  }
  throw FormatException('$owner must have boolean field $field');
}

List<String> _stringList(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value is! YamlList) {
    throw FormatException('$owner must have list field $field');
  }
  final items = <String>[];
  final seen = <String>{};
  for (final item in value) {
    if (item is! String || item.isEmpty) {
      throw FormatException('$owner field $field must contain strings');
    }
    if (!seen.add(item)) {
      throw FormatException('$owner field $field contains duplicate $item');
    }
    items.add(item);
  }
  return items;
}

List<YamlMap> _mapList(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value is! YamlList) {
    throw FormatException('$owner must have list field $field');
  }
  final items = <YamlMap>[];
  for (final item in value) {
    if (item is! YamlMap) {
      throw FormatException('$owner field $field must contain maps');
    }
    items.add(item);
  }
  return items;
}

YamlMap _map(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value is YamlMap) {
    return value;
  }
  throw FormatException('$owner must have map field $field');
}

Map<String, Object?> _objectMap(YamlMap map, String field, String owner) {
  final value = map[field];
  if (value is! YamlMap) {
    throw FormatException('$owner must have map field $field');
  }
  return {
    for (final entry in value.entries)
      entry.key.toString(): _plainYamlValue(entry.value),
  };
}

Map<String, num> _numberMap(YamlMap map, String field, String owner) {
  final raw = _objectMap(map, field, owner);
  final values = <String, num>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is! num) {
      throw FormatException(
        '$owner field $field.${entry.key} must be a number',
      );
    }
    values[entry.key] = value;
  }
  return values;
}

Object? _plainYamlValue(Object? value) {
  return switch (value) {
    YamlMap() => {
      for (final entry in value.entries)
        entry.key.toString(): _plainYamlValue(entry.value),
    },
    YamlList() => [for (final item in value) _plainYamlValue(item)],
    _ => value,
  };
}
