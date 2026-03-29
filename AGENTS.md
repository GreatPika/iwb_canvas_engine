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
- `VERIFICATION.md` for the required verification workflow and test/check entrypoints.
- `tool/invariant_registry.dart` for invariant ids and ownership.

## Execution tracking

- After completing a plan step, update the corresponding checkbox entries in
  `DEVELOPMENT_PLAN.md` and any linked step document so finished items are
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

After any code change, run all checks listed in `VERIFICATION.md`.
Update `VERIFICATION.md` in the same change whenever the
verification surface changes, including new required tests, renamed test
entrypoints, changed shard composition, or new mandatory checks.

## Release hygiene

- Add user-visible changes under `## Unreleased` in `CHANGELOG.md`.
- Move `Unreleased` entries into a versioned section during release cut.
- Prefix breaking changes with `Breaking:`.
- Before publish, also run:
  - `dart doc`
  - `dart pub publish --dry-run`
