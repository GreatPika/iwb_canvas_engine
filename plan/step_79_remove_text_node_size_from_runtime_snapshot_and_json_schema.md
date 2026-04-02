language: russian

# Шаг 79. Удалить `TextNode.size` из runtime-модели, snapshot boundary и JSON schema

## 1. Change Mandate

Этот шаг удаляет `TextNode.size` как хранимый факт из runtime-модели, snapshot boundary и JSON schema, переводит текстовые bounds целиком на derived layout metrics и вводит новую единственную поддерживаемую JSON schema version без текстового `size`.

## 2. Change Boundary

### Included in the Change

- Удаление `size` из runtime `TextNode`, включая конструктор, stored field и любой write-side recompute branch.
- Удаление `size` из `TextNodeSnapshot` и из всех внутренних snapshot schema/backing/materialization owners для текста.
- Удаление text-size ветвления из model boundary mapping, import/export helpers, runtime validation и policy range checks.
- Удаление текстового `size` из JSON write/read contract, включая bump schema version, fixture data и path-aware decode rejection для legacy text payloads that still contain `size`.
- Перевод render geometry и text painting на derived text metrics вместо `TextNodeSnapshot.size`.
- Обновление repository source of truth: `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `PLAN.md`, this step file.

### Not Included in the Change

- Любая работа по общей немутируемости runtime `Scene` или по замене mutable scene graph на immutable runtime model.
- Любая работа по `StrokeNode.points`, `ScenePalette`, palette/stroke mutability или по unified numeric `reject vs normalize` policy.
- Любая попытка сохранить backward-compatible dual contract, в котором текстовый `size` одновременно считается удалённым и при этом продолжает silently survive в typed boundary или JSON decode.
- Любая смена semantics у non-text node `size` fields (`ImageNode`, `RectNode`, related snapshots/specs/JSON payloads).
- Любая новая generic unknown-field framework для JSON; в этом шаге запрещённый `size` закрывается локально для text nodes.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/core/box_nodes.dart`
- `lib/src/core/text_layout.dart`
- `lib/src/core/scene_limits.dart`
- `lib/src/contract/snapshot.dart`
- `lib/src/contract/internal/node_boundary_schema_snapshot.dart`
- `lib/src/contract/internal/snapshot_backing.dart`
- `lib/src/contract/internal/snapshot_materialization.dart`
- `lib/src/contract/internal/snapshot_boundary_impl.dart`
- `lib/src/contract/internal/snapshot_node_boundary_fallback.dart`
- `lib/src/model/document.dart`
- `lib/src/model/document_node_patch_text.dart`
- `lib/src/model/scene_builder_decode_text.dart`
- `lib/src/model/scene_from_snapshot.dart`
- `lib/src/model/scene_node_boundary_mapping.dart`
- `lib/src/model/scene_node_boundary_mapping_common.dart`
- `lib/src/model/scene_node_boundary_mapping_text.dart`
- `lib/src/model/scene_policy.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `lib/src/model/scene_value_validation_node_text.dart`
- `lib/src/interactive/interaction_eligibility_policy.dart`
- `lib/src/render/render_geometry_builder.dart`
- `lib/src/render/cache/scene_text_layout_cache.dart`
- `lib/src/render/scene_painter_node_renderer.dart`
- `lib/src/serialization/scene_codec.dart`
- `tool/invariant_registry.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Test Files

