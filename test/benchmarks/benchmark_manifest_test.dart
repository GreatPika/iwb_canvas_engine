import 'dart:io';

import 'package:test/test.dart';

import '../../tool/bench/src/benchmark_manifest.dart';

// Manifest tests keep the full policy projection in one fixture-backed suite so
// case inventory, profile parameters, and numeric gates drift together.
// ignore: halstead-volume, maintainability-index, source-lines-of-code
void main() {
  group('benchmark manifest schema', () {
    test('loads the benchmark source of truth with the required inventory', () {
      final manifest = BenchmarkManifest.load();

      expect(manifest.manifestVersion, benchmarkManifestVersion);
      expect(manifest.toolSchemaVersion, benchmarkToolSchemaVersion);
      expect(manifest.cases, hasLength(30));
      expect(manifest.profiles.map((profile) => profile.id), [
        'dry_run',
        'smoke',
        'release',
      ]);
      expect(manifest.casesById.keys, _requiredCaseIds);
      expect(
        manifest.casesById['diagnostics.disabled_pointer']!.exactInvariants.map(
          (invariant) => invariant.name,
        ),
        containsAll(['allocation_records_zero', 'allocation_bytes_zero']),
      );
    });

    test('locks profile parameters from the design', () {
      final profiles = BenchmarkManifest.load().profilesById;

      expect(profiles['dry_run']!.iterations, 1);
      expect(profiles['dry_run']!.repetitions, 1);
      expect(profiles['dry_run']!.timingClaims, isFalse);
      expect(profiles['dry_run']!.scaleSelection, 'all_required_scales');
      expect(profiles['smoke']!.warmups, 1);
      expect(profiles['smoke']!.repetitions, 3);
      expect(profiles['smoke']!.minimumMeasuredMs, 500);
      expect(profiles['smoke']!.minimumSamples, 100);
      expect(
        profiles['smoke']!.scaleSelection,
        'smallest_required_scale_preserve_dense',
      );
      expect(profiles['release']!.warmups, 1);
      expect(profiles['release']!.repetitions, 5);
      expect(profiles['release']!.minimumMeasuredMs, 2000);
      expect(profiles['release']!.minimumSamples, 0);
      expect(profiles['release']!.scaleSelection, 'all_required_scales');
    });

    test('locks the selected release contour from the design', () {
      final contour = BenchmarkManifest.load().releaseContour;

      expect(contour.runnerLabel, 'ubuntu-24.04');
      expect(contour.osName, 'Ubuntu');
      expect(contour.osVersion, '24.04');
      expect(contour.flutterChannel, 'stable');
      expect(contour.flutterVersion, '3.44.0');
    });

    test('derives documentation scale labels from manifest scale data', () {
      final manifest = BenchmarkManifest.load();

      expect(
        manifest.casesById['load_document.failure']!.docsScaleLabel,
        'invalid 1k/10k/50k inputs',
      );
      expect(
        manifest.casesById['edit.add_element']!.docsScaleLabel,
        '1k/10k/50k/100k',
      );
    });

    test('locks numeric policy from the design', () {
      final manifest = BenchmarkManifest.load();

      expect(_budgetCapsById(manifest), _expectedBudgetCaps);
      expect(_memoryCapsById(manifest), _expectedMemoryCaps);
      expect(
        manifest.postBaselineRegressionCaps,
        _expectedPostBaselineRegressionCaps,
      );
      expect(
        manifest.firstBaselineReferenceLimits,
        _expectedFirstBaselineReferenceLimits,
      );
    });

    test('locks per-case policy inventory from the design', () {
      final manifest = BenchmarkManifest.load();

      expect(
        _casePolicyFingerprints(manifest),
        _expectedCasePolicyFingerprints,
      );
      expect(
        _caseBoundaryFingerprints(manifest),
        _expectedCaseBoundaryFingerprints,
      );
    });

    test('rejects duplicate case ids', () {
      final error = _parseFailure(
        _manifestText().replaceFirst(
          '  - id: edit.update_visual',
          '  - id: edit.add_element',
        ),
      );

      expect(
        error.message,
        contains('duplicate benchmark case id edit.add_element'),
      );
    });

    test('rejects duplicate scale ids inside a case', () {
      final error = _parseFailure(
        _manifestText().replaceFirst(
          '      - {id: "10k", label: "10k", profiles: [dry_run, release]}',
          '      - {id: "1k", label: "10k", profiles: [dry_run, release]}',
        ),
      );

      expect(
        error.message,
        contains('edit.add_element has duplicate scale 1k'),
      );
    });

    test('rejects missing required metrics', () {
      final error = _parseFailure(
        _manifestText().replaceFirst(
          '    required_metrics: [avg_us, p95_us, max_us, allocation_bytes]',
          '    required_metrics: []',
        ),
      );

      expect(
        error.message,
        contains('edit.add_element must declare required metrics'),
      );
    });

    test('rejects exact invariants without names', () {
      final error = _parseFailure(
        _manifestText().replaceFirst(
          'name: ordinary_paint_plan_invalidations_zero',
          'label: ordinary_paint_plan_invalidations_zero',
        ),
      );

      expect(
        error.message,
        contains('exact invariant must have non-empty string field name'),
      );
    });

    test('rejects invalid baseline policy', () {
      final error = _parseFailure(
        _manifestText().replaceFirst(
          'baseline_policy: reference_comparison',
          'baseline_policy: unsupported_policy',
        ),
      );

      expect(
        error.message,
        contains('unsupported baselinePolicy unsupported_policy'),
      );
    });

    test('rejects retired benchmark vocabulary fields', () {
      final rootError = _parseFailure(
        _manifestText().replaceFirst(
          'first_baseline_reference_limits:',
          'bootstrap_legacy_equivalence:\n'
              '  avg_us_multiplier: 1.35\n'
              'first_baseline_reference_limits:',
        ),
      );
      final caseError = _parseFailure(
        _manifestText().replaceFirst(
          '    baseline_policy: reference_comparison',
          '    baseline_policy: reference_comparison\n'
              '    classification: equivalent_legacy',
        ),
      );

      expect(
        rootError.message,
        contains('retired field bootstrap_legacy_equivalence'),
      );
      expect(caseError.message, contains('retired field classification'));
    });

    test('rejects stale manifest and tool schema versions', () {
      final manifestError = _parseFailure(
        _manifestText().replaceFirst(
          benchmarkManifestVersion,
          'p14_release_readiness_benchmarks_v1',
        ),
      );
      final schemaError = _parseFailure(
        _manifestText().replaceFirst(
          'tool_schema_version: 4',
          'tool_schema_version: 2',
        ),
      );

      expect(manifestError.message, contains('manifest_version must be'));
      expect(schemaError.message, contains('tool_schema_version must be'));
    });

    test('rejects missing measurement boundary fields', () {
      final error = _parseFailure(
        _manifestText().replaceFirst(
          '      timed_scope: action_only',
          '      timing_scope: action_only',
        ),
      );

      expect(
        error.message,
        contains(
          'edit.add_element measurement_boundary must have non-empty string field timed_scope',
        ),
      );
    });

    test('rejects unknown measurement boundary enum values', () {
      final error = _parseFailure(
        _manifestText().replaceFirst(
          '      timed_scope: action_only',
          '      timed_scope: full_run',
        ),
      );

      expect(
        error.message,
        contains(
          'measurement_boundary field timed_scope has unsupported value full_run',
        ),
      );
    });

    test('rejects missing fixture shape', () {
      final error = _parseFailure(
        _manifestText().replaceFirst('    fixture_shape: normal_spread\n', ''),
      );

      expect(
        error.message,
        contains(
          'edit.add_element must have non-empty string field fixture_shape',
        ),
      );
    });

    test('rejects hot cases that opt into lifecycle boundary semantics', () {
      final error = _parseFailure(
        _replaceInCase(
          _manifestText(),
          'edit.add_element',
          '      timed_scope: action_only',
          '      timed_scope: lifecycle',
        ),
      );

      expect(
        error.message,
        contains(
          'edit.add_element measurement boundary must match the selected boundary table',
        ),
      );
    });

    test('rejects dense fixture shape under ordinary spatial query', () {
      final error = _parseFailure(
        _replaceInCase(
          _manifestText(),
          'spatial.query_point',
          '    fixture_shape: normal_spread',
          '    fixture_shape: dense_stress',
        ),
      );

      expect(
        error.message,
        contains(
          'spatial.query_point measurement boundary must match the selected boundary table',
        ),
      );
    });

    test('requires dense spatial fallback policy', () {
      final error = _parseFailure(
        _removeCase(_manifestText(), 'spatial.query_point_dense_stress'),
      );

      expect(
        error.message,
        contains(
          'spatial dense fallback must declare spatial.query_point_dense_stress',
        ),
      );
    });

    test('requires setup diagnostics for prepared fixture scopes', () {
      final error = _parseFailure(
        _manifestText().replaceFirst(
          '      setup_metrics: [setup_us]',
          '      setup_metrics: []',
        ),
      );

      expect(
        error.message,
        contains(
          'edit.add_element prepared fixture setup must declare setup diagnostics',
        ),
      );
    });

    test('requires setup allocation and RSS diagnostics together', () {
      final error = _parseFailure(
        _manifestText().replaceFirst(
          'setup_memory_metrics: [setup_allocation_bytes, setup_rss_delta_bytes]',
          'setup_memory_metrics: [setup_allocation_bytes]',
        ),
      );

      expect(
        error.message,
        contains(
          'edit.add_element prepared fixture setup must declare setup allocation and setup RSS diagnostics',
        ),
      );
    });

    test('rejects non-canonical dry-run spelling', () {
      final error = _parseFailure(
        _manifestText().replaceFirst('id: dry_run', 'id: dry-run'),
      );

      expect(error.message, contains('references unknown value dry_run'));
    });

    test('requires every scale to belong to dry_run and release', () {
      final error = _parseFailure(
        _manifestText().replaceFirst(
          'profiles: [dry_run, smoke, release]',
          'profiles: [smoke, release]',
        ),
      );

      expect(
        error.message,
        contains('edit.add_element scale 1k must belong to dry_run'),
      );
    });

    test(
      'requires exact invariant budget class for invariant-bearing cases',
      () {
        final error = _parseFailure(
          _manifestText().replaceFirst(
            'budget_classes: [hot_input, incremental_edit, exact_invariant]',
            'budget_classes: [hot_input, incremental_edit]',
          ),
        );

        expect(
          error.message,
          contains(
            'must use exact_invariant when exact invariants are declared',
          ),
        );
      },
    );

    test('requires exact invariant metrics to be required metrics', () {
      final error = _parseFailure(
        _manifestText().replaceFirst(
          'metric: selected_count',
          'metric: missing_selected_count',
        ),
      );

      expect(
        error.message,
        contains(
          'exact invariant selected_count_matches_input uses unknown metric',
        ),
      );
    });

    test('rejects release sample fallback drift', () {
      final manifest = BenchmarkManifest.parse(
        _manifestText().replaceFirst(
          '    minimum_samples: 0',
          '    minimum_samples: 100',
        ),
      );

      expect(
        _profilePolicyFingerprint(manifest),
        isNot(_expectedProfilePolicyFingerprint),
      );
    });

    test('rejects smoke scale selection drift', () {
      final manifest = BenchmarkManifest.parse(
        _manifestText().replaceFirst(
          'scale_selection: smallest_required_scale_preserve_dense',
          'scale_selection: all_required_scales',
        ),
      );

      expect(
        _profilePolicyFingerprint(manifest),
        isNot(_expectedProfilePolicyFingerprint),
      );
    });

    test('rejects release contour drift', () {
      final manifest = BenchmarkManifest.parse(
        _manifestText().replaceFirst(
          '  flutter_version: "3.44.0"',
          '  flutter_version: "3.39.0"',
        ),
      );

      expect(
        _releaseContourFingerprint(manifest),
        isNot(_expectedReleaseContourFingerprint),
      );
    });
  });
}

