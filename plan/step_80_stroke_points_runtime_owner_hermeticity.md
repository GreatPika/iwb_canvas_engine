language: russian

# Шаг 80. Герметизировать runtime owner stroke geometry и убрать прямую мутацию `StrokeNode.points`

## 1. Change Mandate

Этот шаг убирает прямую внешнюю мутацию geometry-list у `StrokeNode`, делает node-owned stroke geometry API единственным runtime owner-ом `points` и `pointsRevision`, и закрывает обход stroke invariants через свободный `List`-view.

## 2. Change Boundary

### Included in the Change

- Удаление externally mutable list-surface у `StrokeNode.points` в runtime-core.
- Введение одного канонического node-owned geometry write API для stroke points в `lib/src/core/vector_nodes.dart`.
- Перевод patch-пути stroke geometry на канонический runtime geometry owner вместо прямого `List`-mutation bypass.
- Сохранение monotonic `pointsRevision` semantics только под ownership runtime stroke geometry owner-а.
- Обновление repository source of truth: `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `PLAN.md`, this step file, `tool/invariant_registry.dart`.

### Not Included in the Change

- Любая смена typed/public snapshot boundary для `StrokeNodeSnapshot.points` или `pointsRevision`.
- Любая смена JSON schema, encode/decode contract или scene import/export shape для stroke.
- Любая работа по `ScenePalette`, grid policy, `opacity`, `TextNode`, line/path geometry.
- Любая автоматическая нормализация, сэмплирование или downsampling stroke geometry внутри runtime `StrokeNode`.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/core/vector_nodes.dart`
- `lib/src/model/document_node_patch_stroke.dart`
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
- `test/controller/internal/scene_writer_test.dart`
- `test/controller/core/scene_controller_commit_atomicity_test.dart`
- `test/render/scene_stroke_path_cache_test.dart`
- `test/render/render_geometry_cache_test.dart`

### Fixture and Supporting Data Files

- `PLAN.md`
- `plan/step_80_stroke_points_runtime_owner_hermeticity.md`
- `VERIFICATION.md`

### Analysis Area

- `lib/src/core/**`
- `lib/src/model/**`
- `tool/**`
- `test/core/**`
- `test/model/**`
- `test/controller/**`
- `test/render/**`
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
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `StrokeNode.points` remains readable from runtime code, but the returned collection is an immutable view for external callers and must reject list mutator methods.
2. Runtime stroke geometry mutation is owned only by `StrokeNode.replacePoints(List<Offset> points)` in `lib/src/core/vector_nodes.dart`; this step does not keep point-level mutator surfaces such as external `add`, `insert`, `[]=`, `clear`, or `replaceRange`.
3. `pointsRevision` remains stored runtime metadata because render caches use it, but revision changes are owned only by the canonical stroke geometry write API and must not be re-owned by patch helpers or caches.
4. The canonical stroke geometry write API validates finite coordinates and `kMaxStrokePointsPerNode` at mutation time and rejects invalid input instead of truncating, dropping, or normalizing points.
5. `StrokeNodePatch.points` remains a whole-list patch field; patch application must use the canonical stroke geometry write API and must not mutate any runtime `List` view directly.
6. Typed/public snapshot and JSON stroke contracts remain unchanged in this step.
7. No new `lib/**` production file is introduced for this step.

## 5. Result Requirements

1. External runtime code can no longer mutate `StrokeNode.points` through `List` mutator methods.
2. Every runtime stroke geometry change goes through one canonical node-owned API that enforces finite-point and point-count invariants.
3. `pointsRevision` increments only when the logical stroke point sequence changes and remains unchanged for no-op geometry writes.
4. Patch application, clone independence, hit-testing, render geometry caching, and stroke path caching continue to behave correctly after the direct list-view mutation surface is removed.
5. Repository docs and invariant registry describe `StrokeNode.points` as a hermetic runtime geometry owner rather than an externally mutable list.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `lib/src/core/vector_nodes.dart` currently exposes `StrokeNode.points` through `_RevisionedOffsetListView`, which allows broad direct mutation and increments revision without revalidating count or finite-point invariants after construction.
- `lib/src/model/document_node_patch_stroke.dart` currently applies geometry patches through `stroke.points.replaceRange(...)`, which is a direct bypass around a node-owned geometry API.
- `test/core/nodes_test.dart` currently proves direct `List` mutations and no-op list mutations against the mutable `points` view.
- `test/model/document_clone_test.dart` currently mutates cloned runtime stroke points directly with `cloneNode.points.add(...)`.
- Render caches and snapshot mappings consume `pointsRevision` and `points` as read-side data and must stay compatible with a hermetic runtime write owner.

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

- `StrokeNodeSnapshot.points` remains immutable typed boundary data.
- Historical note: this step still assumed public `StrokeNodeSnapshot.pointsRevision`;
  that boundary field was removed later by step 87 and is no longer part of the
  current contract.
- Existing point-count invariants in typed, decode, and encode paths remain unchanged.
- Existing stroke geometry semantics for hit-testing and rendering remain unchanged.

