# Contract Target Architecture

## Purpose

This document is the source of truth for the contract cleanup sequence that
starts at step `52`.

Step `55` closed the original post-`54` target state mechanically through
`tool/check_guardrails.dart` and `INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY`.
Step `64` reopens the `node_spec.dart` / `node_patch.dart` boundary target
graph explicitly; the updated target state below is the source of truth for
the remaining work.

The sequence may choose local code motion, helper placement, and verification
sequencing only inside the graph defined here. It is not allowed to reinterpret
the contract target graph while executing the plan.

If implementation reveals that this target graph is wrong, the graph must be
updated explicitly in this document before a step is considered complete.

## Target End State

- After step `52`, the node-boundary schema seam is already closed through
  explicit common / patch / spec / snapshot owners.
- Step `53` closes the only wide contract seam by moving snapshot
  construction onto an explicit internal graph with thin public wrappers.
- After step `53`, the only remaining production contract seams are the local
  `part`-attached fast-path helpers in `node_spec.dart` and `node_patch.dart`;
  they are closed in step `54` without reopening the snapshot redesign.
- Step `55` closed the original post-`54` graph through documentation,
  guardrails, invariants, and measured baseline.
- Step `64` reopens the `node_spec.dart` / `node_patch.dart` boundary shape
  and moves them onto explicit internal backing/materialization graphs
  without reopening snapshot producer-side rewiring.
- The updated post-step-`64` state is mechanically pinned: `lib/src/contract/**`
  is part-free, removed residual `*.part.dart` seams do not exist, and
  downstream non-contract code is restricted to the canonical internal import
  surfaces.
- `lib/src/contract/**` keeps the public immutable boundary types and the
  internal validated-boundary owners, but contract cleanup ends in a fully
  `part`-free layer.
- `lib/src/contract/pointer_input.dart` owns routed pointer boundary value
  types and pointer-settings validation, so downstream contract consumers do
  not depend on `core/` for pointer boundary semantics.
- `snapshot.dart` stays the public immutable snapshot surface and becomes a
  `part`-free thin public wrapper surface over an internal snapshot graph.
- `node_spec.dart` and `node_patch.dart` stay public boundary owners, become
  `part`-free, and use explicit internal fast-path modules instead of
  `part`-shared private namespaces.
- `node_patch.dart`, `node_spec.dart`, and `snapshot.dart` remain public
  boundary owners and must not absorb internal schema-helper bodies.
- `internal/node_boundary_schema.dart` becomes a thin canonical internal schema
  barrel rather than a giant static owner bucket.
- Snapshot construction moves into an explicit internal snapshot graph plus a
  thin public wrapper edge.
- Producer-side `model/**` owners build snapshots through internal snapshot
  owners instead of hidden public snapshot fast-path helpers.
- `snapshot`, `node_spec.dart`, and `node_patch.dart` all close trusted
  boundary assembly through explicit internal backing / materialization graphs
  instead of keeping privileged construction inside public boundary files or
  mixed-owner fast-path buckets.
- The remaining asymmetry is producer-side only: `snapshot` rewires
  `model/**` producers to its internal graph because the codebase has a real
  multi-file snapshot producer spine, while `node_spec.dart` and
  `node_patch.dart` stay contract-local wrapper graphs without analogous
  model-side rewiring.
- Large contract files are acceptable only when they are focused public
  immutable boundary surfaces or focused value-object owners. Large internal
  mixed-owner buckets are not acceptable residuals.

## Canonical Boundaries

### Public contract surfaces

- `lib/src/contract/snapshot.dart`
- `lib/src/contract/node_patch.dart`
- `lib/src/contract/node_spec.dart`
- `lib/src/contract/transform2d.dart`
- `lib/src/contract/scene_data_exception.dart`

These files define the supported public or downstream contract surface. They
must not reabsorb internal boundary-schema or fast-path assembly logic.

### Internal canonical surfaces

- `lib/src/contract/internal/node_boundary_schema.dart`
- `lib/src/contract/internal/snapshot_fast_path.dart`
- `lib/src/contract/internal/node_spec_fast_path.dart`
- `lib/src/contract/internal/node_patch_fast_path.dart`

These files are internal canonical import surfaces only. They may export or
delegate to focused internal owners, but they must not become mixed-owner
implementation buckets.

`node_spec_fast_path.dart` and `node_patch_fast_path.dart` are canonical only
for contract-local validated allocation and white-box contract tests. Their
lower-level backing/materialization owners are not canonical non-contract
import surfaces.
Public `NodeSpec` / `NodePatch` constructors and factories remain the normal
runtime construction path and must not route back through those internal
fast-path barrels.

