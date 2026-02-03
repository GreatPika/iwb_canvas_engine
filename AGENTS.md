# Project Context

This file is the quick-start context for new sessions. Keep it concise and avoid duplicating `ARCHITECTURE.md` or `DEVELOPMENT_PLAN.md`.

## What we are building

A Flutter/Dart canvas engine package with scene model, rendering, input handling, and JSON serialization (no app UI or domain logic).

## Canonical sources

- `ARCHITECTURE.md` (system overview and data flow)
- `DEVELOPMENT_PLAN.md` (phased plan with checkboxes; update after each completed item)

## Rules for this repo

- Single source of truth: no sync glue or duplicated state between modules.
- Group is ephemeral: no stored Group node.
- Always mark the checkbox in `DEVELOPMENT_PLAN.md` after completing an item.
- When changing public behavior or public API, update the relevant documentation in the same PR/commit (as applicable):
  - `API_GUIDE.md` (API usage guide / cookbook for agents)
  - `README.md` (project overview, entrypoints, quickstart)
  - `ARCHITECTURE.md` (design/flow/invariants when architecture changes)
  - Dartdoc comments (public symbols) + regenerate `doc/api` if you rely on published HTML docs
- Always run the linter and tests after changes, and report the results.
- Run `dart format --output=none --set-exit-if-changed lib test example/lib` (or `dart format lib test example/lib`) before pushing.
