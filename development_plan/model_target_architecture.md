# Model Target Architecture

## Purpose

This document is the source of truth for the post-step-`51` target
architecture of `lib/src/model`.

Steps `45-51` may choose local code motion, helper placement, and verification
sequencing only inside the graph defined here. They are not allowed to
reinterpret the target graph while executing the plan.

If implementation reveals that this target graph is wrong, the graph must be
updated explicitly in this document before the step is considered complete.

## Target End State

- `lib/src/model/**` stays part-free.
- Public or downstream non-model code keeps entering the layer through the
  canonical facades rather than through internal owner modules.
- `document.dart` stays a canonical transaction facade and must not import
  `scene_builder.dart`.
- `scene_builder.dart`, `scene_node_boundary_mapping.dart`,
  `scene_value_validation.dart`, and `document_node_patch.dart` are thin
  facades or dispatchers rather than mixed owner buckets.
- Every remaining large `model` file is either an explicitly accepted focused
  owner or explicit remaining debt recorded by a follow-up step. Silent
  acceptance is forbidden.

## Canonical Boundaries

### Public or downstream non-model entry surfaces

- `lib/src/model/scene_builder_api.dart`
- `lib/src/model/scene_document_codec.dart`
- `lib/src/model/document.dart`
- `lib/src/model/scene_value_validation.dart`

### Model-local canonical facades

- `lib/src/model/scene_builder.dart`
- `lib/src/model/scene_node_boundary_mapping.dart`
- `lib/src/model/document_node_patch.dart`

These files may orchestrate internal owners, but they must not become generic
support buckets or recover the mixed ownership that steps `40-47` removed.

## Required Final File Graph

### Builder and runtime import graph

- `scene_builder_api.dart` stays the supported `SceneBuilder` surface.
- `scene_builder.dart` stays the thin internal import facade only.
- `scene_document_codec.dart` stays the canonical non-model runtime document
  codec facade.
- `scene_from_snapshot.dart` and `scene_snapshot_from_scene.dart` stay the
  shared runtime import/export owners.
- The parsed-map decode graph beneath `scene_builder.dart` is:
  - `scene_builder_decode_json.dart` as a thin orchestration facade.
  - `scene_builder_decode_scene.dart` as scene decode orchestration owner.
  - `scene_builder_decode_scene_metadata.dart` as schema-version and
    scene-metadata decode owner.
  - `scene_builder_decode_layers.dart` as background/content layer traversal
    decode owner.
  - `scene_builder_decode_node_common.dart` as common node decode owner.
  - `scene_builder_decode_node_family.dart` as family dispatch owner.
  - `scene_builder_decode_image.dart`
  - `scene_builder_decode_text.dart`
  - `scene_builder_decode_stroke.dart`
  - `scene_builder_decode_line.dart`
  - `scene_builder_decode_rect.dart`
  - `scene_builder_decode_path.dart`
  - `scene_builder_json_parse.dart` as scalar or enum parse owner.
  - `scene_builder_json_require.dart` as structural require or typed-extraction
    owner only.
- Parsed-map normalization stays inside `model/`; it does not move into
  `serialization/`.

### Mapping graph

- `scene_node_boundary_mapping.dart` stays the canonical dispatcher facade.
- `scene_node_boundary_mapping_common.dart` is the only common mapping owner.
- Family-local mapping owners are:
  - `scene_node_boundary_mapping_image.dart`
  - `scene_node_boundary_mapping_text.dart`
  - `scene_node_boundary_mapping_stroke.dart`
  - `scene_node_boundary_mapping_line.dart`
  - `scene_node_boundary_mapping_rect.dart`
  - `scene_node_boundary_mapping_path.dart`
- Each family owner is responsible for all of its own mapping directions:
  snapshot -> runtime,
  spec -> runtime,
  and
  runtime -> snapshot.
- `scene_node_boundary_mapping_support.dart` does not exist in the target
  state.

### Validation and scene-policy graph

- `scene_value_validation.dart` stays the canonical validation facade.
- Focused validation owners remain:
  - `scene_value_validation_node.dart`
  - `scene_value_validation_palette_grid.dart`
  - `scene_value_validation_primitives.dart`
  - `scene_value_validation_support.dart`
  - `scene_value_validation_top_level.dart`
- `scene_policy.dart` remains the only scene-level semantic owner.

### Document and patch graph

- `document.dart` stays the canonical downstream transaction facade.
- Focused document owners remain:
  - `document_locator.dart`
  - `document_scene_insert.dart`
  - `document_scene_edit.dart`
  - `document_selection.dart`
  - `document_clone.dart`
- The patch graph beneath `document.dart` is:
  - `document_node_patch.dart` as a thin dispatcher or validation facade.
  - `document_node_patch_common.dart` as common patch helper owner.
  - `document_node_patch_image.dart`
  - `document_node_patch_text.dart`
  - `document_node_patch_stroke.dart`
  - `document_node_patch_line.dart`
  - `document_node_patch_rect.dart`
  - `document_node_patch_path.dart`

## Explicit Non-Goals For Steps 45-51

- Reopening `scene_from_snapshot.dart` / `scene_snapshot_from_scene.dart`
  ownership.
- Reopening `scene_value_validation*.dart` into a new plan sequence.
- Reopening `scene_policy.dart` into a generic metrics-only decomposition.
- Moving decode, mapping, or patch semantics into `serialization/**`,
  `contract/**`, or `document.dart` just to reduce file-local metrics.