String _manifestText() => File(benchmarkManifestPath).readAsStringSync();

Map<String, Map<String, Object?>> _budgetCapsById(BenchmarkManifest manifest) {
  return {
    for (final budget in manifest.budgetClasses) budget.id: budget.absoluteCaps,
  };
}

Map<String, Map<String, Object?>> _memoryCapsById(BenchmarkManifest manifest) {
  return {for (final scope in manifest.memoryScopes) scope.id: scope.caps};
}

List<String> _casePolicyFingerprints(BenchmarkManifest manifest) {
  return [
    for (final benchmarkCase in manifest.cases)
      [
        benchmarkCase.id,
        benchmarkCase.baselinePolicy,
        benchmarkCase.budgetClasses.join(','),
        benchmarkCase.memoryScope,
        benchmarkCase.requiredMetrics.join(','),
        benchmarkCase.exactInvariants
            .map(
              (invariant) => [
                invariant.name,
                invariant.metric,
                invariant.expected ?? '',
                invariant.max ?? '',
              ].join(':'),
            )
            .join(','),
        [
          for (final scale in benchmarkCase.scales)
            '${scale.id}:${scale.profiles.join(',')}',
        ].join(';'),
      ].join('|'),
  ];
}

List<String> _caseBoundaryFingerprints(BenchmarkManifest manifest) {
  return [
    for (final benchmarkCase in manifest.cases)
      [
        benchmarkCase.id,
        benchmarkCase.measurementBoundary.timedScope,
        benchmarkCase.measurementBoundary.setupScope,
        benchmarkCase.measurementBoundary.teardownScope,
        benchmarkCase.measurementBoundary.primaryTiming,
        benchmarkCase.measurementBoundary.primaryMemory,
        benchmarkCase.measurementBoundary.setupMetrics.join(','),
        benchmarkCase.measurementBoundary.setupMemoryMetrics.join(','),
        benchmarkCase.fixtureShape,
      ].join('|'),
  ];
}

