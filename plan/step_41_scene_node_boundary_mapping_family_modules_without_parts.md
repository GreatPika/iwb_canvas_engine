language: russian

# Шаг 41. Разрезать `scene_node_boundary_mapping` на family-local owner-модули без `part`-coupling

## 1. Change Mandate

Этот шаг переводит model-side node boundary mapping с hidden shared-library
layout на explicit family-local owner-модули так, чтобы
`scene_node_boundary_mapping.dart` стал тонким dispatcher facade без `part`
coupling, а runtime import/export entrypoints переиспользовали один и тот же
family-first mapping graph.

## 2. Change Boundary

### Included in the Change

- `lib/src/model/scene_node_boundary_mapping.dart`
- `lib/src/model/scene_node_boundary_mapping_common.part.dart`
- `lib/src/model/scene_node_boundary_mapping_from_snapshot.part.dart`
- `lib/src/model/scene_node_boundary_mapping_from_spec.part.dart`
- `lib/src/model/scene_node_boundary_mapping_to_snapshot.part.dart`
- Explicit family-local mapping modules beneath
  `scene_node_boundary_mapping.dart`
- `lib/src/model/scene_from_snapshot.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `lib/src/model/document.dart` only for node-mapping entrypoints and direct
  delegation spans
- `lib/src/model/document_clone.dart`

### Not Included in the Change

- Builder-local JSON require/decode ownership already covered by step `40`
- `scene_value_validation*.dart` decomposition
- `ScenePolicy` scene-level traversal semantics
- `document.dart` locator, insert, erase, selection, or patch-application
  ownership outside mapping delegation
- Public API surface changes in `lib/iwb_canvas_engine.dart`

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/model/scene_node_boundary_mapping.dart`
- `lib/src/model/scene_node_boundary_mapping_common.part.dart`
- `lib/src/model/scene_node_boundary_mapping_from_snapshot.part.dart`
- `lib/src/model/scene_node_boundary_mapping_from_spec.part.dart`
- `lib/src/model/scene_node_boundary_mapping_to_snapshot.part.dart`
- `lib/src/model/scene_node_boundary_mapping_image.dart`
- `lib/src/model/scene_node_boundary_mapping_text.dart`
- `lib/src/model/scene_node_boundary_mapping_stroke.dart`
- `lib/src/model/scene_node_boundary_mapping_line.dart`
- `lib/src/model/scene_node_boundary_mapping_rect.dart`
- `lib/src/model/scene_node_boundary_mapping_path.dart`
- `lib/src/model/scene_from_snapshot.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `lib/src/model/document.dart`
- `lib/src/model/document_clone.dart`

### Test Files

- `test/model/document_model_test.dart`
- `test/model/document_clone_test.dart`
- `test/model/scene_builder_test.dart`
- `test/model/scene_structural_limits_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/serialization/scene_fixture_test.dart`

### Fixture and Supporting Data Files

- `plan/step_40_scene_builder_thin_facade_and_runtime_import_export_spine.md`
- `plan/step_41_scene_node_boundary_mapping_family_modules_without_parts.md`

### Analysis Area

- `lib/src/model/scene_node_boundary_mapping*.dart`
- `lib/src/model/scene_from_snapshot.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `lib/src/model/document.dart`
- `lib/src/model/document_clone.dart`
- `test/model/document_model_test.dart`
- `test/model/document_clone_test.dart`
- `test/model/scene_builder_test.dart`
- `test/model/scene_structural_limits_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/serialization/scene_fixture_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one mapping-owner slice.
- Changes in `document.dart` are limited to node-mapping entrypoints and their
  direct delegation.
- Every modified test must pin one mapping behavior or structure guarantee.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. This step starts only after step `40` has closed the explicit
   `scene_from_snapshot.dart` runtime import owner.
2. `NodeBoundarySchema` remains the single source of boundary field semantics.
3. `scene_node_boundary_mapping.dart` remains the canonical model-local
   dispatcher entrypoint for runtime node mapping; it must not become a barrel,
   helper dump, or second schema owner.
4. Node family is the primary ownership axis for this seam; snapshot/spec/
   export direction is an operation within a family owner, not the top-level
   file split.
5. Derived text-size semantics remain single-owned and must not fork across
   mapping families.

## 5. Result Requirements

1. `lib/src/model/scene_node_boundary_mapping.dart` no longer contains
   `scene_node_boundary_mapping*.part.dart` declarations and becomes a thin
   dispatcher facade over explicit family-local modules.
2. One explicit family-local module exists for each supported boundary family:
   `image`, `text`, `stroke`, `line`, `rect`, and `path`.
3. `dcm calculate-metrics` no longer reports the current `VERY HIGH`
   `source-lines-of-code` hotspots on
   `sceneNodeFromSnapshotViaBoundarySchema(...)`,
   `sceneNodeFromSpecViaBoundarySchema(...)`,
   and
   `sceneNodeSnapshotFromViaBoundarySchema(...)`
   in `lib/src/model/scene_node_boundary_mapping.dart`.
4. `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
   no longer reports the current direction-first mapping family in the same
   form.