### 6.4 Allowed Semantic Change Zones

- Runtime stroke geometry ownership and mutation semantics.
- Runtime patch application semantics for stroke points.
- Runtime clone/independence semantics for stroke geometry.
- Runtime documentation and invariant wording for stroke geometry ownership.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- direct runtime bypass through `StrokeNode.points.add(...)`, `insert(...)`, `[]=`, `clear()`, `removeAt(...)`, `replaceRange(...)`, and similar list mutations;
- whole-geometry replacement through `StrokeNodePatch.points`;
- clone-based independence checks for runtime stroke geometry;
- render/path-cache freshness checks that observe `pointsRevision`.

### 6.6 Allowed Forms That Do Not Count as Violations

- Read-only iteration over `StrokeNode.points`.
- Whole-list replacement through `StrokeNode.replacePoints(...)`.
- Snapshot and JSON stroke points remaining list-shaped and immutable at the boundary.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `pointsRevision` freshness ownership must stay in `lib/src/core/vector_nodes.dart`; render caches and model helpers remain consumers and must not introduce their own runtime revision bookkeeping.
- Stroke geometry validation must happen at the runtime geometry owner itself; patch owners and caches must not duplicate or weaken that validation contract.

### 6.8 Prohibited

- Keeping a mutable `ListBase`-style geometry view on `StrokeNode.points`.
- Replacing the direct mutable list with another externally mutable validating wrapper.
- Allowing patch code to mutate runtime geometry through any `List`-surface bypass.
- Silently truncating, dropping, or canonicalizing invalid runtime stroke points.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the trigger point must be attached.
7. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [x] Hermetic Runtime Stroke Geometry Owner

#### Slice Contract

`StrokeNode.points` is no longer directly mutable from external runtime code, and one canonical node-owned geometry API becomes the only write owner for stroke points and `pointsRevision`.

#### Change

Перестроить `lib/src/core/vector_nodes.dart` так, чтобы `StrokeNode.points` отдавал immutable view, добавить `StrokeNode.replacePoints(List<Offset> points)` как единственный runtime geometry write API, убрать direct mutable list owner `_RevisionedOffsetListView`, и перевести `pointsRevision` bookkeeping под ownership нового runtime geometry owner-а.

#### Verification

- `flutter analyze`
- MCP test run: root `.` paths `test/core/nodes_test.dart`, `test/core/hit_test_test.dart`

#### Positive Scenarios

- Runtime code can read `stroke.points` and observe current geometry.
- Canonical whole-geometry replacement updates local bounds and increments `pointsRevision` only on real geometry change.
- Constructor and `StrokeNode.fromWorldPoints(...)` still create valid stroke nodes.

#### Negative Scenarios

- External `stroke.points.add(...)`-style mutation fails.
- Invalid point sequences are rejected at runtime geometry write time.
- No-op geometry replacement keeps `pointsRevision` unchanged.

#### Closure Evidence

- `flutter analyze`
- MCP test run: root `.` paths `test/core/nodes_test.dart`, `test/core/hit_test_test.dart`

### Slice 2. [x] Patch, Clone, And Cache Integration Through The Canonical Owner

#### Slice Contract

Patch application, clone independence, and render/cache freshness all work through the new hermetic runtime stroke geometry owner without direct `List` mutation bypasses.

#### Change

Обновить `lib/src/model/document_node_patch_stroke.dart` на canonical stroke geometry replacement API, переписать proofs в `test/model/document_model_test.dart`, `test/model/document_clone_test.dart`, `test/controller/core/scene_controller_commit_atomicity_test.dart`, `test/controller/internal/scene_writer_test.dart`, `test/render/scene_stroke_path_cache_test.dart`, `test/render/render_geometry_cache_test.dart`, и обновить invariant wording в `tool/invariant_registry.dart`.

#### Verification

- `flutter analyze`
- MCP test run: root `.` paths `test/model/document_model_test.dart`, `test/model/document_clone_test.dart`
- MCP test run: root `.` paths `test/controller/internal/scene_writer_test.dart`, `test/controller/core/scene_controller_commit_atomicity_test.dart`
- MCP test run: root `.` paths `test/render/scene_stroke_path_cache_test.dart`, `test/render/render_geometry_cache_test.dart`

#### Positive Scenarios

- `StrokeNodePatch.points` replaces runtime stroke geometry through the canonical owner.
- Cloned scenes keep independent stroke geometry owners.
- Render caches still observe monotonic `pointsRevision` changes when geometry really changes.

#### Negative Scenarios

- No patch path mutates runtime geometry through `stroke.points.replaceRange(...)`.
- No clone proof depends on direct mutation of a runtime `List` view.

#### Closure Evidence

- MCP test run: root `.` paths `test/model/document_model_test.dart`, `test/model/document_clone_test.dart`
- MCP test run: root `.` paths `test/controller/internal/scene_writer_test.dart`, `test/controller/core/scene_controller_commit_atomicity_test.dart`
- MCP test shard preset `render_view`

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
