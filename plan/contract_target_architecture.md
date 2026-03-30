# Contract Target Architecture

## Purpose

This document is the source of truth for the contract cleanup sequence that
starts at step `52`.

Step `55` closes this target state mechanically through
`tool/check_guardrails.dart` and `INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY`.
Remaining references below to intermediate seams describe step-local history,
not active residual debt.

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
- Step `55` is closure only: documentation, guardrails, invariants, and
  measured baseline for the final contract owner graph after steps `52-54`.
- The final post-step-`55` state is mechanically pinned: `lib/src/contract/**`
  is part-free, removed residual `*.part.dart` seams do not exist, and
  downstream non-contract code is restricted to the canonical internal import
  surfaces.
- `lib/src/contract/**` keeps the public immutable boundary types and the
  internal validated-boundary owners, but contract cleanup ends in a fully
  `part`-free layer.
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
- Snapshot asymmetry is intentional: `snapshot` keeps its backing /
  materialization graph because the codebase has a real producer-side snapshot
  graph in `model/**`; `node_spec` and `node_patch` stop at explicit internal
  fast-path modules because they do not have the same multi-file producer
  pressure.
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
for contract-local validated allocation and white-box contract tests.
Non-contract production code must not depend on them.
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
  helpers.
- Public `NodeSpec` constructors remain the normal runtime path: they validate
  boundary input locally and delegate directly to exact internal-only
  `*.prevalidated(...)` entrypoints on the same public file.
- `internal/node_spec_fast_path.dart` owns internal validated `NodeSpec`
  allocation helpers such as `imageNodeSpecFromValidated(...)` and remains a
  normal Dart module.
- `node_spec.dart` exposes only the exact `@internal`
  `*.prevalidated(...)` allocation entrypoints required by
  `internal/node_spec_fast_path.dart`.
- White-box contract tests and contract-local helper callers switch to
  `internal/node_spec_fast_path.dart` explicitly instead of resolving the
  helper family through the public `node_spec.dart` library namespace.
- Snapshot-style backing/materialization owners are not introduced for
  `NodeSpec`, because the current codebase does not have a producer-side
  multi-file `NodeSpec` construction graph analogous to snapshots.

### Node patch boundary graph

- `node_patch.dart` keeps the public `NodePatch` variants, `CommonNodePatch`,
  and public validating constructors only.
- `node_patch.dart` is `part`-free and does not own `part`-attached fast-path
  helpers.
- Public `NodePatch` / `CommonNodePatch` constructors and factories remain the
  normal runtime path: they validate boundary input locally and delegate
  directly to exact internal-only `*.prevalidated(...)` entrypoints on the
  same public file.
- `internal/node_patch_fast_path.dart` owns internal validated `NodePatch`
  allocation helpers such as `commonNodePatchFromValidated(...)` and
  `imageNodePatchFromValidated(...)`, and remains a normal Dart module.
- `node_patch.dart` exposes only the exact `@internal`
  `*.prevalidated(...)` allocation entrypoints required by
  `internal/node_patch_fast_path.dart`.
- White-box contract tests and contract-local helper callers switch to
  `internal/node_patch_fast_path.dart` explicitly instead of resolving the
  helper family through the public `node_patch.dart` library namespace.
- Snapshot-style backing/materialization owners are not introduced for
  `NodePatch`, because the current codebase does not have a producer-side
  multi-file `NodePatch` construction graph analogous to snapshots.

## Explicit Non-Goals For The Sequence

- Splitting `snapshot.dart` into one file per snapshot class family.
- Splitting `node_spec.dart` or `node_patch.dart` into one file per node
  family.
- Reopening `transform2d.dart` because it is large but cohesive.
- Reopening `scene_data_exception.dart` because it contains many taxonomy
  factories.
- Moving contract boundary validation into `model/**` or `serialization/**`.
- Mirroring the snapshot backing/materialization graph for `node_spec.dart`
  or `node_patch.dart` without a new multi-file producer graph that actually
  needs it.
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
- `lib/src/contract/node_spec.dart` with a `part` attachment for internal
  fast-path construction
- `lib/src/contract/node_patch.dart` with a `part` attachment for internal
  fast-path construction
- producer-side `lib/src/model/**` call sites that assemble snapshots through
  public `*SnapshotFromValidated` helpers
- non-contract production imports of
  `internal/node_boundary_schema_{common,patch,spec,snapshot}.dart`,
  `internal/snapshot_backing.dart`,
  `internal/snapshot_materialization.dart`,
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
  snapshot, spec, patch, or validated-boundary owners; constructor/fast-path
  matrices and direction-mixed schema buckets are not accepted residuals.
