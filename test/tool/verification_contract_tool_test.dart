@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/tool_process_test_support.dart';

void main() {
  group('tool/check_verification_contract.dart', () {
    test('passes when AGENTS and CI stay aligned with the registry', () async {
      final sandbox = await _createSandbox();
      try {
        _writeCanonicalAgents(sandbox);
        _writeCanonicalCiWorkflow(sandbox);
        _writeCanonicalPerfNightlyWorkflow(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'check_verification_contract.dart',
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(result.stdout.toString(), contains('Verification contract OK'));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('fails when AGENTS verification instruction drifts', () async {
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

        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('Verification instruction drifted in AGENTS.md.'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('fails when CI run surface drifts', () async {
      final sandbox = await _createSandbox();
      try {
        _writeCanonicalAgents(sandbox);
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

    test('fails when CI tool-test trigger surface drifts', () async {
      final sandbox = await _createSandbox();
      try {
        _writeCanonicalAgents(sandbox);
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
        _writeCanonicalAgents(sandbox);
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
  });
}

const List<String> _canonicalTriggerEntries = <String>[
  'lib/iwb_canvas_engine.dart',
  'tool/**',
  'test/tool/**',
  'test/tool/support/guardrails_tool_test_support.dart',
  'test/tool/support/tool_process_test_support.dart',
  'test/tool/support/public_entrypoint_contract.dart',
  'pubspec.yaml',
  'pubspec.lock',
];

const String _toolTestJobsExpr = r'${{ steps.test-jobs.outputs.jobs }}';
const String _coverageJobsExpr = r'${{ steps.test-jobs.outputs.jobs }}';

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

void _writeCanonicalAgents(Directory sandbox) {
  writeSandboxFile(sandbox, 'AGENTS.md', '''
# Product boundary

## Verification

After any code change, run `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->` and provide every modified, added, renamed, or deleted repository-relative path as one line from that file or from stdin.
- Documentation-only changes do not require the full Flutter pipeline unless
  the task also changes code, tooling contracts, or executable examples.
''');
}

void _writeCanonicalCiWorkflow(
  Directory sandbox, {
  List<String>? triggerEntries,
  String? removeRun,
}) {
  final runEntries = <String>[
    'dcm analyze .',
    'dart format --output=none --set-exit-if-changed lib test example/lib example/test tool',
    'flutter analyze',
    'flutter analyze lib test',
    'dart run tool/check_verification_contract.dart',
    'dart run tool/check_import_boundaries.dart',
    'dart run tool/check_public_api_surface.dart',
    'dart run tool/check_guardrails.dart',
    'dart run tool/check_invariant_coverage.dart',
    'flutter test --no-pub test',
    'flutter test --coverage --no-pub --exclude-tags=tool -j "$_coverageJobsExpr"',
    'dart run tool/check_coverage.dart',
    'dart run tool/run_tool_tests.dart --jobs="$_toolTestJobsExpr"',
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
      - name: DCM analyze
        run: ${runEntries[0]}
      - name: Format
        run: ${runEntries[1]}
      - name: Analyze
        run: ${runEntries[2]}
      - name: Example analyze
        working-directory: example
        run: ${runEntries[3]}
      - name: Verification contract
        run: ${runEntries.contains('dart run tool/check_verification_contract.dart') ? 'dart run tool/check_verification_contract.dart' : 'dart run tool/check_import_boundaries.dart'}
      - name: Import boundaries
        run: ${runEntries.contains('dart run tool/check_import_boundaries.dart') ? 'dart run tool/check_import_boundaries.dart' : 'dart run tool/check_public_api_surface.dart'}
      - name: Public API surface
        run: ${runEntries.contains('dart run tool/check_public_api_surface.dart') ? 'dart run tool/check_public_api_surface.dart' : 'dart run tool/check_guardrails.dart'}
      - name: Guardrails
        run: ${runEntries.contains('dart run tool/check_guardrails.dart') ? 'dart run tool/check_guardrails.dart' : 'dart run tool/check_invariant_coverage.dart'}
      - name: Invariant coverage
        run: ${runEntries.contains('dart run tool/check_invariant_coverage.dart') ? 'dart run tool/check_invariant_coverage.dart' : 'flutter test --no-pub test'}
      - name: Example test
        working-directory: example
        run: ${runEntries.contains('flutter test --no-pub test') ? 'flutter test --no-pub test' : 'flutter test --coverage --no-pub --exclude-tags=tool'}

  tests-coverage:
    steps:
      - name: Coverage test
        run: ${runEntries.contains('flutter test --coverage --no-pub --exclude-tags=tool -j "$_coverageJobsExpr"') ? 'flutter test --coverage --no-pub --exclude-tags=tool -j "$_coverageJobsExpr"' : 'dart run tool/check_coverage.dart'}
      - name: Coverage check
        run: ${runEntries.contains('dart run tool/check_coverage.dart') ? 'dart run tool/check_coverage.dart' : 'echo missing'}

  tool-tests:
    steps:
      - name: Tool tests
        run: ${runEntries.contains('dart run tool/run_tool_tests.dart --jobs="$_toolTestJobsExpr"') ? 'dart run tool/run_tool_tests.dart --jobs="$_toolTestJobsExpr"' : 'echo missing'}
''');
}

void _writeCanonicalPerfNightlyWorkflow(
  Directory sandbox, {
  String? removeRun,
}) {
  final runEntries = <String>[
    'flutter pub get',
    'dart run tool/bench/run_load_profiles.dart --profile=full --output=build/bench/load_profiles_full.json',
    'dart run tool/bench/diff_load_profiles.dart --profile=full --baseline=tool/bench/baselines/load_profiles_full_baseline.json --current=build/bench/load_profiles_full.json --output=build/bench/load_profiles_full_diff.json',
  ].where((entry) => entry != removeRun).toList(growable: false);

  writeSandboxFile(sandbox, '.github/workflows/perf_nightly.yaml', '''
name: Perf Nightly

jobs:
  perf:
    steps:
      - name: Pub get
        run: ${runEntries[0]}
      - name: Load profiles (full)
        run: ${runEntries.contains('dart run tool/bench/run_load_profiles.dart --profile=full --output=build/bench/load_profiles_full.json') ? 'dart run tool/bench/run_load_profiles.dart --profile=full --output=build/bench/load_profiles_full.json' : runEntries[0]}
      - name: Diff full benchmark report vs baseline
        run: ${runEntries.contains('dart run tool/bench/diff_load_profiles.dart --profile=full --baseline=tool/bench/baselines/load_profiles_full_baseline.json --current=build/bench/load_profiles_full.json --output=build/bench/load_profiles_full_diff.json') ? 'dart run tool/bench/diff_load_profiles.dart --profile=full --baseline=tool/bench/baselines/load_profiles_full_baseline.json --current=build/bench/load_profiles_full.json --output=build/bench/load_profiles_full_diff.json' : runEntries.last}
''');
}
