# Workspace Instructions

This repository is now a workspace with two intentionally separated areas:

- `legacy/iwb_canvas_engine/` — the existing engine. Treat it as a functional
  oracle and implementation donor only.
- `next/iwb_canvas_engine_next/` — the new engine package and the only place
  for new architecture, new implementation, new tests, and new transition docs.

The repository root is only the workspace/control layer.

## Root Ownership

Keep root files limited to workspace-level configuration and agent guidance:

- `AGENTS.md`
- `.agents/`
- `.gitignore`
- `analysis_options.yaml`
- `dart_test.yaml`
- `pubspec.yaml`
- `pubspec.lock`
- `plan/`
- `legacy/`
- `next/`

Do not move old package docs, source, tests, tooling, or CI back into the root.
Do not place new engine implementation files in the root.
Keep root `plan/` limited to workspace-level Change Contracts and audit trails;
target architecture, subsystem contracts, verification assets, donor docs, and
transition source material still live under `next/iwb_canvas_engine_next/docs/`.

## Legacy Boundary

`legacy/iwb_canvas_engine/` is not the target implementation area.

Use it only to:

- inspect old behavior;
- run old tests or examples when needed;
- identify donor code;
- compare functional behavior;
- copy or adapt code into `next/iwb_canvas_engine_next/` when explicitly useful.

Do not modify legacy code unless the user explicitly asks for a legacy fix or
the change is required to keep the moved legacy package runnable after workspace
layout work.

The new engine must not import the legacy package or any `legacy/**` source.

## Next Boundary

`next/iwb_canvas_engine_next/` owns the new library.

Put all new-engine artifacts here:

- package source;
- tests;
- tools;
- diagrams;
- architecture docs;
- implementation plans;
- functional ledgers;
- donor registries;
- guardrail registries;
- release gates.

The current transition source documents live under the role-based next-engine
documentation:

- `next/iwb_canvas_engine_next/docs/architecture/README.md`
- `next/iwb_canvas_engine_next/docs/contracts/`
- `next/iwb_canvas_engine_next/docs/verification/`
- `next/iwb_canvas_engine_next/docs/planning/`
- `next/iwb_canvas_engine_next/docs/donors/`

Do not treat legacy architecture docs as binding architecture for the new
engine. They are evidence for old behavior only.

## Donor Rules

Old code may be used as a donor only through one of these modes:

- `copy` — move the idea or implementation shape into `next`, then make it
  compile under the new API and package layout.
- `adapt` — preserve behavior while changing ownership, naming, API, or data
  shape for the new architecture.
- `rewrite-reference` — use the old code/tests only as behavioral evidence.

Every copied or adapted donor must have ported or equivalent tests in `next`.
If a donor conflicts with the new API, package layout, or no-legacy boundary,
the new architecture wins.

## Workspace Commands

Use the workspace root for dependency resolution:

```bash
flutter pub get
dart pub workspace list
dart analyze
```

Use package directories for package-specific app/test runs. For example:

```bash
cd legacy/iwb_canvas_engine/example
flutter run -d macos
flutter analyze
flutter test --no-pub test/widget_test.dart
```

When new code appears under `next/iwb_canvas_engine_next/`, run verification
from that package directory unless a root workspace command is more appropriate.

## Documentation

Write durable project documentation in English unless the user explicitly asks
for another language. User-facing chat should follow the user's language.

Do not create root-level docs for the new engine, except workspace-level Change
Contracts under root `plan/`. Place engine architecture, contracts,
verification, planning, donor docs, and indexes under
`next/iwb_canvas_engine_next/docs/`.

## Change Discipline

Prefer mechanical moves for layout changes.

Before changing code, identify whether the change belongs to:

- workspace root;
- legacy oracle/donor package;
- next package.

Keep these boundaries explicit in final reports. If a command fails after a
layout change, first suspect stale generated files, workspace config, or old
paths before changing implementation code.
