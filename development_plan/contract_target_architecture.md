# Contract Target Architecture

## Purpose

This document is the source of truth for the contract cleanup sequence that
starts at step `52`.

The sequence may choose local code motion, helper placement, and verification
sequencing only inside the graph defined here. It is not allowed to reinterpret
the contract target graph while executing the plan.

If implementation reveals that this target graph is wrong, the graph must be
updated explicitly in this document before a step is considered complete.

## Target End State

- After step `52`, the node-boundary schema seam is already closed through
  explicit common / patch / spec / snapshot owners; the remaining contract
  cleanup starts with the full snapshot-boundary redesign in step `53`.
- `lib/src/contract/**` keeps the public immutable boundary types and the
  internal validated-boundary owners, but the remaining snapshot seam stops
  relying on both `part`-coupled shared namespaces and public fast-path
  helpers as the runtime construction model.
- `snapshot.dart` stays the public immutable snapshot surface and becomes a
  `part`-free thin public wrapper surface over an internal snapshot graph.
- `node_patch.dart`, `node_spec.dart`, and `snapshot.dart` remain public
  boundary owners and must not absorb internal schema-helper bodies.
- `internal/node_boundary_schema.dart` becomes a thin canonical internal schema
  barrel rather than a giant static owner bucket.
- Snapshot construction moves into an explicit internal snapshot graph plus a
  thin public wrapper edge.
- Producer-side `model/**` owners build snapshots through internal snapshot
  owners instead of hidden public snapshot fast-path helpers.
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

These files are internal canonical import surfaces only. They may export or
delegate to focused internal owners, but they must not become mixed-owner
implementation buckets.

## Required Final File Graph

### Node boundary schema graph

- `internal/node_boundary_schema.dart` stays the canonical internal schema
  import surface and becomes a thin barrel only.
- `internal/node_boundary_schema_common.dart` owns:
  - schema field typedefs shared across directions;
  - common validated-boundary conversion helpers;
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

## Explicit Non-Goals For The Sequence

- Splitting `snapshot.dart` into one file per snapshot class family.
- Reopening `transform2d.dart` because it is large but cohesive.
- Reopening `scene_data_exception.dart` because it contains many taxonomy
  factories.
- Moving contract boundary validation into `model/**` or `serialization/**`.
- Introducing generic `support`, `helpers`, or `utils` buckets instead of the
  focused owner files named above.

## Residual Policy

### Files that must not remain as residual mixed-owner hotspots

- `lib/src/contract/internal/node_boundary_schema.dart`
- `lib/src/contract/internal/snapshot_fast_path.part.dart`
- `lib/src/contract/snapshot.dart` as the owner of trusted fast-path snapshot
  field assembly
- producer-side `lib/src/model/**` call sites that assemble snapshots through
  public `*SnapshotFromValidated` helpers

If any of these shapes remain, the contract cleanup sequence has not reached
its target state.

### Accepted large focused owners

- `lib/src/contract/snapshot.dart` may remain large because it is the public
  immutable snapshot family surface.
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
  snapshot or validated-boundary owners; constructor/fast-path matrices and
  direction-mixed schema buckets are not accepted residuals.
