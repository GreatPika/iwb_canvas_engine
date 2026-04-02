language: russian

# Шаг 81. Сделать `ScenePalette` runtime value-owner и убрать post-construction mutation обходы

## 1. Change Mandate

Этот шаг делает `ScenePalette` immutable runtime value-owner, убирает post-construction mutation обходы через списки палитры и фиксирует replacement-only semantics для runtime palette state.

## 2. Change Boundary

### Included in the Change

- Заморозка runtime `ScenePalette` list fields после construction.
- Явная фиксация `Scene.palette` как mutable reference to immutable palette value-object, а не как owner mutable nested lists.
- Удаление runtime bypass-возможности через `penColors/backgroundColors/gridSizes` list mutation после constructor-time validation.
- Обновление repository source of truth: `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `PLAN.md`, this step file, `tool/invariant_registry.dart`.

### Not Included in the Change

- Любая новая public write API для поэлементного изменения палитры.
- Любая смена typed/public snapshot palette contract или JSON schema.
- Любая работа по `StrokeNode.points`, `TextNode`, `opacity`, `GridSettings.cellSize`, grid normalization policy.
- Любая change to palette item-count, emptiness, or numeric validation rules themselves.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/core/scene.dart`
- `lib/src/model/document_clone.dart`
- `tool/invariant_registry.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Test Files

- `test/model/document_model_test.dart`
- `test/model/document_clone_test.dart`
- `test/model/scene_value_validation_primitives_test.dart`
- `test/serialization/scene_codec_validation_test.dart`

### Fixture and Supporting Data Files

- `PLAN.md`
- `plan/step_81_scene_palette_runtime_value_owner.md`
- `VERIFICATION.md`

### Analysis Area

- `lib/src/core/**`
- `lib/src/model/**`
- `tool/**`
- `test/model/**`
- `test/serialization/**`
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

1. `ScenePalette` becomes an immutable runtime value-object: constructor inputs are defensively copied and stored as unmodifiable lists in the constructor itself.
2. `Scene.palette` remains a mutable field on `Scene`, but palette updates are replacement-only at the object level; this step does not keep mutable nested list ownership.
3. This step does not introduce element-level mutation helpers, validating mutable wrappers, or ad hoc synchronization logic for palette lists.
4. Typed/public snapshot and JSON palette contracts remain unchanged in this step.
5. No new `lib/**` production file is introduced for this step.

## 5. Result Requirements

1. Runtime `ScenePalette.penColors`, `backgroundColors`, and `gridSizes` can no longer be mutated after construction.
2. Mutating constructor input lists after creating `ScenePalette` does not affect the runtime palette object.
3. Scene cloning and snapshot export continue to preserve palette values correctly while keeping palette object ownership independent.
4. Repository docs and invariant wording describe runtime palette state as replacement-only and not as constructor-validated mutable nested lists.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `lib/src/core/scene.dart` currently copies palette constructor inputs but stores them as mutable `List` fields, so constructor-time validation can be bypassed later.
- `lib/src/model/document_clone.dart` currently deep-clones palette lists explicitly and must stay correct after `ScenePalette` becomes immutable.
- `test/model/document_clone_test.dart` already proves palette object and list identity are independent across clones.
- `test/model/scene_value_validation_primitives_test.dart` and serialization tests already prove palette validation rules at typed and JSON boundaries and must remain green after runtime palette freezing.

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

- Snapshot palette immutability remains unchanged.
- Palette item-count and non-empty invariants remain unchanged.
- Palette JSON shape and schema version remain unchanged.
- Runtime `Scene.palette` field remains replaceable at the scene level.

### 6.4 Allowed Semantic Change Zones

- Runtime palette object ownership and mutability semantics.
- Runtime clone semantics for palette ownership.
- Runtime documentation and invariant wording for palette ownership.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- post-construction mutation attempts through `palette.penColors.add(...)`, `backgroundColors.add(...)`, `gridSizes.add(...)`, and similar list writes;
- constructor-input aliasing after `ScenePalette(...)` creation;
- scene clone and snapshot export paths that read palette values.

### 6.6 Allowed Forms That Do Not Count as Violations

- Replacing `scene.palette` with a new `ScenePalette` instance.
- Reading palette lists from runtime, snapshot, and JSON paths.
- Reusing existing palette validation rules at typed and JSON boundaries.

### 6.8 Prohibited

- Keeping mutable runtime palette lists after construction.
- Adding per-list mutation helpers or validating wrappers as a substitute for immutable palette ownership.
- Adding synchronization glue between palette lists and a second canonical owner.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [x] Immutable Runtime Palette Value Owner

#### Slice Contract

`ScenePalette` becomes an immutable runtime value-object and no longer exposes mutable post-construction list owners.

#### Change

Перестроить `lib/src/core/scene.dart` так, чтобы `ScenePalette` defensively copied and froze all constructor lists inside its constructor and clearly represented replacement-only runtime palette ownership.

#### Verification

- `flutter analyze`
- MCP test run: root `.` paths `test/model/document_model_test.dart`, `test/model/scene_value_validation_primitives_test.dart`

#### Positive Scenarios

- Runtime code can read palette values after construction.
- Palette constructor input aliasing no longer leaks into runtime state.
- Replacing `scene.palette` with a new value-object remains supported.

#### Negative Scenarios

- `palette.penColors.add(...)`-style writes fail.
- No runtime palette object can be made invalid by mutating nested lists after constructor validation.

#### Closure Evidence

- Green run of the listed verifications.

### Slice 2. [x] Clone And Boundary Proofs Over Immutable Palette Ownership

#### Slice Contract

Scene cloning, runtime validation, and serialization proofs continue to work with `ScenePalette` as an immutable runtime value-owner.

#### Change

Обновить `lib/src/model/document_clone.dart` при необходимости для replacement-only palette ownership, переписать proofs в `test/model/document_clone_test.dart` и сохранить boundary proofs in `test/serialization/scene_codec_validation_test.dart`, затем обновить invariant wording в `tool/invariant_registry.dart`.

#### Verification

- `flutter analyze`
- MCP test run: root `.` paths `test/model/document_clone_test.dart`
- MCP test run: root `.` paths `test/serialization/scene_codec_validation_test.dart`

#### Positive Scenarios

- Scene clones keep independent palette object ownership.
- Snapshot export and encode continue to emit the same palette values.

#### Negative Scenarios

- No clone proof depends on mutating runtime palette lists directly.

#### Closure Evidence

- Green run of the listed verifications.

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
