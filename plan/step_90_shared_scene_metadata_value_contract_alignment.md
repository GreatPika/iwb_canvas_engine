language: russian

# Change Contract

## 1. Change Mandate

Этот шаг выравнивает shared scene-metadata value contracts между runtime,
public, and import paths so ordinary constructors, validated helpers, runtime
writes, import validation, and JSON decode all reject the same invalid
`camera`, `grid`, `background`, and `palette` states instead of deferring those
failures to later `ScenePolicy` or encode-only checks.

## 2. Change Boundary

### Included in the Change

- Выравнивание shared value contract для scene metadata:
  `Camera` / `CameraSnapshot`, `GridSettings` / `GridSnapshot`,
  `BackgroundSnapshot`, `ScenePalette` / `ScenePaletteSnapshot`,
  `SceneImportDraft` metadata backings, and their validated helper paths.
- Введение одного contract-owned helper owner-а для shared scene-metadata value
  rules: finite/in-range camera offset, finite positive bounded grid cell size,
  enabled-grid minimum cell size, non-empty palette lists, bounded palette item
  count, and finite positive bounded `palette.gridSizes`.
- Перевод ordinary public metadata constructors and runtime value owners onto
  the same shared contract instead of keeping raw public metadata containers or
  runtime-only partial validation.
- Перевод validated fast-path helper names and backing builders onto honest
  semantics so `...FromValidated` helpers no longer materialize invalid scene
  metadata values.
- Перевод import/decode/model validation for scene metadata onto the same shared
  contract and removal of duplicate late-only palette/grid/camera value checks
  from `ScenePolicy`.
- Сохранение одного explicit internal raw bypass for invalid scene metadata
  under `contract/internal/**` and raw draft/backing constructors for tests and
  package-internal support code.
- Обновление repository source of truth:
  `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`,
  `VERIFICATION.md`, `tool/invariant_registry.dart`, `PLAN.md`,
  this step file.

### Not Included in the Change

- Любая смена JSON field names, JSON schema version, or encoded field set.
- Любая работа по scene-wide structural invariants from step `89`.
- Любая работа по node-family range envelopes outside scene metadata:
  transform scale bounds, node size bounds, thickness upper bounds, text layout
  bounds, or node-specific range helpers.
- Любая смена render read-side crash-safety guards beyond keeping them clearly
  non-authoritative.
