# Product boundary

`iwb_canvas_engine` is a Flutter/Dart canvas engine package. It owns scene
modeling, rendering, input handling, and JSON serialization. It does not own
app UI, product workflows, or backend logic.

## Document map

- `README.md` for package overview and getting started.
- `API_GUIDE.md` for public API, runtime behavior, and migration notes.
- `ARCHITECTURE.md` for architecture, invariants, and module boundaries.
- `CHANGELOG.md` for released and unreleased user-visible changes.
- `KNOWN_ISSUES.md` for active, confirmed defects with mechanical evidence and
  constrained entry rules.
- `PLAN.md` for the active roadmap.

## Plan workflow

- `PLAN.md` is the active roadmap and the source of truth for planned work.
- When adding a new step to `PLAN.md`, use `$change-contract` directly as the
  canonical step-contract template. Do not infer the required structure from
  existing plan steps.
- Follow the step contract as written during implementation. If a step contract
  conflicts with the current code, guardrails, tests, or repository-local
  boundary enforcement, stop implementation, report the exact contradiction with
  file-level evidence, and resolve the contract or enforcement before
  continuing. Do not silently reinterpret the plan.
- After completing a plan step, update the corresponding checkbox entries in
  `PLAN.md` and any linked step document so finished items are marked done in
  the same change.

## Documentation hygiene

- Public behavior changes must update:
  - `README.md` using `$readme-sync`
  - `API_GUIDE.md` using `$api-guide-sync`
  - `ARCHITECTURE.md` using `$architecture-sync` when invariants, architecture, or module ownership change
  - `CHANGELOG.md` using `$changelog-sync`
- Documentation should stay release-ready: concise, current, and free of stale
  implementation detail.
- `KNOWN_ISSUES.md` is for active confirmed defects only. If an issue is listed
  there, it is unresolved. Remove it in the same change that fixes it and adds
  regression proof. Do not use it for feature ideas, temporary notes, archived
  history, or unverified suspicions.

## Invariant discipline

- Add or modify invariant definitions in `tool/invariant_registry.dart`.
- Reference enforcement with exact `// INV:<id>` markers in `test/**` or `tool/**`.

## Verification

After any code change, run `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->` and provide every modified, added, renamed, or deleted repository-relative path as one line from that file or from stdin.

- Run targeted tool-test verification only for tool-impacting changes or when
  debugging a tool failure; otherwise rely on the required preset's resolved
  plan.
- For new production files under `lib/**`, run `dcm calculate-metrics` and keep
  them green against the current thresholds.
- Run `dcm calculate-metrics` for legacy files only when adding a large new
  unit, substantially rewriting a hotspot, or validating a suspected metric
  regression.
- Do not run package tests directly with plain `dart test` in this repository.
  Use the verification preset or `flutter test` for production/package-owned
  surfaces. For `test/tool/**`, use `dart run tool/run_tool_tests.dart` or the
  verification preset; that repository wrapper owns its internal `dart test`
  invocation.
- Coverage is shell-only. After a failed coverage gate, prefer
  `dart run tool/check_coverage.dart --json` for machine-first triage, add
  `--uncovered-branches` when branch diagnostics matter, and add
  `--changed-only` when the next action should be limited to changed
  `lib/src/**` files from the current git worktree. The JSON `gaps` payload is
  the canonical actionable output and already includes candidate test files
  plus preferred verification step ids when they can be resolved.
- For minimal runtime/listener contract repros that need a clean package
  boundary, use `dart run tool/run_temp_pkg_test.dart`. Do not hand-assemble
  ad hoc `/tmp` test packages or run manual import/path wiring when this tool
  fits the task.
- Run heavyweight verification commands sequentially. Do not run
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