## Required Final File Graph

### Node boundary schema graph

- `internal/node_boundary_schema.dart` stays the canonical internal schema
  import surface and becomes a thin barrel only.
- `internal/node_boundary_schema_common.dart` owns:
  - schema field typedefs shared across directions;
  - common validated-boundary conversion helpers;
  - shared direction-neutral node-common and text-field semantics reused by
    `spec` and `snapshot` owners while leaving their requiredness and
    assembly-specific fields local;
  - primitive/shared validators that are truly cross-direction rather than
    patch-local, spec-local, or snapshot-local.
- `internal/node_boundary_schema_patch.dart` owns patch-only validation and
  `NodePatch` field rehydration helpers.
- `internal/node_boundary_schema_spec.dart` owns spec-only validation and
  `NodeSpec` field rehydration helpers.
- `internal/node_boundary_schema_snapshot.dart` owns snapshot-only validation
  and `NodeSnapshot` field rehydration helpers.
- `NodeBoundarySchema` as a giant static class does not exist in the target
  state.

### Snapshot boundary graph

- `snapshot.dart` keeps the public immutable snapshot classes and public
  validating constructors only.
- `snapshot.dart` is `part`-free and does not own privileged fast-path
  construction.
- `internal/snapshot_fast_path.dart` stays the canonical internal snapshot
  construction import surface and becomes a thin barrel only.
- `internal/snapshot_backing.dart` owns trusted immutable scene-level and
  node-family snapshot representation.
- `internal/snapshot_materialization.dart` owns wrapper materialization between
  the internal snapshot graph and the public snapshot wrappers exposed by
  `snapshot.dart`.
- Step `53` implementation pins that split concretely: `snapshot.dart` keeps
  only public validating constructors plus wrapper accessors,
  `snapshot_backing.dart` owns immutable storage, and
  `snapshot_materialization.dart` owns wrapper creation and compatibility
  helpers re-exported through `internal/snapshot_fast_path.dart`.
- Producer-side owners in `scene_snapshot_from_scene.dart`,
  `scene_builder_decode_*.dart`,
  and
  `scene_node_boundary_mapping*.dart`
  build snapshots through the internal snapshot graph and materialize public
  snapshot objects only at edges that must still return public snapshot types.
- Internal compatibility helpers for validated or intentionally malformed
  public snapshots may remain only behind `internal/snapshot_fast_path.dart`
  and must delegate through backing/materialization owners instead of public
  `_internal` constructors.

### Node spec boundary graph

- `node_spec.dart` keeps the public `NodeSpec` variants and public validating
  constructors only.
- `node_spec.dart` is `part`-free and does not own `part`-attached fast-path
  helpers or privileged trusted assembly.
- Public `NodeSpec` constructors remain the normal runtime path: they validate
  boundary input locally and materialize exact internal spec backings through
  class-local internal materialization entrypoints.
- `internal/node_spec_fast_path.dart` stays the canonical internal validated
  `NodeSpec` construction import surface and becomes a thin barrel only.
- `internal/node_spec_backing.dart` owns trusted immutable `NodeSpec` family
  representation.
- `internal/node_spec_materialization.dart` owns wrapper materialization
  between the internal spec graph and the public `NodeSpec` wrappers exposed
  by `node_spec.dart`.
- Internal compatibility helpers for validated `NodeSpec` construction may
  remain only behind `internal/node_spec_fast_path.dart` and must delegate
  through backing/materialization owners instead of public `_internal`
  constructor matrices or public top-level helper seams.
- White-box contract tests and contract-local helper callers switch to
  `internal/node_spec_fast_path.dart` explicitly instead of resolving the
  helper family through the public `node_spec.dart` library namespace.
- `NodeSpec` does not require producer-side `model/**` rewiring analogous to
  step `53`, because the current codebase does not have a non-contract
  multi-file `NodeSpec` construction graph that bypasses the public boundary.

### Node patch boundary graph

- `node_patch.dart` keeps the public `NodePatch` variants, `CommonNodePatch`,
  and public validating constructors only.
- `node_patch.dart` is `part`-free and does not own `part`-attached fast-path
  helpers or privileged trusted assembly.
- Public `NodePatch` / `CommonNodePatch` constructors and factories remain the
  normal runtime path: they validate boundary input locally and delegate
  through internal patch backing/materialization owners instead of keeping the
  trusted assembly path inside the public file.
