# Repository Instructions

This repository is the canonical root package for the new
`iwb_canvas_engine` implementation. Treat the repository root as the owner of
new engine source, package metadata, tests, tools, and durable target-engine
documentation.

The repository keeps one intentionally isolated transition area:

- `legacy/iwb_canvas_engine/` - the existing engine. Treat it as a functional
  oracle and implementation donor only.

## Root Ownership

The repository root owns the new engine package:

- `pubspec.yaml`
- `pubspec.lock`
- `analysis_options.yaml`
- `dart_test.yaml`
- `lib/`
- `test/`
- `tool/`
- `docs/`
- `plan/`
- `.agents/`
- `.gitignore`
- `AGENTS.md`
- `legacy/`

Put new-engine implementation files, tests, tools, diagrams, architecture docs,
contracts, implementation plans, verification assets, donor records, registries,
and release gates under the root package paths.

Root `plan/` remains limited to workspace-level Change Contracts and audit
trails. Durable target-engine documentation belongs under `docs/`.

## Legacy Boundary

`legacy/iwb_canvas_engine/` is not the target implementation area.

Use it only to:

- inspect legacy behavior;
- run legacy tests or examples when needed;
- identify donor code;
- compare functional behavior;
- copy or adapt code into the root package when explicitly useful.

Do not modify legacy code unless the user explicitly asks for a legacy fix or
the change is required to keep the legacy package runnable after repository
layout work.

The new engine must not import the legacy package or any `legacy/**` source.

## Donor Rules

Legacy code may be used as a donor only through one of these modes:

- `copy` - move the idea or implementation shape into the root package, then
  make it compile under the new API and package layout.
- `adapt` - preserve behavior while changing ownership, naming, API, or data
  shape for the new architecture.
- `rewrite-reference` - use the legacy code/tests only as behavioral evidence.

Every copied or adapted donor must have ported or equivalent tests in the root
package. If a donor conflicts with the new API, package layout, or no-legacy
boundary, the new architecture wins.

## Commands

Use the repository root for new-engine package commands:

```bash
flutter pub get
dart analyze
dart run docs/tool/check_docs.dart
```

Use legacy package directories only for legacy oracle checks. For example:

```bash
cd legacy/iwb_canvas_engine
flutter pub get
flutter analyze

cd legacy/iwb_canvas_engine/example
flutter pub get
flutter run -d macos
flutter analyze
flutter test --no-pub test/widget_test.dart
```

## Documentation

Write durable project documentation in English unless the user explicitly asks
for another language. User-facing chat should follow the user's language.

Do not create extra root-level docs for the new engine outside the established
root package structure. Place engine architecture, contracts, verification,
planning, donor docs, indexes, diagrams, and documentation tooling under
`docs/`.

## Change Discipline

Prefer mechanical moves for layout changes.

Before changing code, identify whether the change belongs to:

- root package;
- legacy oracle/donor package;
- workspace-level planning under `plan/`.

Keep these boundaries explicit in final reports. If a command fails after a
layout change, first suspect stale generated files, package config, or stale paths
before changing implementation code.
