# Development Plan

There is no active development wave in this file right now. The `5.0.0`
stabilization and release-prep work was completed on `2026-02-18`, and this
document stays intentionally minimal between planning cycles.

## Current status

- There is no active roadmap tracked in this file until a new scoped workstream
  is opened.
- Historical implementation detail belongs in `CHANGELOG.md` and git history,
  not in this file.
- The next active plan should replace this document with a fresh, decision-ready
  roadmap for the new work.

## When opening the next wave

- Start with one objective and explicit release target.
- Record only active items, not completed history.
- Link to `ARCHITECTURE.md` when a task changes invariants or module boundaries.
- Update `API_GUIDE.md`, `README.md`, and `CHANGELOG.md` in the same change when
  public behavior changes.

## Validation baseline for code changes

1. `dart format --output=none --set-exit-if-changed lib test example/lib tool`
2. `flutter analyze`
3. `flutter test`
4. `flutter test --coverage`
5. `dart run tool/check_coverage.dart`
6. `dart run tool/check_invariant_coverage.dart`
7. `dart run tool/check_guardrails.dart`
8. `dart run tool/check_import_boundaries.dart`

For documentation-only changes, these checks are optional unless a task modifies
tooling contracts or references.
