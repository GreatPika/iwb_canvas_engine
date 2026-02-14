# Project Context

This file is the quick-start context for new sessions. Keep it concise and avoid duplicating `ARCHITECTURE.md` or `DEVELOPMENT_PLAN.md`.

## What we are building

A Flutter/Dart canvas engine package with scene model, rendering, input handling, and JSON serialization (no app UI or domain logic).

## Canonical sources

- `ARCHITECTURE.md` (system overview and data flow)
- `DEVELOPMENT_PLAN.md` (optional roadmap; may be empty between planning cycles)
- `tool/invariant_registry.dart` (canonical machine-readable invariant list)

## Rules for this repo

- Single source of truth: no sync glue or duplicated state between modules.
- Group is ephemeral: no stored Group node.
- Invariants must be explicit and enforced:
  - Add/modify invariants in `tool/invariant_registry.dart`.
  - Reference enforcement sites with `// INV:<id>` in `test/**` or `tool/**`.
  - Keep `dart run tool/check_invariant_coverage.dart` green (CI enforces this).
- When changing public behavior or public API, update documentation in the same change:
  - `API_GUIDE.md`
  - `README.md`
  - `ARCHITECTURE.md` (when architecture/invariants change)
- Run linter/tests for code changes and report results.
- For documentation-only changes, checks are not required.
- Exception: if `tool/invariant_registry.dart` is changed, run and report `dart run tool/check_invariant_coverage.dart`.

## Changelog

- Keep `CHANGELOG.md` updated for user-visible changes.
- Add entries under `## Unreleased` while developing.
- For release `X.Y.Z (YYYY-MM-DD)`, move entries from `Unreleased` into the release section and delete `Unreleased`.
- Prefix breaking changes with `Breaking:`.

## Required checks (run locally before pushing code changes)

1) Formatting (fail on diffs)

- `dart format --output=none --set-exit-if-changed lib test example/lib tool`

2) Static analysis

- `flutter analyze`

3) Unit tests

- `flutter test`

4) Coverage gates (line coverage for `lib/src/**` must be 100%)

- `flutter test --coverage`
- `dart run tool/check_coverage.dart`

5) Invariant coverage (every invariant must have enforcement)

- `dart run tool/check_invariant_coverage.dart`

6) Guardrails

- `dart run tool/check_guardrails.dart`

7) Import boundary rules

- `dart run tool/check_import_boundaries.dart`

8) Documentation + publish sanity (recommended before release)

- `dart doc`
- `dart pub publish --dry-run`
