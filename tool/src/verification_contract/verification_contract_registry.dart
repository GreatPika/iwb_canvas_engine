import 'verification_contract_models.dart';

const String requiredCodeChangePreset = 'required_code_change';
const String ciWorkflowPath = '.github/workflows/ci.yaml';
const String perfNightlyWorkflowPath = '.github/workflows/perf_nightly.yaml';
const String apiDocsPagesWorkflowPath = '.github/workflows/api_docs_pages.yaml';
const String windowsInstallerWorkflowPath =
    '.github/workflows/windows_installer.yaml';
const String toolTestFilterName = 'tool_tests';

const String ciToolTestJobsExpression = r'${{ steps.test-jobs.outputs.jobs }}';
const String ciCoverageJobsExpression = r'${{ steps.test-jobs.outputs.jobs }}';
const String ciCoverageJobsCommand =
    'JOBS="\$(getconf _NPROCESSORS_ONLN)"\n'
    'if [ "\$JOBS" -gt 1 ]; then\n'
    '  JOBS=\$((JOBS - 1))\n'
    'fi\n'
    'echo "jobs=\$JOBS" >> "\$GITHUB_OUTPUT"';
const String ciToolJobsCommand =
    'JOBS="\$(getconf _NPROCESSORS_ONLN)"\n'
    'if [ "\$JOBS" -gt 1 ]; then\n'
    '  JOBS=\$((JOBS - 1))\n'
    'fi\n'
    'if [ "\$JOBS" -gt 6 ]; then\n'
    '  JOBS=6\n'
    'fi\n'
    'echo "jobs=\$JOBS" >> "\$GITHUB_OUTPUT"';
const String perfNightlyFuzzCommand =
    'JOBS="\$(getconf _NPROCESSORS_ONLN)"\n'
    'if [ "\$JOBS" -gt 1 ]; then\n'
    '  JOBS=\$((JOBS - 1))\n'
    'fi\n'
    'flutter test test/controller/scene_controller_randomized_txn_test.dart --no-pub -j "\$JOBS"';
const String apiDocsPagesGenerateSiteCommand =
    'set -euo pipefail\n'
    '\n'
    'repo_name="\${GITHUB_REPOSITORY#*/}"\n'
    'base_href="/\${repo_name}/demo/"\n'
    '\n'
    'rm -rf build/site\n'
    'mkdir -p build/site\n'
    '\n'
    'dart doc --output build/site/api\n'
    '\n'
    'pushd example\n'
    'flutter pub get\n'
    'flutter build web --release --base-href "\${base_href}"\n'
    'popd\n'
    '\n'
    'mkdir -p build/site/demo\n'
    'cp -a example/build/web/. build/site/demo/\n'
    '\n'
    "cat > build/site/index.html <<'HTML'\n"
    '<!doctype html>\n'
    '<html lang="en">\n'
    '  <head>\n'
    '    <meta charset="utf-8" />\n'
    '    <meta name="viewport" content="width=device-width,initial-scale=1" />\n'
    '    <title>iwb_canvas_engine</title>\n'
    '    <style>\n'
    '      :root { color-scheme: light dark; }\n'
    '      body { font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; margin: 40px; line-height: 1.45; }\n'
    '      .card { max-width: 720px; padding: 20px 22px; border: 1px solid rgba(127,127,127,.25); border-radius: 12px; }\n'
    '      a { font-weight: 600; }\n'
    '      ul { margin: 10px 0 0; padding-left: 18px; }\n'
    '    </style>\n'
    '  </head>\n'
    '  <body>\n'
    '    <div class="card">\n'
    '      <h1>iwb_canvas_engine</h1>\n'
    '      <p>GitHub Pages site for API reference and a live demo built from <code>example/</code>.</p>\n'
    '      <ul>\n'
    '        <li><a href="./demo/">Web demo</a></li>\n'
    '        <li><a href="./api/">API reference (Dartdoc)</a></li>\n'
    '      </ul>\n'
    '    </div>\n'
    '  </body>\n'
    '</html>\n'
    'HTML';
