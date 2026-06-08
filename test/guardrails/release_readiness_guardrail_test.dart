import 'package:test/test.dart';

import '../../tool/guardrails/src/guardrail_executor.dart';
import '../../tool/guardrails/src/guardrail_registry.dart';
import '../../tool/guardrails/src/guardrail_violation.dart';
import '../../tool/guardrails/src/release_readiness_checks.dart';
import 'fixtures/runner_backed_guardrail_test_support.dart';

// Keep the positive runner route and negative release-readiness fixtures
// together so the P14 guardrail contract cannot drift across separate tests.
// ignore: halstead-volume, maintainability-index, source-lines-of-code
void main() {
  test('release benchmark readiness guardrail is runner-backed', () async {
    expect(
      await guardrailIsRunnerBacked(
        id: releaseBenchmarkReadinessGuardrailId,
        suites: {'blocking', 'release'},
        proofPaths: [
          'test/benchmarks/benchmark_diff_test.dart',
          'test/guardrails/release_readiness_guardrail_test.dart',
        ],
      ),
      isTrue,
    );
    expect(
      guardrailInventory()[releaseBenchmarkReadinessGuardrailId]?.suites,
      containsAll({'blocking', 'release'}),
    );
    expect(guardrailRouteFor(releaseBenchmarkReadinessGuardrailId), isNotNull);
  });

  test(
    'release benchmark readiness guardrail accepts current repository',
    () async {
      expect(await checkReleaseBenchmarkReadiness(), isEmpty);
    },
  );

  test('release benchmark readiness guardrail rejects missing diff gate', () {
    expect(
      _violationMessages(
        _checkWith(
          releaseWorkflow: _validReleaseWorkflow.replaceFirst(
            'run: $_releaseDiffCommand',
            '# $_releaseDiffCommand',
          ),
        ),
      ),
      contains(contains('release workflow missing required command')),
    );
  });

  test('release benchmark readiness guardrail rejects bypassed diff steps', () {
    expect(
      _violationMessages(
        _checkWith(
          releaseWorkflow: _validReleaseWorkflow.replaceFirst(
            'run: $_releaseDiffCommand',
            '''
if: false
        run: $_releaseDiffCommand''',
          ),
        ),
      ),
      contains(contains('release benchmark step must not use if')),
    );
    expect(
      _violationMessages(
        _checkWith(
          releaseWorkflow: _validReleaseWorkflow.replaceFirst(
            'run: $_releaseDiffCommand',
            '''
continue-on-error: true
        run: $_releaseDiffCommand''',
          ),
        ),
      ),
      contains(
        contains('release benchmark step must not use continue-on-error'),
      ),
    );
  });

  test('release benchmark readiness guardrail rejects public exports', () {
    expect(
      _violationMessages(
        _checkWith(
          publicSurfaceSources: const [
            GuardrailSourceSnapshot(
              path: 'lib/src/api/canvas_runtime.dart',
              content: "export '../contracts/public/canvas_benchmark.dart';",
            ),
          ],
        ),
      ),
      contains(
        contains('public surface must not expose P14 benchmark tooling'),
      ),
    );
  });

  test(
    'release benchmark readiness guardrail rejects adapter names in lib',
    () {
      expect(
        _violationMessages(
          _checkWith(
            productionSources: const [
              GuardrailSourceSnapshot(
                path: 'lib/src/api/bad.dart',
                content: 'final class NextEngineAdapter {}',
              ),
            ],
          ),
        ),
        contains(
          contains('production source must not contain NextEngineAdapter'),
        ),
      );
    },
  );

  test(
    'release benchmark readiness guardrail rejects benchmark hooks in lib',
    () {
      expect(
        _violationMessages(
          _checkWith(
            productionSources: const [
              GuardrailSourceSnapshot(
                path: 'lib/src/runtime/bad.dart',
                content: 'bool benchmarkMode = false;',
              ),
            ],
          ),
        ),
        contains(contains('production source must not contain benchmark')),
      );
      expect(
        _violationMessages(
          _checkWith(
            productionSources: const [
              GuardrailSourceSnapshot(
                path: 'lib/src/runtime/bad.dart',
                content: 'void releaseMeasurementProbe() {}',
              ),
            ],
          ),
        ),
        contains(
          contains('production source must not contain releaseMeasurement'),
        ),
      );
    },
  );

  test(
    'release benchmark readiness guardrail rejects legacy benchmark proof',
    () {
      expect(
        _violationMessages(
          _checkWith(
            benchmarkSources: const [
              GuardrailSourceSnapshot(
                path: 'tool/bench/src/bad.dart',
                content: "import 'package:legacy/bench.dart';",
              ),
            ],
          ),
        ),
        contains(
          contains('benchmark release proof must not invoke legacy paths'),
        ),
      );
    },
  );

  test(
    'release benchmark readiness guardrail rejects non-manual baseline writes',
    () {
      expect(
        _violationMessages(
          _checkWith(
            extraWorkflowFiles: const {
              '.github/workflows/bad.yml':
                  'run: dart run tool/bench/update_baseline.dart --approved=x',
            },
          ),
        ),
        contains(contains('approved baselines may only be written manually')),
      );
    },
  );

  test('release benchmark readiness guardrail rejects rogue tool writers', () {
    expect(
      _violationMessages(
        _checkWith(
          benchmarkSources: const [
            GuardrailSourceSnapshot(
              path: 'tool/bench/rogue.dart',
              content:
                  'void main() => runBenchmarkBaselineUpdateCli(const []);',
            ),
          ],
        ),
      ),
      contains(
        contains('approved baseline writes must stay behind update_baseline'),
      ),
    );
    expect(
      _violationMessages(
        _checkWith(
          benchmarkSources: const [
            GuardrailSourceSnapshot(
              path: 'tool/bench/rogue.dart',
              content:
                  'const path = "tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json";',
            ),
          ],
        ),
      ),
      contains(
        contains('approved baseline writes must stay behind update_baseline'),
      ),
    );
  });

  test('release benchmark readiness guardrail scans yaml workflow files', () {
    expect(
      _violationMessages(
        _checkWith(
          extraWorkflowFiles: const {
            '.github/workflows/bad.yaml':
                'run: dart run tool/bench/update_baseline.dart --approved=x',
          },
        ),
      ),
      contains(contains('approved baselines may only be written manually')),
    );
  });

  test(
    'release benchmark readiness guardrail rejects legacy workflow steps',
    () {
      expect(
        _violationMessages(
          _checkWith(
            releaseWorkflow: _validReleaseWorkflow.replaceFirst(
              '      - run: dart run tool/guardrails/run.dart',
              '''
      - run: dart run legacy/tool/bench/run_load_profiles.dart
      - run: dart run tool/guardrails/run.dart''',
            ),
          ),
        ),
        contains(
          contains('release benchmark workflow must not invoke legacy paths'),
        ),
      );
    },
  );

  test(
    'release benchmark readiness guardrail rejects direct baseline path writes',
    () {
      expect(
        _violationMessages(
          _checkWith(
            extraWorkflowFiles: const {
              '.github/workflows/bad.yml':
                  'run: cp current.json tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json',
            },
          ),
        ),
        contains(contains('approved baselines may only be written manually')),
      );
    },
  );

  test(
    'release benchmark readiness guardrail rejects automatic baseline update',
    () {
      expect(
        _violationMessages(
          _checkWith(
            baselineUpdateWorkflow: '''
on:
  workflow_dispatch:
  push:
jobs:
  update-benchmark-baseline:
    runs-on: ubuntu-24.04
    steps:
      - run: dart run tool/bench/update_baseline.dart
''',
          ),
        ),
        contains(contains('manual baseline update workflow is incomplete')),
      );
    },
  );
}

