# Documentation for `iwb_canvas_engine_next`

This directory is the durable source of truth for the next-engine transition and
target architecture.

Start architecture work at `architecture/README.md`. Start execution planning at
`indexes/by_phase.md`. Start donor work at `donors/00_reuse_rules.md` and
`_registry/donors.yaml`.

## Layout

- `architecture/`: target-system shape, ownership, package boundaries,
  architecture decisions, and diagram source data.
- `contracts/`: subsystem-level normative behavior and invariants.
- `verification/`: functional ledger, tests, guardrails, benchmarks, and release
  gates.
- `planning/`: legacy-oracle context, implementation sequencing, and historical
  draft notes.
- `donors/`: donor inventory sections. Donor use is controlled by
  `_registry/donors.yaml`.
- `diagrams/`: human-readable catalog and Mermaid diagram files.
- `indexes/`: human-readable maps by phase, subsystem, guardrail, test area, and
  donor relation.
- `_registry/`: machine-readable section coverage and donor records.
- `../../plan/`: workspace-level Change Contracts and audit trails for
  documentation or architecture changes.

## Source rule

The role-based files are the documentation source of truth. The active owner is
the role folder and `_registry/sections.yaml`; retired pre-split source markers
are not part of the current contract.

## Donor rule

A donor is allowed for implementation only when `_registry/donors.yaml` gives it
a target phase and owner. Records with `decision: avoid` or
`target_phases: [reference_only]` are not implementation structure.

## Mechanical checks

Run these commands from `next/iwb_canvas_engine_next/`:

```bash
dart run docs/tool/generate_context_capsules.dart --check
dart run docs/tool/check_docs.dart
```