const String windowsInstallerMetadataCommand =
    r'$pubspec = Get-Content pubspec.yaml -Raw'
    '\n'
    r"if ($pubspec -notmatch '(?m)^version:\s*([0-9A-Za-z\.\+\-]+)\s*$') {"
    '\n'
    r'  throw "Could not resolve package version from pubspec.yaml"'
    '\n'
    r'}'
    '\n'
    '\n'
    r'$packageVersion = $Matches[1]'
    '\n'
    r"$installerVersion = $packageVersion.Split('+')[0]"
    '\n'
    r"$safeVersion = $packageVersion -replace '[^0-9A-Za-z\.\-]+', '-'"
    '\n'
    r"$outputDir = Join-Path $env:GITHUB_WORKSPACE 'build\installer'"
    '\n'
    '\n'
    r'"package_version=$packageVersion" >> $env:GITHUB_OUTPUT'
    '\n'
    r'"installer_version=$installerVersion" >> $env:GITHUB_OUTPUT'
    '\n'
    r'"safe_version=$safeVersion" >> $env:GITHUB_OUTPUT'
    '\n'
    r'"output_dir=$outputDir" >> $env:GITHUB_OUTPUT';
const String windowsInstallerBuildCommand =
    r"New-Item -ItemType Directory -Force -Path '${{ steps.metadata.outputs.output_dir }}' | Out-Null"
    '\n'
    '\n'
    r"& 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe' `"
    '\n'
    r"  '/DMyAppVersion=${{ steps.metadata.outputs.installer_version }}' `"
    '\n'
    r"  '/DMyOutputDir=${{ steps.metadata.outputs.output_dir }}' `"
    '\n'
    r"  '/DMyOutputBaseFilename=iwb_canvas_engine_example_setup_${{ steps.metadata.outputs.safe_version }}' `"
    '\n'
    r"  '/DMySourceDir=${{ github.workspace }}\example\build\windows\x64\runner\Release' `"
    '\n'
    r"  '.\tool\windows\example_installer.iss'";

