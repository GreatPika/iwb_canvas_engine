# Verification

- For new production files under `lib/**`, run `dcm calculate-metrics` and keep
  them green against the current thresholds.
- Run `dcm calculate-metrics` for legacy files only when adding a large new
  unit, substantially rewriting a hotspot, or validating a suspected metric
  regression.
- Use `dart format lib test example/lib example/test tool` when you need to
  apply formatting locally. Keep the required check below as the non-mutating
  verification step.
- Run package and example tests via the MCP test runner. Use only these
  canonical shard presets:
  - `core`: root `.` paths `test/core`
  - `model_contract`: root `.` paths `test/model`, `test/serialization`,
    `test/contract`, `test/public_api`, `test/entrypoints`
  - `controller_internal`: root `.` paths `test/controller/internal`
  - `controller`: root `.` paths `test/controller/core`,
    `test/controller/commands`,
    `test/controller/scene_controller_randomized_txn_test.dart`,
    `test/controller/scene_invariants_test.dart`,
    `test/controller/scene_snapshot_invariant_assertions_test.dart`
  - `render_view`: root `.` paths `test/render`, `test/view`
  - `interactive`: root `.` paths `test/interactive`
  - `example`: root `example/` paths `test`
- In MCP runs, pass one directory or file per `paths` entry. Do not use shell
  globs or raw `flutter test` CLI flags; use only MCP-supported
  `testRunnerArgs`.
- Coverage is shell-only: MCP test runs do not generate `coverage/lcov.info`.
- Run heavyweight Flutter invocations sequentially. Do not run
  `flutter test --coverage ...` in parallel with `dart run tool/run_tool_tests.dart`.
- Run tool tests only when the change touches tool-test surface. The trigger
  list in this file must stay identical to `.github/workflows/ci.yaml`:
  - `tool/**`
  - `test/tool/**`
  - `test/tool/support/guardrails_tool_test_support.dart`
  - `test/tool/support/tool_process_test_support.dart`
  - `test/tool/support/public_entrypoint_contract.dart`
  - `pubspec.yaml`
  - `pubspec.lock`
- Run tool tests with `dart run tool/run_tool_tests.dart` (use `--jobs=N`
  when you need to override parallelism).
- Documentation-only changes do not require the full Flutter pipeline unless the
  task also changes code, tooling contracts, or executable examples.
- Required checks for code changes:
  1. Non-mutating formatting check:
     `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
  2. `flutter analyze`
  3. `(cd example && flutter analyze lib test)`
  4. `dcm analyze .`
  5. `dart run tool/check_import_boundaries.dart`
  6. `dart run tool/check_public_api_surface.dart`
  7. `dart run tool/check_guardrails.dart`
  8. `dart run tool/check_invariant_coverage.dart`
  9. Run these MCP test shard presets:
     - `core`
     - `model_contract`
     - `controller_internal`
     - `controller`
     - `render_view`
     - `interactive`
     - `example`
  10. `flutter test --coverage --no-pub --exclude-tags=tool`
  11. `dart run tool/check_coverage.dart`
  12. Run `dart run tool/run_tool_tests.dart` when the tool-test trigger list
      above matches the change.
