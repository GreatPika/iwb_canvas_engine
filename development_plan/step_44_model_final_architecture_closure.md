language: russian

# Шаг 44. Замкнуть финальную model architecture на docs, guardrails и baseline

## 1. Change Mandate

Этот шаг завершает `model`-layer sequence after steps `40-43`: финальная
архитектура `model` должна быть явно зафиксирована в in-repo documentation,
подтверждена mechanical guardrails/invariants and downstream proofs, и закрыта
финальным measured baseline без reopening production ownership slices.

## 2. Change Boundary

### Included in the Change

- Final architecture-doc update for the `model` owner graph after steps
  `40-43`
- Extension of guardrail tooling and invariant-backed proofs so the final
  `model` facade/internal-owner split is pinned against regression
- Final `model` metrics/clone rebaseline and roadmap closure tied directly to
  steps `40-44`

### Not Included in the Change

- Reopening production `model` refactors from steps `40-43` beyond minimal
  adaptation required to satisfy the proofs introduced by this step
- Public API changes for `SceneBuilder`, snapshots, or codec entrypoints
- New public tooling entrypoints or package exports created only for this step
- Production work in `controller/**`, `interactive/**`, `render/**`,
  `view/**`, `serialization/**`, or `contract/**` outside documentation or
  verification directly tied to the final `model` architecture

## 3. File Map and Analysis Areas

### Implementation Files

- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`
- `tool/check_guardrails.dart`
- `tool/src/guardrails/guardrails_runner.dart`
- `tool/src/guardrails/model_architecture_guardrails.dart`
- `tool/invariant_registry.dart`

### Test Files

- `test/model/document_model_test.dart`
- `test/model/document_clone_test.dart`
- `test/model/scene_builder_test.dart`
- `test/model/scene_value_validation_primitives_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_fixture_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

### Fixture and Supporting Data Files

- `development_plan/step_40_scene_builder_thin_facade_and_runtime_import_export_spine.md`
- `development_plan/step_41_scene_node_boundary_mapping_family_modules_without_parts.md`
- `development_plan/step_42_scene_value_validation_explicit_modules_without_parts.md`
- `development_plan/step_43_document_txn_facade_and_focused_owner_split.md`
- `development_plan/step_44_model_final_architecture_closure.md`

### Analysis Area

- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`
- `lib/src/model/**`
- `tool/check_guardrails.dart`
- `tool/src/guardrails/**`
- `tool/invariant_registry.dart`
- `test/model/**`
- `test/public_api/**`
- `test/serialization/**`
- `test/tool/guardrails/**`
- `development_plan/step_40*.md`
- `development_plan/step_41*.md`
- `development_plan/step_42*.md`
- `development_plan/step_43*.md`
- `development_plan/step_44*.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified documentation file must either describe the final `model`
  architecture or record the final measured `model` baseline.
- Every modified guardrail or proof file must pin one final `model` boundary
  against architectural regression.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. This step starts only after steps `40-43` are closed.
2. `SceneBuilder` remains the public import/canonicalization gateway through
   `scene_builder_api.dart`, while `scene_builder.dart` remains the thin
   internal import facade.
3. `scene_document_codec.dart` is the canonical internal runtime document
   codec facade for non-model serialization flows; downstream non-model code
   must not import `scene_builder.dart` or `scene_policy.dart` directly.
4. `scene_from_snapshot.dart` and `scene_snapshot_from_scene.dart` remain the
   shared runtime import/export owners; `document.dart` must not regain
   builder-owned conversion logic.
5. `scene_node_boundary_mapping.dart` remains the canonical mapping facade over
   family-local owner modules.
6. `scene_value_validation.dart` remains the canonical validation facade, and
   `ScenePolicy` remains the single owner of scene-level semantics.
7. `document.dart` remains the canonical downstream txn facade over focused
   document-local owners.
8. Final closure must pin architecture by documentation plus mechanical proofs;
   metrics alone are insufficient.

## 5. Result Requirements

1. `ARCHITECTURE.md` describes the final `model` architecture with:
   `scene_builder_api.dart` as the public `SceneBuilder` surface,
   `scene_builder.dart` as a thin import facade,
   `scene_document_codec.dart` as the canonical runtime document codec facade
   for non-model serialization,
   `scene_from_snapshot.dart` / `scene_snapshot_from_scene.dart` as shared
   runtime import/export owners,
   `scene_node_boundary_mapping.dart` as a thin mapping facade over
   family-local modules,
   `scene_value_validation.dart` as a thin validation facade over explicit
   domain modules,
   `ScenePolicy` as the only scene-level semantic owner,
   and `document.dart` as a thin downstream txn facade over focused document
   owners.
2. `DEVELOPMENT_PLAN.md` and steps `40-44` describe one consistent final
   `model` end-state with no stale references to remaining `part`-based or
   mixed-owner architecture debt in the `model` layer.
3. A model-specific guardrail runs through `tool/check_guardrails.dart` and
   fails when:
   `lib/src/model/**` reintroduces `part` / `part of`,
   `document.dart` imports `scene_builder.dart`,
   or downstream non-model code imports or re-exports
   `scene_builder.dart`,
   `scene_policy.dart`, or the internal owner modules introduced by steps
   `40-43` instead of the canonical facades.
4. `tool/invariant_registry.dart` contains an explicit final-architecture
   invariant for `model`, and `dart run tool/check_invariant_coverage.dart`
   stays green.
5. Final measured `model` baseline is recorded from actual runs of
   `dcm calculate-metrics lib/src/model --report-all`
   and
   `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`;
   no accepted residual `HIGH` / `VERY HIGH` hotspot or clone cluster may
   belong to the mixed-owner shapes explicitly removed by steps `40-43`.
6. `rg -n "^(part|part of) " lib/src/model -g '*.dart'` returns no matches.

## 6. Implementation Specification

### 6.1 Analysis Scope

- This step assumes the production owner splits from steps `40-43` are already
  closed and does not reopen them as its main subject.
- The pre-closure `model` baseline that this step must supersede began from
  the residual sequence identified before step `40`:
  mixed builder/import ownership,
  direction-first mapping ownership,
  `scene_value_validation` `part` coupling,
  and `document.dart` mixed ownership.
- `ARCHITECTURE.md` currently states that `model/` owns conversions and that
  `SceneBuilder` / `ScenePolicy` belong to `model`, but it does not yet pin
  the final file-local owner graph expected after steps `40-43`.
- `tool/src/guardrails/guardrails_runner.dart` currently has no dedicated
  `model` architecture guardrail; final closure must add one explicitly rather
  than relying on prose or incidental import-boundary coverage.
- Final measured closure baseline must be taken from actual post-step runs and
  recorded in the repo documentation; inferred numbers are forbidden.

### 6.2 Target Verification Units

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/model --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `rg -n "^(part|part of) " lib/src/model -g '*.dart'`
- MCP test runner:
  `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner:
  `test/controller/core test/controller/commands`
  plus
  `test/controller/scene_invariants_test.dart`,
  `test/controller/scene_snapshot_invariant_assertions_test.dart`,
  and
  `test/controller/scene_controller_randomized_txn_test.dart`
- MCP test runner:
  `test/render test/view`
- MCP test runner:
  `test/interactive`
- MCP test runner:
  `example/test` with root `example/`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

### 6.3 Protected States, Data, or Structures

- Final `SceneBuilder` import/canonicalization contract and diagnostics.
- Runtime import/export ownership and snapshot/spec conversion semantics.
- `ScenePolicy` ownership of scene-level semantics.
- Final document facade surface consumed by controller, interactive,
  serialization, and builder-facing code.
- Accepted residual `model` seams and their final measured baseline.

### 6.4 Allowed Semantic Change Zones

- Architecture documentation.
- Guardrail tooling and invariant-backed proof surfaces.
- Roadmap and baseline documentation tied directly to the final `model`
  architecture.
- Minimal production adaptations required to satisfy the final proofs without
  reopening steps `40-43`.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- The new model guardrail must reuse the existing `check_guardrails.dart`
  entrypoint and tool-test harness rather than creating a second public
  verification command.
- Guardrail assertions must pin the final `model` file graph directly enough to
  fail when:
  `scene_builder.dart`,
  `scene_node_boundary_mapping.dart`,
  `scene_value_validation.dart`,
  or `document.dart`
  reabsorb mixed-owner bodies,
  or when downstream non-model files bypass the canonical model facades.
- Final measured `model` baseline must be recorded from actual runs of the
  listed verification units, not from inferred or copied numbers.

### 6.8 Prohibited

- Reopening production `model` refactors as a substitute for documenting or
  pinning the final architecture.
- Leaving the final `model` architecture implicit only in step documents
  without updating `ARCHITECTURE.md`.
- Accepting final closure without a dedicated `model` guardrail and invariant
  coverage.
- Accepting residual mixed-owner hotspots or clone clusters in
  `scene_builder.dart`,
  `scene_node_boundary_mapping.dart`,
  `scene_value_validation.dart`,
  or `document.dart`
  as closure-state seams.

## 7. Execution Rules

1. This step starts only after steps `40-43` are closed.
2. This step closes only if the final `model` architecture is both documented
   and mechanically pinned against regression.
3. Rebaseline alone does not count as closure without the corresponding
   docs/guardrail/invariant updates.
4. Scope expansion beyond `model` architecture closure is forbidden.

## 8. Vertical Slices

### Slice 1. [x] Add model architecture guardrails and invariant-backed proof surface

#### Slice Contract

The final `model` file graph is mechanically enforced and fails on the exact
architectural regressions removed by steps `40-43`.

#### Change

Add a dedicated `model` architecture guardrail under the existing guardrail
runner, register a final `model` architecture invariant, and extend tool tests
so they fail when `part` returns to `lib/src/model/**`, when
`document.dart -> scene_builder.dart` is reintroduced, or when downstream
non-model code imports the internal owner modules directly.

#### Verification

- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`

#### Closure Evidence

- Green run of the listed verifications.
- The new `model` guardrail is executed from the canonical guardrails runner.
- Invariant coverage includes the final `model` architecture invariant and its
  proof marker.

### Slice 2. [x] Rebaseline and document the final model architecture

#### Slice Contract

The final `model` architecture and its accepted residual seams are recorded
consistently in repo docs and roadmap, and the closure baseline is taken from
actual runs.

#### Change

Update `ARCHITECTURE.md`, `DEVELOPMENT_PLAN.md`, and steps `40-44` to describe
the final `model` owner graph, then record the final measured `model`
metrics/clone baseline from actual runs of the closure verification units.

#### Verification

- `dcm calculate-metrics lib/src/model --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `rg -n "^(part|part of) " lib/src/model -g '*.dart'`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- MCP test runner:
  `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner:
  `test/controller/core test/controller/commands`
  plus
  `test/controller/scene_invariants_test.dart`,
  `test/controller/scene_snapshot_invariant_assertions_test.dart`,
  and
  `test/controller/scene_controller_randomized_txn_test.dart`
- MCP test runner:
  `test/render test/view`
- MCP test runner:
  `test/interactive`
- MCP test runner:
  `example/test` with root `example/`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `ARCHITECTURE.md` and `DEVELOPMENT_PLAN.md` describe the same final `model`
  architecture.
- Final measured baseline is recorded from the actual runs, and any accepted
  residuals are limited to focused single-purpose modules only.

## 8.1 Measured Closure Baseline (2026-03-27)

### `dcm calculate-metrics lib/src/model --report-all`

- Scanned files: `28`
- No `VERY HIGH` hotspots remain in `lib/src/model/**`.
- Residual `HIGH` hotspots are limited to focused single-purpose modules:
  - `document.dart`: file `number-of-imports = 14`; facade delegate
    `txnInsertNodeInScene` has `5` parameters
  - `document_node_patch.dart`: `_txnApplyCommonPatch` has `43` SLOC
  - `document_scene_edit.dart`: `txnInsertNodeInScene` has `5` parameters
  - `scene_builder_decode_json.dart`: file `number-of-imports = 18`;
    `_decodeBackgroundSnapshot` has `43` SLOC
  - `scene_from_snapshot.dart`: `sceneFromSnapshot` has `43` SLOC
  - `scene_value_validation_node.dart`: file `number-of-imports = 16`
- These residuals stay within focused owner modules or thin facades and do not
  reopen the mixed-owner shapes removed by steps `40-43`.

### `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`

- Clone clusters found: `15`
- Scan summary: `scannedFiles=28`, `scannedBlocks=158`, `parseErrors=0`
- Residual clusters are concentrated in focused family/owner modules such as
  `scene_node_boundary_mapping_*`,
  `document_node_patch.dart`,
  `scene_builder_json_require.dart`,
  `scene_builder_decode_json.dart`,
  `scene_value_validation_*`, and the shared import/export pair
  `scene_from_snapshot.dart` / `scene_snapshot_from_scene.dart`.
- No reported cluster references
  `document.dart`,
  `scene_builder.dart`,
  `scene_node_boundary_mapping.dart`, or
  `scene_value_validation.dart`,
  so the final canonical facades do not reappear as mixed-owner clone seams.

### Guardrail / Structure Closure

- `dart run tool/check_guardrails.dart` is green with the new dedicated model
  architecture guardrail.
- `dart run tool/check_invariant_coverage.dart` is green with
  `INV-ENG-MODEL-ARCHITECTURE-BOUNDARY`.
- `rg -n "^(part|part of) " lib/src/model -g '*.dart'` returns no matches.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/model --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `rg -n "^(part|part of) " lib/src/model -g '*.dart'`
- MCP test runner:
  `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner:
  `test/controller/core test/controller/commands`
  plus
  `test/controller/scene_invariants_test.dart`,
  `test/controller/scene_snapshot_invariant_assertions_test.dart`,
  and
  `test/controller/scene_controller_randomized_txn_test.dart`
- MCP test runner:
  `test/render test/view`
- MCP test runner:
  `test/interactive`
- MCP test runner:
  `example/test` with root `example/`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
