# Project Context

This file is the quick-start context for new sessions. Keep it concise and avoid duplicating `ARCHITECTURE.md` or `DEVELOPMENT_PLAN.md`.

## What we are building

A Flutter/Dart canvas engine package with scene model, rendering, input handling, and JSON serialization (no app UI or domain logic).

## Canonical sources

- `ARCHITECTURE.md` (system overview and data flow)
- `DEVELOPMENT_PLAN.md` (phased plan with checkboxes; update after each completed item)
- `CODE_REVIEW_CHECKLIST.md` (maintainer checklist for code review and quality gates)
- `tool/invariant_registry.dart` (canonical machine-readable invariant list)

## Rules for this repo

- Single source of truth: no sync glue or duplicated state between modules.
- Group is ephemeral: no stored Group node.
- Invariants must be explicit and enforced:
  - Add/modify invariants in `tool/invariant_registry.dart`.
  - Reference enforcement sites with `// INV:<id>` in `test/**` or `tool/**`.
  - Keep `dart run tool/check_invariant_coverage.dart` green (CI enforces this).
- Always mark the checkbox in `DEVELOPMENT_PLAN.md` after completing an item.
- When changing public behavior or public API, update the relevant documentation in the same PR/commit (as applicable):
  - `API_GUIDE.md` (API usage guide / cookbook for agents)
  - `README.md` (project overview, entrypoints, quickstart)
  - `ARCHITECTURE.md` (design/flow/invariants when architecture changes)
  - Dartdoc comments (public symbols) + regenerate `doc/api` if you rely on published HTML docs
- Always run the linter and tests after changes, and report the results.

## Changelog

- Keep `CHANGELOG.md` updated for user-visible changes.
- Add entries under `## Unreleased` as you work.
- When releasing `X.Y.Z (YYYY-MM-DD)`, move Unreleased entries into that section and leave `## Unreleased` empty.
- Prefix breaking changes with `Breaking:`; avoid listing pure refactors unless they affect users.

## Required checks (run locally before pushing)

Run these from the repo root:

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

6) Import boundary rules

   - `dart run tool/check_import_boundaries.dart`

7) Documentation + publish sanity (recommended before release)

   - `dart doc`
   - `dart pub publish --dry-run`
