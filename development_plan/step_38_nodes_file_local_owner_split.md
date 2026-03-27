language: russian

# Шаг 38. Разнести `nodes.dart` по file-local owner-модулям без переоткрытия core graph

## 1. Change Mandate

Этот шаг переносит пост-`37` node owner graph из одного перегруженного
`nodes.dart` в focused core-local files, сохраняя `nodes.dart` как
канонический import facade и не переоткрывая semantic seams, уже закрытые в
`core`.

## 2. Change Boundary

### Included in the Change

- Physical split of the mutable node owner graph from `lib/src/core/nodes.dart`
  into:
  `lib/src/core/scene_node.dart`,
  `lib/src/core/box_nodes.dart`,
  `lib/src/core/vector_nodes.dart`,
  and
  `lib/src/core/path_node.dart`.
- Preservation of `lib/src/core/nodes.dart` as the canonical mutable-node
  import facade for downstream consumers.
- Structural proof and architecture-doc updates required to pin the new
  file-local node owner graph.

### Not Included in the Change

- Reopening node semantics already closed by step `37`, including
  `SceneNode.transform`,
  `TextNode.size`,
  path-cache invalidation,
  mutable stroke-geometry revision behavior,
  and vector world/local normalization semantics.
- Reopening `text_layout.dart`, `action_events.dart`, `id_generator.dart`, or
  `pointer_input.dart`.
- Public API changes, package export changes, or higher-layer production
  refactors beyond direct import adaptation required by the file split.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/core/nodes.dart`
- `lib/src/core/scene_node.dart`
- `lib/src/core/box_nodes.dart`
- `lib/src/core/vector_nodes.dart`
- `lib/src/core/path_node.dart`
- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`

### Test Files

- `test/core/nodes_test.dart`
- `test/core/node_geometry_test.dart`
- `test/core/scene_spatial_index_test.dart`
- `test/render/render_geometry_cache_test.dart`
- `test/render/scene_stroke_path_cache_test.dart`
- `test/model/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`

### Fixture and Supporting Data Files

- `development_plan/step_38_nodes_file_local_owner_split.md`

### Analysis Area

- `lib/src/core/nodes.dart`
- `lib/src/core/scene_node.dart`
- `lib/src/core/box_nodes.dart`
- `lib/src/core/vector_nodes.dart`
- `lib/src/core/path_node.dart`
- `test/core/nodes_test.dart`
- `test/core/node_geometry_test.dart`
- `test/core/scene_spatial_index_test.dart`
- `test/render/render_geometry_cache_test.dart`
- `test/render/scene_stroke_path_cache_test.dart`
- `test/model/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `ARCHITECTURE.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one file-local node-owner
  slice.
- Every modified test must be tied to one structural or behavioral
  verification.
- Every modified documentation file must pin the final `nodes.dart` facade and
  file-local node owner graph.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. The post-`37` core owner graph remains locked:
   `SceneNode` is the common mutable shell,
   box/vector/path support owners stay explicit,
   and leaf support owners stay outside mutable node files.
2. `lib/src/core/nodes.dart` remains the canonical mutable-node import path for
   downstream non-node consumers.
3. `SceneNode.transform` remains the single source of truth for mutable node
   transforms.
4. `core/node_geometry.dart` and `core/scene_spatial_index.dart` remain the
   focused shared owners for runtime geometry and spatial-query concerns.

## 5. Result Requirements

1. `lib/src/core/nodes.dart` no longer keeps the current handwritten mutable
   node implementations and owner helper bodies in one file; it becomes a
   focused facade over file-local node owner modules.
2. `scene_node.dart`, `box_nodes.dart`, `vector_nodes.dart`, and
   `path_node.dart` each have one clear reason to change and keep only the node
   family and support seams that belong to that file.
3. No accepted residual `HIGH` metric after closure may belong to
   `lib/src/core/nodes.dart` as a file-size or import-concentration hotspot.
4. Existing render, spatial-index, model, and serialization consumers remain
   behaviorally equivalent.
5. `ARCHITECTURE.md` and structural proofs describe and pin the new node file
   graph consistently.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `lib/src/core/nodes.dart` currently has `1367` lines.