## Residual Policy

### Files that must not remain as residual mixed-owner hotspots after step `51`

- `lib/src/model/scene_builder_decode_json.dart`
- `lib/src/model/scene_builder_json_require.dart`
- `lib/src/model/scene_node_boundary_mapping_support.dart`
- `lib/src/model/document_node_patch.dart`
- `lib/src/model/scene_builder_decode_scene.dart`
- `lib/src/model/document_scene_edit.dart`

If any of these files still carry the mixed-owner role they have today, the
sequence has not reached its target state.

### Helper seams that must not remain open after step `50`

- The helper family centered on
  `lib/src/model/scene_builder_json_require.dart`
  and
  `lib/src/model/scene_builder_json_parse.dart`
  must no longer appear in the current cluster-`2` form.
  This seam is expected to close inside the existing two files through narrow
  optional field-access primitives owned by `scene_builder_json_require.dart`;
  new builder helper owner files or generic parser frameworks are forbidden.
- The exact duplicate pair
  `document_locator.dart::_txnResolveLayerNodesForLocator`
  and
  `document_scene_edit.dart::_txnResolveLayerNodesForErase`
  must be removed.
- The structural duplicate pair
  `document_locator.dart::_txnWriteLayerNodeLocations`
  and
  `document_scene_edit.dart::_txnReindexLayerNodes`
  must be removed.

### Owner seams that must not remain open after step `51`

- `scene_builder_decode_scene.dart` must no longer own both
  scene-metadata decode
  and
  layer traversal decode in the same file.
  After step `51`, it remains only the orchestration entry below
  `scene_builder_decode_json.dart`, while
  `scene_builder_decode_scene_metadata.dart`
  owns schema-version / camera / background / palette decode and
  `scene_builder_decode_layers.dart`
  owns background/content layer traversal decode.
- `document_scene_edit.dart` must no longer own both
  insert or target-layer resolution
  and
  erase or clear semantics.
  After step `51`,
  `document_scene_insert.dart`
  owns `txnInsertNodeInScene`, `txnResolveInsertLayerIndex`, and
  `txnFindContentLayerIndexById`,
  while
  `document_scene_edit.dart`
  owns erase / prepared-removal / clear semantics only.

### Measured post-step-`50` baseline

- The measured clone baseline after step `49` reports `13` clusters and `66`
  similar pairs across `lib/src/model`, but no cluster or pair keeps
  `scene_builder_json_require.dart` coupled to
  `scene_builder_json_parse.dart`.
- The named locator/index duplicate pairs between
  `document_locator.dart`
  and
  `document_scene_edit.dart`
  are absent from the measured post-step baseline.
- The remaining `HIGH` metric items are exactly the accepted focused-owner
  residuals listed below:
  `document.dart` `number-of-imports`,
  `document.dart::txnInsertNodeInScene` parameter count,
  `document_scene_insert.dart::txnInsertNodeInScene` parameter count,
  `scene_builder_decode_node_family.dart` `number-of-imports`,
  `scene_from_snapshot.dart::sceneFromSnapshot` source lines,
  and
  `scene_value_validation_node.dart` `number-of-imports`.
- No new `HIGH` / `VERY HIGH` hotspot appears outside that accepted residual
  set.

### Post-step-`51` large-file target

- `scene_builder_decode_scene.dart` must leave the accepted large-file set by
  becoming a thin orchestration owner.
- `document_scene_edit.dart` must stay below the review threshold and must not
  reacquire insert or target-layer ownership.

### Large-file review threshold for this sequence

- Review every top-level `lib/src/model/*.dart` file above `300` lines during
  step `50` and any file that step `51` touches while splitting the two
  residual owner seams.

### Large files currently expected to remain acceptable after steps `45-51`

These files may stay large only if step `51` confirms that they are focused
owners and not the center of a removed mixed-owner seam:

- `lib/src/model/scene_value_validation_node.dart`
- `lib/src/model/scene_value_validation_top_level.dart`
- `lib/src/model/scene_policy.dart`

Measured post-step-`50` line counts still keep
`scene_builder_decode_scene.dart` (`320`) above the threshold, which is why
step `51` exists. `document_scene_edit.dart` is `287` lines, but it remains an
open owner-split seam until insert/layer-target responsibilities move into
`document_scene_insert.dart`.

### Residual red metrics that may be acceptable without opening a new plan step

Only the following currently observed low-severity residuals may remain after
steps `45-51`, and only if step `51` classifies them explicitly as focused
tradeoffs:

- `lib/src/model/document.dart`: `number-of-imports`
- `lib/src/model/document.dart`: `txnInsertNodeInScene` parameter count
- `lib/src/model/document_scene_insert.dart`: `txnInsertNodeInScene` parameter
  count
- `lib/src/model/scene_builder_decode_node_family.dart`: `number-of-imports`
- `lib/src/model/scene_from_snapshot.dart`: `sceneFromSnapshot` source lines
- `lib/src/model/scene_value_validation_node.dart`: `number-of-imports`

If these residuals disappear, they must not be replaced by new red items in
other seams without updating this document.

## Closure Conditions

Step `51` may close only if all of the following are true:

- The measured `model` baseline matches this target graph.
- No removed mixed-owner seam is silently re-accepted as final state.
- Remaining large files and residual red metrics are classified explicitly
  against this document.
- Guardrails, invariants, and tool tests pin the relevant boundaries strongly
  enough that future scans can detect regression without re-deriving the
  intended architecture from step history.
