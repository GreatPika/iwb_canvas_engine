language: russian

# Шаг 53. Перестроить snapshot boundary: internal graph, public materialization, producer-side model rewiring

## 1. Change Mandate

Этот шаг закрывает snapshot fast-path seam честно: privileged snapshot
assembly уходит из public `snapshot.dart` в explicit internal snapshot graph,
`model/**` producer spine перестаёт собирать snapshot family через public
fast-path surface, а публичный snapshot boundary остаётся совместимым как thin
public wrapper layer over immutable internal snapshot backing.

Closure status after step `55`: this snapshot split is part of the final
contract architecture and is now pinned mechanically by
`plan/contract_target_architecture.md`,
`tool/check_guardrails.dart`, and
`INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY`.

## 2. Change Boundary

### Included in the Change

- `lib/src/contract/snapshot.dart`
- Removal of `lib/src/contract/internal/snapshot_fast_path.part.dart`
- `lib/src/contract/internal/snapshot_fast_path.dart`
- `lib/src/contract/internal/snapshot_backing.dart`
- `lib/src/contract/internal/snapshot_materialization.dart`
- `lib/iwb_canvas_engine.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `lib/src/model/scene_builder_decode_*.dart`
- `lib/src/model/scene_node_boundary_mapping*.dart`
- `test/contract/contract_layer_smoke_test.dart`
- `test/contract/validated_fast_path_contract_test.dart`
- `test/public_api/snapshot_immutability_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/model/document_model_test.dart`
- `test/model/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_fixture_test.dart`
- `test/controller/core/scene_controller_commit_failures_test.dart`
- `test/controller/scene_snapshot_invariant_assertions_test.dart`
- `test/render/render_geometry_cache_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/scene_text_layout_cache_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `ARCHITECTURE.md`
- `PLAN.md`
- `plan/contract_target_architecture.md`
- `plan/step_53_snapshot_fast_path_explicit_internal_owners.md`

### Not Included in the Change

- `lib/src/contract/node_patch.dart`
- `lib/src/contract/node_spec.dart`
- `lib/src/model/scene_policy.dart`
- `lib/src/model/scene_value_validation*.dart`
- `lib/src/serialization/**` beyond direct compatibility edits required by the
  new snapshot producer graph
- `example/**`
- `tool/**`
- Splitting `snapshot.dart` into one public file per snapshot family
- A symmetry follow-up for `node_patch.dart` / `node_spec.dart`

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/snapshot.dart`
- `lib/src/contract/internal/snapshot_fast_path.dart`
- `lib/src/contract/internal/snapshot_backing.dart`
- `lib/src/contract/internal/snapshot_materialization.dart`
- `lib/iwb_canvas_engine.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `lib/src/model/scene_builder_decode_*.dart`
- `lib/src/model/scene_node_boundary_mapping*.dart`
- `ARCHITECTURE.md`

### Test Files

- `test/contract/contract_layer_smoke_test.dart`
- `test/contract/validated_fast_path_contract_test.dart`
- `test/public_api/snapshot_immutability_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/model/document_model_test.dart`
- `test/model/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_fixture_test.dart`
- `test/controller/core/scene_controller_commit_failures_test.dart`
- `test/controller/scene_snapshot_invariant_assertions_test.dart`
- `test/render/render_geometry_cache_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/scene_text_layout_cache_test.dart`
- `test/view/scene_view_interactive_test.dart`

### Fixture and Supporting Data Files

- `test/fixtures/scene.json`
- `PLAN.md`
- `plan/contract_target_architecture.md`
- `plan/step_53_snapshot_fast_path_explicit_internal_owners.md`

### Analysis Area

