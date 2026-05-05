# Architecture entrypoint

This is the first stop for target-system architecture work in
`iwb_canvas_engine_next`.

Use this folder to understand current system shape, ownership boundaries,
package boundaries, and architecture-level decisions. Do not use planning
documents as the source for current runtime ownership.

## Read path

1. Read `00_architecture_overview.md` for scope and non-goals.
2. Read `01_runtime_ownership.md` and `02_package_boundaries.md` for the target
   runtime shape.
3. Read `03_data_model.md` and `04_decisions_and_differences.md` for state
   ownership and accepted differences from the legacy engine.
4. Read `docs/diagrams/README.md` and the Mermaid files in `docs/diagrams/`
   when changing architecture.

## Role routing

- Architecture ownership and package boundary work starts in
  `docs/architecture/01_runtime_ownership.md` and
  `docs/architecture/02_package_boundaries.md`.
- Public API work routes to `docs/contracts/public_api_v1.md`.
- Schema and JSON compatibility work routes to
  `docs/contracts/schema_v1.md` and
  `docs/contracts/codec_boundary.md`.
- Validation work routes to `docs/contracts/validation_limits.md`.
- Runtime state and document model work starts in
  `docs/architecture/03_data_model.md`, then routes to
  `docs/contracts/edit_kernel.md`,
  `docs/contracts/load_document.md`, and
  `docs/contracts/operation_matrix.md`.
- Interaction work routes to `docs/contracts/interaction_engine.md`.
- Rendering work routes to `docs/contracts/frame_rendering.md`,
  `docs/contracts/cache_policy.md`, and
  `docs/verification/tests.md`.
- Geometry and spatial work routes to `docs/contracts/geometry.md` and
  `docs/contracts/spatial_kernel.md`.
- Resource lifecycle work routes to `docs/contracts/resources.md`.
- Diagnostics work routes to `docs/contracts/diagnostics.md`.
- Test, benchmark, guardrail, and release-readiness work routes to
  `docs/verification/`.
- Implementation sequencing routes to `docs/implementation/`.
- Legacy-oracle evidence and historical planning notes route to `docs/planning/`.
- Donor decisions route to `docs/donors/` and
  `docs/_registry/donors.yaml`.
- Change Contracts route to `../../plan/`.

## Role boundaries

- `architecture/` owns current target-system shape.
- `contracts/` owns subsystem-level normative behavior and invariants.
- `verification/` owns proof plans, guardrails, tests, benchmarks, and release
  gates.
- `planning/` owns transition sequencing and historical context.
- `donors/` owns old-engine donor rules and reusable evidence.
- `_registry/` owns machine-readable section coverage and donor records.

## Mechanical checks

Run these commands from `next/iwb_canvas_engine_next/`:

```bash
dart run docs/tool/generate_context_capsules.dart --check
dart run docs/tool/check_docs.dart
```