String _profilePolicyFingerprint(BenchmarkManifest manifest) {
  return [
    for (final profile in manifest.profiles)
      [
        profile.id,
        profile.warmups,
        profile.repetitions,
        profile.iterations,
        profile.minimumMeasuredMs,
        profile.minimumSamples,
        profile.timingClaims,
        profile.scaleSelection,
      ].join(':'),
  ].join('|');
}

String _releaseContourFingerprint(BenchmarkManifest manifest) {
  final contour = manifest.releaseContour;
  return [
    contour.runnerLabel,
    contour.osName,
    contour.osVersion,
    contour.flutterChannel,
    contour.flutterVersion,
  ].join('|');
}

FormatException _parseFailure(String text) {
  try {
    BenchmarkManifest.parse(text, source: benchmarkManifestPath);
  } on FormatException catch (error) {
    return error;
  }
  throw StateError('Expected benchmark manifest parsing to fail.');
}

String _removeCase(String text, String caseId) {
  final casePattern = _casePattern(caseId);
  if (!casePattern.hasMatch(text)) {
    throw StateError('Missing manifest case $caseId.');
  }
  return text.replaceFirst(casePattern, '');
}

String _replaceInCase(String text, String caseId, String from, String to) {
  final casePattern = _casePattern(caseId);
  final match = casePattern.firstMatch(text);
  if (match == null) {
    throw StateError('Missing manifest case $caseId.');
  }
  final body = match.group(0);
  if (body == null) {
    throw StateError('Missing manifest case $caseId.');
  }
  if (!body.contains(from)) {
    throw StateError('Manifest case $caseId does not contain "$from".');
  }
  return text.replaceFirst(body, body.replaceFirst(from, to));
}