- `lib/src/contract/snapshot.dart`
- `lib/src/contract/internal/snapshot*.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `lib/src/model/scene_builder_decode_*.dart`
- `lib/src/model/scene_node_boundary_mapping*.dart`
- `lib/iwb_canvas_engine.dart`
- `test/contract/**`
- `test/public_api/**`
- `test/model/**`
- `test/serialization/**`
- `test/controller/**`
- `test/render/**`
- `test/view/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified internal snapshot file must be tied to one exact owner role:
  backing, materialization, or canonical fast-path import surface.
- Every modified `model/**` file must either become a producer of internal
  snapshot graph data or become a public-edge materialization point; it must
  not retain privileged snapshot assembly.
- Every new or modified test must be tied to one verification of public
  compatibility, malformed-snapshot behavior, or downstream consumer
  stability.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `plan/contract_target_architecture.md` remains the source of
   truth for the contract cleanup sequence that starts at step `52`.
2. `snapshot.dart` remains the only supported public snapshot surface and must
   keep public API compatibility.
3. `snapshot.dart` is part-free in the target state of this step.
4. Trusted snapshot assembly moves into explicit internal owners and is not
   kept as a public `_internal` constructor matrix or as `part`-local
   privileged plumbing.
5. Producer-side `model/**` code that assembles snapshots must depend on the
   new internal snapshot construction surface instead of hidden helpers from
   the public snapshot library.
6. The public snapshot materialization model for this step is fixed: scene,
   layer, palette, and node snapshot types become thin public wrappers over
   immutable internal backing objects; one-way copied materialization and
   adapter-only alternatives are not part of this step.
7. `sceneSnapshotFromValidated` and node-family `*SnapshotFromValidated`
   helpers may survive only as internal compatibility helpers for failure
   injection and contract tests; they are not the runtime construction model
   after this step.
8. `CameraSnapshot`, `BackgroundSnapshot`, and `GridSnapshot` remain direct
   public value objects in this step because they are not the privileged
   assembly seam being closed.
9. `node_patch.dart` and `node_spec.dart` stay out of scope for this step and
   are not reopened for symmetry work here.

## 5. Result Requirements

1. `lib/src/contract/snapshot.dart` contains no `part` directives and no
   privileged fast-path constructor matrix.
2. `lib/src/contract/internal/snapshot_fast_path.part.dart` no longer exists,
   and `lib/src/contract/internal/snapshot_fast_path.dart` exists as the
   canonical internal snapshot construction import surface.
3. Trusted immutable snapshot representation is owned by explicit internal
   files for backing storage and public materialization.
4. Public `SceneSnapshot`, layer snapshots, palette snapshot, and every
   concrete `NodeSnapshot` subtype remain the same observable public types with
   the same public fields and subtype dispatch surface.
5. Public scene/layer/palette/node snapshots in this step are thin wrappers
   over immutable internal backing objects rather than copied materialized
   value objects.
6. Public snapshot constructors preserve current validation, canonical
   defaults, defensive copying, immutable collections, and text-size
   semantics.
7. Producer-side files in `lib/src/model/**` no longer assemble snapshots
   through `*SnapshotFromValidated` helpers imported from `snapshot.dart`.
8. Malformed snapshot regression scenarios remain constructible through the
   internal snapshot fast-path surface and still fail at downstream policy,
   codec, or controller boundaries rather than at public constructor entry.
9. No new public exports or entrypoints are added to `lib/iwb_canvas_engine.dart`
   or to the public snapshot surface.
10. Architecture and roadmap documents describe the new snapshot graph as
    `internal backing graph -> thin public wrapper edge`, not as `public
    snapshot class with hidden privileged assembly`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- The current seam is wider than `snapshot.dart`: the public snapshot library
  owns privileged construction through `snapshot_fast_path.part.dart`, and the
  producer-side `model/**` graph depends on that public fast-path matrix for
  runtime-to-snapshot mapping and JSON decode.
- A contract-local backing refactor alone does not close this step, because it
  leaves the model producer graph on the old construction model even if
  `snapshot.dart` becomes thinner internally.
- The honest fix is a boundary-model change: explicit internal snapshot
  representation, explicit public materialization, and producer-side rewiring
  to that internal graph.
- `scene_policy.dart`, `scene_value_validation*.dart`, and most of
  `serialization/**` stay consumer-side users of public snapshots unless a
  direct compatibility edit is required to keep the redesigned graph green.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/contract/snapshot.dart lib/src/contract/internal/snapshot*.dart lib/src/model/scene_snapshot_from_scene.dart lib/src/model/scene_builder_decode_*.dart lib/src/model/scene_node_boundary_mapping*.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract lib/src/model`
- `dart run tool/analysis/find_similar_clones.dart lib/src/contract lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `! rg -n "sceneSnapshotFromValidated|backgroundLayerSnapshotFromValidated|contentLayerSnapshotFromValidated|scenePaletteSnapshotFromValidated|imageNodeSnapshotFromValidated|textNodeSnapshotFromValidated|strokeNodeSnapshotFromValidated|lineNodeSnapshotFromValidated|rectNodeSnapshotFromValidated|pathNodeSnapshotFromValidated" lib/src/model`
- MCP test runner:
  `test/contract test/public_api`
- MCP test runner:
  `test/model test/serialization`
- MCP test runner:
  `test/controller/core test/controller/commands` plus controller-root
  `*_test.dart` files
- MCP test runner:
  `test/render test/view`

### 6.3 Protected States, Data, or Structures

- Public snapshot field names, field types, and subtype-dispatch behavior.
- Immutable ownership of scene-layer lists, node lists, palette lists, and
  stroke-point payloads.
- Public constructor validation for ids, transforms, opacity, hit padding,
  scene palette data, and geometry/text fields.
- Import canonicalization behavior and path-aware diagnostics exposed through
  `SceneBuilder` and `decodeScene`.
- Downstream consumers that key off snapshot fields and revisions in
  controller, render, and view code.
- Existing malformed snapshot scenarios used to prove downstream boundary
  enforcement.

### 6.4 Allowed Semantic Change Zones

- Internal snapshot representation and backing ownership.
- Public snapshot wrapper implementation over internal backing.
- Producer-side model assembly for runtime-to-snapshot mapping and JSON decode.
- Internal compatibility fast-path helpers used by contract tests and
  malformed-snapshot regression tests.
- Public export adaptation required to keep internal helpers out of the package
  root.
- Documentation and roadmap text required to pin the final snapshot graph.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- When proving producer-side rewiring, structural analysis must treat direct
  imports of `snapshot.dart`, package-root re-exports, and any `show` / `hide`
  aliases as equivalent uses of the public snapshot surface.
- The step is not closed while any `lib/src/model/**` file resolves
  `*SnapshotFromValidated` symbols from the public snapshot library or while
  any `part` attachment keeps snapshot fast-path assembly inside the public
  snapshot library.

### 6.8 Prohibited

- Keeping `snapshot_fast_path.part.dart` or introducing a new `part`-based
  fast-path family under `snapshot.dart`.
- Keeping public snapshot `_internal` constructors as the runtime or model
  fast-path allocation path after the redesign.
- Leaving producer-side `model/**` assembly on public
  `*SnapshotFromValidated` helpers.
- Moving public snapshot validation into `model/**` or `serialization/**`.
- Replacing the fixed wrapper model with copied public materialization or an
  adapter-only layer.
- Adding wrapper interning, synchronized duplicate state, or any other
  multi-source snapshot ownership.
- Exporting internal snapshot owner files from the public package root.
- Reopening `node_patch.dart` or `node_spec.dart` as part of this step.
- Metric-only wrappers or helper indirection that preserve the old ownership
  model under new names.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the
   trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must
   be covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.
9. This step closes only if both seams are closed together: the public
   snapshot-library seam and the producer-side model-construction seam.
10. A contract-local backing rewrite without producer-side model rewiring does
    not count as closing this step.
11. A producer-side rewiring that still materializes through public fast-path
    helpers does not count as closing this step.

## 8. Vertical Slices

### Slice 1. [x] Introduce the internal snapshot graph and thin public wrapper model

#### Slice Contract

Public snapshot classes stop owning trusted field assembly and become thin
public wrappers over explicit immutable internal snapshot backing objects.

#### Change

Create the focused internal snapshot owners for backing storage and wrapper
materialization, convert `snapshot.dart` scene/layer/palette/node families to
delegate storage to that graph, keep `CameraSnapshot` / `BackgroundSnapshot` /
`GridSnapshot` as direct public value objects, and preserve current public
constructor behavior.

#### Verification

- `dcm calculate-metrics lib/src/contract/snapshot.dart lib/src/contract/internal/snapshot*.dart --report-all`
- `dart run tool/check_public_api_surface.dart`
- MCP test runner:
  `test/contract/contract_layer_smoke_test.dart test/public_api/snapshot_immutability_test.dart`

#### Positive Scenarios

- Public constructors still validate ids, numeric ranges, and immutable
  collections.
- Public snapshot fields remain readable through the same types and names as
  before the change.

#### Closure Evidence

- Green run of the listed verifications.
- `snapshot_immutability_test.dart` still proves defensive copying and frozen
  collections for scene, palette, and stroke payloads.

### Slice 2. [x] Rewire runtime-to-snapshot and JSON-decode producers to the internal graph

#### Slice Contract

Producer-side `model/**` code assembles snapshots through the internal
snapshot graph and materializes public snapshot objects only at the public
edges that must still return public snapshot types.

#### Change

Refactor `scene_snapshot_from_scene.dart`, the `scene_builder_decode_*.dart`
graph, and the `scene_node_boundary_mapping*.dart` graph so their construction
path targets internal snapshot owners instead of public fast-path helpers from
`snapshot.dart`.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_snapshot_from_scene.dart lib/src/model/scene_builder_decode_*.dart lib/src/model/scene_node_boundary_mapping*.dart --report-all`
- `dart run tool/check_import_boundaries.dart`
- `! rg -n "sceneSnapshotFromValidated|backgroundLayerSnapshotFromValidated|contentLayerSnapshotFromValidated|scenePaletteSnapshotFromValidated|imageNodeSnapshotFromValidated|textNodeSnapshotFromValidated|strokeNodeSnapshotFromValidated|lineNodeSnapshotFromValidated|rectNodeSnapshotFromValidated|pathNodeSnapshotFromValidated" lib/src/model`
- MCP test runner:
  `test/model/document_model_test.dart test/model/scene_builder_test.dart test/public_api/scene_builder_test.dart`

#### Positive Scenarios

- `sceneSnapshotFromScene(...)` still returns the same public `SceneSnapshot`
  contract type.
- `sceneBuilderDecodeSceneSnapshotFromJson(...)` and `SceneBuilder.buildFromJson(...)`
  still return public snapshot objects with the same diagnostics and
  canonicalization behavior.

#### Closure Evidence

- Green run of the listed verifications.
- The `rg` verification returns no producer-side `model/**` call sites that
  still use the public snapshot fast-path helper family.

### Slice 3. [x] Replace the legacy fast-path matrix with an internal compatibility surface

#### Slice Contract

The legacy `snapshot_fast_path.part.dart` seam disappears, and internal
validated or malformed snapshot construction survives only through an explicit
internal compatibility surface layered on top of the new internal graph.

#### Change

Delete `snapshot_fast_path.part.dart`, introduce `internal/snapshot_fast_path.dart`
as the canonical internal snapshot construction surface, move any remaining
validated or failure-injection helper bodies onto backing/materialization
owners, and adapt `iwb_canvas_engine.dart` plus contract tests to the new
surface.

#### Verification

- `! rg -n "part 'internal/snapshot_fast_path.part.dart'|part of '../snapshot.dart'" lib/src/contract`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- MCP test runner:
  `test/contract/validated_fast_path_contract_test.dart`

#### Negative Scenarios

- Malformed snapshot construction still bypasses public validation only through
  the internal surface.
- Contract tests still exercise typed validated helpers without regaining
  privileged construction inside the public snapshot library.

#### Closure Evidence

- Green run of the listed verifications.
- The `rg` verification returns no `snapshot.dart` fast-path `part`
  attachment and no remaining `part of '../snapshot.dart'` fast-path module.

### Slice 4. [x] Rebaseline downstream proof surface for the new snapshot boundary model

#### Slice Contract

Serialization, controller, render, and view consumers continue to work against
the same public snapshot API after the producer-side redesign, and the
roadmap/architecture documents pin the new owner graph explicitly.

#### Change

Update the required downstream tests and documentation so they prove public
compatibility, malformed-snapshot failure behavior, and render/controller/view
stability against the new internal-graph plus public-materialization design.

#### Verification

- MCP test runner:
  `test/serialization/scene_codec_validation_test.dart test/serialization/scene_fixture_test.dart`
- MCP test runner:
  `test/controller/core/scene_controller_commit_failures_test.dart test/controller/scene_snapshot_invariant_assertions_test.dart`
- MCP test runner:
  `test/render/render_geometry_cache_test.dart test/render/scene_painter_test.dart test/render/scene_text_layout_cache_test.dart`
- MCP test runner:
  `test/view/scene_view_interactive_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Fixtures Used

- `test/fixtures/scene.json`

#### Positive Scenarios

- Stable scene fixture round-trip still produces the same JSON.
- Controller, render, and view flows still consume the same public snapshot
  fields and subtype graph.

#### Negative Scenarios

- Invalid palette/grid/node snapshots built through the internal compatibility
  surface still fail in codec or policy boundaries, not at public constructor
  entrypoints.

#### Closure Evidence

- Green run of the listed verifications.
- Diagnostic output from malformed snapshot tests still points at downstream
  codec, policy, or controller boundaries.
- `ARCHITECTURE.md`, `PLAN.md`, and
  `plan/contract_target_architecture.md` describe the final
  snapshot graph consistently.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/contract/snapshot.dart lib/src/contract/internal/snapshot*.dart lib/src/model/scene_snapshot_from_scene.dart lib/src/model/scene_builder_decode_*.dart lib/src/model/scene_node_boundary_mapping*.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract lib/src/model`
- `dart run tool/analysis/find_similar_clones.dart lib/src/contract lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner:
  `test/core`
- MCP test runner:
  `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner:
  `test/controller/internal`
- MCP test runner:
  `test/controller/core test/controller/commands` plus controller-root
  `*_test.dart` files
- MCP test runner:
  `test/render test/view`
- MCP test runner:
  `test/interactive`
- MCP test runner:
  `example/test` with MCP root `example/`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