final VerificationGraph verificationGraph = VerificationGraph(
  steps: const <String, VerificationStepDefinition>{
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
    'architecture_atlas': VerificationStepDefinition(
      id: 'architecture_atlas',
      kind: VerificationStepKind.driftCheck,
      command: 'dart run tool/check_architecture_atlas.dart',
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
  },
  scopes: const <VerificationScopeDefinition>[
    VerificationScopeDefinition(id: 'core', stepId: 'scope_core'),
    VerificationScopeDefinition(
      id: 'model_contract',
      stepId: 'scope_model_contract',
    ),
    VerificationScopeDefinition(
      id: 'controller_internal',
      stepId: 'scope_controller_internal',
    ),
    VerificationScopeDefinition(id: 'controller', stepId: 'scope_controller'),
    VerificationScopeDefinition(id: 'render_view', stepId: 'scope_render_view'),
    VerificationScopeDefinition(id: 'interactive', stepId: 'scope_interactive'),
    VerificationScopeDefinition(id: 'example', stepId: 'scope_example'),
  ],
  presets: const <String, VerificationPresetDefinition>{
    requiredCodeChangePreset: VerificationPresetDefinition(
      id: requiredCodeChangePreset,
      stepIds: <String>[
        'format_check',
        'analyze',
        'example_analyze',
        'dcm_analyze',
        'verification_contract',
        'architecture_atlas',
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
      ],
      runsToolTestsOnMatchingChanges: true,
    ),
  },
  workflows: const <String, VerificationWorkflowDefinition>{
    ciWorkflowPath: VerificationWorkflowDefinition(
      path: ciWorkflowPath,
      runExpectations: <VerificationRunExpectation>[
        VerificationRunExpectation(command: 'flutter pub get'),
        VerificationRunExpectation(
          command:
              'dart format --output=none --set-exit-if-changed lib test '
              'example/lib example/test tool',
        ),
        VerificationRunExpectation(command: 'flutter analyze'),
        VerificationRunExpectation(command: 'flutter pub get', cwd: 'example'),
        VerificationRunExpectation(
          command: 'flutter analyze lib test',
          cwd: 'example',
        ),
        VerificationRunExpectation(
          command: 'flutter test --no-pub test',
          cwd: 'example',
        ),
        VerificationRunExpectation(
          command: 'dart run tool/check_verification_contract.dart',
        ),
        VerificationRunExpectation(
          command: 'dart run tool/check_architecture_atlas.dart',
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
        VerificationRunExpectation(command: 'flutter pub get'),
        VerificationRunExpectation(command: ciCoverageJobsCommand),
        VerificationRunExpectation(
          command:
              'flutter test --coverage --no-pub --exclude-tags=tool '
              '-j "$ciCoverageJobsExpression"',
        ),
        VerificationRunExpectation(
          command: 'dart run tool/check_coverage.dart',
        ),
        VerificationRunExpectation(command: 'flutter pub get'),
        VerificationRunExpectation(command: ciToolJobsCommand),
        VerificationRunExpectation(
          command:
              'dart run tool/run_tool_tests.dart '
              '--jobs="$ciToolTestJobsExpression"',
        ),
        VerificationRunExpectation(command: 'flutter pub get'),
        VerificationRunExpectation(command: 'dart doc'),
        VerificationRunExpectation(command: 'dart pub publish --dry-run'),
      ],
      ownsEntireExecutableRunSurface: true,
      changeFilters: <String, List<String>>{
        toolTestFilterName: <String>[
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
        ],
      },
    ),
    perfNightlyWorkflowPath: VerificationWorkflowDefinition(
      path: perfNightlyWorkflowPath,
      runExpectations: <VerificationRunExpectation>[
        VerificationRunExpectation(command: 'flutter pub get'),
        VerificationRunExpectation(command: perfNightlyFuzzCommand),
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
      ],
      ownsEntireExecutableRunSurface: true,
    ),
    apiDocsPagesWorkflowPath: VerificationWorkflowDefinition(
      path: apiDocsPagesWorkflowPath,
      runExpectations: <VerificationRunExpectation>[
        VerificationRunExpectation(command: 'flutter pub get'),
        VerificationRunExpectation(command: apiDocsPagesGenerateSiteCommand),
        VerificationRunExpectation(command: 'touch build/site/.nojekyll'),
      ],
      ownsEntireExecutableRunSurface: true,
    ),
    windowsInstallerWorkflowPath: VerificationWorkflowDefinition(
      path: windowsInstallerWorkflowPath,
      runExpectations: <VerificationRunExpectation>[
        VerificationRunExpectation(command: 'flutter pub get'),
        VerificationRunExpectation(command: 'flutter pub get', cwd: 'example'),
        VerificationRunExpectation(
          command: 'flutter build windows --release',
          cwd: 'example',
        ),
        VerificationRunExpectation(command: windowsInstallerMetadataCommand),
        VerificationRunExpectation(
          command: 'choco install innosetup --no-progress -y',
        ),
        VerificationRunExpectation(command: windowsInstallerBuildCommand),
      ],
      ownsEntireExecutableRunSurface: true,
    ),
  },
);

VerificationPresetDefinition get requiredCodeChangePresetDefinition {
  final preset = verificationGraph.preset(requiredCodeChangePreset);
  if (preset == null) {
    throw StateError('Missing verification preset $requiredCodeChangePreset');
  }
  return preset;
}

VerificationWorkflowDefinition get ciWorkflowDefinition {
  final workflow = verificationGraph.workflow(ciWorkflowPath);
  if (workflow == null) {
    throw StateError('Missing verification workflow $ciWorkflowPath');
  }
  return workflow;
}

VerificationWorkflowDefinition get perfNightlyWorkflowDefinition {
  final workflow = verificationGraph.workflow(perfNightlyWorkflowPath);
  if (workflow == null) {
    throw StateError('Missing verification workflow $perfNightlyWorkflowPath');
  }
  return workflow;
}

Map<String, VerificationStepDefinition> get verificationSteps =>
    verificationGraph.steps;

List<String> get verificationScopes => verificationGraph.scopeIds;

Map<String, String> get verificationScopeStepIds =>
    verificationGraph.scopeStepIds;

List<String> get requiredCodeChangeStepIds =>
    requiredCodeChangePresetDefinition.stepIds;

List<String> get toolTestTriggerEntries {
  final triggers = ciWorkflowDefinition.changeFilters[toolTestFilterName];
  if (triggers == null) {
    throw StateError(
      'Missing change filter $toolTestFilterName in $ciWorkflowPath',
    );
  }
  return triggers;
}

List<VerificationRunExpectation> get ciWorkflowRunExpectations =>
    ciWorkflowDefinition.runExpectations;

List<VerificationRunExpectation> get perfNightlyWorkflowRunExpectations =>
    perfNightlyWorkflowDefinition.runExpectations;

List<VerificationWorkflowDefinition> get verificationWorkflowDefinitions =>
    List<VerificationWorkflowDefinition>.unmodifiable(
      verificationGraph.workflows.values,
    );