- `internal/node_patch_fast_path.dart` stays the canonical internal validated
  `NodePatch` construction import surface and becomes a thin barrel only.
- `internal/node_patch_backing.dart` owns trusted immutable
  `CommonNodePatch` / `NodePatch` family representation.
- `internal/node_patch_materialization.dart` owns wrapper materialization
  between the internal patch graph and the public patch wrappers exposed by
  `node_patch.dart`.
- Internal compatibility helpers for validated `NodePatch` construction may
  remain only behind `internal/node_patch_fast_path.dart` and must delegate
  through backing/materialization owners instead of public `_internal`
  constructor matrices or public top-level helper seams.
- White-box contract tests and contract-local helper callers switch to
  `internal/node_patch_fast_path.dart` explicitly instead of resolving the
  helper family through the public `node_patch.dart` library namespace.
- `NodePatch` does not require producer-side `model/**` rewiring analogous to
  step `53`, because the current codebase does not have a non-contract
  multi-file `NodePatch` construction graph that bypasses the public boundary.

## Explicit Non-Goals For The Sequence

- Splitting `snapshot.dart` into one file per snapshot class family.
- Splitting `node_spec.dart` or `node_patch.dart` into one file per node
  family.
- Reopening `transform2d.dart` because it is large but cohesive.
- Reopening `scene_data_exception.dart` because it contains many taxonomy
  factories.
- Moving contract boundary validation into `model/**` or `serialization/**`.
- Reopening snapshot producer-side `model/**` rewiring while redesigning
  `node_spec.dart` or `node_patch.dart`.
- Exporting `node_spec_backing.dart`,
  `node_spec_materialization.dart`,
  `node_patch_backing.dart`,
  or
  `node_patch_materialization.dart`
  from the public package root.
- Introducing generic `support`, `helpers`, or `utils` buckets instead of the
  focused owner files named above.

## Residual Policy

### Files that must not remain as residual mixed-owner hotspots

- `lib/src/contract/internal/node_boundary_schema.dart`
- `lib/src/contract/internal/snapshot_fast_path.part.dart`
- `lib/src/contract/internal/node_spec_fast_path.part.dart`
- `lib/src/contract/internal/node_patch_fast_path.part.dart`
- `lib/src/contract/snapshot.dart` as the owner of trusted fast-path snapshot
  field assembly
- `lib/src/contract/node_spec.dart` as the owner of trusted spec backing or
  materialization assembly
- `lib/src/contract/node_patch.dart` as the owner of trusted patch backing or
  materialization assembly
- `lib/src/contract/internal/node_spec_fast_path.dart` as a mixed-owner
  implementation bucket instead of a thin canonical barrel
- `lib/src/contract/internal/node_patch_fast_path.dart` as a mixed-owner
  implementation bucket instead of a thin canonical barrel
- producer-side `lib/src/model/**` call sites that assemble snapshots through
  public `*SnapshotFromValidated` helpers
- non-contract production imports of
  `internal/node_boundary_schema_{common,patch,spec,snapshot}.dart`,
  `internal/snapshot_backing.dart`,
  `internal/snapshot_materialization.dart`,
  `internal/node_spec_backing.dart`,
  `internal/node_spec_materialization.dart`,
  `internal/node_patch_backing.dart`,
  `internal/node_patch_materialization.dart`,
  `internal/node_spec_fast_path.dart`,
  or
  `internal/node_patch_fast_path.dart`

If any of these shapes remain, the contract cleanup sequence has not reached
its target state.

### Accepted large focused owners

- `lib/src/contract/snapshot.dart` may remain large because it is the public
  immutable snapshot family surface.
- `lib/src/contract/node_spec.dart` may remain large because it is the public
  immutable `NodeSpec` family surface.
- `lib/src/contract/node_patch.dart` may remain large because it is the public
  immutable `NodePatch` family surface.
- `lib/src/contract/transform2d.dart` may remain large because it is a focused
  value-object owner.
- `lib/src/contract/scene_data_exception.dart` may remain large because it is a
  focused boundary error-taxonomy owner.

### Accepted residual metrics after final closure

- Remaining `HIGH` metrics are acceptable only when they belong to the focused
  public boundary surfaces listed above and not to internal mixed-owner
  buckets.
- No `VERY HIGH` metric item may remain on the internal node-boundary schema or
  snapshot boundary seams.
- Clone residuals are acceptable only as family symmetry inside focused
  snapshot, spec, patch, backing/materialization, or validated-boundary
  owners; constructor/fast-path matrices and direction-mixed schema buckets
  are not accepted residuals.