5. `txnNodeFromSnapshot(...)`, `txnNodeFromSpec(...)`,
   `txnSceneFromSnapshot(...)`, `txnSceneToSnapshot(...)`,
   and `sceneSnapshotFromScene(...)` remain behaviorally equivalent for the
   current snapshot/spec/runtime contracts.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Step `40` has already established `scene_from_snapshot.dart` as the explicit
  runtime import owner beneath `SceneBuilder` and `document.dart`; this step
  must consume that seam rather than reopening builder-owned wrappers.
- `scene_node_boundary_mapping.dart` currently still depends on four `part`
  files and carries three `VERY HIGH` dispatcher hotspots:
  `sceneNodeFromSnapshotViaBoundarySchema(...)`,
  `sceneNodeFromSpecViaBoundarySchema(...)`,
  and
  `sceneNodeSnapshotFromViaBoundarySchema(...)`.
- The current clone inventory in `lib/src/model` still includes a live
  mapping-family cluster centered on
  `scene_node_boundary_mapping_from_snapshot.part.dart`,
  `scene_node_boundary_mapping_from_spec.part.dart`,
  and
  `scene_node_boundary_mapping_to_snapshot.part.dart`.
- `document.dart`, `document_clone.dart`, `scene_from_snapshot.dart`, and
  `scene_snapshot_from_scene.dart` are the runtime consumers that must share
  the same family-local mapping graph after this step.
- The existing contract fast-path surface and `NodeBoundarySchema` ownership
  from steps `17.1-18.2` remain locked.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/model/scene_node_boundary_mapping.dart lib/src/model/scene_node_boundary_mapping_image.dart lib/src/model/scene_node_boundary_mapping_text.dart lib/src/model/scene_node_boundary_mapping_stroke.dart lib/src/model/scene_node_boundary_mapping_line.dart lib/src/model/scene_node_boundary_mapping_rect.dart lib/src/model/scene_node_boundary_mapping_path.dart lib/src/model/scene_from_snapshot.dart lib/src/model/scene_snapshot_from_scene.dart lib/src/model/document.dart lib/src/model/document_clone.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- `rg -n "^part 'scene_node_boundary_mapping_|^part of 'scene_node_boundary_mapping" lib/src/model`
- MCP test runner:
  `test/model/document_model_test.dart test/model/document_clone_test.dart test/model/scene_builder_test.dart test/model/scene_structural_limits_test.dart`
- MCP test runner:
  `test/public_api/scene_builder_test.dart test/public_api/validated_boundary_value_test.dart`
- MCP test runner:
  `test/serialization/scene_fixture_test.dart`

### 6.3 Protected States, Data, or Structures

- Runtime conversion parity between `Scene`, `SceneSnapshot`, and `NodeSpec`.
- `NodeBoundarySchema` ownership of boundary field semantics.
- Derived text-size behavior and boundary-to-runtime field normalization.
- Existing document-local mutation semantics outside the mapping delegation
  spans touched by this step.

### 6.4 Allowed Semantic Change Zones

- Physical file boundaries and imports inside the mapping seam.
- Mapping delegation from `document.dart`, `document_clone.dart`,
  `scene_from_snapshot.dart`, and `scene_snapshot_from_scene.dart`.
- Structural proofs and tests that pin the final family-first mapping graph.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- Downstream runtime consumers must continue to enter the mapping seam through
  `scene_node_boundary_mapping.dart`; family-local modules are internal
  implementation owners and must not become ad hoc direct dependencies across
  the layer.
- `scene_node_boundary_mapping.dart` may import family-local modules, but it
  must not re-export them.
- This step removes `part` coupling by using explicit module dependencies and
  family-local ownership, not by replacing `part` files with a new generic
  `helpers` or `utils` bucket.
- The change must not reopen `contract/internal/node_boundary_schema.dart` or
  create model-local copies of schema-owned field assembly.

### 6.8 Prohibited

- Keeping the current direction-first mapping bodies in parallel with the new
  family-local modules.
- Moving boundary field semantics or validated primitive rules out of
  `NodeBoundarySchema` and existing validated owners.
