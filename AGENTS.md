# Product boundary

`iwb_canvas_engine` is a Flutter/Dart canvas engine package. It owns scene
modeling, rendering, input handling, and JSON serialization. It does not own
app UI, product workflows, or backend logic.

## Document map

- `README.md` for package overview and getting started.
- `API_GUIDE.md` for public API, runtime behavior, and migration notes.
- `ARCHITECTURE.md` for architecture, invariants, and module boundaries.
- `CHANGELOG.md` for released and unreleased user-visible changes.
- `DEVELOPMENT_PLAN.md` for the active roadmap.
- `tool/invariant_registry.dart` for invariant ids and ownership.

## Working rules

- Keep one source of truth for runtime state. Do not add sync glue.
- Group is ephemeral. Do not introduce a stored Group node.
- After completing a plan step, update the corresponding checkbox entries in
  `DEVELOPMENT_PLAN.md` and any linked step document so finished items are
  marked done in the same change.
- Public behavior changes must update:
  - `README.md`
  - `API_GUIDE.md`
  - `ARCHITECTURE.md` when invariants, architecture, or module ownership change
  - `CHANGELOG.md`
- Documentation should stay release-ready: concise, current, and free of stale
  implementation detail.

## Invariant discipline

- Add or modify invariant definitions in `tool/invariant_registry.dart`.
- Reference enforcement with exact `// INV:<id>` markers in `test/**` or `tool/**`.
- Keep `dart run tool/check_invariant_coverage.dart` green.

## Validation policy

- Run and report the standard checks for code changes.
- Keep `analysis_options.yaml` as the single source of truth for DCM metrics
  thresholds.
- For new production files under `lib/**`, run `dcm calculate-metrics` and keep
  them green against the current thresholds.
- Run `dcm calculate-metrics` for legacy files only when adding a large new
  unit, substantially rewriting a hotspot, or validating a suspected metric
  regression.
- Use `dart format lib test example/lib example/test tool` when you need to
  apply formatting locally. Keep the required check below as the non-mutating
  verification step. `dart format --output=none --set-exit-if-changed ...`
  must not write files, even though Dart may still print `Changed ...` for
  files that would need formatting.
- Run package and example tests via the MCP test runner.
- MCP test runs do not generate `coverage/lcov.info`; use
  `flutter test --coverage --no-pub --exclude-tags=tool` before
  `dart run tool/check_coverage.dart`.
- Run example-package tests from the `example/` project root so
  `package:iwb_canvas_engine_example/...` imports resolve correctly.
- Keep test runs sharded.
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
- If `tool/invariant_registry.dart` changes, always run and report
  `dart run tool/check_invariant_coverage.dart`.

## Required checks for code changes

1. Non-mutating formatting check:
   `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
2. `dcm analyze .`
3. `flutter analyze`
4. `(cd example && flutter analyze lib test)`
5. Run these MCP test shards:
   - `test/core`
   - `test/model test/serialization test/contract test/public_api test/entrypoints`
   - `test/controller/internal`
   - `test/controller/core test/controller/commands` plus controller-root
     `*_test.dart` files (the MCP runner does not expand shell globs)
   - `test/render test/view`
   - `test/interactive`
   - `example/test` with MCP root `example/`
6. `flutter test --coverage --no-pub --exclude-tags=tool`
7. `dart run tool/check_coverage.dart`
8. `dart run tool/check_invariant_coverage.dart`
9. `dart run tool/check_guardrails.dart`
10. `dart run tool/check_import_boundaries.dart`
11. `dart run tool/check_public_api_surface.dart`
12. Run `dart run tool/run_tool_tests.dart` when the tool-test trigger list
    above matches the change.

## Release hygiene

- Add user-visible changes under `## Unreleased` in `CHANGELOG.md`.
- Move `Unreleased` entries into a versioned section during release cut.
- Prefix breaking changes with `Breaking:`.
- Before publish, also run:
  - `dart doc`
  - `dart pub publish --dry-run`
