language: russian

# Шаг 78. Поднять недостающие render contracts в invariant registry для существующих proof surfaces

## 1. Change Mandate

Этот шаг backfill-ит invariant registry для уже существующих render/`ScenePainter` contracts, которые уже доказаны тестами, но ещё не имеют explicit invariant ids и proof markers.

## 2. Change Boundary

### Included in the Change

- Добавление missing render invariants в `tool/invariant_registry.dart` для текущих test-backed render contracts.
- Добавление explicit `// INV:<id>` markers в dedicated render proof files.
- Targeted invariant-id alignment с уже существующими render/`ScenePainter` architectural claims в `ARCHITECTURE.md`, если новый registry backfill требует явной привязки ids к существующим bullets.

### Not Included in the Change

- Любая новая render behavior, cache logic, painter logic или architectural refactor.
- Любой новый `toolProof` или static-analysis tool для render contracts.
- Любая работа по CI trigger surface или guardrails claim contour.

## 3. File Map and Analysis Areas

### Implementation Files

- `tool/invariant_registry.dart`

### Test Files

- `test/render/render_hit_bounds_parity_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`

### Fixture and Supporting Data Files

- `ARCHITECTURE.md`
- `PLAN.md`
- `plan/step_78_render_contract_invariant_registry_backfill.md`

### Analysis Area

- `tool/invariant_registry.dart`
- `test/render/render_hit_bounds_parity_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `ARCHITECTURE.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. This step backfills registry coverage for already existing render contracts; it does not introduce new render semantics.
2. The new render contracts remain test-backed invariants only; this step does not add `toolProof` for them.
3. Invariant granularity is semantic, not “one invariant per assertion”; the contracts added here are `INV-ENG-RENDER-HIT-BOUNDS-PARITY`, `INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION`, and `INV-ENG-SCENE-PAINTER-MODULE-BOUNDARY`.
4. Existing render-adjacent invariants `INV-ENG-EPOCH-INVALIDATION`, `INV-ENG-RENDER-GEOMETRY-KEY-STABLE`, and `INV-ENG-VIEW-RENDER-READ-STATE-BOUNDARY` stay owned by their current proof surfaces.
5. `scene_painter_bounds_contract_test.dart` owns the structural `ScenePainter` module-boundary contract; overlapping helper assertions there do not replace `scene_painter_frame_contract_test.dart` as the primary proof for frame-resolution semantics.

## 5. Result Requirements

1. `tool/invariant_registry.dart` declares `INV-ENG-RENDER-HIT-BOUNDS-PARITY` with `test/render/render_hit_bounds_parity_test.dart` as its `primaryProof`.
2. `tool/invariant_registry.dart` declares `INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION` with `test/render/scene_painter_frame_contract_test.dart` as its `primaryProof`.
3. `tool/invariant_registry.dart` declares `INV-ENG-SCENE-PAINTER-MODULE-BOUNDARY` with `test/render/scene_painter_bounds_contract_test.dart` as its `primaryProof`.
4. Each declared render proof file contains matching explicit `// INV:<id>` markers.
5. `dart run tool/check_invariant_coverage.dart` passes with the new render invariants.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `test/render/render_hit_bounds_parity_test.dart` proves that render hit candidate bounds and core hit-test candidate bounds derive from the same render `worldBounds` contract across rect/path/line/stroke families.
- `test/render/scene_painter_frame_contract_test.dart` proves that `ScenePainter` resolves preview delta and geometry once per node per frame.
- `test/render/scene_painter_bounds_contract_test.dart` proves that `ScenePainter` modules stay part-free, `ScenePainterShell` stays orchestration-only, and node/selection renderers consume frame-resolved data instead of reopening geometry lookup.
- `ARCHITECTURE.md` already carries stable render/`ScenePainter` contract bullets for these semantics, especially around frame ownership, selection ownership, node-render ownership, and shell/module boundaries.

### 6.2 Target Verification Units

- `dart run tool/check_invariant_coverage.dart`
- MCP test shard preset: `render_view`

### 6.3 Protected States, Data, or Structures

- Existing render invariant ids and proof mappings in `tool/invariant_registry.dart`.
- Existing render and `ScenePainter` behavior.
- Existing `ARCHITECTURE.md` render bullets and their current semantics.

### 6.4 Allowed Semantic Change Zones

- New render invariant ids, scopes, and titles for already existing proof surfaces.
- Explicit marker placement in dedicated render proof files.
- Targeted architecture doc cross-reference for the new invariant ids, only if needed to keep the source of truth aligned.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- whole-file dedicated render proof surface with one explicit marker;
- one render proof file carrying more than one explicit marker when a file proves more than one declared render invariant;
- existing navigation-only `INV:` references outside the declared render proof files.

### 6.6 Allowed Forms That Do Not Count as Violations

- Existing render tests that stay marker-free because they are not the declared `primaryProof` for a registry invariant.
- Existing render invariants continuing to point at their current proof files.
- A dedicated render proof file using a file-top standalone `// INV:<id>` marker when the whole file is the proof surface for that invariant.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `INV-ENG-RENDER-HIT-BOUNDS-PARITY` must be scoped to the hit-bounds parity contract already exercised in `test/render/render_hit_bounds_parity_test.dart`.
- `INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION` must be scoped to the once-per-node-per-frame resolution contract already exercised in `test/render/scene_painter_frame_contract_test.dart`.
- `INV-ENG-SCENE-PAINTER-MODULE-BOUNDARY` must be scoped to the module-boundary/shell-orchestration/resolved-data contract already exercised in `test/render/scene_painter_bounds_contract_test.dart`.
- The step must not collapse these three contracts into one broad render invariant that would blur proof ownership and future diagnostics.

### 6.8 Prohibited

- Reusing an existing render invariant id for a different contract just to avoid adding a new registry entry.
- Introducing `toolProof` for these render contracts.
- Refactoring render code or tests beyond the marker/registry/doc changes needed for the backfill.
- Turning perf-style micro-observations into new invariants when they are not already stable architecture or test contracts.

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

### Slice 1. [ ] Render Registry Backfill

#### Slice Contract

The existing render parity and `ScenePainter` contract tests are represented in `tool/invariant_registry.dart` as explicit invariants with matching proof markers.

#### Change

Добавить three missing render invariants в registry, расставить matching `// INV:<id>` markers в dedicated render proof files и, если нужно, привязать новые ids к уже существующим render bullets в `ARCHITECTURE.md`.

#### Verification

- `dart run tool/check_invariant_coverage.dart`
- MCP test shard preset: `render_view`

#### Fixtures Used

- `test/render/render_hit_bounds_parity_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`

#### Positive Scenarios

- `render_hit_bounds_parity_test.dart` explicitly proves the render/world-bounds parity invariant.
- `scene_painter_frame_contract_test.dart` explicitly proves the once-per-frame resolution invariant.
- `scene_painter_bounds_contract_test.dart` explicitly proves the `ScenePainter` module-boundary invariant.

#### Negative Scenarios

- `dart run tool/check_invariant_coverage.dart` fails if any of the new registry entries is added without a matching marker in its declared proof file.
- `dart run tool/check_invariant_coverage.dart` fails if a marker is added for one of the new ids in a different undeclared render file instead of the declared primary proof.

#### Closure Evidence

- Green run of the listed verifications.
- Failure diagnostics from `check_invariant_coverage` for missing/undeclared marker scenarios tied to the new render ids.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test shard presets: `core`, `model_contract`, `controller_internal`, `controller`, `render_view`, `interactive`, `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`
