language: russian

# Шаг 70. Замкнуть остаточные системные контракты целевой архитектуры

## 1. Change Mandate
This change migrates `iwb_canvas_engine` to one controller-owned committed write-side, one read-only render-state bridge for `view/render`, sealed public contract types for the touched internal-only hooks, unified model-owned limits for stroke and palette, and guardrails that enforce these contracts automatically.

## 2. Change Boundary

### Included in the Change
- Single read-side bridge for `view/render`, including live marquee and overlay repaint wiring without `view -> interactive/internal/**` access.
- Single controller-owned committed mutation routing for the touched scene and selection paths, including closure of the active-gesture bypass through `scene.write(...)`.
- Removal of duplicate scene import/materialization before `replaceScene(...)` reaches the controller-owned mutation path.
- Unification of `kMaxStrokePointsPerNode` and `kMaxPaletteItems` as model-owned invariants applied across typed construction/import, validation, serialization, and JSON decode.
- Removal of public `materialize(...)` and `internalBacking` exposure from the touched exported contract types.
- Tooling and regression checks for foreign `internal/**` imports and non-executable invariant proofs.

### Not Included in the Change
- Choosing and implementing the long-term text contract between serialized `size` and explicit `textDirection`.
- Introducing a new public signal stream or promoting internal committed signals to supported public API.
- Performance work outside the read-side ownership changes listed above.
- Public API renames unrelated to the touched internal-only contract leakage.

## 3. File Map and Analysis Areas

### Implementation Files
- `lib/src/view/scene_view_render_surface.dart`
- `lib/src/view/scene_view_interactive.dart`
- `lib/src/view/scene_view_interactive_overlay_painter.dart`
- `lib/src/render/scene_painter.dart`
- `lib/src/render/scene_painter_frame.dart`
- `lib/src/interactive/scene_controller_scene.dart`
- `lib/src/interactive/internal/scene_controller_scene_mutations.dart`
- `lib/src/interactive/interaction_eligibility_policy.dart`
- `lib/src/view/scene_view_interactive_pointer_host.dart`
- `lib/src/controller/scene_writer_selection.dart`
- `lib/src/controller/mutation_op.dart`
- `lib/src/controller/scene_mutation_applier.dart`
- `lib/src/model/scene_policy.dart`
- `lib/src/model/scene_builder_decode_stroke.dart`
- `lib/src/model/scene_builder_decode_scene_metadata.dart`
- `lib/src/model/scene_value_validation_palette_grid.dart`
- `lib/src/contract/snapshot.dart`
- `lib/src/contract/node_spec.dart`
- `lib/src/contract/node_patch.dart`
- `tool/src/import_boundaries/directive_boundary_checker.dart`
- `tool/src/import_boundaries/import_boundary_policy.dart`
- `tool/check_invariant_coverage.dart`

