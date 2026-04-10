# Product boundary

`iwb_canvas_engine` is a Flutter/Dart canvas engine package. It owns scene
modeling, rendering, input handling, and JSON serialization. It does not own
app UI, product workflows, or backend logic.

## Document map

- `README.md` for package overview and getting started.
- `API_GUIDE.md` for public API, runtime behavior, and migration notes.
- `ARCHITECTURE.md` for architecture, invariants, and module boundaries.
- `CHANGELOG.md` for released and unreleased user-visible changes.
- `PLAN.md` for the active roadmap.

## Execution tracking

- After completing a plan step, update the corresponding checkbox entries in
  `PLAN.md` and any linked step document so finished items are
  marked done in the same change.

## Documentation hygiene

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

## Verification

After any code change, run `dart run tool/run_verification_preset.dart run --preset required_code_change --changed-paths-file=<path>` and write every modified, added, renamed, or deleted repository-relative path to that file, one path per line.
- For new production files under `lib/**`, run `dcm calculate-metrics` and keep
  them green against the current thresholds.
- Run `dcm calculate-metrics` for legacy files only when adding a large new
  unit, substantially rewriting a hotspot, or validating a suspected metric
  regression.
- Do not run package tests with plain `dart test` in this repository. Use the
  verification preset or `flutter test` for the owned surface.
- Coverage is shell-only. After a failed coverage gate, prefer
  `dart run tool/check_coverage.dart --json --uncovered-branches` to inspect
  missing LCOV files, missed lines, and uncovered branches from the existing
  `coverage/lcov.info` artifact.
- Run heavyweight Flutter invocations sequentially. Do not run
  `flutter test --coverage ...` in parallel with
  `dart run tool/run_tool_tests.dart`.
- Documentation-only changes do not require the full Flutter pipeline unless
  the task also changes code, tooling contracts, or executable examples.

## Release hygiene

- Add user-visible changes under `## Unreleased` in `CHANGELOG.md`.
- Move `Unreleased` entries into a versioned section during release cut.
- Prefix breaking changes with `Breaking:`.
- Before publish, also run:
  - `dart doc`
  - `dart pub publish --dry-run`
