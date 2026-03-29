language: russian

# Шаг 52. Разрезать `node_boundary_schema` на explicit direction owners и убрать schema `part`-coupling

## 1. Change Mandate

Этот шаг открывает residual `contract` cleanup sequence и закрывает первый
реальный architecture seam в слое: `node_boundary_schema.dart` больше не должен
быть giant static bucket, который держится на `part`-shared namespace для
patch/spec/snapshot semantics.

После шага `node_boundary_schema` должен стать thin internal barrel над
explicit direction owners без `part`-coupling, без возвращения логики в
`node_patch.dart` / `node_spec.dart` / `snapshot.dart` и без metric-only
compression.

Closure status after step `55`: the residual seams referenced below are closed,
and the final contract end-state is now pinned by
`plan/contract_target_architecture.md`,
`tool/check_guardrails.dart`, and
`INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY`.

## 2. Change Boundary

### Included in the Change

- `lib/src/contract/internal/node_boundary_schema.dart`
- `lib/src/contract/internal/node_boundary_schema_common.dart`
- `lib/src/contract/internal/node_boundary_schema_patch.dart`
- `lib/src/contract/internal/node_boundary_schema_spec.dart`
- `lib/src/contract/internal/node_boundary_schema_snapshot.dart`
- Removal of
  `lib/src/contract/internal/node_boundary_schema_patch.part.dart`
- Removal of
  `lib/src/contract/internal/node_boundary_schema_spec.part.dart`
- Removal of
  `lib/src/contract/internal/node_boundary_schema_snapshot.part.dart`
- Removal of
  `lib/src/contract/internal/node_boundary_schema_primitives.part.dart`
- `lib/src/contract/node_patch.dart` only for direct adaptation to the new
  internal schema surface
- `lib/src/contract/node_spec.dart` only for direct adaptation to the new
  internal schema surface
- `lib/src/contract/snapshot.dart` only for direct adaptation to the new
  internal schema surface
- `lib/src/serialization/scene_codec.dart` only for direct adaptation to the
  new internal schema surface
- `lib/src/model/**` only where `NodeBoundarySchema.*` call-sites must move to
  the new internal schema surface
- `ARCHITECTURE.md`
- `PLAN.md`
- `plan/contract_target_architecture.md`
- `plan/step_52_node_boundary_schema_explicit_owner_split.md`

### Not Included in the Change

- `snapshot_fast_path.part.dart` and the `snapshot.dart` fast-path seam beyond
  direct compatibility work required by the schema split
- Splitting `snapshot.dart` into multiple public files
- Reopening `transform2d.dart`, `scene_data_exception.dart`, or validated value
  owners
