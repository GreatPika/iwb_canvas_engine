# Project Context (iwb_canvas_engine)

Last updated: 2026-01-30

This file is the quick-start context for new sessions. Keep it concise and avoid duplicating `ARCHITECTURE.md` or `DEVELOPMENT_PLAN.md`.

## What we are building

A Flutter/Dart canvas engine package with scene model, rendering, input handling, and JSON serialization (no app UI or domain logic).

## Canonical sources

- `TZ.md` (requirements + Appendix A decisions)
- `ARCHITECTURE.md` (system overview and data flow)
- `DEVELOPMENT_PLAN.md` (phased plan with checkboxes; update after each completed item)

## Current status

- Phase: 2 (JSON serialization next).
- Working set: core model + math + hit-test + tests in place; plan updated.
- Next focus: implement JSON v1 export/import and validation.

## Rules for this repo

- Single source of truth: no sync glue or duplicated state between modules.
- Group is ephemeral: no stored Group node.
- Always mark the checkbox in `DEVELOPMENT_PLAN.md` after completing an item.
