@Tags(['tool'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/bench/load_profile_policy.dart';
import '../../tool/bench/run_load_profiles.dart' as run_load_profiles;

void main() {
  group('tool/bench/run_load_profiles.dart', () {
    test('accepts exact smoke case set from policy', () {
      final policy = loadProfilePolicyFor('smoke');

      final issues = run_load_profiles.validateCollectedBenchmarkCases(
        policy: policy,
        parsedCases: <Map<String, Object?>>[
          for (final caseName in policy.requiredCaseNames)
            <String, Object?>{'name': caseName},
        ],
      );

      expect(issues, isEmpty);
    });

    test('fails when a required smoke case is missing', () {
      final policy = loadProfilePolicyFor('smoke');

      final issues = run_load_profiles.validateCollectedBenchmarkCases(
        policy: policy,
        parsedCases: <Map<String, Object?>>[
          <String, Object?>{'name': 'nodes_10000'},
          <String, Object?>{'name': 'strokes_1000_pts_256'},
          <String, Object?>{'name': worstCaseName},
        ],
      );

      expect(
        issues,
        contains('missing required benchmark cases: $selectionPathCaseName'),
      );
    });

    test('fails on duplicate and unexpected case names', () {
      final policy = loadProfilePolicyFor('smoke');

      final issues = run_load_profiles.validateCollectedBenchmarkCases(
        policy: policy,
        parsedCases: <Map<String, Object?>>[
          <String, Object?>{'name': 'nodes_10000'},
          <String, Object?>{'name': 'nodes_10000'},
          <String, Object?>{'name': 'strokes_1000_pts_256'},
          <String, Object?>{'name': selectionPathCaseName},
          <String, Object?>{'name': worstCaseName},
          <String, Object?>{'name': 'unexpected_case'},
        ],
      );

      expect(issues, contains('duplicate benchmark cases: nodes_10000'));
      expect(issues, contains('unexpected benchmark cases: unexpected_case'));
    });

    test('fails when a parsed case omits its name', () {
      final policy = loadProfilePolicyFor('smoke');

      final issues = run_load_profiles.validateCollectedBenchmarkCases(
        policy: policy,
        parsedCases: <Map<String, Object?>>[
          <String, Object?>{'name': ''},
        ],
      );

      expect(issues, <String>[
        'benchmark case #0 is missing a non-empty "name"',
      ]);
    });
  });
}
