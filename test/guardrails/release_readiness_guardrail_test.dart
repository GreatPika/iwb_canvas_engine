import 'package:test/test.dart';

import '../../tool/guardrails/src/guardrail_executor.dart';
import '../../tool/guardrails/src/guardrail_registry.dart';
import '../../tool/guardrails/src/guardrail_violation.dart';
import '../../tool/guardrails/src/release_readiness_checks.dart';
import 'fixtures/runner_backed_guardrail_test_support.dart';

// Keep the positive runner route and negative release-readiness fixtures
// together so the release guardrail contract cannot drift across separate tests.
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

  test(
    'release benchmark readiness guardrail rejects quarantined workflow',
    () {
      expect(
        _violationMessages(
          _checkWith(
            extraWorkflowFiles: const {
              '.github/workflows/release_benchmarks.yml': 'name: Release',
            },
          ),
        ),
        contains(contains('GitHub release benchmark workflow is quarantined')),
      );
    },
  );

  test(
    'release benchmark readiness guardrail rejects baseline update workflow',
    () {
      expect(
        _violationMessages(
          _checkWith(
            extraWorkflowFiles: const {
              '.github/workflows/update_benchmark_baseline.yml':
                  'name: Update benchmark baseline',
            },
          ),
        ),
        contains(contains('GitHub release benchmark workflow is quarantined')),
      );
    },
  );

  test(
    'release benchmark readiness guardrail rejects workflow benchmark run',
    () {
      expect(
        _violationMessages(
          _checkWith(
            extraWorkflowFiles: const {
              '.github/workflows/bad.yml':
                  'run: dart run tool/bench/run.dart --profile=\${BENCH_PROFILE}',
            },
          ),
        ),
        contains(
          contains(
            'GitHub workflow must not run quarantined benchmark command',
          ),
        ),
      );
      expect(
        _violationMessages(
          _checkWith(
            extraWorkflowFiles: const {
              '.github/workflows/bad.yml':
                  'run: dart run tool/bench/diff.dart --baseline=baseline.json',
            },
          ),
        ),
        contains(
          contains(
            'GitHub workflow must not run quarantined benchmark command',
          ),
        ),
      );
    },
  );

  test(
    'release benchmark readiness guardrail rejects interpolated benchmark run',
    () {
      expect(
        _violationMessages(
          _checkWith(
            extraWorkflowFiles: const {
              '.github/workflows/bad.yml': r'''
jobs:
  bad:
    runs-on: ubuntu-24.04
    env:
      BENCH_DIR: tool/bench
    strategy:
      matrix:
        script:
          - run.dart
    steps:
      - run: dart run ${BENCH_DIR}/${{ matrix.script }} --profile=release
''',
            },
          ),
        ),
        contains(
          contains(
            'GitHub workflow must not run quarantined benchmark command',
          ),
        ),
      );
    },
  );

  test('release benchmark readiness guardrail rejects matrix include run', () {
    expect(
      _violationMessages(
        _checkWith(
          extraWorkflowFiles: const {
            '.github/workflows/bad.yml': r'''
jobs:
  bad:
    runs-on: ubuntu-24.04
    env:
      BENCH_DIR: tool/bench
    strategy:
      matrix:
        include:
          - script: run.dart
    steps:
      - run: dart run ${BENCH_DIR}/${{ matrix.script }} --profile=release
''',
          },
        ),
      ),
      contains(
        contains('GitHub workflow must not run quarantined benchmark command'),
      ),
    );
  });

  test('release benchmark readiness guardrail rejects compact expressions', () {
    expect(
      _violationMessages(
        _checkWith(
          extraWorkflowFiles: const {
            '.github/workflows/bad.yml': r'''
jobs:
  bad:
    runs-on: ubuntu-24.04
    strategy:
      matrix:
        script:
          - run.dart
    steps:
      - run: dart run ${{env.BENCH_DIR}}/${{matrix.script}} --profile=release
        env:
          BENCH_DIR: tool/bench
''',
          },
        ),
      ),
      contains(
        contains('GitHub workflow must not run quarantined benchmark command'),
      ),
    );
  });

  test(
    'release benchmark readiness guardrail rejects quoted path segments',
    () {
      expect(
        _violationMessages(
          _checkWith(
            extraWorkflowFiles: const {
              '.github/workflows/bad.yml': r'''
jobs:
  bad:
    runs-on: ubuntu-24.04
    env:
      BENCH_DIR: tool/bench
    steps:
      - run: dart run tool/bench/"run.dart" --profile=release
      - run: dart run "$BENCH_DIR"/diff.dart --profile=release
''',
            },
          ),
        ),
        contains(
          contains(
            'GitHub workflow must not run quarantined benchmark command',
          ),
        ),
      );
    },
  );

  test('release benchmark readiness guardrail rejects nested expressions', () {
    expect(
      _violationMessages(
        _checkWith(
          extraWorkflowFiles: const {
            '.github/workflows/bad.yml': r'''
jobs:
  bad:
    runs-on: ubuntu-24.04
    strategy:
      matrix:
        script:
          - run.dart
    steps:
      - run: dart run ${{ env.BENCH_DIR }}/${{ env.BENCH_SCRIPT }} --profile=release
        env:
          BENCH_DIR: tool/bench
          BENCH_SCRIPT: ${{ matrix.script }}
''',
          },
        ),
      ),
      contains(
        contains('GitHub workflow must not run quarantined benchmark command'),
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
        contains('public surface must not expose release benchmark tooling'),
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
    'release benchmark readiness guardrail rejects retired benchmark routes',
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
          contains(
            'benchmark release proof must not invoke retired package paths',
          ),
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
                  'const path = "tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_44_0.json";',
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
    'release benchmark readiness guardrail rejects direct baseline path writes',
    () {
      expect(
        _violationMessages(
          _checkWith(
            extraWorkflowFiles: const {
              '.github/workflows/bad.yml':
                  'run: cp current.json tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_44_0.json',
            },
          ),
        ),
        contains(contains('approved baselines may only be written manually')),
      );
    },
  );

  test(
    'release benchmark readiness guardrail rejects baseline update command',
    () {
      expect(
        _violationMessages(
          _checkWith(
            extraWorkflowFiles: const {
              '.github/workflows/bad.yml':
                  'run: dart run tool/bench/update_baseline.dart',
            },
          ),
        ),
        contains(
          contains(
            'GitHub workflow must not run quarantined benchmark command',
          ),
        ),
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
  Iterable<GuardrailSourceSnapshot> productionSources = const [],
  Iterable<GuardrailSourceSnapshot> benchmarkSources = const [],
  Map<String, String> extraWorkflowFiles = const {},
}) {
  return checkReleaseBenchmarkReadinessSources(
    publicSurfaceSources: publicSurfaceSources,
    productionSources: productionSources,
    benchmarkSources: benchmarkSources,
    workflowFiles: extraWorkflowFiles,
  );
}
