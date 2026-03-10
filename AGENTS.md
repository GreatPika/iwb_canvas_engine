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
- Use `dart format lib test example/lib example/test tool` when you need to
  apply formatting locally. Keep the required check below as the non-mutating
  verification step.
- Run package and example tests via the MCP test runner.
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
- Run `test/tool` file-by-file.
- Documentation-only changes do not require the full Flutter pipeline unless the
  task also changes code, tooling contracts, or executable examples.
- If `tool/invariant_registry.dart` changes, always run and report
  `dart run tool/check_invariant_coverage.dart`.

## Required checks for code changes

1. `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
2. `flutter analyze`
3. `(cd example && flutter analyze lib test)`
4. Run these MCP test shards:
   - `test/core`
   - `test/model test/serialization test/contract test/public_api test/entrypoints`
   - `test/controller/internal`
   - `test/controller/core test/controller/commands test/controller/*.dart`
   - `test/render test/view`
   - `test/interactive`
   - `example/test`
5. `dart run tool/check_coverage.dart`
6. `dart run tool/check_invariant_coverage.dart`
7. `dart run tool/check_guardrails.dart`
8. `dart run tool/check_import_boundaries.dart`
9. `dart run tool/check_public_api_surface.dart`
10. Run `test/tool` file-by-file when the tool-test trigger list above matches
    the change.

## Release hygiene

- Add user-visible changes under `## Unreleased` in `CHANGELOG.md`.
- Move `Unreleased` entries into a versioned section during release cut.
- Prefix breaking changes with `Breaking:`.
- Before publish, also run:
  - `dart doc`
  - `dart pub publish --dry-run`