- `dcm calculate-metrics lib/src/core --report-all` currently reports one
  residual `HIGH` in `nodes.dart`: file `number-of-imports = 12`.
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/core`
  currently reports `3` remaining clone clusters, all concentrated in
  `nodes.dart`.
- Existing downstream consumers across `core`, `model`, `controller`,
  `interactive`, `view`, and `test` import `lib/src/core/nodes.dart` directly,
  so import-path stability is part of the change.
- `test/core/nodes_test.dart` currently pins the owner split inside one source
  file and must be updated to pin the final multi-file graph instead.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/core/nodes.dart lib/src/core/scene_node.dart lib/src/core/box_nodes.dart lib/src/core/vector_nodes.dart lib/src/core/path_node.dart --report-all`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner:
  `test/core/nodes_test.dart test/core/node_geometry_test.dart test/core/scene_spatial_index_test.dart`
- MCP test runner:
  `test/render/render_geometry_cache_test.dart test/render/scene_stroke_path_cache_test.dart`
- MCP test runner:
  `test/model/scene_builder_test.dart test/serialization/scene_codec_validation_test.dart`

### 6.3 Protected States, Data, or Structures

- `SceneNode.transform` and bounds semantics.
- Box-node `topLeftWorld` semantics.
- Stroke/line world/local normalization semantics.
- `PathNode` local-path cache invalidation and diagnostics behavior.
- `TextNode.size` derived layout semantics.
- Existing downstream mutable-node import path through `lib/src/core/nodes.dart`.

### 6.4 Allowed Semantic Change Zones

- Physical file allocation of the mutable node owner graph.
- Canonical mutable-node import facade design in `nodes.dart`.
- Structural tests and architecture documentation that pin the final file graph.
- Minimal import adaptation required to preserve the canonical facade boundary.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- Non-node consumers outside the split node implementation files must continue
  to import mutable nodes through `lib/src/core/nodes.dart`.
- New split node implementation files must not be imported directly from
  `model/**`,
  `controller/**`,
  `interactive/**`,
  `render/**`,
  `view/**`,
  or generic tests outside proofs that explicitly verify the file graph.
- `nodes.dart` may re-export the split node implementation files, but must not
  become a new handwritten semantic owner again.

### 6.8 Prohibited

- Using `part` / `part of` or a generated shell as a substitute for real
  file-local owner modules.
- Reopening node behavior semantics only to justify the physical split.
- Moving leaf support owners back into mutable node files.
- Allowing downstream higher layers to bypass `lib/src/core/nodes.dart` and
  import file-local node modules directly.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the
   trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must be
   covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [ ] File-local node owners exist beneath the canonical facade

#### Slice Contract

Mutable node implementations no longer co-reside in one handwritten
`nodes.dart`; they live in focused file-local owner modules beneath the
canonical `nodes.dart` facade.

#### Change

Create `scene_node.dart`, `box_nodes.dart`, `vector_nodes.dart`, and
`path_node.dart`, move the corresponding node families and support owners into
those files, and reduce `nodes.dart` to a focused import/export facade.

#### Verification

- `dcm calculate-metrics lib/src/core/nodes.dart lib/src/core/scene_node.dart lib/src/core/box_nodes.dart lib/src/core/vector_nodes.dart lib/src/core/path_node.dart --report-all`
- `dart run tool/check_import_boundaries.dart`
- MCP test runner:
  `test/core/node_geometry_test.dart test/core/scene_spatial_index_test.dart`
- MCP test runner:
  `test/render/render_geometry_cache_test.dart test/render/scene_stroke_path_cache_test.dart`
- MCP test runner:
  `test/model/scene_builder_test.dart test/serialization/scene_codec_validation_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `nodes.dart` no longer contains the handwritten implementations of the moved
  mutable node owners.

### Slice 2. [ ] Structural proofs pin the final node file graph

#### Slice Contract

Existing architectural proofs fail when the canonical `nodes.dart` facade or
the file-local node owner split regresses.

#### Change

Update `test/core/nodes_test.dart` and `ARCHITECTURE.md` so they pin the final
`nodes.dart` facade boundary and the focused file-local node owner graph.

#### Verification

- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/core/nodes_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `ARCHITECTURE.md` and `test/core/nodes_test.dart` describe the same final
  node file graph.

## 9. Final Verification

- `dcm calculate-metrics lib/src/core/nodes.dart lib/src/core/scene_node.dart lib/src/core/box_nodes.dart lib/src/core/vector_nodes.dart lib/src/core/path_node.dart --report-all`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner:
  `test/core/nodes_test.dart test/core/node_geometry_test.dart test/core/scene_spatial_index_test.dart`
- MCP test runner:
  `test/render/render_geometry_cache_test.dart test/render/scene_stroke_path_cache_test.dart`
- MCP test runner:
  `test/model/scene_builder_test.dart test/serialization/scene_codec_validation_test.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
