@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../../tool/bench/load_profile_policy.dart';
import '../../tool/bench/run_load_profiles.dart' as run_load_profiles;

String _extractMethodBody({
  required String source,
  required String methodStart,
}) {
  final startIndex = source.indexOf(methodStart);
  if (startIndex < 0) {
    throw StateError('Method signature not found: $methodStart');
  }
  var bodyStart = -1;
  var parenDepth = 0;
  for (var i = startIndex; i < source.length; i++) {
    final char = source[i];
    if (char == '(') {
      parenDepth += 1;
    } else if (char == ')') {
      if (parenDepth > 0) {
        parenDepth -= 1;
      }
    } else if (char == '{' && parenDepth == 0) {
      bodyStart = i;
      break;
    }
  }
  if (bodyStart < 0) {
    throw StateError('Method body start not found: $methodStart');
  }

  var depth = 1;
  for (var i = bodyStart + 1; i < source.length; i++) {
    final char = source[i];
    if (char == '{') {
      depth += 1;
    } else if (char == '}') {
      depth -= 1;
      if (depth == 0) {
        return source.substring(bodyStart + 1, i);
      }
    }
  }
  throw StateError('Method body end not found: $methodStart');
}

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
          <String, Object?>{'name': backgroundLayerPaintAdmissionCaseName},
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

    test(
      'background paint benchmark is wired through SceneControllerSceneViewRenderState instead of benchmark-only render state',
      () {
        final source = File(
          'tool/bench/load_profiles_cases_test.dart',
        ).readAsStringSync();
        final body = _extractMethodBody(
          source: source,
          methodStart:
              'Map<String, Object?> _runBackgroundLayerPaintAdmissionCase({',
        );

        expect(body, contains('SceneControllerSceneViewRenderState('));
        expect(body, isNot(contains('_BenchmarkControllerRenderState(')));
        expect(
          source,
          contains('load profile background-layer-paint profile=\$profile'),
        );
      },
    );
  });
}