- Любое введение нового public raw metadata type, compatibility wrapper, or
  hidden repair-normalization path.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/scene_contract_limits.dart`
- `lib/src/contract/scene_model_invariants.dart`
- `lib/src/contract/snapshot.dart`
- `lib/src/contract/internal/snapshot_backing.dart`
- `lib/src/contract/internal/snapshot_materialization.dart`
- `lib/src/contract/internal/snapshot_boundary_impl.dart`
- `lib/src/contract/internal/snapshot_fast_path.dart`
- `lib/src/core/grid_safety_limits.dart`
- `lib/src/core/scene.dart`
- `lib/src/core/scene_limits.dart`
- `lib/src/interactive/internal/scene_controller_mutation_boundary.dart`
- `lib/src/model/document_clone.dart`
- `lib/src/model/scene_from_import_draft.dart`
- `lib/src/model/scene_import_draft.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `lib/src/model/scene_builder_decode_scene_metadata.dart`
- `lib/src/model/scene_policy.dart`
- `lib/src/model/scene_value_validation_palette_grid.dart`
- `lib/src/model/scene_value_validation_scene.dart`
- `lib/src/controller/scene_invariants.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `VERIFICATION.md`
- `tool/invariant_registry.dart`

### Test Files

- `test/public_api/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/public_api/snapshot_immutability_test.dart`
- `test/core/public_contracts_constants_test.dart`
- `test/model/document_model_test.dart`
- `test/model/document_clone_test.dart`
- `test/model/scene_builder_test.dart`
- `test/model/scene_value_validation_primitives_test.dart`
- `test/contract/validated_fast_path_contract_test.dart`
- `test/contract/validated_internal_helpers_test.dart`
- `test/controller/internal/scene_writer_test.dart`
- `test/controller/core/scene_controller_commit_failures_test.dart`
- `test/controller/scene_invariants_test.dart`
- `test/interactive/core/scene_controller_mutation_boundary_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/scene_static_layer_cache_test.dart`
- `test/view/scene_view_test.dart`
- `test/view/scene_view_interactive_test.dart`

### Fixture and Supporting Data Files

- `PLAN.md`
- `plan/step_90_shared_scene_metadata_value_contract_alignment.md`

### Analysis Area

- `lib/src/contract/**`
- `lib/src/core/**`
- `lib/src/model/**`
- `lib/src/controller/**`
- `lib/src/interactive/**`
- `test/public_api/**`
- `test/core/**`
- `test/model/**`
- `test/contract/**`
- `test/controller/**`
- `test/interactive/**`
- `test/serialization/**`
- `test/render/**`
- `test/view/**`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `VERIFICATION.md`
- `tool/invariant_registry.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every modified source-of-truth doc must be tied to the changed runtime/public
  contract it now describes.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. User-confirmed target state: documented late-only or helper-only
   scene-metadata validation drift must be replaced with the clean contract, not
   preserved as legacy behavior.
2. This step covers the full scene-metadata value contour, not only palette
   item lists: `camera.offset`, `background.grid`, and `palette` values must
   share one contract across runtime, public, and import paths.
3. Shared scene-metadata value rules must live below `model/` so they can be
   consumed by `contract`, `core`, and `model` without a `contract -> model`
   dependency; the existing `scene_contract_limits.dart` and
   `scene_model_invariants.dart` ownership family is extended instead of
   introducing a second parallel owner.
4. Contract-relevant shared metadata limits move into
   `lib/src/contract/scene_contract_limits.dart` as the exact source of truth:
   `sceneCoordMin`, `sceneCoordMax`, `sceneSizeMax`, and `kMinGridCellSize`
   stop being authored only under `core/**`, and `core/**`, `model/**`,
   `interactive/**`, and tests consume the contract-owned constants from there.
5. Ordinary public metadata constructors stop being raw invalid-state
   containers: `CameraSnapshot`, `GridSnapshot`, and `BackgroundSnapshot` must
   reject invalid values eagerly like `ScenePaletteSnapshot`; losing `const`
   constructors for these public value objects is accepted in this step.
6. Runtime scene metadata owners must use the same shared contract as public
   metadata values: `Camera.offset`, `GridSettings`, and `ScenePalette` must
   reject invalid states eagerly instead of relying on later import/encode or
   invariant sweeps.
7. `ScenePolicy` remains the import/runtime orchestration owner, but it must
   stop privately re-owning shared scene-metadata value rules after this step;
   node-family and non-metadata range validation remain there.
8. `...FromValidated` helper names and validated backing builders must become
   truthful for scene metadata. Invalid palette/grid/camera fixtures may remain
   only through explicit raw backings/materialization under `contract/internal`
   or the internal draft layer from step `88`.
9. This step does not add hidden repair, silent normalization, or compatibility
   defaults. Ordinary callers either create valid scene metadata or get an
   eager failure.
10. JSON field names, snapshot field names, and runtime scene shape stay
    unchanged in this step.

## 5. Result Requirements

1. Ordinary public constructors for `CameraSnapshot`, `GridSnapshot`,
   `BackgroundSnapshot`, and `ScenePaletteSnapshot` reject the same invalid
   scene-metadata states that runtime/import paths reject for the same data.
2. Runtime `Camera`, `GridSettings`, and `ScenePalette` reject the same invalid
   scene-metadata states that public/import paths reject for the same data.
3. Shared scene-metadata value helpers own all of the following rules with one
   contract:
   finite/in-range camera offset, finite positive bounded grid cell size,
   enabled-grid minimum cell size, non-empty palette lists, bounded palette
   item count, and finite positive bounded `palette.gridSizes`.
4. Validated helper paths (`cameraSnapshotFromValidated`,
   `gridSnapshotFromValidated`, `backgroundSnapshotFromValidated`,
   `scenePaletteSnapshotFromValidated`, `sceneSnapshotFromValidated`,
   validated metadata backing builders, runtime export/import producers) do not
   materialize invalid scene metadata values.
5. Import/decode/model validation for scene metadata uses the same shared
   contract and no longer depends on duplicate late-only palette/grid/camera
   checks living privately inside `ScenePolicy`.
6. Invalid scene metadata fixtures used by tests or package-internal support
   code are created only through explicit raw internal backings/materialization
   and not through ordinary public constructors or validated helper names.
7. Public docs, verification guidance, and invariant registry describe
   scene-metadata values as one shared contract across runtime, public, and
   import paths.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `lib/src/contract/snapshot.dart` currently validates `ScenePaletteSnapshot`
  more strictly than runtime `ScenePalette`, while `CameraSnapshot`,
  `GridSnapshot`, and `BackgroundSnapshot` remain raw public value containers
  whose invalidity is caught only when wrapped by `SceneSnapshot(...)` or later
  import/encode paths.
- `lib/src/core/scene.dart` currently gives `GridSettings` only a partial
  shared contract (`finite`, `> 0`, enabled-grid minimum) and leaves
  `Camera.offset` as a raw mutable field with only downstream finite guards.
  Runtime `ScenePalette` still validates only item-count and ownership, not the
  full public/import palette envelope.
- `lib/src/model/document_clone.dart` and
  `lib/src/model/scene_from_import_draft.dart` both construct runtime
  `Camera`, `GridSettings`, and `ScenePalette` values and therefore must remain
  valid under the new eager runtime metadata contract without introducing a
  second metadata owner.
- `lib/src/interactive/internal/scene_controller_mutation_boundary.dart`
  currently enforces the enabled-grid minimum and finite camera offset with its
  own imports/callbacks and therefore must stay aligned when the shared
  metadata contract owner moves.
- `lib/src/model/scene_policy.dart` currently re-owns shared scene-metadata
  value checks for `camera.offset`, `background.grid.cellSize`, and
  `palette.gridSizes` upper ranges, while
  `lib/src/model/scene_value_validation_palette_grid.dart` separately owns
  palette emptiness/positive rules and enabled-grid minimum checks.
- `lib/src/model/scene_builder_decode_scene_metadata.dart` currently parses
  scene metadata and enforces only part of the shared contract early
  (for example finite numbers and palette item count), leaving empty lists,
  enabled-grid minimum, positive `palette.gridSizes`, and metadata upper ranges
  to later model validation.
- `lib/src/contract/internal/snapshot_backing.dart` and
  `lib/src/contract/internal/snapshot_materialization.dart` currently expose
  `...FromValidated` metadata builders that can still materialize invalid
  palette/grid/camera values, so helper names are inaccurate.
- `lib/src/contract/internal/snapshot_boundary_impl.dart` currently materializes
  camera/background/grid/palette internal snapshots by calling ordinary public
  constructors. Once those constructors validate eagerly, explicit internal raw
  carriers are required to keep malformed-fixture support under
  `contract/internal/**`.
- `test/serialization/scene_codec_validation_test.dart`,
  `test/controller/core/scene_controller_commit_failures_test.dart`,
  `test/render/scene_painter_test.dart`, and
  `test/view/scene_view_interactive_test.dart` currently rely on validated
  helpers or ordinary public constructors to create invalid metadata values and
  then assert a later encode/import/render failure. Those proofs must split
  into eager ordinary-constructor failure vs explicit internal raw bypass.

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
- `dart run tool/run_tool_tests.dart`
- MCP test runner: root `.` paths `test/public_api/validated_boundary_value_test.dart`
- MCP test runner: root `.` paths `test/public_api/scene_builder_test.dart`
- MCP test runner: root `.` paths `test/public_api/snapshot_immutability_test.dart`
- MCP test runner: root `.` paths `test/core/public_contracts_constants_test.dart`
- MCP test runner: root `.` paths `test/model/document_model_test.dart`
- MCP test runner: root `.` paths `test/model/document_clone_test.dart`
- MCP test runner: root `.` paths `test/model/scene_builder_test.dart`
- MCP test runner: root `.` paths `test/model/scene_value_validation_primitives_test.dart`
- MCP test runner: root `.` paths `test/contract/validated_fast_path_contract_test.dart`
- MCP test runner: root `.` paths `test/contract/validated_internal_helpers_test.dart`
- MCP test runner: root `.` paths `test/controller/internal/scene_writer_test.dart`
- MCP test runner: root `.` paths `test/controller/core/scene_controller_commit_failures_test.dart`
- MCP test runner: root `.` paths `test/controller/scene_invariants_test.dart`
- MCP test runner: root `.` paths `test/interactive/core/scene_controller_mutation_boundary_test.dart`
- MCP test runner: root `.` paths `test/serialization/scene_codec_validation_test.dart`
- MCP test runner: root `.` paths `test/serialization/scene_test.dart`
- MCP test shard preset `render_view`

### 6.3 Protected States, Data, or Structures

- Existing scene metadata defaults:
  zero camera offset, default background color, default grid config, default
  palette colors and grid sizes.
- Existing immutable list ownership for snapshot palette values and runtime
  palette values.
- Existing deterministic `SceneDataException` `code`, `path`, and immutable
  `details` contract for malformed import/encode metadata failures.
- Existing internal raw malformed-snapshot and malformed-draft support under
  `contract/internal/**` and the draft/backing layer introduced by step `88`.
- Existing public `SceneSnapshot` structural validity guarantee from step `89`.
- Existing render/read-side `sanitizeFiniteOffset(...)` crash-safety logic as a
  defensive fallback, but not as canonical value semantics.

### 6.4 Allowed Semantic Change Zones

- Shared metadata limit ownership and shared metadata violation helpers.
- Public metadata constructor semantics and runtime metadata setter semantics.
- Validated fast-path metadata helper semantics and internal raw bypass usage.
- Import/decode/model validation ownership for scene metadata values.
- Runtime invariant sweep wording and source-of-truth documentation for shared
  metadata contracts.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- ordinary public constructor bypass through `CameraSnapshot(...)`,
  `GridSnapshot(...)`, `BackgroundSnapshot(...)`, `ScenePaletteSnapshot(...)`;
- runtime direct-write bypass through `Camera.offset`, `GridSettings.cellSize`,
  `GridSettings.isEnabled`, and `ScenePalette(...)`;
- validated-helper bypass through `cameraSnapshotFromValidated(...)`,
  `gridSnapshotFromValidated(...)`, `backgroundSnapshotFromValidated(...)`,
  `scenePaletteSnapshotFromValidated(...)`, and `sceneSnapshotFromValidated(...)`;
- validated-backing bypass through `cameraSnapshotBackingFromValidated(...)`,
  `gridSnapshotBackingFromValidated(...)`,
  `backgroundSnapshotBackingFromValidated(...)`,
  `scenePaletteSnapshotBackingFromValidated(...)`,
  `sceneSnapshotBackingFromValidated(...)`;
- import/decode late-failure paths where metadata currently passes ordinary
  construction and is rejected only by `ScenePolicy` or `encodeScene(...)`;
- explicit internal raw malformed-fixture construction through raw backing
  constructors and `materialize*` helpers.

### 6.6 Allowed Forms That Do Not Count as Violations

- Explicit raw malformed metadata used only under `contract/internal/**` or the
  internal draft/backing layer for tests and package-internal support code.
- Read-side crash-safety sanitation in render/view code that remains a last
  defensive fallback and does not define canonical metadata semantics.
- Remaining node-specific range validation in `ScenePolicy` that does not
  describe scene metadata values.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- Shared metadata helper code must stay consumable from `contract`, `core`, and
  `model` without introducing `contract -> model` imports.
- `core/grid_safety_limits.dart` and `core/scene_limits.dart` may keep
  non-contract runtime/render limits, but `sceneCoordMin`, `sceneCoordMax`,
  `sceneSizeMax`, and `kMinGridCellSize` must be imported from
  `lib/src/contract/scene_contract_limits.dart` after this step.
- `ScenePolicy` may consume the shared metadata helpers, but ordinary public
  constructors and runtime setters must not call into `ScenePolicy`.
- Internal raw carriers/materializers for metadata snapshots must remain under
  `contract/internal/**`; no new public raw metadata API may be added.
- `SceneImportDraft(...)` must stop assembling raw decode state through
  validated backing builders once those builders become honest. Raw decode and
  malformed-draft assembly must go through `SceneImportDraft.fromBacking(...)`
  and raw backing constructors instead.
- If public metadata constructors lose `const`, every compile fallout in
  `test/render/**`, `test/view/**`, and any touched production file must close
  in the same slice where the constructor semantics change.

### 6.8 Prohibited

- Keeping palette emptiness/positive/upper-bound rules split between different
  owners across runtime, public, and import paths.
- Keeping `CameraSnapshot`, `GridSnapshot`, or `BackgroundSnapshot` as ordinary
  public invalid-state containers after this step.
- Keeping any `...FromValidated` scene-metadata helper capable of materializing
  invalid metadata values.
- Preserving `ScenePolicy` as the only place that rejects oversized camera
  offsets, oversized `background.grid.cellSize`, or oversized
  `palette.gridSizes`.
- Reintroducing invalid metadata through hidden normalization, fallback, or
  “validate later” semantics.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice changes ordinary public constructor semantics, positive and
   negative constructor scenarios plus compile fallout must close in the same
   slice.
7. If a slice changes validated helper semantics, the same slice must include
   both positive validated-helper proofs and explicit raw-bypass negative
   proofs.
8. Scope expansion into node-family range contracts is forbidden until the
   mandatory slices of this step are closed.
9. The plan must remain detailed enough that the implementing agent has no
   material branch in how to execute the slice.

## 8. Vertical Slices

### Slice 1. [x] Shared Public And Runtime Scene-Metadata Value Owners

#### Slice Contract

Ordinary public metadata constructors and runtime metadata owners reject the
same invalid `camera`, `grid`, `background`, and `palette` states eagerly
through one shared lower-layer metadata contract.

#### Change

Extend `lib/src/contract/scene_contract_limits.dart` and
`lib/src/contract/scene_model_invariants.dart` so they own the shared
scene-metadata value rules required outside `model/`, and move the shared
constants `sceneCoordMin`, `sceneCoordMax`, `sceneSizeMax`, and
`kMinGridCellSize` into `lib/src/contract/scene_contract_limits.dart` as the
authoritative owner. Rebuild `lib/src/contract/snapshot.dart`,
`lib/src/core/scene.dart`, and
`lib/src/interactive/internal/scene_controller_mutation_boundary.dart` on those
helpers/constants so `CameraSnapshot`, `GridSnapshot`, `BackgroundSnapshot`,
`ScenePaletteSnapshot`, `Camera`, `GridSettings`, and `ScenePalette` all reject
invalid values eagerly with the same semantics. Adapt
`lib/src/model/scene_from_import_draft.dart` and
`lib/src/model/document_clone.dart` if needed so import-to-runtime and clone
paths stay on the same eager runtime contract. Update
`lib/src/core/grid_safety_limits.dart`, `lib/src/core/scene_limits.dart`, and
`lib/src/controller/scene_invariants.dart` only as needed to keep ownership and
runtime invariant wording honest, then close all public/runtime compile fallout
caused by validated metadata constructors.

#### Verification

- `flutter analyze`
- MCP test runner: root `.` paths `test/public_api/validated_boundary_value_test.dart`
- MCP test runner: root `.` paths `test/public_api/snapshot_immutability_test.dart`
- MCP test runner: root `.` paths `test/core/public_contracts_constants_test.dart`
- MCP test runner: root `.` paths `test/contract/validated_internal_helpers_test.dart`
- MCP test runner: root `.` paths `test/model/document_model_test.dart`
- MCP test runner: root `.` paths `test/model/document_clone_test.dart`
- MCP test runner: root `.` paths `test/controller/internal/scene_writer_test.dart`
- MCP test runner: root `.` paths `test/controller/scene_invariants_test.dart`
- MCP test runner: root `.` paths `test/interactive/core/scene_controller_mutation_boundary_test.dart`
- MCP test shard preset `render_view`

#### Positive Scenarios

- Valid camera offsets, valid grid settings, and valid palette values still
  construct correctly through ordinary public and runtime APIs.
- Scene metadata defaults remain unchanged.
- Runtime palette replacement and runtime camera/grid writes still work for
  valid values.

#### Negative Scenarios

- Ordinary public `CameraSnapshot`, `GridSnapshot`, `BackgroundSnapshot`, and
  `ScenePaletteSnapshot` constructors reject invalid metadata eagerly.
- Runtime `Camera`, `GridSettings`, and `ScenePalette` reject the same invalid
  metadata eagerly.
- No render/view proof depends on `const` ordinary metadata constructors after
  the constructor semantics change.

#### Closure Evidence

- Green run of the listed verifications.

### Slice 2. [x] Honest Validated Fast Paths And Explicit Raw Metadata Bypass

#### Slice Contract

Validated fast-path helpers and metadata backing builders become truthful:
ordinary validated helper names no longer materialize invalid scene metadata,
and malformed metadata fixtures use explicit raw internal bypasses.

#### Change

Rebuild `lib/src/contract/internal/snapshot_backing.dart`,
`lib/src/contract/internal/snapshot_materialization.dart`,
`lib/src/contract/internal/snapshot_boundary_impl.dart`,
`lib/src/contract/internal/snapshot_fast_path.dart`,
`lib/src/model/scene_import_draft.dart`, and
`lib/src/model/scene_snapshot_from_scene.dart` so validated metadata backing
builders and materializers enforce the shared metadata contract while raw draft
and raw snapshot fixture assembly remain explicit through internal raw backing
constructors/materializers only. `SceneImportDraft(...)` must stop delegating
to `sceneSnapshotBackingFromValidated(...)`; decode and malformed-draft paths
must assemble raw backing through `SceneImportDraft.fromBacking(...)`.
Replace every invalid metadata test that currently uses ordinary constructors or
`...FromValidated` helpers with an explicit raw internal bypass.

#### Verification

- MCP test runner: root `.` paths `test/contract/validated_fast_path_contract_test.dart`
- MCP test runner: root `.` paths `test/contract/validated_internal_helpers_test.dart`
- MCP test runner: root `.` paths `test/controller/core/scene_controller_commit_failures_test.dart`
- MCP test runner: root `.` paths `test/serialization/scene_codec_validation_test.dart`
- MCP test runner: root `.` paths `test/view/scene_view_interactive_test.dart`
- MCP test runner: root `.` paths `test/render/scene_painter_test.dart`

#### Positive Scenarios

- Validated helpers still materialize canonical public scene metadata for valid
  values.
- Runtime export and validated import-draft to public snapshot conversion still
  preserve valid metadata values without drift.

#### Negative Scenarios

- `cameraSnapshotFromValidated(...)`, `gridSnapshotFromValidated(...)`,
  `backgroundSnapshotFromValidated(...)`,
  `scenePaletteSnapshotFromValidated(...)`, and
  `sceneSnapshotFromValidated(...)` reject invalid scene metadata instead of
  deferring failures to encode/import/render paths.
- Malformed metadata fixtures required by tests use explicit raw internal
  backings/materialization and not ordinary validated helper names.

#### Closure Evidence

- Green run of the listed verifications.

### Slice 3. [x] Import, Decode, And Model Validation Parity For Scene Metadata

#### Slice Contract

Import/decode/model validation for scene metadata uses the same shared metadata
contract as ordinary public and runtime construction, and `ScenePolicy` no
longer privately re-owns shared palette/grid/camera value rules.

#### Change

Rebuild `lib/src/model/scene_builder_decode_scene_metadata.dart`,
`lib/src/model/scene_policy.dart`,
`lib/src/model/scene_value_validation_palette_grid.dart`, and
`lib/src/model/scene_value_validation_scene.dart` so scene-metadata validation
consumes the shared lower-layer metadata helpers and removes late-only duplicate
checks for camera/grid/palette values from `ScenePolicy`. Preserve existing
deterministic `SceneDataException` diagnostics for import/decode/encode failure
paths, update `tool/invariant_registry.dart`, `README.md`, `API_GUIDE.md`,
`ARCHITECTURE.md`, `CHANGELOG.md`, and `VERIFICATION.md`, and keep node-family
range validation out of this step.

#### Verification

- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- MCP test runner: root `.` paths `test/public_api/scene_builder_test.dart`
- MCP test runner: root `.` paths `test/model/scene_builder_test.dart`
- MCP test runner: root `.` paths `test/model/scene_value_validation_primitives_test.dart`
- MCP test runner: root `.` paths `test/serialization/scene_codec_validation_test.dart`
- MCP test runner: root `.` paths `test/serialization/scene_test.dart`

#### Positive Scenarios

- Valid scene metadata still round-trips through public construction, encode,
  decode, import, and runtime export without contract drift.
- Model validation and JSON decode report the same accepted metadata envelope as
  runtime/public construction for scene metadata.

#### Negative Scenarios

- Invalid scene metadata fails through the same shared contract semantics across
  ordinary public construction, runtime replacement/write, decode/import, and
  encode validation.
- No remaining `ScenePolicy`-private palette/grid/camera rule rejects a value
  that ordinary public/runtime constructors still accept.

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
- `dart run tool/run_tool_tests.dart`
- MCP test runner: root `.` paths `test/public_api/scene_builder_test.dart`
- MCP test runner: root `.` paths `test/public_api/validated_boundary_value_test.dart`
- MCP test runner: root `.` paths `test/public_api/snapshot_immutability_test.dart`
- MCP test runner: root `.` paths `test/core/public_contracts_constants_test.dart`
- MCP test runner: root `.` paths `test/model/document_model_test.dart`
- MCP test runner: root `.` paths `test/model/document_clone_test.dart`
- MCP test runner: root `.` paths `test/model/scene_builder_test.dart`
- MCP test runner: root `.` paths `test/model/scene_value_validation_primitives_test.dart`
- MCP test runner: root `.` paths `test/contract/validated_fast_path_contract_test.dart`
- MCP test runner: root `.` paths `test/contract/validated_internal_helpers_test.dart`
- MCP test runner: root `.` paths `test/controller/internal/scene_writer_test.dart`
- MCP test runner: root `.` paths `test/controller/core/scene_controller_commit_failures_test.dart`
- MCP test runner: root `.` paths `test/controller/scene_invariants_test.dart`
- MCP test runner: root `.` paths `test/interactive/core/scene_controller_mutation_boundary_test.dart`
- MCP test runner: root `.` paths `test/serialization/scene_codec_validation_test.dart`
- MCP test runner: root `.` paths `test/serialization/scene_test.dart`
- MCP test shard preset `render_view`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