RegExp _casePattern(String caseId) {
  return RegExp(
    '  - id: ${RegExp.escape(caseId)}\\n[\\s\\S]*?(?=\\n  - id:|\\z)',
  );
}

const _requiredCaseIds = [
  'edit.add_element',
  'edit.update_visual',
  'edit.update_transform',
  'edit.move_selection',
  'edit.set_camera_offset',
  'edit.add_line',
  'input.selected_move_preview',
  'frame.selected_move_preview_cached_ordinary_plan',
  'input.marquee_preview',
  'input.draw_preview',
  'input.line_preview',
  'input.eraser_preview',
  'input.eraser_budget_exceeded',
  'frame.main_capture',
  'frame.overlay_capture',
  'frame.paint_candidates',
  'resources.resolve_sync',
  'resources.resolve_sync_cold_budget',
  'resources.mark_dirty',
  'resources.mark_all_dirty',
  'projection.read_document',
  'codec.decode_v1',
  'load_document.success',
  'load_document.breakdown',
  'load_document.failure',
  'spatial.query_point',
  'spatial.query_point_dense_stress',
  'spatial.touched_update',
  'runtime.dispose_during_gesture',
  'diagnostics.disabled_pointer',
];

const _expectedBudgetCaps = {
  'hot_input': {
    'avg_us_by_scale': {
      '1k': 9000,
      '10k': 8000,
      '50k': 40000,
      '100k': 40000,
    },
    'p95_us_by_scale': {
      '1k': 11000,
      '10k': 15000,
      '50k': 70000,
      '100k': 50000,
    },
    'max_us_by_scale': {
      '1k': 32000,
      '10k': 15000,
      '50k': 70000,
      '100k': 50000,
    },
  },
  'incremental_edit': {
    'avg_us_by_scale': {
      '1k': 1500,
      '10k': 8000,
      '50k': 40000,
      '100k': 85000,
    },
    'p95_us_by_scale': {
      '1k': 4000,
      '10k': 10000,
      '50k': 50000,
      '100k': 100000,
    },
    'max_us_by_scale': {
      '1k': 8000,
      '10k': 15000,
      '50k': 50000,
      '100k': 100000,
    },
  },
  'frame_capture': {
    'avg_us_by_scale': {
      '1k': 6000,
      '10k': 6000,
      '50k': 40000,
      '100k': 40000,
    },
    'p95_us_by_scale': {
      '1k': 10000,
      '10k': 10000,
      '50k': 60000,
      '100k': 60000,
    },
    'max_us_by_scale': {
      '1k': 25000,
      '10k': 25000,
      '50k': 60000,
      '100k': 60000,
    },
  },
  'query_read': {
    'avg_us_by_scale': {
      '1k': 6000,
      '10k': 20000,
      '50k': 110000,
      '100k': 210000,
    },
    'p95_us_by_scale': {
      '1k': 8000,
      '10k': 40000,
      '50k': 140000,
      '100k': 250000,
    },
    'max_us_by_scale': {
      '1k': 15000,
      '10k': 35000,
      '50k': 140000,
      '100k': 250000,
    },
  },
  'resource_budgeted': {
    'avg_us': 1000,
    'p95_us': 4000,
    'max_us': 8000,
    'cold_sync_resolver_calls': 128,
  },
  'bulk_io': {
    'p95_us_by_scale': {
      '1k': 100000,
      '10k': 500000,
      '50k': 2250000,
      '100k': 2000000,
    },
    'failure_mutation_count': 0,
  },
  'exact_invariant': {
    'required_counts_match_manifest': true,
    'positive_drift_allowed': false,
  },
  'allocation_budget': {
    'zero_allocation_records': 0,
    'zero_allocation_bytes': 0,
    'zero_rss_delta_bytes': 0,
  },
};