List<String> _violationMessages(Iterable<Object> violations) {
  return violations.map((violation) => violation.toString()).toList();
}

// These named inputs keep each negative fixture tied to the source surface it
// edits, which is clearer than hiding them behind an opaque fixture object.
// ignore: number-of-parameters
List<GuardrailViolation> _checkWith({
  Iterable<GuardrailSourceSnapshot> publicSurfaceSources = const [],
  String releaseWorkflow = _validReleaseWorkflow,
  String baselineUpdateWorkflow = _validBaselineUpdateWorkflow,
  Iterable<GuardrailSourceSnapshot> productionSources = const [],
  Iterable<GuardrailSourceSnapshot> benchmarkSources = const [],
  Map<String, String> extraWorkflowFiles = const {},
}) {
  return checkReleaseBenchmarkReadinessSources(
    publicSurfaceSources: publicSurfaceSources,
    productionSources: productionSources,
    benchmarkSources: benchmarkSources,
    workflowFiles: {
      '.github/workflows/release_benchmarks.yml': releaseWorkflow,
      '.github/workflows/update_benchmark_baseline.yml': baselineUpdateWorkflow,
      ...extraWorkflowFiles,
    },
  );
}

const _releaseDiffCommand =
    'dart run tool/bench/diff.dart --profile=release '
    '--baseline=tool/bench/baselines/approved/'
    'release_ubuntu_24_04_flutter_3_38_0.json '
    '--current=build/bench/current/'
    'release_ubuntu_24_04_flutter_3_38_0.json '
    '--output=build/bench/diff/'
    'release_ubuntu_24_04_flutter_3_38_0.json';

const _validReleaseWorkflow =
    '''
jobs:
  release-benchmarks:
    runs-on: ubuntu-24.04
    steps:
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.38.0
      - run: dart run tool/bench/run.dart --profile=release
      - run: $_releaseDiffCommand
      - run: dart run tool/architecture_graph/check.dart
      - run: dart run tool/architecture_graph/generate_views.dart --check
      - run: dart run tool/guardrails/run.dart
''';

const _validBaselineUpdateWorkflow = '''
on:
  workflow_dispatch:
jobs:
  update-benchmark-baseline:
    runs-on: ubuntu-24.04
    steps:
      - run: dart run tool/bench/update_baseline.dart
''';
