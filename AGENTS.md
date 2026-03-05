# Project Context

This file is the fast path for contributors and coding agents. Keep it concise,
and use the documents below as the canonical source instead of duplicating them
here.

## Product boundary

`iwb_canvas_engine` is a Flutter/Dart canvas engine package. It owns scene
modeling, rendering, input handling, and JSON serialization. It does not own
app UI, product workflows, or backend logic.

## Document map

| File | Primary audience | Purpose | Canonical for |
| --- | --- | --- | --- |
| `README.md` | External users | Package landing page | Scope, install, first-use guidance |
| `API_GUIDE.md` | Integrators | Public API reference | Runtime, serialization, migration |
| `ARCHITECTURE.md` | Maintainers | System design notes | Data flow, invariants, module boundaries |
| `CHANGELOG.md` | Users and maintainers | Release history | Released and unreleased user-visible changes |
| `DEVELOPMENT_PLAN.md` | Maintainers | Active roadmap only | Current planning wave, if any |
| `tool/invariant_registry.dart` | Maintainers and CI | Machine-readable invariants | Invariant ids and ownership |

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
- Documentation-only changes do not require the full Flutter pipeline unless the
  task also changes code, tooling contracts, or executable examples.
- If `tool/invariant_registry.dart` changes, always run and report
  `dart run tool/check_invariant_coverage.dart`.

## Required checks for code changes

1. `dart format --output=none --set-exit-if-changed lib test example/lib tool`
2. `flutter analyze`
3. `flutter test --coverage`
4. `dart run tool/check_coverage.dart`
5. `dart run tool/check_invariant_coverage.dart`
6. `dart run tool/check_guardrails.dart`
7. `dart run tool/check_import_boundaries.dart`
8. `dart run tool/check_public_api_surface.dart`

## Release hygiene

- Add user-visible changes under `## Unreleased` in `CHANGELOG.md`.
- Move `Unreleased` entries into a versioned section during release cut.
- Prefix breaking changes with `Breaking:`.
- Before publish, also run:
  - `dart doc`
  - `dart pub publish --dry-run`
