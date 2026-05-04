# Architecture entrypoint

This is the first stop for target-system architecture work in
`iwb_canvas_engine_next`.

Use this folder to understand current system shape, ownership boundaries,
package boundaries, and architecture-level decisions. Do not use planning
documents as the source for current runtime ownership.

## Read path

1. Read `architecture.yaml` for the machine-readable owner, boundary, and
   dependency model.
2. Read `00_architecture_overview.md` for scope and non-goals.
3. Read `01_runtime_ownership.md` and `02_package_boundaries.md` for the target
   runtime shape.
4. Read `03_data_model.md` and `04_decisions_and_differences.md` for state
   ownership and accepted differences from the legacy engine.
5. Read `diagrams.md` and the generated files in `docs/split/diagrams/generated/` when changing
   architecture.

## Role routing

- Architecture ownership and package boundary work starts in
  `docs/split/architecture/architecture.yaml`.
- Public API work routes to `docs/split/contracts/public_api_v1.md`.
- Schema and JSON compatibility work routes to
  `docs/split/contracts/schema_v1.md` and
  `docs/split/contracts/codec_boundary.md`.
- Validation work routes to `docs/split/contracts/validation_limits.md`.
- Runtime state and document model work starts in
  `docs/split/architecture/03_data_model.md`, then routes to
  `docs/split/contracts/edit_kernel.md`,
  `docs/split/contracts/load_document.md`, and
  `docs/split/contracts/operation_matrix.md`.
- Interaction work routes to `docs/split/contracts/interaction_engine.md`.
- Rendering work routes to `docs/split/contracts/frame_rendering.md`,
  `docs/split/contracts/cache_policy.md`, and
  `docs/split/verification/tests.md`.
- Geometry and spatial work routes to `docs/split/contracts/geometry.md` and
  `docs/split/contracts/spatial_kernel.md`.
- Resource lifecycle work routes to `docs/split/contracts/resources.md`.
- Diagnostics work routes to `docs/split/contracts/diagnostics.md`.
- Migration work routes to `docs/split/contracts/migration_tool.md`.
- Test, benchmark, guardrail, and release-readiness work routes to
  `docs/split/verification/`.
- Legacy-oracle evidence and implementation sequencing route to
  `docs/split/planning/`.
- Donor decisions route to `docs/split/donors/` and
  `docs/split/_registry/donors.yaml`.
- Change Contracts route to `../../plan/`.

## Role boundaries

- `architecture/` owns current target-system shape.
- `contracts/` owns subsystem-level normative behavior and invariants.
- `verification/` owns proof plans, guardrails, tests, benchmarks, and release
  gates.
- `planning/` owns transition sequencing and historical context.
- `donors/` owns old-engine donor rules and reusable evidence.
- `_registry/` owns machine-readable section, donor, diagram, guardrail, phase,
  and test relationships.

## Mechanical checks

Run these commands from `next/iwb_canvas_engine_next/`:

```bash
dart run docs/split/tool/generate_split_context_capsules.dart --check
dart run docs/split/tool/check_split_navigation.dart
dart run docs/split/tool/check_split_source_coverage.dart
dart run docs/split/tool/generate_architecture_diagrams.dart --check
```
