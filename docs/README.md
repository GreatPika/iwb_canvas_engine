# Documentation for `iwb_canvas_engine`

This directory is the durable source of truth for the new-engine transition and
target architecture.

Start architecture work at `architecture/README.md`. Start implementation work
with the phase files under `docs/implementation/`. Start donor work at
`donors/00_reuse_rules.md` and `_registry/donors.yaml`.

## Layout

- `architecture/`: target-system shape, ownership, package boundaries,
  architecture decisions, and diagram source data.
- `contracts/`: subsystem-level normative behavior and invariants.
- `implementation/`: phase-by-phase implementation checklists. Each phase file
  lists what to build, what to read first, which diagrams to use, which donors
  are allowed or forbidden, which guardrails apply, which tests are required,
  and the exit gate for that phase.
- `verification/`: functional ledger, tests, guardrails, benchmarks, and release
  gates.
- `donors/`: donor inventory sections. Donor use is controlled by
  `_registry/donors.yaml`.
- `diagrams/`: human-readable catalog and Mermaid diagram files.
- `indexes/`: human-readable maps by phase, subsystem, guardrail, test area, and
  donor relation. Use these as reverse lookups, not as the implementation
  entrypoint.
- `_registry/`: machine-readable section coverage and donor records.
- `plan/`: workspace-level Change Contracts and audit trails for
  documentation or architecture changes.

## Source rule

The role-based files are the documentation source of truth. The active owner is
the role folder and `_registry/sections.yaml`; retired pre-split source markers
are not part of the current contract.

## Implementation phases

Use these files as the working sequence:

1. `docs/implementation/p0_package_skeleton_and_hard_boundaries.md`
2. `docs/implementation/p1_legacy_oracle_lock.md`
3. `docs/implementation/p1_5_v1_scope_gate_before_public_api_freeze.md`
4. `docs/implementation/p2_public_api_v1_freeze.md`
5. `docs/implementation/p3_schema_v1_dto_validation_and_codec_skeleton.md`
6. `docs/implementation/p4_resources.md`
7. `docs/implementation/p5_store_kernel_and_projection_cache.md`
8. `docs/implementation/p6_edit_kernel.md`
9. `docs/implementation/p7_spatial_and_geometry.md`
10. `docs/implementation/p8_frame_engine_and_render_caches.md`
11. `docs/implementation/p9_interaction_engine.md`
12. `docs/implementation/p10_flutter_surface.md`
13. `docs/implementation/p12_benchmarks_diagrams_and_release_readiness.md`

## Donor rule

A donor is allowed for implementation only when `_registry/donors.yaml` gives it
a target phase and owner. Records with `decision: avoid` or
`target_phases: [reference_only]` are not implementation structure.

Phase files use human-readable donor decisions: `copy`, `copy/adapt`, `adapt`,
`adapt/rewrite`, and `rewrite-reference`. The registry stores the composite
forms as snake_case YAML values.

## Mechanical checks

Run these commands from the repository root:

```bash
dart run docs/tool/generate_context_capsules.dart --check
dart run docs/tool/check_docs.dart
```
