import 'dart:io';

import 'package:test/test.dart';

import '../../tool/bench/src/benchmark_manifest.dart';

// Manifest tests keep the full policy projection in one fixture-backed suite so
// case inventory, profile parameters, and numeric gates drift together.
// ignore: halstead-volume, maintainability-index, source-lines-of-code
void main() {
  group('benchmark manifest schema', () {
    test('loads the P14 source of truth with the required inventory', () {
      final manifest = BenchmarkManifest.load();

      expect(manifest.manifestVersion, 'p14_release_readiness_benchmarks_v1');
      expect(manifest.toolSchemaVersion, 1);
      expect(manifest.cases, hasLength(28));
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
      expect(contour.flutterVersion, '3.38.0');
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
        manifest.bootstrapLegacyEquivalence,
        _expectedBootstrapLegacyEquivalence,
      );
    });

    test('locks per-case policy inventory from the design', () {
      final manifest = BenchmarkManifest.load();

      expect(
        _casePolicyFingerprints(manifest),
        _expectedCasePolicyFingerprints,
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

    test('rejects invalid equivalent-legacy classification', () {
      final error = _parseFailure(
        _manifestText().replaceFirst(
          'classification: equivalent_legacy',
          'classification: legacyish',
        ),
      );

      expect(error.message, contains('unsupported classification legacyish'));
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
          '  flutter_version: "3.38.0"',
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
        benchmarkCase.classification,
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
  'load_document.failure',
  'spatial.query_point',
  'spatial.touched_update',
  'runtime.dispose_during_gesture',
  'diagnostics.disabled_pointer',
];

const _expectedBudgetCaps = {
  'hot_input': {'avg_us': 500, 'p95_us': 2000, 'max_us': 4000},
  'incremental_edit': {'avg_us': 1000, 'p95_us': 4000, 'max_us': 8000},
  'frame_capture': {'avg_us': 4000, 'p95_us': 8000, 'max_us': 16000},
  'query_read': {'avg_us': 500, 'p95_us': 2000, 'max_us': 4000},
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
      '50k': 1000000,
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
    'allocation_bytes_cap': 65536,
    'rss_delta_bytes_cap': 1048576,
  },
  'incremental_owner_update': {
    'allocation_base_bytes': 262144,
    'allocation_per_reported_item_bytes': 512,
    'rss_delta_bytes_cap': 2097152,
  },
  'frame_or_resource': {
    'allocation_base_bytes': 524288,
    'allocation_per_reported_item_bytes': 128,
    'rss_delta_bytes_cap': 4194304,
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
  'p95_us_percent': 15,
  'max_us_percent': 30,
  'allocation_or_rss_percent': 10,
  'allocation_floor_bytes': 65536,
  'rss_floor_bytes': 1048576,
};

const _expectedBootstrapLegacyEquivalence = {'avg_us_multiplier': 1.35};

const _expectedProfilePolicyFingerprint =
    'dry_run:0:1:1:0:0:false:all_required_scales|'
    'smoke:1:3::500:100:true:smallest_required_scale_preserve_dense|'
    'release:1:5::2000:0:true:all_required_scales';

const _expectedReleaseContourFingerprint =
    'ubuntu-24.04|Ubuntu|24.04|stable|3.38.0';

const _expectedCasePolicyFingerprints = [
  'edit.add_element|equivalent_legacy|incremental_edit,allocation_budget|incremental_owner_update|avg_us,p95_us,max_us,allocation_bytes||1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release;100k:dry_run,release',
  'edit.update_visual|equivalent_legacy|incremental_edit,allocation_budget|incremental_owner_update|avg_us,p95_us,max_us,touched_count||1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release;100k:dry_run,release',
  'edit.update_transform|equivalent_legacy|incremental_edit,allocation_budget|incremental_owner_update|spatial_touched_pages,allocation_bytes||1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release;100k:dry_run,release',
  'edit.move_selection|equivalent_legacy|hot_input,incremental_edit,exact_invariant|incremental_owner_update|selected_count,avg_us,p95_us,max_us|selected_count_matches_input:selected_count::|1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release',
  'edit.set_camera_offset|equivalent_legacy|hot_input,incremental_edit,exact_invariant|incremental_owner_update|avg_us,p95_us,max_us,ordinary_paint_plan_invalidations|ordinary_paint_plan_invalidations_zero:ordinary_paint_plan_invalidations:0:|1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release;100k:dry_run,release',
  'edit.add_line|equivalent_legacy|incremental_edit,allocation_budget|incremental_owner_update|avg_us,p95_us,max_us,allocation_bytes||1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release',
  'input.selected_move_preview|new_only|hot_input,exact_invariant|hot_or_query|scene_repaint_count,avg_us,max_us|scene_repaint_count_bounded:scene_repaint_count::|1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release',
  'frame.selected_move_preview_cached_ordinary_plan|new_only|frame_capture,query_read,exact_invariant|frame_or_resource|ordinary_plan_hit_rate,supplement_count,cached_preview_delta_count|cached_preview_delta_absent:cached_preview_delta_count:0:|1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release',
  'input.marquee_preview|new_only|hot_input,exact_invariant|hot_or_query|overlay_repaint_count,avg_us,max_us|overlay_repaint_count_bounded:overlay_repaint_count::|1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release',
  'input.draw_preview|new_only|hot_input,exact_invariant|hot_or_query|point_count,avg_us,max_us|point_count_matches_input:point_count::|1k:dry_run,smoke,release;10k:dry_run,release',
  'input.line_preview|new_only|hot_input,exact_invariant|hot_or_query|overlay_repaint_count,avg_us,max_us|overlay_repaint_count_bounded:overlay_repaint_count::|1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release',
  'input.eraser_preview|new_only|hot_input,exact_invariant|hot_or_query|candidate_count,exact_check_count|eraser_exact_checks_match_candidates:exact_check_count::|1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release',
  'input.eraser_budget_exceeded|new_only|frame_capture,exact_invariant|frame_or_resource|budget_exceeded_count,partial_erase_count|partial_erase_count_zero:partial_erase_count:0:|dense_50k:dry_run,smoke,release',
  'frame.main_capture|equivalent_legacy|frame_capture,allocation_budget|frame_or_resource|avg_us,p95_us,max_us,allocation_bytes||1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release;100k:dry_run,release',
  'frame.overlay_capture|new_only|frame_capture,allocation_budget|frame_or_resource|avg_us,p95_us,max_us,allocation_bytes||active_previews:dry_run,smoke,release',
  'frame.paint_candidates|new_only|frame_capture,allocation_budget,exact_invariant|frame_or_resource|candidate_count,offscreen_layer_count,save_layer_count|save_layer_count_zero:save_layer_count:0:,offscreen_layer_count_zero:offscreen_layer_count:0:|1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release;100k:dry_run,release',
  'resources.resolve_sync|new_only|resource_budgeted,exact_invariant|frame_or_resource|surface_resource_session_resolver_calls,session_cache_hits,repaint_count|resolver_calls_bounded:surface_resource_session_resolver_calls::|1k_resources:dry_run,smoke,release',
  'resources.resolve_sync_cold_budget|new_only|resource_budgeted,exact_invariant|frame_or_resource|session_budget_resolver_calls,budget_placeholders,throttled_repaint_count|session_budget_resolver_calls_lte_128:session_budget_resolver_calls::128|1k_uncached_image_records:dry_run,smoke,release',
  'resources.mark_dirty|new_only|resource_budgeted,exact_invariant|frame_or_resource|repaint_count,target_session_cache_invalidation_cost|target_session_cache_invalidation_bounded:target_session_cache_invalidation_cost::|1k_resources:dry_run,smoke,release',
  'resources.mark_all_dirty|new_only|resource_budgeted,exact_invariant|frame_or_resource|repaint_count,all_entry_session_cache_invalidation_cost|all_entry_session_cache_invalidation_bounded:all_entry_session_cache_invalidation_cost::|1k_resources:dry_run,smoke,release',
  'projection.read_document|new_only|query_read|bulk_document_1k_10k_50k_100k|first_read_us,cache_hit_us||1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release;100k:dry_run,release',
  'codec.decode_v1|equivalent_legacy|bulk_io,allocation_budget,exact_invariant|codec_fixture_bulk|avg_us,p95_us,max_us,error_payload|error_payload_matches_fixture:error_payload::|all_fixtures:dry_run,smoke,release',
  'load_document.success|equivalent_legacy|bulk_io,allocation_budget|bulk_document_1k_10k_50k_100k|avg_us,p95_us,max_us,rebuild_cost,allocation_bytes||1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release;100k:dry_run,release',
  'load_document.failure|equivalent_legacy|bulk_io,allocation_budget,exact_invariant|bulk_document_1k_10k_50k_100k|avg_us,p95_us,max_us,committed_mutation_count|committed_mutation_count_zero:committed_mutation_count:0:|invalid_1k:dry_run,smoke,release;invalid_10k:dry_run,release;invalid_50k:dry_run,release',
  'spatial.query_point|equivalent_legacy|query_read,exact_invariant|hot_or_query|tile_count,fallback_count|fallback_count_bounded:fallback_count::|1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release;100k:dry_run,release',
  'spatial.touched_update|equivalent_legacy|query_read,incremental_edit,exact_invariant|incremental_owner_update|rebuilt_ids,rebuilt_pages|rebuilt_pages_match_touched_set:rebuilt_pages::|1k:dry_run,smoke,release;10k:dry_run,release;50k:dry_run,release',
  'runtime.dispose_during_gesture|new_only|hot_input,exact_invariant|hot_or_query|avg_us,p95_us,max_us,resolver_calls,action_events|resolver_calls_zero:resolver_calls:0:,action_events_zero:action_events:0:|active_selected_overlay_previews:dry_run,smoke,release',
  'diagnostics.disabled_pointer|new_only|hot_input,exact_invariant,allocation_budget|zero_allocation|allocation_records,allocation_bytes|allocation_records_zero:allocation_records:0:,allocation_bytes_zero:allocation_bytes:0:|hot_pointer:dry_run,smoke,release',
];
