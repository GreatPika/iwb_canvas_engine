import 'verification_contract_models.dart';

const String requiredCodeChangePreset = 'required_code_change';
const String perfNightlyWorkflowPath = '.github/workflows/perf_nightly.yaml';

const List<String> verificationScopes = <String>[
  'core',
  'model_contract',
  'controller_internal',
  'controller',
  'render_view',
  'interactive',
  'example',
];

const List<String> toolTestTriggerEntries = <String>[
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

const String agentsVerificationInstruction =
    'After any code change, run `dart run tool/run_verification_preset.dart '
    'run --preset=required_code_change --changed-paths-file=<path-or->` and '
    'provide every modified, added, renamed, or deleted repository-relative '
    'path as one line from that file or from stdin.';

const String ciToolTestJobsExpression = r'${{ steps.test-jobs.outputs.jobs }}';
const String ciCoverageJobsExpression = r'${{ steps.test-jobs.outputs.jobs }}';

const List<VerificationRunExpectation> ciWorkflowRunExpectations =
    <VerificationRunExpectation>[
      VerificationRunExpectation(command: 'dcm analyze .'),
      VerificationRunExpectation(
        command:
            'dart format --output=none --set-exit-if-changed lib test '
            'example/lib example/test tool',
      ),
      VerificationRunExpectation(command: 'flutter analyze'),
      VerificationRunExpectation(
        command: 'flutter analyze lib test',
        cwd: 'example',
      ),
      VerificationRunExpectation(
        command: 'dart run tool/check_verification_contract.dart',
      ),
      VerificationRunExpectation(
        command: 'dart run tool/check_import_boundaries.dart',
      ),
      VerificationRunExpectation(
        command: 'dart run tool/check_public_api_surface.dart',
      ),
      VerificationRunExpectation(
        command: 'dart run tool/check_guardrails.dart',
      ),
      VerificationRunExpectation(
        command: 'dart run tool/check_invariant_coverage.dart',
      ),
      VerificationRunExpectation(
        command: 'flutter test --no-pub test',
        cwd: 'example',
      ),
      VerificationRunExpectation(
        command:
            'flutter test --coverage --no-pub --exclude-tags=tool '
            '-j "$ciCoverageJobsExpression"',
      ),
      VerificationRunExpectation(command: 'dart run tool/check_coverage.dart'),
      VerificationRunExpectation(
        command:
            'dart run tool/run_tool_tests.dart '
            '--jobs="$ciToolTestJobsExpression"',
      ),
    ];

const List<VerificationRunExpectation> perfNightlyWorkflowRunExpectations =
    <VerificationRunExpectation>[
      VerificationRunExpectation(command: 'flutter pub get'),
      VerificationRunExpectation(
        command:
            'dart run tool/bench/run_load_profiles.dart '
            '--profile=full --output=build/bench/load_profiles_full.json',
      ),
      VerificationRunExpectation(
        command:
            'dart run tool/bench/diff_load_profiles.dart '
            '--profile=full '
            '--baseline=tool/bench/baselines/load_profiles_full_baseline.json '
            '--current=build/bench/load_profiles_full.json '
            '--output=build/bench/load_profiles_full_diff.json',
      ),
    ];

const Map<String, VerificationStepDefinition> verificationSteps =
    <String, VerificationStepDefinition>{
      'format_check': VerificationStepDefinition(
        id: 'format_check',
        kind: VerificationStepKind.shell,
        command:
            'dart format --output=none --set-exit-if-changed lib test '
            'example/lib example/test tool',
      ),
      'analyze': VerificationStepDefinition(
        id: 'analyze',
        kind: VerificationStepKind.shell,
        command: 'flutter analyze',
      ),
      'example_analyze': VerificationStepDefinition(
        id: 'example_analyze',
        kind: VerificationStepKind.shell,
        command: 'flutter analyze lib test',
        cwd: 'example',
      ),
      'dcm_analyze': VerificationStepDefinition(
        id: 'dcm_analyze',
        kind: VerificationStepKind.shell,
        command: 'dcm analyze .',
      ),
      'verification_contract': VerificationStepDefinition(
        id: 'verification_contract',
        kind: VerificationStepKind.driftCheck,
        command: 'dart run tool/check_verification_contract.dart',
      ),
      'import_boundaries': VerificationStepDefinition(
        id: 'import_boundaries',
        kind: VerificationStepKind.shell,
        command: 'dart run tool/check_import_boundaries.dart',
      ),
      'public_api_surface': VerificationStepDefinition(
        id: 'public_api_surface',
        kind: VerificationStepKind.shell,
        command: 'dart run tool/check_public_api_surface.dart',
      ),
      'guardrails': VerificationStepDefinition(
        id: 'guardrails',
        kind: VerificationStepKind.shell,
        command: 'dart run tool/check_guardrails.dart',
      ),
      'invariant_coverage': VerificationStepDefinition(
        id: 'invariant_coverage',
        kind: VerificationStepKind.shell,
        command: 'dart run tool/check_invariant_coverage.dart',
      ),
      'scope_core': VerificationStepDefinition(
        id: 'scope_core',
        kind: VerificationStepKind.shell,
        command: 'flutter test --no-pub test/core',
      ),
      'scope_model_contract': VerificationStepDefinition(
        id: 'scope_model_contract',
        kind: VerificationStepKind.shell,
        command:
            'flutter test --no-pub test/model test/serialization '
            'test/contract test/public_api test/entrypoints',
      ),
      'scope_controller_internal': VerificationStepDefinition(
        id: 'scope_controller_internal',
        kind: VerificationStepKind.shell,
        command: 'flutter test --no-pub test/controller/internal',
      ),
      'scope_controller': VerificationStepDefinition(
        id: 'scope_controller',
        kind: VerificationStepKind.shell,
        command:
            'flutter test --no-pub test/controller/core '
            'test/controller/commands '
            'test/controller/scene_controller_randomized_txn_test.dart '
            'test/controller/scene_invariants_test.dart '
            'test/controller/scene_snapshot_invariant_assertions_test.dart',
      ),
      'scope_render_view': VerificationStepDefinition(
        id: 'scope_render_view',
        kind: VerificationStepKind.shell,
        command: 'flutter test --no-pub test/render test/view',
      ),
      'scope_interactive': VerificationStepDefinition(
        id: 'scope_interactive',
        kind: VerificationStepKind.shell,
        command: 'flutter test --no-pub test/interactive',
      ),
      'scope_example': VerificationStepDefinition(
        id: 'scope_example',
        kind: VerificationStepKind.shell,
        command: 'flutter test --no-pub test',
        cwd: 'example',
      ),
      'coverage': VerificationStepDefinition(
        id: 'coverage',
        kind: VerificationStepKind.shell,
        command: 'flutter test --coverage --no-pub --exclude-tags=tool',
      ),
      'coverage_check': VerificationStepDefinition(
        id: 'coverage_check',
        kind: VerificationStepKind.shell,
        command: 'dart run tool/check_coverage.dart',
      ),
      'tool_tests': VerificationStepDefinition(
        id: 'tool_tests',
        kind: VerificationStepKind.toolTests,
        command: 'dart run tool/run_tool_tests.dart',
      ),
    };

const Map<String, String> verificationScopeStepIds = <String, String>{
  'core': 'scope_core',
  'model_contract': 'scope_model_contract',
  'controller_internal': 'scope_controller_internal',
  'controller': 'scope_controller',
  'render_view': 'scope_render_view',
  'interactive': 'scope_interactive',
  'example': 'scope_example',
};

const List<String> requiredCodeChangeStepIds = <String>[
  'format_check',
  'analyze',
  'example_analyze',
  'dcm_analyze',
  'verification_contract',
  'import_boundaries',
  'public_api_surface',
  'guardrails',
  'invariant_coverage',
  'scope_core',
  'scope_model_contract',
  'scope_controller_internal',
  'scope_controller',
  'scope_render_view',
  'scope_interactive',
  'scope_example',
  'coverage',
  'coverage_check',
];
