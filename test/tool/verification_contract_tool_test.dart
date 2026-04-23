@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/tool_process_test_support.dart';

void main() {
  group('tool/check_verification_contract.dart', () {
    test(
      'passes when workflows stay aligned with the registry graph',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeCanonicalCiWorkflow(sandbox);
          _writeCanonicalPerfNightlyWorkflow(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'check_verification_contract.dart',
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
          expect(
            result.stdout.toString(),
            contains('Verification contract OK'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'ignores AGENTS.md because it is outside the executable contract',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeCanonicalCiWorkflow(sandbox);
          _writeCanonicalPerfNightlyWorkflow(sandbox);
          writeSandboxFile(sandbox, 'AGENTS.md', '''
# Product boundary

## Verification

Run something else.
''');

          final result = await runSandboxTool(
            sandbox,
            'check_verification_contract.dart',
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('fails when CI run surface drifts', () async {
      final sandbox = await _createSandbox();
      try {
        _writeCanonicalCiWorkflow(
          sandbox,
          removeRun: 'dart run tool/check_verification_contract.dart',
        );
        _writeCanonicalPerfNightlyWorkflow(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'check_verification_contract.dart',
        );

        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains(
            'missing expected run entry `.|dart run tool/check_verification_contract.dart`',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('fails when CI reintroduces DCM analyze', () async {
      final sandbox = await _createSandbox();
      try {
        _writeCanonicalCiWorkflow(
          sandbox,
          extraStaticChecksRun: 'dcm analyze .',
        );
        _writeCanonicalPerfNightlyWorkflow(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'check_verification_contract.dart',
        );

        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains(
            '.github/workflows/ci.yaml has unexpected executable run entry `.|dcm analyze .`',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('fails when CI tool-test trigger surface drifts', () async {
      final sandbox = await _createSandbox();
      try {
        _writeCanonicalCiWorkflow(
          sandbox,
          triggerEntries: <String>[
            ..._canonicalTriggerEntries,
            'tool/extra.dart',
          ],
        );
        _writeCanonicalPerfNightlyWorkflow(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'check_verification_contract.dart',
        );

        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains(
            'Unexpected .github/workflows/ci.yaml tool_tests entries: tool/extra.dart',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('fails when perf nightly run surface drifts', () async {
      final sandbox = await _createSandbox();
      try {
        _writeCanonicalCiWorkflow(sandbox);
        _writeCanonicalPerfNightlyWorkflow(
          sandbox,
          removeRun:
              'dart run tool/bench/run_load_profiles.dart --profile=full --output=build/bench/load_profiles_full.json',
        );

        final result = await runSandboxTool(
          sandbox,
          'check_verification_contract.dart',
        );

        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains(
            'missing expected run entry '
            '`.|dart run tool/bench/run_load_profiles.dart --profile=full --output=build/bench/load_profiles_full.json`',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'fails when perf nightly owned run surface grows unexpectedly',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeCanonicalCiWorkflow(sandbox);
          _writeCanonicalPerfNightlyWorkflow(sandbox, extraRun: 'echo drift');

          final result = await runSandboxTool(
            sandbox,
            'check_verification_contract.dart',
          );

          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains(
              '.github/workflows/perf_nightly.yaml has unexpected executable run entry `.|echo drift`',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('fails when perf nightly duplicates an owned run entry', () async {
      final sandbox = await _createSandbox();
      try {
        _writeCanonicalCiWorkflow(sandbox);
        _writeCanonicalPerfNightlyWorkflow(
          sandbox,
          extraRun: 'flutter pub get',
        );

        final result = await runSandboxTool(
          sandbox,
          'check_verification_contract.dart',
        );

        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains(
            '.github/workflows/perf_nightly.yaml has unexpected executable run entry `.|flutter pub get`',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'accepts perf nightly folded block run syntax for equivalent command',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeCanonicalCiWorkflow(sandbox);
          _writeCanonicalPerfNightlyWorkflow(
            sandbox,
            loadProfilesRunHeader: '>-',
            loadProfilesRunBody:
                'dart run tool/bench/run_load_profiles.dart --profile=full\n'
                '--output=build/bench/load_profiles_full.json',
          );

          final result = await runSandboxTool(
            sandbox,
            'check_verification_contract.dart',
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'accepts perf nightly literal keep block syntax for equivalent command',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeCanonicalCiWorkflow(sandbox);
          _writeCanonicalPerfNightlyWorkflow(sandbox, fuzzRunHeader: '|+');

          final result = await runSandboxTool(
            sandbox,
            'check_verification_contract.dart',
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('reports invalid workflow yaml without crashing', () async {
      final sandbox = await _createSandbox();
      try {
        _writeCanonicalCiWorkflow(sandbox);
        writeSandboxFile(sandbox, '.github/workflows/perf_nightly.yaml', '''
name: Perf Nightly

jobs:
  perf:
    steps:
      - name: Broken
        run: [unterminated
''');

        final result = await runSandboxTool(
          sandbox,
          'check_verification_contract.dart',
        );

        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('FAIL: verification contract drift detected.'),
        );
        expect(
          result.stderr.toString(),
          contains('.github/workflows/perf_nightly.yaml contains invalid YAML'),
        );
        expect(
          result.stderr.toString(),
          isNot(contains('Unhandled exception')),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    for (final scenario in _yamlCompatibilityScenarios) {
      test('accepts ${scenario.name}', () async {
        final sandbox = await _createSandbox();
        try {
          _writeCanonicalCiWorkflow(sandbox);
          _writeCanonicalPerfNightlyWorkflow(sandbox);
          scenario.mutate(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'check_verification_contract.dart',
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      });
    }
  });
}

final List<_YamlCompatibilityScenario>
_yamlCompatibilityScenarios = <_YamlCompatibilityScenario>[
  _YamlCompatibilityScenario(
    name: 'single-quoted run scalar',
    mutate: (sandbox) {
      _replaceInSandboxFile(
        sandbox,
        '.github/workflows/perf_nightly.yaml',
        'run: flutter pub get',
        "run: 'flutter pub get'",
      );
    },
  ),
  _YamlCompatibilityScenario(
    name: 'double-quoted run scalar',
    mutate: (sandbox) {
      _replaceInSandboxFile(
        sandbox,
        '.github/workflows/perf_nightly.yaml',
        'run: flutter pub get',
        'run: "flutter pub get"',
      );
    },
  ),
  _YamlCompatibilityScenario(
    name: 'single-quoted working-directory scalar',
    mutate: (sandbox) {
      _replaceInSandboxFile(
        sandbox,
        '.github/workflows/ci.yaml',
        'working-directory: example',
        "working-directory: 'example'",
      );
    },
  ),
  _YamlCompatibilityScenario(
    name: 'double-quoted working-directory scalar',
    mutate: (sandbox) {
      _replaceInSandboxFile(
        sandbox,
        '.github/workflows/ci.yaml',
        'working-directory: example',
        'working-directory: "example"',
      );
    },
  ),
  _YamlCompatibilityScenario(
    name: 'plain run scalar with trailing comment',
    mutate: (sandbox) {
      _replaceInSandboxFile(
        sandbox,
        '.github/workflows/perf_nightly.yaml',
        'run: flutter pub get',
        'run: flutter pub get # keep cache warm',
      );
    },
  ),
  _YamlCompatibilityScenario(
    name: 'working-directory scalar with trailing comment',
    mutate: (sandbox) {
      _replaceInSandboxFile(
        sandbox,
        '.github/workflows/ci.yaml',
        'working-directory: example',
        'working-directory: example # example package',
      );
    },
  ),
  _YamlCompatibilityScenario(
    name: 'literal block header with trailing comment',
    mutate: (sandbox) {
      _replaceInSandboxFile(
        sandbox,
        '.github/workflows/perf_nightly.yaml',
        'run: |',
        'run: | # nightly fuzz',
      );
    },
  ),
  _YamlCompatibilityScenario(
    name: 'folded block header with trailing comment',
    mutate: (sandbox) {
      _replaceInSandboxFile(
        sandbox,
        '.github/workflows/perf_nightly.yaml',
        'run: dart run tool/bench/run_load_profiles.dart --profile=full --output=build/bench/load_profiles_full.json',
        'run: >- # folded equivalent\n'
            '          dart run tool/bench/run_load_profiles.dart --profile=full\n'
            '          --output=build/bench/load_profiles_full.json',
      );
    },
  ),
  _YamlCompatibilityScenario(
    name: 'folded block header with explicit indentation indicator',
    mutate: (sandbox) {
      _replaceInSandboxFile(
        sandbox,
        '.github/workflows/perf_nightly.yaml',
        'run: dart run tool/bench/run_load_profiles.dart --profile=full --output=build/bench/load_profiles_full.json',
        'run: >2-\n'
            '          dart run tool/bench/run_load_profiles.dart --profile=full\n'
            '          --output=build/bench/load_profiles_full.json',
      );
    },
  ),
  _YamlCompatibilityScenario(
    name: 'double-quoted run scalar with trailing comment',
    mutate: (sandbox) {
      _replaceInSandboxFile(
        sandbox,
        '.github/workflows/perf_nightly.yaml',
        'run: flutter pub get',
        'run: "flutter pub get" # pinned for readability',
      );
    },
  ),
];

const List<String> _canonicalTriggerEntries = <String>[
  'lib/iwb_canvas_engine.dart',
  'tool/**',
  'test/tool/**',
  'test/tool/support/guardrail_fixture_manifest.dart',
  'test/tool/support/guardrail_fixture_writer.dart',
  'test/tool/support/guardrails_sandbox_support.dart',
  'test/tool/support/import_boundaries_sandbox_support.dart',
  'test/tool/support/tool_diagnostic_matchers.dart',
  'test/tool/support/tool_process_test_support.dart',
  'test/tool/support/public_entrypoint_contract.dart',
  'pubspec.yaml',
  'pubspec.lock',
];

const String _toolTestJobsExpr = r'${{ steps.test-jobs.outputs.jobs }}';
const String _coverageJobsExpr = r'${{ steps.test-jobs.outputs.jobs }}';
const String _coverageJobsRun = r'''JOBS="$(getconf _NPROCESSORS_ONLN)"
if [ "$JOBS" -gt 1 ]; then
  JOBS=$((JOBS - 1))
fi
echo "jobs=$JOBS" >> "$GITHUB_OUTPUT"''';
const String _toolJobsRun = r'''JOBS="$(getconf _NPROCESSORS_ONLN)"
if [ "$JOBS" -gt 1 ]; then
  JOBS=$((JOBS - 1))
fi
if [ "$JOBS" -gt 6 ]; then
  JOBS=6
fi
echo "jobs=$JOBS" >> "$GITHUB_OUTPUT"''';

Future<Directory> _createSandbox() {
  return createToolSandbox(
    tempPrefix: 'iwb_canvas_engine_verification_contract_',
    toolFiles: const <String>[
      'tool/check_verification_contract.dart',
      'tool/src/verification_contract',
    ],
    includeAnalyzer: false,
  );
}

void _replaceInSandboxFile(
  Directory sandbox,
  String relativePath,
  String oldText,
  String newText,
) {
  final file = File('${sandbox.path}/$relativePath');
  final original = file.readAsStringSync();
  final updated = original.replaceFirst(oldText, newText);
  expect(
    updated,
    isNot(equals(original)),
    reason: 'Expected to update $relativePath',
  );
  file.writeAsStringSync(updated);
}

String _indentBlock(String value, int spaces) {
  final prefix = ' ' * spaces;
  return value.split('\n').map((line) => '$prefix$line').join('\n');
}

void _writeCanonicalCiWorkflow(
  Directory sandbox, {
  List<String>? triggerEntries,
  String? removeRun,
  String? extraStaticChecksRun,
}) {
  final staticChecksRuns = <String>[
    'flutter pub get',
    'dart format --output=none --set-exit-if-changed lib test example/lib example/test tool',
    'flutter analyze',
    if (extraStaticChecksRun != null && extraStaticChecksRun != removeRun)
      extraStaticChecksRun,
    'flutter pub get',
    'flutter analyze lib test',
    'flutter test --no-pub test',
    'dart run tool/check_verification_contract.dart',
    'dart run tool/check_import_boundaries.dart',
    'dart run tool/check_public_api_surface.dart',
    'dart run tool/check_guardrails.dart',
    'dart run tool/check_invariant_coverage.dart',
  ].where((entry) => entry != removeRun).toList(growable: false);

  writeSandboxFile(sandbox, '.github/workflows/ci.yaml', '''
name: CI

jobs:
  tool-test-changes:
    steps:
      - name: Detect tool-test-impacting changes
        with:
          filters: |
            tool_tests:
${(triggerEntries ?? _canonicalTriggerEntries).map((entry) => "              - '$entry'").join('\n')}

  static-checks:
    steps:
      - name: Pub get
        run: ${staticChecksRuns[0]}
      - name: Format
        run: ${staticChecksRuns[1]}
      - name: Analyze
        run: ${staticChecksRuns[2]}
      ${staticChecksRuns.contains('dcm analyze .') ? '- name: DCM analyze\n        run: dcm analyze .' : ''}
      - name: Example pub get
        working-directory: example
        run: ${staticChecksRuns.contains('flutter pub get') ? 'flutter pub get' : 'echo missing'}
      - name: Example analyze
        working-directory: example
        run: ${staticChecksRuns.contains('flutter analyze lib test') ? 'flutter analyze lib test' : 'flutter test --no-pub test'}
      - name: Example test
        working-directory: example
        run: ${staticChecksRuns.contains('flutter test --no-pub test') ? 'flutter test --no-pub test' : 'dart run tool/check_verification_contract.dart'}
      - name: Verification contract
        run: ${staticChecksRuns.contains('dart run tool/check_verification_contract.dart') ? 'dart run tool/check_verification_contract.dart' : 'dart run tool/check_import_boundaries.dart'}
      - name: Import boundaries
        run: ${staticChecksRuns.contains('dart run tool/check_import_boundaries.dart') ? 'dart run tool/check_import_boundaries.dart' : 'dart run tool/check_public_api_surface.dart'}
      - name: Public API surface
        run: ${staticChecksRuns.contains('dart run tool/check_public_api_surface.dart') ? 'dart run tool/check_public_api_surface.dart' : 'dart run tool/check_guardrails.dart'}
      - name: Guardrails
        run: ${staticChecksRuns.contains('dart run tool/check_guardrails.dart') ? 'dart run tool/check_guardrails.dart' : 'dart run tool/check_invariant_coverage.dart'}
      - name: Invariant coverage
        run: ${staticChecksRuns.contains('dart run tool/check_invariant_coverage.dart') ? 'dart run tool/check_invariant_coverage.dart' : 'echo missing'}

  tests-coverage:
    steps:
      - name: Pub get
        run: ${removeRun == 'flutter pub get' ? 'echo missing' : 'flutter pub get'}
      - name: Coverage jobs
        run: |
${_indentBlock(_coverageJobsRun, 10)}
      - name: Coverage test
        run: ${removeRun == 'flutter test --coverage --no-pub --exclude-tags=tool -j "$_coverageJobsExpr"' ? 'dart run tool/check_coverage.dart' : 'flutter test --coverage --no-pub --exclude-tags=tool -j "$_coverageJobsExpr"'}
      - name: Coverage check
        run: ${removeRun == 'dart run tool/check_coverage.dart' ? 'echo missing' : 'dart run tool/check_coverage.dart'}

  tool-tests:
    steps:
      - name: Pub get
        run: ${removeRun == 'flutter pub get' ? 'echo missing' : 'flutter pub get'}
      - name: Tool jobs
        run: |
${_indentBlock(_toolJobsRun, 10)}
      - name: Tool tests
        run: ${removeRun == 'dart run tool/run_tool_tests.dart --jobs="$_toolTestJobsExpr"' ? 'echo missing' : 'dart run tool/run_tool_tests.dart --jobs="$_toolTestJobsExpr"'}

  release-hygiene:
    steps:
      - name: Pub get
        run: ${removeRun == 'flutter pub get' ? 'echo missing' : 'flutter pub get'}
      - name: Dartdoc
        run: ${removeRun == 'dart doc' ? 'echo missing' : 'dart doc'}
      - name: Publish dry-run
        run: ${removeRun == 'dart pub publish --dry-run' ? 'echo missing' : 'dart pub publish --dry-run'}
''');
}

void _writeCanonicalPerfNightlyWorkflow(
  Directory sandbox, {
  String? removeRun,
  String? extraRun,
  String fuzzRunHeader = '|',
  String loadProfilesRunHeader = '',
  String? loadProfilesRunBody,
}) {
  const fuzzRun = '''
JOBS="\$(getconf _NPROCESSORS_ONLN)"
if [ "\$JOBS" -gt 1 ]; then
  JOBS=\$((JOBS - 1))
fi
flutter test test/controller/scene_controller_randomized_txn_test.dart --no-pub -j "\$JOBS"
''';
  final runEntries = <String>[
    'flutter pub get',
    fuzzRun,
    'dart run tool/bench/run_load_profiles.dart --profile=full --output=build/bench/load_profiles_full.json',
    'dart run tool/bench/diff_load_profiles.dart --profile=full --baseline=tool/bench/baselines/load_profiles_full_baseline.json --current=build/bench/load_profiles_full.json --output=build/bench/load_profiles_full_diff.json',
  ].where((entry) => entry != removeRun).toList();
  if (extraRun != null && extraRun != removeRun) {
    runEntries.add(extraRun);
  }

  writeSandboxFile(sandbox, '.github/workflows/perf_nightly.yaml', '''
name: Perf Nightly

jobs:
  perf:
    steps:
      - name: Pub get
        run: ${runEntries[0]}
      - name: Randomized txn fuzz (nightly profile)
        run: $fuzzRunHeader
${runEntries.contains(fuzzRun) ? fuzzRun.split('\n').map((line) => '          $line').join('\n') : '          ${runEntries[0]}'}
      - name: Load profiles (full)
${loadProfilesRunBody != null ? '        run: $loadProfilesRunHeader\n${loadProfilesRunBody.split('\n').map((line) => '          $line').join('\n')}' : '        run: ${runEntries.contains('dart run tool/bench/run_load_profiles.dart --profile=full --output=build/bench/load_profiles_full.json') ? 'dart run tool/bench/run_load_profiles.dart --profile=full --output=build/bench/load_profiles_full.json' : runEntries[0]}'}
      - name: Diff full benchmark report vs baseline
        run: ${runEntries.contains('dart run tool/bench/diff_load_profiles.dart --profile=full --baseline=tool/bench/baselines/load_profiles_full_baseline.json --current=build/bench/load_profiles_full.json --output=build/bench/load_profiles_full_diff.json') ? 'dart run tool/bench/diff_load_profiles.dart --profile=full --baseline=tool/bench/baselines/load_profiles_full_baseline.json --current=build/bench/load_profiles_full.json --output=build/bench/load_profiles_full_diff.json' : runEntries.last}
${extraRun == null ? '' : '''
      - name: Unexpected extra run
        run: ${runEntries.last}
'''}
''');
}

class _YamlCompatibilityScenario {
  const _YamlCompatibilityScenario({required this.name, required this.mutate});

  final String name;
  final void Function(Directory sandbox) mutate;
}
