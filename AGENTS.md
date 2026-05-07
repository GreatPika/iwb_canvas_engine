# Repository Instructions

The repository root is the canonical `iwb_canvas_engine` package. New-engine
source, tests, tools, package metadata, and durable target-engine documentation
belong under root package paths. `legacy/iwb_canvas_engine/` remains an isolated,
runnable oracle and donor package until a later explicit deletion.

## Legacy Boundary

Use `legacy/iwb_canvas_engine/` only to:

- inspect legacy behavior;
- run legacy tests or examples;
- identify donor code;
- compare functional behavior;
- copy or adapt code into the root package when explicitly useful.

Do not modify legacy code unless the user explicitly asks for a legacy fix or a
change is required to keep the legacy package runnable after repository layout
work.

## Commands

Use the repository root for new-engine package commands:

- flutter pub get
- dart analyze
- dcm analyze .
- dcm calculate-metrics .
- dart run docs/tool/generate_context_capsules.dart --check
- dart run docs/tool/check_docs.dart

Run `dart test` from the root when a root `test/` directory exists.

## Documentation

Write durable project documentation in English unless the user explicitly asks
for another language. User-facing chat should follow the user's language.

Do not create extra root-level docs outside the established root package
structure. Place engine architecture, contracts, verification, implementation
plans, donor docs, indexes, diagrams, and documentation tooling under `docs/`.

## Change Discipline

Before changing files, identify whether the change belongs to:

- root package;
- legacy oracle or donor package;
- workspace-level planning under `plan/`.

Keep these boundaries explicit in final reports. If a command fails after a
layout change, first suspect stale generated files, package config, or stale
paths before changing implementation code.