const _expectedMemoryCaps = {
  'zero_allocation': {'allocation_bytes_cap': 0, 'rss_delta_bytes_cap': 0},
  'hot_or_query': {
    'allocation_bytes_cap_by_scale': {
      '1k': 2750000,
      '10k': 1048576,
      '50k': 22000000,
      '100k': 1048576,
    },
    'rss_delta_bytes_cap_by_scale': {
      '1k': 2750000,
      '10k': 1048576,
      '50k': 22000000,
      '100k': 1048576,
    },
  },
  'incremental_owner_update': {
    'allocation_bytes_cap_by_scale': {
      '1k': 262144,
      '10k': 700000,
      '50k': 18000000,
      '100k': 27250000,
    },
    'rss_delta_bytes_cap_by_scale': {
      '1k': 2097152,
      '10k': 700000,
      '50k': 18000000,
      '100k': 27250000,
    },
  },
  'frame_or_resource': {
    'allocation_bytes_cap_by_scale': {
      '1k': 524288,
      '10k': 4194304,
      '50k': 9000000,
      '100k': 4194304,
    },
    'rss_delta_bytes_cap_by_scale': {
      '1k': 4194304,
      '10k': 4194304,
      '50k': 9000000,
      '100k': 4194304,
    },
  },
  'bulk_document_1k_10k_50k_100k': {
    'allocation_bytes_cap_by_scale': {
      '1k': 8388608,
      '10k': 25165824,
      '50k': 125829120,
      '100k': 251658240,
    },
    'rss_delta_bytes_cap_by_scale': {
      '1k': 16777216,
      '10k': 33554432,
      '50k': 167772160,
      '100k': 335544320,
    },
  },
  'codec_fixture_bulk': {
    'allocation_min_bytes': 4194304,
    'allocation_encoded_input_multiplier': 4,
    'rss_min_bytes': 16777216,
    'rss_encoded_input_multiplier': 2,
  },
};

