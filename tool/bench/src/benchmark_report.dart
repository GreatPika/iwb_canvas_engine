import 'dart:convert';

import 'benchmark_manifest.dart';

final class BenchmarkReport {
  const BenchmarkReport({
    required this.schemaVersion,
    required this.manifestVersion,
    required this.manifestFingerprint,
    required this.profile,
    required this.runtime,
    required this.cases,
  });

  final int schemaVersion;
  final String manifestVersion;
  final String manifestFingerprint;
  final BenchmarkProfileReport profile;
  final BenchmarkRuntimeReport runtime;
  final List<BenchmarkCaseReport> cases;

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'manifestVersion': manifestVersion,
      'manifestFingerprint': manifestFingerprint,
      'profile': profile.toJson(),
      'runtime': runtime.toJson(),
      'caseCount': cases.length,
      'cases': [for (final benchmarkCase in cases) benchmarkCase.toJson()],
    };
  }
}

final class BenchmarkProfileReport {
  const BenchmarkProfileReport({
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

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'warmups': warmups,
      'repetitions': repetitions,
      'iterations': iterations,
      'minimumMeasuredMs': minimumMeasuredMs,
      'minimumSamples': minimumSamples,
      'timingClaims': timingClaims,
      'scaleSelection': scaleSelection,
    };
  }
}

final class BenchmarkRuntimeReport {
  const BenchmarkRuntimeReport({
    required this.runnerLabel,
    required this.osName,
    required this.osVersion,
    required this.dartVersion,
    required this.flutterChannel,
    required this.flutterVersion,
    required this.releaseContour,
    required this.runtimeMode,
    required this.assertionsEnabled,
    required this.debugInvariantMode,
  });

  final String runnerLabel;
  final String osName;
  final String osVersion;
  final String dartVersion;
  final String flutterChannel;
  final String flutterVersion;
  final BenchmarkReleaseContourReport releaseContour;
  final String runtimeMode;
  final bool assertionsEnabled;
  final bool debugInvariantMode;

  Map<String, Object?> toJson() {
    return {
      'runnerLabel': runnerLabel,
      'osName': osName,
      'osVersion': osVersion,
      'dartVersion': dartVersion,
      'flutterChannel': flutterChannel,
      'flutterVersion': flutterVersion,
      'releaseContour': releaseContour.toJson(),
      'runtimeMode': runtimeMode,
      'assertionsEnabled': assertionsEnabled,
      'debugInvariantMode': debugInvariantMode,
    };
  }
}

final class BenchmarkReleaseContourReport {
  const BenchmarkReleaseContourReport({
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

  Map<String, Object?> toJson() {
    return {
      'runnerLabel': runnerLabel,
      'osName': osName,
      'osVersion': osVersion,
      'flutterChannel': flutterChannel,
      'flutterVersion': flutterVersion,
    };
  }
}

final class BenchmarkCaseReport {
  const BenchmarkCaseReport({
    required this.id,
    required this.classification,
    required this.scale,
    required this.scaleLabel,
    required this.budgetClasses,
    required this.memoryScope,
    required this.warmups,
    required this.repetitions,
    required this.iterations,
    required this.timingClaims,
    required this.metrics,
    required this.exactInvariants,
  });

  final String id;
  final String classification;
  final String scale;
  final String scaleLabel;
  final List<String> budgetClasses;
  final String memoryScope;
  final int warmups;
  final int repetitions;
  final int iterations;
  final bool timingClaims;
  final Map<String, Object?> metrics;
  final Map<String, BenchmarkInvariantReport> exactInvariants;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'classification': classification,
      'scale': scale,
      'scaleLabel': scaleLabel,
      'budgetClasses': budgetClasses,
      'memoryScope': memoryScope,
      'warmups': warmups,
      'repetitions': repetitions,
      'iterations': iterations,
      'timingClaims': timingClaims,
      'metrics': metrics,
      'exactInvariants': {
        for (final entry in exactInvariants.entries)
          entry.key: entry.value.toJson(),
      },
    };
  }
}

final class BenchmarkInvariantReport {
  const BenchmarkInvariantReport({
    required this.metric,
    required this.actual,
    required this.expected,
    required this.max,
    required this.passed,
  });

  final String metric;
  final Object? actual;
  final Object? expected;
  final num? max;
  final bool passed;

  Map<String, Object?> toJson() {
    return {
      'metric': metric,
      'actual': actual,
      'expected': expected,
      'max': max,
      'passed': passed,
    };
  }
}

String benchmarkManifestFingerprint(BenchmarkManifest manifest) {
  final encoded = jsonEncode(_benchmarkManifestProjection(manifest));
  var hash = 0x811c9dc5;
  for (final codeUnit in encoded.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

// The fingerprint projection mirrors the full policy surface; keeping every
// manifest-owned field here prevents partial hashes from missing drift.
// ignore: halstead-volume, source-lines-of-code
Map<String, Object?> _benchmarkManifestProjection(BenchmarkManifest manifest) {
  return {
    'manifest_version': manifest.manifestVersion,
    'tool_schema_version': manifest.toolSchemaVersion,
    'release_contour': {
      'runner_label': manifest.releaseContour.runnerLabel,
      'os_name': manifest.releaseContour.osName,
      'os_version': manifest.releaseContour.osVersion,
      'flutter_channel': manifest.releaseContour.flutterChannel,
      'flutter_version': manifest.releaseContour.flutterVersion,
    },
    'profiles': [
      for (final profile in manifest.profiles)
        {
          'id': profile.id,
          'warmups': profile.warmups,
          'repetitions': profile.repetitions,
          'iterations': profile.iterations,
          'minimum_measured_ms': profile.minimumMeasuredMs,
          'minimum_samples': profile.minimumSamples,
          'timing_claims': profile.timingClaims,
          'scale_selection': profile.scaleSelection,
        },
    ],
    'budget_classes': [
      for (final budgetClass in manifest.budgetClasses)
        {
          'id': budgetClass.id,
          'absolute_caps': _sortedJsonMap(budgetClass.absoluteCaps),
        },
    ],
    'memory_scopes': [
      for (final scope in manifest.memoryScopes)
        {'id': scope.id, 'caps': _sortedJsonMap(scope.caps)},
    ],
    'post_baseline_regression_caps': _sortedJsonMap(
      manifest.postBaselineRegressionCaps,
    ),
    'bootstrap_legacy_equivalence': _sortedJsonMap(
      manifest.bootstrapLegacyEquivalence,
    ),
    'cases': [
      for (final benchmarkCase in manifest.cases)
        {
          'id': benchmarkCase.id,
          'classification': benchmarkCase.classification,
          'budget_classes': benchmarkCase.budgetClasses,
          'memory_scope': benchmarkCase.memoryScope,
          'docs_metrics_label': benchmarkCase.docsMetricsLabel,
          'required_metrics': benchmarkCase.requiredMetrics,
          'exact_invariants': [
            for (final invariant in benchmarkCase.exactInvariants)
              {
                'name': invariant.name,
                'metric': invariant.metric,
                'expected': invariant.expected,
                'max': invariant.max,
              },
          ],
          'scales': [
            for (final scale in benchmarkCase.scales)
              {
                'id': scale.id,
                'label': scale.label,
                'profiles': scale.profiles,
              },
          ],
        },
    ],
  };
}

Map<String, Object?> _sortedJsonMap(Map<String, Object?> values) {
  final keys = values.keys.toList()..sort();
  return {for (final key in keys) key: values[key]};
}