- `test/core/nodes_test.dart`
- `test/core/hit_test_test.dart`
- `test/model/document_model_test.dart`
- `test/model/document_clone_test.dart`
- `test/model/scene_builder_test.dart`
- `test/model/scene_value_validation_primitives_test.dart`
- `test/controller/core/scene_controller_copy_on_write_test.dart`
- `test/controller/scene_controller_randomized_txn_test.dart`
- `test/controller/support/scene_snapshot_invariant_assertions.dart`
- `test/interactive/core/interaction_eligibility_policy_test.dart`
- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
- `test/interactive/core/scene_controller_interactive_dispose_fail_fast_test.dart`
- `test/interactive/core/scene_controller_interactive_dispose_matrix_test.dart`
- `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`
- `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- `test/public_api/snapshot_immutability_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/scene_render_caches_test.dart`
- `test/render/scene_text_layout_cache_test.dart`
- `test/serialization/scene_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_fixture_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/view/scene_view_test.dart`

### Fixture and Supporting Data Files

- `test/fixtures/scene.json`
- `PLAN.md`
- `plan/step_79_remove_text_node_size_from_runtime_snapshot_and_json_schema.md`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `VERIFICATION.md`

### Analysis Area

- `lib/src/core/**`
- `lib/src/contract/**`
- `lib/src/interactive/**`
- `lib/src/model/**`
- `lib/src/render/**`
- `lib/src/serialization/**`
- `tool/**`
- `test/core/**`
- `test/model/**`
- `test/public_api/**`
- `test/serialization/**`
- `test/controller/**`
- `test/render/**`
- `test/tool/**`
- `test/view/**`
- `test/interactive/**`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `TextNode.size` is removed from runtime node state and must not remain as constructor parameter, mutable field, patch target, exported getter, or write-side synchronized cache visible outside a file-local owner.
2. `TextNodeSnapshot.size` is removed from the public snapshot boundary and from every internal text snapshot schema/backing/materialization/fallback owner.
3. Text bounds are derived only from text layout inputs (`text`, `fontSize`, `align`, `textDirection`, `fontFamily`, `lineHeight`, `maxWidth`, style flags) and must not be accepted as external input on any typed or JSON text boundary.
4. `TextNodeSnapshotSizePolicy` and every preserve/recompute text-size branch are removed; this step does not keep a transitional compatibility seam for stored text size.
5. JSON write version becomes `schemaVersion = 7`, JSON read set becomes `{7}`, and this step does not keep read compatibility for schema `6`.
6. Under schema version `7`, a text JSON object that still contains `size` must fail decode with a path-aware `SceneDataException` attributed to that text node `size` field; the field must not be ignored, canonicalized away, or converted into derived bounds.
7. Render geometry and painter placement for text must derive bounds from measured text layout, not from any stored snapshot size.
8. No new public API surface is introduced for exposing derived text size; if a local cache is needed, it stays file-local and non-serialized.
9. No new `lib/**` production file is introduced for this step; the change must be implemented inside the existing owner files listed in this contract.
10. Runtime text layout ownership is implemented as file-local cached derived metrics inside `lib/src/core/box_nodes.dart`; every layout-affecting `TextNode` mutation invalidates that cache, and `lib/src/core/text_layout.dart` remains a pure measurement owner instead of mutating runtime nodes.
11. `TextNode.fromTopLeftWorld(...)` remains supported as an AABB-based placement helper, but it must no longer accept a caller-supplied `size`; placement is resolved from the node’s derived text bounds after construction.
12. Snapshot-side text bounds for render geometry, painter alignment, interaction eligibility, and view/controller read-side flows must all derive from measured layout via the shared `TextLayoutRequest` normalization semantics; no second snapshot-specific width/height contract is allowed.

## 5. Result Requirements

1. `TextNode` no longer exposes a stored `size` field or constructor argument, and `TextNode.localBounds` is computed from derived text layout metrics.
2. Direct runtime mutation of any layout-affecting text field and `TextNodePatch` mutation of the same fields both keep text bounds correct without any explicit recompute helper at the call site.
3. `TextNodeSnapshot`, internal text snapshot schema/backing/materialization, scene validation, scene policy, and snapshot import/export no longer read, write, validate, range-check, or transport a text `size` field.
4. JSON encode never writes a text `size` field, JSON decode rejects schema-version-7 text nodes that contain `size`, and the only supported JSON schema version after the change is `7`.
5. Render geometry, selection/world-bounds computation, and text painting continue to place text correctly using measured layout output and explicit `textDirection`.
6. Repository docs, changelog, and fixture data describe the removed text `size` contract and the new schema version consistently.
7. `TextNode.fromTopLeftWorld(...)` and `topLeftWorld` continue to provide AABB-based text placement semantics without any caller-visible text `size` input.
8. `tool/invariant_registry.dart` no longer claims that a stored `TextNode.size` exists and instead points to the post-change invariant that text bounds are derived from text layout inputs without crossing typed or JSON boundaries as stored size.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `lib/src/core/box_nodes.dart` currently stores `TextNode.size` and uses it for `localBounds`.
- `lib/src/core/text_layout.dart` currently mutates `TextNode.size` through `recomputeDerivedTextSize(...)`.
- `lib/src/model/document_node_patch_text.dart` currently recomputes and compares stored size after text patch application.
- `lib/src/core/box_nodes.dart` currently exposes `TextNode.fromTopLeftWorld(...)` with a caller-supplied `size`, so placement semantics must be rewritten explicitly instead of left implicit.
- `lib/src/contract/snapshot.dart` and internal snapshot owners currently require and materialize `TextNodeSnapshot.size`.
- `lib/src/model/scene_builder_decode_text.dart` currently requires `size` from text JSON payloads.
- `lib/src/serialization/scene_codec.dart` currently writes text `size` and re-derives a canonical serialized size before JSON export.
- `lib/src/model/scene_policy.dart` and `lib/src/model/scene_value_validation_node_text.dart` currently validate and range-check text size.
- `lib/src/render/render_geometry_builder.dart` and `lib/src/render/scene_painter_node_renderer.dart` currently consume `TextNodeSnapshot.size`.
- `lib/src/interactive/interaction_eligibility_policy.dart` currently remeasures text snapshots locally and must stay aligned with the render-side text-bounds contract after snapshot `size` removal.
- `tool/invariant_registry.dart` currently contains `INV-ENG-TEXT-SIZE-DERIVED` with the title `TextNode.size is always derived from text layout inputs`, and this repository-local source of truth must be rewritten to the post-removal invariant wording.
- `test/fixtures/scene.json` currently uses `schemaVersion: 6` and carries text-node `size`.

### 6.2 Target Verification Units

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test shard preset `core`
- MCP test shard preset `model_contract`
- MCP test shard preset `controller_internal`
- MCP test shard preset `controller`
- MCP test shard preset `render_view`
- MCP test shard preset `interactive`
- MCP test shard preset `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

### 6.3 Protected States, Data, or Structures

- Explicit `textDirection` remains required for text typed boundaries and JSON decode.
- `TextAlign.start` / `TextAlign.end` semantics must continue to resolve against the text node’s explicit `textDirection`.
- Existing validation rules for `text`, `fontSize`, `fontFamily`, `maxWidth`, and `lineHeight` remain boundary-owned and must stay intact.
- Existing `size` semantics for non-text nodes remain unchanged.
- Existing scene/layer/background ownership and mutable-scene architecture remain unchanged.
- Existing text render/cache reuse in `SceneTextLayoutCache` remains the render-side owner for `TextPainter` reuse; this step must not introduce a second render-local text layout cache.
- `TextNode.topLeftWorld` and `TextNode.fromTopLeftWorld(...)` remain AABB-based placement helpers and must continue to honor the current world-bounds semantics after stored size removal.

### 6.4 Allowed Semantic Change Zones

- Runtime text node storage and invalidation semantics.
- Text snapshot/public boundary shape.
- Text-specific validation and scene-policy range semantics.
- Text import/export and model boundary mapping semantics.
- Text JSON schema/versioning and text-field decode/encode behavior.
- Text render geometry and painter placement semantics.
- Text contract documentation and changelog entries.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- direct runtime mutation of `TextNode` layout-affecting fields;
- patch-based text mutation through `TextNodePatch`;
- `TextNodeSpec -> TextNode` creation;
- `TextNodeSnapshot -> TextNode` import;
- `SceneNode -> TextNodeSnapshot` / `Scene -> SceneSnapshot` export;
- schema-version-7 JSON decode and encode of text nodes;
- legacy text JSON payloads that still contain a `size` field.
- `TextNode.fromTopLeftWorld(...)` and subsequent `topLeftWorld` mutations after runtime size removal;
- snapshot-based selection center / preview eligibility flows that previously tolerated stale serialized text size.

### 6.6 Allowed Forms That Do Not Count as Violations

- File-local cached derived layout metrics that are not exposed as constructor input, mutable field, snapshot getter, or serialized payload.
- Read-side measurement through `TextLayoutRequest`, `TextLayoutRequest.forNode(...)`, `SceneTextLayoutCache`, or `buildSceneTextPainter(...)`.
- Non-text nodes continuing to use stored `size`.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `TextNode.localBounds`, render geometry for `TextNodeSnapshot`, painter alignment for `TextNodeSnapshot`, and interactive snapshot center calculation must all resolve text extents through `TextLayoutRequest` normalization rules from `lib/src/core/text_layout.dart`; ad hoc numeric normalization outside that owner is forbidden.
- Snapshot-side text-bounds derivation may use render cache reuse where applicable, but every snapshot-side consumer that needs text extents must follow one field-to-layout mapping with explicit `textDirection`; render and interactive owners must not drift by maintaining separate semantic interpretations of text bounds.

### 6.8 Prohibited

- Keeping any text `size` field on `TextNode`, `TextNodeSnapshot`, or text JSON payloads as a deprecated compatibility alias.
- Replacing the removed field with a second externally writable mirror such as `measuredSize`, `layoutSize`, or another stored boundary field.
- Keeping `recomputeDerivedTextSize(...)` as a write-side synchronization helper that mutates a stored runtime size after patch/import/export.
- Keeping `TextNodeSnapshotSizePolicy` or any equivalent preserve-vs-recompute branch under a different name.
- Accepting schema `6` after this step or silently accepting/removing text `size` under schema `7`.
- Introducing a new generic unknown-field framework as part of this step.
- Leaving `TextNode.fromTopLeftWorld(...)` in a half-migrated state where it still accepts `size` but ignores it, or where top-left placement semantics silently change without an explicit contract update.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must be covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [ ] Runtime Text Node Without Stored Size

#### Slice Contract

`TextNode` keeps only text layout inputs in runtime state, derives local bounds from file-local layout metrics, and no runtime call site is responsible for manually resynchronizing a stored text size after mutation.

#### Change

Убрать `size` из `TextNode` constructor/field surface в `lib/src/core/box_nodes.dart`, перевести text bounds на file-local cached derived metrics with explicit invalidation for every layout-affecting field setter, переписать `TextNode.fromTopLeftWorld(...)` so it derives placement from measured text bounds instead of caller-supplied size, удалить write-side mutation of stored size from `lib/src/core/text_layout.dart` and `lib/src/model/document_node_patch_text.dart`, and update runtime text validation so it validates only text inputs and derived-read semantics instead of a stored text size field.

#### Verification

- `flutter analyze`
- MCP test run: root `.` paths `test/core/nodes_test.dart`, `test/core/hit_test_test.dart`
- MCP test run: root `.` paths `test/model/document_model_test.dart`, `test/model/document_clone_test.dart`, `test/model/scene_value_validation_primitives_test.dart`

#### Positive Scenarios

- A `TextNode` created from `TextNodeSpec` exposes correct local bounds without accepting a `size` constructor argument.
- Direct runtime mutation of `text`, `fontSize`, `textDirection`, `fontFamily`, `maxWidth`, and `lineHeight` updates derived bounds automatically.
- `TextNodePatch` updates the same layout-affecting fields without requiring a caller-visible recompute helper.
- `TextNode.fromTopLeftWorld(...)` positions text by derived AABB bounds without requiring a caller-supplied size.

#### Negative Scenarios

- No runtime path keeps a stale stored text size after a layout-affecting mutation.
- No write-side helper remains that mutates text size after patch application as a second owner of text layout semantics.
- No runtime placement helper still accepts or stores a text `size` input.

#### Closure Evidence

- Green run of the listed verifications.

### Slice 2. [ ] Snapshot Boundary And Render Path Without Text Size

#### Slice Contract

Text snapshot/export/import/render paths no longer transport or consume a stored text size field, and every text snapshot/render bound is derived from the text layout inputs instead of snapshot payload state.

#### Change

Удалить `size` from `TextNodeSnapshot` in `lib/src/contract/snapshot.dart`, from internal snapshot schema/backing/materialization/fallback owners, from `scene_node_boundary_mapping` text import/export, from `scene_from_snapshot.dart` / `document.dart` text-size-policy plumbing, from text-specific validation and scene-policy range checks, and from every snapshot-side consumer that currently reads `TextNodeSnapshot.size`; `lib/src/render/render_geometry_builder.dart`, `lib/src/render/scene_painter_node_renderer.dart`, `lib/src/render/cache/scene_text_layout_cache.dart`, and `lib/src/interactive/interaction_eligibility_policy.dart` must derive text bounds from measured text layout rather than `node.size`.

#### Verification

- `flutter analyze`
- MCP test run: root `.` paths `test/model`
- MCP test run: root `.` paths `test/public_api`
- MCP test run: root `.` paths `test/render/scene_painter_test.dart`, `test/render/scene_render_caches_test.dart`, `test/render/scene_text_layout_cache_test.dart`
- MCP test run: root `.` paths `test/view/scene_view_test.dart`, `test/view/scene_view_interactive_test.dart`
- MCP test run: root `.` paths `test/controller/core/scene_controller_copy_on_write_test.dart`, `test/controller/scene_controller_randomized_txn_test.dart`
- MCP test run: root `.` paths `test/interactive/core/interaction_eligibility_policy_test.dart`, `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`, `test/interactive/core/scene_controller_interactive_dispose_fail_fast_test.dart`, `test/interactive/core/scene_controller_interactive_dispose_matrix_test.dart`, `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`, `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`

#### Fixtures Used

- `test/fixtures/scene.json`

#### Positive Scenarios

- Typed text snapshots are created, materialized, cloned, rendered, and selected using only text layout inputs and explicit `textDirection`.
- Scene import/export round-trips text nodes without any text-size field on the typed snapshot boundary.
- Render geometry and painter alignment remain correct for text nodes after snapshot size removal.
- Snapshot-based center/selection and interactive preview flows continue to derive text bounds from measured layout and remain aligned with render-world bounds.

#### Negative Scenarios

- No import/export/render path depends on `TextNodeSnapshotSizePolicy` or on a stored text snapshot size.
- No scene validation or scene-policy range check still reports a text `.size` field.
- No interactive/controller read-side helper still assumes a stored text snapshot size exists.

#### Closure Evidence

- Green run of the listed verifications.

### Slice 3. [ ] Schema Version 7 Text JSON Without `size`

#### Slice Contract

The only supported JSON schema version is `7`, text JSON payloads never include `size`, and schema-version-7 decode fails on any text node that still carries `size`.

#### Change

Обновить schema constants in `lib/src/core/scene_limits.dart`, удалить text `size` from JSON encode in `lib/src/serialization/scene_codec.dart`, remove required text-size decode from `lib/src/model/scene_builder_decode_text.dart`, add an explicit path-aware rejection for text JSON objects that contain `size`, update `test/fixtures/scene.json`, and rewrite serialization/builder tests plus docs/changelog to the schema-version-7 contract without text `size`.

#### Verification

- `flutter analyze`
- MCP test run: root `.` paths `test/serialization`
- MCP test run: root `.` paths `test/model/scene_builder_test.dart`
- MCP test run: root `.` paths `test/public_api/scene_builder_test.dart`, `test/public_api/validated_boundary_value_test.dart`

#### Fixtures Used

- `test/fixtures/scene.json`

#### Positive Scenarios

- Encoding a scene with text nodes writes schema version `7` and omits text `size`.
- Decoding and `SceneBuilder.buildFromJson(...)` accept schema-version-7 text payloads that contain only layout inputs and explicit `textDirection`.
- The stable fixture round-trip remains green after removing text `size` and bumping schema version.

#### Negative Scenarios

- Decoding a schema-version-7 text node with `size` fails with a `SceneDataException` attributed to that text node `size` field.
- Decoding schema version `6` fails because the supported read set is `{7}` only.
- Typed/public boundary construction no longer accepts a text snapshot `size` field.

#### Closure Evidence

- Green run of the listed verifications.
- Diagnostic output for rejected text-node `size` under schema version `7`.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test shard preset `core`
- MCP test shard preset `model_contract`
- MCP test shard preset `controller_internal`
- MCP test shard preset `controller`
- MCP test shard preset `render_view`
- MCP test shard preset `interactive`
- MCP test shard preset `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