const _expectedPostBaselineRegressionCaps = {
  'avg_us_percent': 15,
  'avg_us_floor_us': 15000,
  'p95_us_percent': 15,
  'p95_us_floor_us': 30000,
  'max_us_percent': 30,
  'max_us_floor_us': 30000,
  'allocation_or_rss_percent': 10,
  'allocation_floor_bytes': 16777216,
  'rss_floor_bytes': 16777216,
};

const _expectedFirstBaselineReferenceLimits = {'avg_us_multiplier': 1.35};

const _expectedProfilePolicyFingerprint =
    'dry_run:0:1:1:0:0:false:all_required_scales|'
    'smoke:1:3::500:100:true:smallest_required_scale_preserve_dense|'
    'release:1:5::2000:0:true:all_required_scales';

const _expectedReleaseContourFingerprint =
    'ubuntu-24.04|Ubuntu|24.04|stable|3.44.0';

const _expectedCaseBoundaryFingerprints = [
  'edit.add_element|action_only|per_sample_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|normal_spread',
  'edit.update_visual|action_only|per_sample_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|normal_spread',
  'edit.update_transform|action_only|per_sample_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|normal_spread',
  'edit.move_selection|action_only|per_sample_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|normal_spread',
  'edit.set_camera_offset|action_only|per_sample_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|normal_spread',
  'edit.add_line|action_only|per_sample_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|normal_spread',
  'input.selected_move_preview|action_only|per_sample_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|normal_spread',
  'frame.selected_move_preview_cached_ordinary_plan|action_only|per_run_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|normal_spread',
  'input.marquee_preview|action_only|per_sample_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|normal_spread',
  'input.draw_preview|action_only|per_sample_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|normal_spread',
  'input.line_preview|action_only|per_sample_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|normal_spread',
  'input.eraser_preview|action_only|per_sample_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|normal_spread',
  'input.eraser_budget_exceeded|action_only|per_sample_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|dense_stress',
  'frame.main_capture|action_only|per_run_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|normal_spread',
  'frame.overlay_capture|action_only|per_run_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|active_preview',
  'frame.paint_candidates|action_only|per_run_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|normal_spread',
  'resources.resolve_sync|action_only|per_sample_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|resource_set',
  'resources.resolve_sync_cold_budget|action_only|per_sample_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|resource_set',
  'resources.mark_dirty|action_only|per_sample_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|resource_set',
  'resources.mark_all_dirty|action_only|per_sample_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|resource_set',
  'projection.read_document|projection_split|per_sample_prepared_fixture|excluded|projection_action_total|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|normal_spread',
  'codec.decode_v1|lifecycle|per_run_prepared_fixture|measured_lifecycle|lifecycle|lifecycle|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|codec_fixture',
  'load_document.success|action_only|per_sample_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|normal_spread',
  'load_document.breakdown|lifecycle|per_run_prepared_fixture|measured_lifecycle|lifecycle|lifecycle|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|codec_fixture',
  'load_document.failure|lifecycle|per_sample_prepared_fixture|measured_lifecycle|lifecycle|lifecycle|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|invalid_document',
  'spatial.query_point|action_only|per_run_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|normal_spread',
  'spatial.query_point_dense_stress|action_only|per_run_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|dense_stress',
  'spatial.touched_update|action_only|per_sample_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|normal_spread',
  'runtime.dispose_during_gesture|action_only|per_sample_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|active_preview',
  'diagnostics.disabled_pointer|action_only|per_sample_prepared_fixture|excluded|action|action|setup_us|setup_allocation_bytes,setup_rss_delta_bytes|hot_pointer',
];