### Test Files
- `test/view/scene_view_interactive_test.dart`
- `test/view/scene_view_test.dart`
- `test/render/scene_painter_test.dart`
- `test/interactive/core/scene_controller_interactive_basics_test.dart`
- `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- `test/controller/core/scene_controller_commit_atomicity_test.dart`
- `test/model/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/tool/invariant_coverage_tool_test.dart`

### Fixture and Supporting Data Files
- `.github/workflows/ci.yaml`
- `VERIFICATION.md`
- `test/tool/support/public_entrypoint_contract.dart`

### Analysis Area
- `lib/src/view/**`
- `lib/src/render/**`
- `lib/src/interactive/**`
- `lib/src/controller/**`
- `lib/src/model/**`
- `lib/src/contract/**`
- `tool/**`
- `test/view/**`
- `test/interactive/core/**`
- `test/model/**`
- `test/serialization/**`
- `test/tool/**`

### Outside the Change Boundary
- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific slice and its verification cannot be closed.

### File Change Rule
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions
1. `view` must not import or read foreign `interactive/internal/**`; `SceneViewRenderSurface`, `ScenePainter`, and overlay rendering must consume one read-only render-state source.
2. `controller` remains the only owner of committed scene mutations; `interactive` remains the owner of transient gesture state and must not duplicate snapshot import or mutate `TxnContext` directly.
3. `kMaxStrokePointsPerNode` and `kMaxPaletteItems` must be model-owned invariants applied uniformly across typed construction/import, validation, serialization, and JSON decode.
4. Guardrails for this area must reject foreign `internal/**` imports by structure and must require executable proof for the touched invariant coverage rules.

## 5. Result Requirements
1. No production file in `lib/src/view/**` imports `interactive/internal/**`, and the marquee/overlay state used by `SceneViewRenderSurface`, `ScenePainter`, and `SceneViewInteractiveOverlayPainter` is read from one render-state bridge with matching repaint ownership.
2. Public mutation entrypoints cannot mutate committed scene state during an active gesture by bypassing the interactive owner; `scene.write(...)` no longer provides that bypass for the touched operations.
3. `replaceScene(...)` performs scene import/materialization only in the controller-owned mutation path, and the touched selection mutations use one canonical controller execution path instead of a mixed direct-`TxnContext` path.
4. `SceneSnapshot`, `NodeSpec`, and `NodePatch` no longer expose public `materialize(...)` or `internalBacking` members.
5. The package cannot emit stroke-point-count or palette-size data through typed construction or serialization that its own decode rejects for those limits.
6. Tooling fails on foreign `internal/**` imports and on comment-only invariant proofs for the touched rule set.

## 6. Implementation Specification

### 6.1 Analysis Scope
- Read-side ownership: transient render-state assembly, painter inputs, and repaint source wiring.
- Write-side ownership: active-gesture admission, `replaceScene(...)` routing, and canonical controller execution for the touched selection mutations.
- Model-owned invariants: shared validation ownership for stroke point count and palette item count.
- Public boundary sealing: removal of internal-only hooks from exported contract types without changing supported subject fields.
- Guardrail proof strength: import-boundary structure checks and invariant-proof execution checks.

### 6.2 Target Verification Units
- `test/view/scene_view_interactive_test.dart`
- `test/render/scene_painter_test.dart`
- `test/interactive/core/scene_controller_interactive_basics_test.dart`
- `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- `test/controller/core/scene_controller_commit_atomicity_test.dart`
- `test/model/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `tool/check_import_boundaries.dart`
- `tool/check_public_api_surface.dart`
- `tool/check_invariant_coverage.dart`
- `tool/run_tool_tests.dart`

### 6.3 Protected States, Data, or Structures
- Committed scene snapshot, committed selection state, and camera state.
- Active gesture state, including marquee rectangle, preview delta, and overlay preview state.
- Exported contract types for scene snapshots, node specs, and node patches.
- Model-owned limits for stroke point count and palette item count.

### 6.4 Allowed Semantic Change Zones
- Read-only render-state assembly and repaint subscription wiring.
- Public mutation admission during active gesture and controller-owned mutation routing.
- Shared validation ownership for the touched model limits.
- Internal adaptation behind exported contract types.
- Architecture tooling and invariant-proof validation rules.

### 6.5 Recognition Forms That Must Be Supported Within This Change
- direct foreign-layer import into `internal/**`;
- relative-path foreign-layer import into `internal/**`;
- `package:` foreign-layer import into `internal/**`.

### 6.6 Allowed Forms That Do Not Count as Violations
- same-layer imports into that layer’s own `internal/**`.
- canonical `contract/internal/**` imports from `model` and `serialization`.

### 6.7 Requirements for Resolution of Links and Structural Analysis
- The import-boundary rule must normalize both `package:` and relative imports before layer comparison.
- The import-boundary rule must compare the importer layer, target layer, and the presence of a foreign `internal/` segment; top-level layer allowlists alone are insufficient for this change.
- The invariant-proof rule must distinguish executable proof units from plain marker comments inside the touched proof paths.

### 6.8 Prohibited
- direct `view` calls to `sceneControllerInternal*` helpers;
- pre-controller `txnSceneFromSnapshot(...)` in the interactive `replaceScene(...)` path;
- mixed canonical/direct `TxnContext` mutation for the touched selection operations;
- public `materialize(...)` or `internalBacking` exposure on the touched exported contract types;
- decode-only ownership for the touched stroke and palette limits.

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

### Slice 1. [ ] Read-side bridge and live marquee state

#### Slice Contract
`view/render` consumes transient marquee and overlay state from one read-only render-state bridge, and live marquee rendering no longer depends on a widget-field snapshot or foreign `interactive/internal/**` access.

#### Change
Introduce the render-state bridge needed by `SceneViewRenderSurface`, `ScenePainter`, and `SceneViewInteractiveOverlayPainter`; remove foreign `interactive/internal/**` access from the view-side read path; rewire repaint ownership to the same source that provides the transient render data.

#### Verification
- `flutter test test/view/scene_view_interactive_test.dart`
- `flutter test test/render/scene_painter_test.dart`
- `dart tool/check_import_boundaries.dart`

#### Positive Scenarios
- marquee selection is visible and updates across multiple drag frames in `SceneViewInteractive`;
- overlay preview clears immediately after controller-visible scene-boundary operations that reset the active gesture.

#### Negative Scenarios
- a foreign `view -> interactive/internal/**` import fails the import-boundary check;
- the read path cannot rely on one-time `selectionRect` capture for live marquee rendering.

#### Closure Evidence
- green run of the listed view/render tests;
- green run of the import-boundary tool with the new foreign-`internal/**` rule;
- diagnostic output for the blocked foreign `internal/**` case.

### Slice 2. [ ] Canonical committed mutation routing for touched paths

#### Slice Contract
The touched public scene and selection mutations no longer bypass the interactive owner during an active gesture, `replaceScene(...)` imports the scene only in the controller-owned path, and the touched selection mutations use one canonical controller execution mechanism.

#### Change
Block the active-gesture bypass through `scene.write(...)` for the touched operations, remove the pre-controller `txnSceneFromSnapshot(...)` call from the interactive `replaceScene(...)` path, and move the touched selection mutations onto one canonical controller execution path.

#### Verification
- `flutter test test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_basics_test.dart`
- `flutter test test/controller/core/scene_controller_commit_atomicity_test.dart`

#### Positive Scenarios
- `replaceScene(...)` and `setCameraOffset(...)` still reset active gesture state through the controller-owned path;
- touched selection mutations commit through the same controller execution mechanism.

#### Negative Scenarios
- `scene.write(...)` with touched selection or document-replacement operations fails during an active gesture at the admission point;
- no second scene import occurs before the controller mutation path handles `replaceScene(...)`.

#### Closure Evidence
- green run of the listed interactive/controller tests;
- diagnostic output showing the active-gesture guard trigger for the blocked `scene.write(...)` path.

### Slice 3. [ ] Model-owned limit invariants for stroke and palette

#### Slice Contract
`kMaxStrokePointsPerNode` and `kMaxPaletteItems` are enforced by one shared model-owned validation path across typed construction/import, validation, serialization, and JSON decode.

#### Change
Move stroke-point-count and palette-item-count validation into shared model-owned validators used by the touched contract constructors, model validation, serialization admission, and JSON decode.

#### Verification
- `flutter test test/model/scene_builder_test.dart`
- `flutter test test/serialization/scene_codec_validation_test.dart`

#### Positive Scenarios
- maximum valid stroke and palette values round-trip through typed construction, serialization, and decode;
- typed import and JSON decode accept the same in-range limit cases.

#### Negative Scenarios
- over-limit stroke snapshots are rejected before serialization completes;
- over-limit palette snapshots are rejected identically by typed construction/import and decode.

#### Closure Evidence
- green run of the listed model/serialization tests;
- failing negative cases for over-limit stroke and palette inputs captured in the listed verification units.

### Slice 4. [ ] Sealed exported contract types

#### Slice Contract
The touched exported contract types expose only supported subject fields and factories; internal backing/materialization hooks are no longer public members.

#### Change
Move internal backing/materialization access behind non-exported adapters for `SceneSnapshot`, `NodeSpec`, and `NodePatch`, and update internal callers to use the non-exported path instead of public hooks.

#### Verification
- `dart tool/check_public_api_surface.dart`
- `dart tool/run_tool_tests.dart`

#### Positive Scenarios
- supported subject fields on the touched contract types remain exported through the public entrypoint;
- internal adaptation continues to work through non-exported helpers.

#### Negative Scenarios
- public API surface output no longer contains `materialize` or `internalBacking` on the touched exported types.

#### Closure Evidence
- green run of the public API surface check;
- green run of the tool test suite covering the touched public-surface rules.

### Slice 5. [ ] Guardrails and executable proof hardening

#### Slice Contract
Tooling rejects foreign `internal/**` imports and rejects comment-only invariant proof paths for the touched rules.

#### Change
Extend the import-boundary checker to treat foreign `internal/**` imports as violations under the locked rules, strengthen `check_invariant_coverage.dart` so marker comments alone are insufficient proof for the touched invariant coverage rule, and update CI or verification wiring only as needed to execute those checks.

#### Verification
- `dart tool/check_import_boundaries.dart`
- `dart tool/check_invariant_coverage.dart`
- `flutter test test/tool/invariant_coverage_tool_test.dart`
- `dart tool/run_tool_tests.dart`

#### Positive Scenarios
- same-layer `internal/**` imports and the canonical `contract/internal/**` paths still pass;
- executable proof units with valid invariant markers still pass coverage checks.

#### Negative Scenarios
- `view -> interactive/internal/**` fails the import-boundary tool;
- a proof path containing only a marker comment fails invariant coverage.

#### Closure Evidence
- green run of the listed tools and tool tests;
- diagnostic output for the blocked foreign `internal/**` import;
- diagnostic output for the blocked comment-only proof path.

## 9. Final Verification
- `flutter test test/view/scene_view_interactive_test.dart`
- `flutter test test/view/scene_view_test.dart`
- `flutter test test/render/scene_painter_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_basics_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- `flutter test test/controller/core/scene_controller_commit_atomicity_test.dart`
- `flutter test test/model/scene_builder_test.dart`
- `flutter test test/serialization/scene_codec_validation_test.dart`
- `dart tool/check_import_boundaries.dart`
- `dart tool/check_public_api_surface.dart`
- `dart tool/check_invariant_coverage.dart`
- `dart tool/run_tool_tests.dart`
- final diagnostics for the blocked active-gesture write bypass, blocked foreign `internal/**` import, and blocked comment-only invariant proof.

## 10. Acceptance Criteria
- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
