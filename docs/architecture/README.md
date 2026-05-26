# Architecture entrypoint

This router points architecture work to the current target-system owners and to
the generated navigation that supports phase, subsystem, and diagram lookup.

## Read path

1. `docs/architecture/00_architecture_overview.md`
2. `docs/architecture/01_runtime_ownership.md`
3. `docs/architecture/02_package_boundaries.md`
4. `docs/architecture/03_data_model.md`
5. `docs/architecture/04_decisions_and_differences.md`
6. `docs/architecture/architecture_graph.yaml`
7. `docs/diagrams/catalog.md`

## Work routes

- Public API: `docs/contracts/public_api_v1.md`
- Schema and codec: `docs/contracts/schema_v1.md` and `docs/contracts/codec_boundary.md`
- Validation and diagnostics: `docs/contracts/validation_limits.md` and `docs/contracts/diagnostics.md`
- Runtime, edit, load, and operations: `docs/contracts/edit_kernel.md`, `docs/contracts/load_document.md`, and `docs/contracts/operation_matrix.md`
- Interaction: `docs/contracts/interaction_engine.md`
- Frame, cache, geometry, and spatial work: `docs/contracts/frame_rendering.md`, `docs/contracts/cache_policy.md`, `docs/contracts/geometry.md`, and `docs/contracts/spatial_kernel.md`
- Resources: `docs/contracts/resources.md`
- Verification: `docs/verification/`
- Implementation phases: `docs/indexes/by_phase.md`
- Subsystems: `docs/indexes/by_subsystem.md`
- Diagrams: `docs/diagrams/catalog.md`

## Boundary

- `docs/architecture/` owns target-system shape.
- `docs/contracts/` owns subsystem behavior and invariants.
- `docs/verification/` owns proof plans, guardrails, tests, benchmarks, and release gates.
- `docs/implementation/` owns phase sequencing.
- `docs/donors/` owns donor rules and evidence.
- `docs/_registry/` owns relationship metadata for generated navigation.

## Checks

```bash
dart run docs/tool/sync_generated_docs.dart --check
dart run docs/tool/check_docs.dart
dart run tool/architecture_graph/generate_views.dart --phase P6 --check
```