- Introducing new `part` / `part of` declarations in the mapping seam.
- Expanding `document.dart` scope beyond the direct mapping entrypoint spans.
- Changing mapping behavior solely to reduce metrics.

## 7. Execution Rules

1. This step starts only after step `40` is closed.
2. Slice `2` is forbidden until slice `1` is closed and verified.
3. This step closes only if the mapping seam becomes both part-free and
   family-first.
4. Scope expansion beyond model-side mapping ownership is forbidden.

## 8. Vertical Slices

### Slice 1. [x] `scene_node_boundary_mapping.dart` becomes a part-free family dispatcher

#### Slice Contract

The canonical mapping facade dispatches by node family to explicit owner
modules and no longer owns long direction-first bodies through `part`
coupling.

#### Change

Create the explicit family-local modules for `image`, `text`, `stroke`,
`line`, `rect`, and `path`, route
`sceneNodeFromSnapshotViaBoundarySchema(...)` and
`sceneNodeFromSpecViaBoundarySchema(...)` through them, and remove the
replaced mapping `part` bodies from the facade.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_node_boundary_mapping.dart lib/src/model/scene_node_boundary_mapping_image.dart lib/src/model/scene_node_boundary_mapping_text.dart lib/src/model/scene_node_boundary_mapping_stroke.dart lib/src/model/scene_node_boundary_mapping_line.dart lib/src/model/scene_node_boundary_mapping_rect.dart lib/src/model/scene_node_boundary_mapping_path.dart lib/src/model/document.dart --report-all`
- `rg -n "^part 'scene_node_boundary_mapping_|^part of 'scene_node_boundary_mapping" lib/src/model`
- MCP test runner:
  `test/model/document_model_test.dart`
- MCP test runner:
  `test/public_api/validated_boundary_value_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `scene_node_boundary_mapping.dart` no longer contains the replaced
  direction-first family bodies.
- Runtime node import-from-snapshot and import-from-spec entrypoints still
  resolve through the canonical facade.

### Slice 2. [x] All runtime import/export consumers share the same family-local mapping graph

#### Slice Contract

Scene import/export and document clone paths reuse the same family-local
modules without preserving the legacy mapping matrix in a different file.

#### Change

Route `scene_from_snapshot.dart`, `scene_snapshot_from_scene.dart`,
`document_clone.dart`, and any remaining export-side mapping callsites through
the same family-local modules, then delete the replaced mapping `part` files.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_from_snapshot.dart lib/src/model/scene_snapshot_from_scene.dart lib/src/model/document_clone.dart lib/src/model/scene_node_boundary_mapping.dart lib/src/model/scene_node_boundary_mapping_image.dart lib/src/model/scene_node_boundary_mapping_text.dart lib/src/model/scene_node_boundary_mapping_stroke.dart lib/src/model/scene_node_boundary_mapping_line.dart lib/src/model/scene_node_boundary_mapping_rect.dart lib/src/model/scene_node_boundary_mapping_path.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- MCP test runner:
  `test/model/document_clone_test.dart test/model/scene_builder_test.dart test/model/scene_structural_limits_test.dart`
- MCP test runner:
  `test/public_api/scene_builder_test.dart`
- MCP test runner:
  `test/serialization/scene_fixture_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- The current mapping-family clone cluster no longer appears in the same form.
- No `scene_node_boundary_mapping*.part.dart` file remains in the final
  mapping graph.

## 9. Final Verification

- `dcm calculate-metrics lib/src/model/scene_node_boundary_mapping.dart lib/src/model/scene_node_boundary_mapping_image.dart lib/src/model/scene_node_boundary_mapping_text.dart lib/src/model/scene_node_boundary_mapping_stroke.dart lib/src/model/scene_node_boundary_mapping_line.dart lib/src/model/scene_node_boundary_mapping_rect.dart lib/src/model/scene_node_boundary_mapping_path.dart lib/src/model/scene_from_snapshot.dart lib/src/model/scene_snapshot_from_scene.dart lib/src/model/document.dart lib/src/model/document_clone.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- `rg -n "^part 'scene_node_boundary_mapping_|^part of 'scene_node_boundary_mapping" lib/src/model`
- MCP test runner:
  `test/model/document_model_test.dart test/model/document_clone_test.dart test/model/scene_builder_test.dart test/model/scene_structural_limits_test.dart`
- MCP test runner:
  `test/public_api/scene_builder_test.dart test/public_api/validated_boundary_value_test.dart`
- MCP test runner:
  `test/serialization/scene_fixture_test.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