- Moving boundary validation logic into `model/**` or `serialization/**`
- New public API exports or entrypoints

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/internal/node_boundary_schema.dart`
- `lib/src/contract/internal/node_boundary_schema_common.dart`
- `lib/src/contract/internal/node_boundary_schema_patch.dart`
- `lib/src/contract/internal/node_boundary_schema_spec.dart`
- `lib/src/contract/internal/node_boundary_schema_snapshot.dart`
- `lib/src/contract/node_patch.dart`
- `lib/src/contract/node_spec.dart`
- `lib/src/contract/snapshot.dart`
- `lib/src/serialization/scene_codec.dart`
- `ARCHITECTURE.md`

### Test Files

- `test/contract/patch_field_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/contract/validated_fast_path_contract_test.dart`
- `test/contract/validated_internal_helpers_test.dart`
- `test/contract/contract_layer_smoke_test.dart`
- `test/public_api/node_patch_semantics_test.dart`
- `test/public_api/snapshot_immutability_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/model/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_fixture_test.dart`

### Fixture and Supporting Data Files

- `PLAN.md`
- `plan/contract_target_architecture.md`
- `plan/step_52_node_boundary_schema_explicit_owner_split.md`

### Analysis Area

- `lib/src/contract/internal/node_boundary_schema*.dart`
- `lib/src/contract/node_patch.dart`
- `lib/src/contract/node_spec.dart`
- `lib/src/contract/snapshot.dart`
- `lib/src/serialization/scene_codec.dart`
- `lib/src/model/**`
- `test/contract/**`
- `test/public_api/**`
- `test/model/**`
- `test/serialization/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified `node_boundary_schema*` file must be tied either to common
  schema ownership or to one exact direction owner: patch, spec, or snapshot.
- Every modified downstream call-site file must only adapt to the new internal
  schema surface; it must not take ownership of schema logic.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `plan/contract_target_architecture.md` is the source of truth
   for the contract cleanup sequence that starts at this step.
2. `lib/src/contract/internal/node_boundary_schema.dart` remains the canonical
   internal schema import surface, but after this step it is barrel-only.
3. `NodeBoundarySchema` as a giant static class is removed rather than kept as
   a compatibility wrapper, because retaining the bucket would preserve the
   wrong ownership shape even if implementation moved to new files.
4. Shared schema field typedefs and truly cross-direction primitive/common
   helpers move into `node_boundary_schema_common.dart`.
5. Patch/spec/snapshot validation and rehydration helpers move into
   `node_boundary_schema_patch.dart`,
   `node_boundary_schema_spec.dart`,
   and
   `node_boundary_schema_snapshot.dart`
   respectively.
6. `node_patch.dart`, `node_spec.dart`, `snapshot.dart`, `scene_codec.dart`,
   and `model/**` adapt to the new internal schema surface; they do not keep
   `NodeBoundarySchema.` compatibility calls.
7. `snapshot_fast_path.part.dart` is not reopened by this step; its cleanup is
   the next seam in the sequence after this step is closed and verified.

## 5. Result Requirements

1. `lib/src/contract/internal/node_boundary_schema.dart` contains no `part`
   directives and no static owner bucket.
2. `node_boundary_schema_common.dart`,
   `node_boundary_schema_patch.dart`,
   `node_boundary_schema_spec.dart`,
   and
   `node_boundary_schema_snapshot.dart`
   exist as normal Dart modules.
3. There are no remaining references to `NodeBoundarySchema.` in production
   code.
4. `node_patch.dart`, `node_spec.dart`, and `snapshot.dart` keep their public
   semantics while delegating to the new internal schema surface.
5. `scene_codec.dart` and affected `model/**` call sites reuse the new schema
   owners without regaining local validation logic.
6. `dcm` and clone results for the schema seam improve because the static class
   bucket and its `part` family no longer exist.
7. No new `HIGH` / `VERY HIGH` hotspot appears outside the still-open
   `snapshot` fast-path seam and the accepted focused public contract owners
   listed in `plan/contract_target_architecture.md`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current `node_boundary_schema.dart` owns shared typedefs, patch/spec/snapshot
  validation entrypoints, and rehydration helpers through a single static class
  plus four `part` files.
- This is the actual owner problem in the seam: patch/spec/snapshot directions
  are mixed inside one library-private namespace, so call sites cannot point at
  explicit owners.
- The correct architectural fix is not to make the static class thinner; it is
  to replace the bucket with explicit modules and a thin internal barrel.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/contract/internal/node_boundary_schema.dart lib/src/contract/internal/node_boundary_schema_common.dart lib/src/contract/internal/node_boundary_schema_patch.dart lib/src/contract/internal/node_boundary_schema_spec.dart lib/src/contract/internal/node_boundary_schema_snapshot.dart lib/src/contract/node_patch.dart lib/src/contract/node_spec.dart lib/src/contract/snapshot.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract`
- `dart run tool/analysis/find_similar_clones.dart lib/src/contract`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner:
  `test/contract`
- MCP test runner:
  `test/model test/serialization test/public_api test/entrypoints`

### 6.3 Protected States, Data, or Structures

- Public `NodePatch`, `NodeSpec`, and `NodeSnapshot` semantics.
- Error-code, path, and details attribution on validated boundary failures.
- `SceneBuilder` / `scene_codec.dart` behavior that depends on schema
  rehydration helpers.
- Snapshot immutability guarantees and collection ownership semantics.

### 6.4 Allowed Semantic Change Zones

- Internal contract schema ownership and internal call-site rewiring.
- Documentation updates required to pin the contract target graph.

### 6.8 Prohibited

- Keeping `NodeBoundarySchema` as a forwarding compatibility class.
- Replacing `part` files with a new `support`, `helpers`, or `utils` bucket.
- Moving patch/spec/snapshot schema logic into public boundary files.
- Reopening `snapshot_fast_path.part.dart` as part of this step.
- Cosmetic signature reshaping whose only purpose is to lower metrics.

## 7. Execution Rules

1. This step closes only if the schema seam is resolved by explicit owners and
   not by a renamed compatibility bucket.
2. The next contract step may be planned only after this step is verified and
   the measured schema baseline is understood.
3. Scope expansion into the snapshot fast-path seam is forbidden except for
   minimal compatibility work required to keep the schema split green.

## 8. Vertical Slices

### Slice 1. [x] Replace the static schema bucket with explicit owner modules

#### Slice Contract

The `node_boundary_schema` seam moves from a `part`-shared static class to a
thin internal barrel over explicit common / patch / spec / snapshot owners.

#### Change

Create the focused schema modules, move the confirmed helper families into
their direction owners, reduce `node_boundary_schema.dart` to an export or
barrel surface, and delete the legacy `part` files.

#### Verification

- `dcm calculate-metrics ...node_boundary_schema... --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract`
- `rg -n "NodeBoundarySchema\\.|part 'node_boundary_schema_.*part.dart'" lib/src/contract lib/src/model lib/src/serialization -g '*.dart'`

### Slice 2. [x] Rewire downstream contract, model, and serialization call sites

#### Slice Contract

Downstream code consumes the new internal schema surface without reintroducing
local validation or compatibility wrappers.

#### Change

Adapt `node_patch.dart`, `node_spec.dart`, `snapshot.dart`, `scene_codec.dart`,
and the affected `model/**` files to the new barrel or focused schema owners,
then remove the last `NodeBoundarySchema.` references.

#### Verification

- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- MCP test runner:
  `test/contract`
- MCP test runner:
  `test/model test/serialization test/public_api test/entrypoints`

## 9. Final Verification Checklist

- [x] `node_boundary_schema.dart` is a thin internal barrel only.
- [x] `node_boundary_schema*.part.dart` files are deleted.
- [x] `NodeBoundarySchema.` no longer appears in production code.
- [x] Public patch/spec/snapshot behavior is unchanged.
- [x] Metrics and clone output improve on the schema seam without reopening the
      snapshot fast-path seam.
- [x] `plan/contract_target_architecture.md`,
      `PLAN.md`,
      and this step describe one consistent post-step state.
