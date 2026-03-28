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
  cleanup starts with the snapshot fast-path seam in step `53`.
- `lib/src/contract/**` keeps the public immutable boundary types and the
  internal validated-boundary owners, but the remaining internal hotspot seams
  stop relying on `part`-coupled shared namespaces.
- `snapshot.dart` stays the public immutable snapshot surface and becomes
  `part`-free.
- `node_patch.dart`, `node_spec.dart`, and `snapshot.dart` remain public
  boundary owners and must not absorb internal schema-helper bodies.
- `internal/node_boundary_schema.dart` becomes a thin canonical internal schema
  barrel rather than a giant static owner bucket.
- The snapshot fast path moves out of `snapshot.dart` `part` coupling into
  explicit internal owner modules.
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

### Snapshot fast-path graph

- `snapshot.dart` keeps the public immutable snapshot classes and public
  validating factories only.
- `snapshot.dart` no longer contains
  `part 'internal/snapshot_fast_path.part.dart';`.
- `internal/snapshot_fast_path.dart` becomes a thin internal import surface for
  validated snapshot allocation helpers.
- `internal/snapshot_fast_path_scene.dart` owns scene, layer, camera,
  background, grid, and palette fast-path allocation.
- `internal/snapshot_fast_path_node.dart` owns node-family fast-path
  allocation.
- `snapshot.dart` exposes explicit `@internal` prevalidated constructors or
  equivalent internal-only allocation entrypoints so the fast-path modules no
  longer require `part` access to private constructors.

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
- `lib/src/contract/snapshot.dart` with a fast-path `part` attachment

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
  snapshot fast-path seams.
- Clone residuals are acceptable only as family symmetry inside focused
  snapshot or validated-boundary owners; constructor/fast-path matrices and
  direction-mixed schema buckets are not accepted residuals.