const _expectedCasePolicyFingerprints = [
  'edit.add_element|reference_comparison|incremental_edit,allocation_budget|incremental_owner_update|avg_us,p95_us,max_us,allocation_bytes||1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release;100k:dry_run,release',
  'edit.update_visual|reference_comparison|incremental_edit,allocation_budget|incremental_owner_update|avg_us,p95_us,max_us,touched_count||1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release;100k:dry_run,release',
  'edit.update_transform|reference_comparison|incremental_edit,allocation_budget|incremental_owner_update|spatial_touched_pages,allocation_bytes||1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release;100k:dry_run,release',
  'edit.move_selection|reference_comparison|hot_input,incremental_edit,exact_invariant|incremental_owner_update|selected_count,avg_us,p95_us,max_us|selected_count_matches_input:selected_count::|1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release',
  'edit.set_camera_offset|reference_comparison|hot_input,incremental_edit,exact_invariant|incremental_owner_update|avg_us,p95_us,max_us,ordinary_paint_plan_invalidations|ordinary_paint_plan_invalidations_zero:ordinary_paint_plan_invalidations:0:|1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release;100k:dry_run,release',
  'edit.add_line|reference_comparison|incremental_edit,allocation_budget|incremental_owner_update|avg_us,p95_us,max_us,allocation_bytes||1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release',
  'input.selected_move_preview|absolute_budget|hot_input,exact_invariant|hot_or_query|scene_repaint_count,avg_us,max_us|scene_repaint_count_bounded:scene_repaint_count::|1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release',
  'frame.selected_move_preview_cached_ordinary_plan|absolute_budget|frame_capture,query_read,exact_invariant|frame_or_resource|ordinary_plan_hit_rate,supplement_count,cached_preview_delta_count|cached_preview_delta_absent:cached_preview_delta_count:0:|1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release',
  'input.marquee_preview|absolute_budget|hot_input,exact_invariant|hot_or_query|overlay_repaint_count,avg_us,max_us|overlay_repaint_count_bounded:overlay_repaint_count::|1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release',
  'input.draw_preview|absolute_budget|hot_input,exact_invariant|hot_or_query|point_count,avg_us,max_us|point_count_matches_input:point_count::|1k:dry_run,smoke,release;10k:dry_run,release',
  'input.line_preview|absolute_budget|hot_input,exact_invariant|hot_or_query|overlay_repaint_count,avg_us,max_us|overlay_repaint_count_bounded:overlay_repaint_count::|1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release',
  'input.eraser_preview|absolute_budget|hot_input,exact_invariant|hot_or_query|candidate_count,exact_check_count|eraser_exact_checks_match_candidates:exact_check_count::|1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release',
  'input.eraser_budget_exceeded|absolute_budget|frame_capture,exact_invariant|frame_or_resource|budget_exceeded_count,partial_erase_count|partial_erase_count_zero:partial_erase_count:0:|dense_50k:dry_run,smoke,release',
  'frame.main_capture|reference_comparison|frame_capture,allocation_budget|frame_or_resource|avg_us,p95_us,max_us,allocation_bytes||1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release;100k:dry_run,release',
  'frame.overlay_capture|absolute_budget|frame_capture,allocation_budget|frame_or_resource|avg_us,p95_us,max_us,allocation_bytes||active_previews:dry_run,smoke,release',
  'frame.paint_candidates|absolute_budget|frame_capture,allocation_budget,exact_invariant|frame_or_resource|candidate_count,offscreen_layer_count,save_layer_count|save_layer_count_zero:save_layer_count:0:,offscreen_layer_count_zero:offscreen_layer_count:0:|1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release;100k:dry_run,release',
  'resources.resolve_sync|absolute_budget|resource_budgeted,exact_invariant|frame_or_resource|surface_resource_session_resolver_calls,session_cache_hits,repaint_count|resolver_calls_bounded:surface_resource_session_resolver_calls::|1k_resources:dry_run,smoke,release',
  'resources.resolve_sync_cold_budget|absolute_budget|resource_budgeted,exact_invariant|frame_or_resource|session_budget_resolver_calls,budget_placeholders,throttled_repaint_count|session_budget_resolver_calls_lte_128:session_budget_resolver_calls::128|1k_uncached_image_records:dry_run,smoke,release',
  'resources.mark_dirty|absolute_budget|resource_budgeted,exact_invariant|frame_or_resource|repaint_count,target_session_cache_invalidation_cost|target_session_cache_invalidation_bounded:target_session_cache_invalidation_cost::|1k_resources:dry_run,smoke,release',
  'resources.mark_all_dirty|absolute_budget|resource_budgeted,exact_invariant|frame_or_resource|repaint_count,all_entry_session_cache_invalidation_cost|all_entry_session_cache_invalidation_bounded:all_entry_session_cache_invalidation_cost::|1k_resources:dry_run,smoke,release',
  'projection.read_document|absolute_budget|query_read|bulk_document_1k_10k_50k_100k|first_read_us,cache_hit_us||1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release;100k:dry_run,release',
  'codec.decode_v1|reference_comparison|bulk_io,allocation_budget,exact_invariant|codec_fixture_bulk|avg_us,p95_us,max_us,error_payload|error_payload_matches_fixture:error_payload::|all_fixtures:dry_run,smoke,release',
  'load_document.success|reference_comparison|bulk_io,allocation_budget|bulk_document_1k_10k_50k_100k|avg_us,p95_us,max_us,schema_import_load_us,rebuild_cost,allocation_bytes||1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release',
  'load_document.breakdown|absolute_budget|bulk_io,allocation_budget|bulk_document_1k_10k_50k_100k|avg_us,p95_us,max_us,decode_us,runtime_construct_us,schema_import_load_us,first_projection_us,loaded_element_count,projected_element_count,allocation_bytes||1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release',
  'load_document.failure|reference_comparison|bulk_io,allocation_budget,exact_invariant|bulk_document_1k_10k_50k_100k|avg_us,p95_us,max_us,committed_mutation_count|committed_mutation_count_zero:committed_mutation_count:0:|invalid_1k:dry_run,smoke,release;invalid_10k:dry_run,release;invalid_50k:dry_run,release',
  'spatial.query_point|reference_comparison|query_read,exact_invariant|hot_or_query|tile_count,fallback_count|fallback_count_bounded:fallback_count::|1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release;100k:dry_run,release',
  'spatial.query_point_dense_stress|absolute_budget|query_read,exact_invariant|hot_or_query|fallback_count|fallback_count_bounded:fallback_count::|dense_50k:dry_run,smoke,release',
  'spatial.touched_update|reference_comparison|query_read,incremental_edit,exact_invariant|incremental_owner_update|rebuilt_ids,rebuilt_pages|rebuilt_pages_match_touched_set:rebuilt_pages::|1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release',
  'runtime.dispose_during_gesture|absolute_budget|hot_input,exact_invariant|hot_or_query|avg_us,p95_us,max_us,resolver_calls,action_events|resolver_calls_zero:resolver_calls:0:,action_events_zero:action_events:0:|active_selected_overlay_previews:dry_run,smoke,release',
  'diagnostics.disabled_pointer|absolute_budget|hot_input,exact_invariant,allocation_budget|zero_allocation|allocation_records,allocation_bytes|allocation_records_zero:allocation_records:0:,allocation_bytes_zero:allocation_bytes:0:|hot_pointer:dry_run,smoke,release',
];
