language: russian

# Шаг 48. Замкнуть residual model architecture после шагов `45-47` на docs, guardrails и baseline

## 1. Change Mandate

Этот шаг завершает residual `model` sequence after steps `45-47`: финальная
архитектура `model` должна быть повторно зафиксирована в documentation,
guardrails, invariants, metrics/clone baseline, и explicit residual review of
large files so that the layer ends in a clear owner graph rather than in a
collection of locally improved hotspots.

## 2. Change Boundary

### Included in the Change

- Final architecture-doc update for the post-step-`45-47` `model` owner graph
- Guardrail/invariant pinning for the full internal-owner graph after the
  additional residual cleanup
- Final measured `model` baseline for metrics, clones, and large-file review
- Roadmap closure tied directly to steps `45-48`

### Not Included in the Change

- New production refactors beyond minimal adaptation required to satisfy the
  proof surfaces introduced by this step
- Public API changes for `SceneBuilder`, document codecs, snapshots, or node
  patch contracts
- Reopening `controller/**`, `interactive/**`, `render/**`, `view/**`,
  `serialization/**`, or `contract/**` beyond documentation or verification
  directly tied to the final `model` architecture

## 3. File Map and Analysis Areas

### Implementation Files

- `ARCHITECTURE.md`
- `PLAN.md`
- `tool/check_guardrails.dart`
- `tool/src/guardrails/guardrails_runner.dart`
- `tool/src/guardrails/model_architecture_guardrails.dart`
- `tool/invariant_registry.dart`

### Test Files

- `test/model/**`
- `test/public_api/**`
- `test/serialization/**`
- `test/controller/**`
- `test/render/**`
- `test/view/**`
- `test/interactive/**`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

### Fixture and Supporting Data Files

- `plan/model_target_architecture.md`
- `plan/step_44_model_final_architecture_closure.md`
- `plan/step_45_scene_builder_json_decode_and_require_owner_split.md`
- `plan/step_46_scene_node_boundary_mapping_support_owner_cleanup.md`
- `plan/step_47_document_node_patch_family_owner_split.md`
- `plan/step_48_model_residual_architecture_closure.md`

### Analysis Area

- `ARCHITECTURE.md`
- `PLAN.md`
- `lib/src/model/**`
- `tool/check_guardrails.dart`
- `tool/src/guardrails/**`
- `tool/invariant_registry.dart`
- `test/**`
- `plan/step_44*.md`
- `plan/step_45*.md`
- `plan/step_46*.md`
- `plan/step_47*.md`
- `plan/step_48*.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified documentation file must either describe the final `model`
  architecture or record its measured final baseline.
- Every modified guardrail, invariant, or proof file must pin one final
  `model` boundary against regression.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Steps `40-44` remain the foundation of the final `model` architecture:
   part-free facades, shared runtime import/export, explicit validation graph,
   and thin document facade.
2. Step `45` defines the final builder JSON decode graph:
   thin `scene_builder.dart`,
   canonical non-model facade in `scene_document_codec.dart`,
   explicit scene-topology, node-common, scalar-parse, and node-family decode
   owners.
3. Step `46` defines the final mapping graph:
   thin `scene_node_boundary_mapping.dart`,
   one true common mapping owner,
   and family-local mapping owners that own their assembly directions.
4. Step `47` defines the final patch graph:
   thin `document_node_patch.dart`,
   one common patch owner,
   and one family-local patch owner per supported node family.
5. `plan/model_target_architecture.md` is the source of truth for
   the exact post-step-`48` file graph, residual policy, and acceptable large
   files; step `48` must validate against it rather than infer the target from
   local improvements.
6. Metrics and clone scans remain proof tools, not design drivers. Any accepted
   residual hotspot or large file must be justified by focused ownership, not
   by accidental survival.

## 5. Result Requirements

1. `ARCHITECTURE.md` describes the final `model` owner graph after steps
   `45-47`, including:
   `scene_builder.dart` as a thin internal import facade,
   `scene_document_codec.dart` as the canonical non-model runtime document
   codec facade,
   explicit JSON decode owners,
   `scene_node_boundary_mapping.dart` plus one common mapping owner and
   family-local mapping owners,
   `scene_value_validation.dart` plus explicit validation domain owners,
   `scene_policy.dart` as the only scene-level semantic owner,
   `document.dart` as the canonical downstream txn facade,
   and `document_node_patch.dart` plus common/family-local patch owners.
2. `PLAN.md` and steps `44-48` describe one consistent final
   `model` end-state with no stale closure language that ignores residual
   builder decode, mapping support, or document patch ownership.
3. `plan/model_target_architecture.md` exists and describes the
   exact post-step-`48` target graph, accepted residuals, and large-file
   policy for `lib/src/model`.
4. `tool/check_guardrails.dart` and `tool/invariant_registry.dart` pin the
   final post-step-`45-47` `model` graph so regressions fail mechanically.
5. Final measured `model` baseline is recorded from actual runs of:
   `dcm calculate-metrics lib/src/model --report-all`,
   `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`,
   `dart run tool/analysis/find_similar_clones.dart lib/src/model`,
   and a large-file review command over `lib/src/model/*.dart`.
6. No accepted residual `HIGH` / `VERY HIGH` hotspot, clone cluster, or large
   file may belong to the mixed-owner shapes explicitly removed by steps
   `45-47`.
7. Any remaining large `model` file must be explicitly classified in the final
   closure notes as:
   acceptable focused owner,
   or
   remaining architecture debt.
   Silent acceptance is forbidden.
8. `rg -n "^(part|part of) " lib/src/model -g '*.dart'` returns no matches.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Step `44` closed the macro-architecture of `model`, but subsequent residual
  analysis still found red hotspots and clone families centered on:
  `scene_builder_decode_json.dart`,
  `scene_builder_json_require.dart`,
  `scene_node_boundary_mapping_support.dart`,
  and `document_node_patch.dart`.
- This step supersedes that earlier closure state by recording the final
  post-residual architecture and measured baseline after steps `45-47`.
- `plan/model_target_architecture.md` fixes the exact target graph
  ahead of execution, including the allowed residual red set and large-file
  review threshold; step `48` must validate and, if needed, explicitly revise
  that target instead of interpreting it implicitly.
- Large files are part of the closure proof, because the residual analysis
  showed that size alone is not the issue; mixed ownership is. Final closure
  must therefore distinguish focused large owners from mixed-owner debt.

### 6.2 Target Verification Units

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/model --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/analysis/find_similar_clones.dart lib/src/model`
- `find lib/src/model -maxdepth 1 -name '*.dart' -print0 | xargs -0 wc -l | sort -nr`
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
- Final runtime import/export ownership and node mapping graph.
- Final validation and scene-policy ownership boundaries.
- Final document mutation/patch application contract consumed by controller and
  interactive layers.
- Final accepted `model` residual baseline and large-file classification.

### 6.4 Allowed Semantic Change Zones

- Architecture documentation and roadmap text.
- Guardrail tooling, invariant definitions, and proof surfaces.
- Minimal production adaptations required to satisfy the final proofs without
  reopening the production ownership slices from steps `45-47`.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- Final closure must make the internal `model` graph explicit enough that a
  future residual scan can tell the difference between focused owners and
  architecture regressions without re-deriving the intended ownership model
  from history.
- The large-file review must be treated as a first-class architecture proof,
  not as an informal afterthought.
- Final closure must not rely on prose alone; the relevant boundaries must be
  mechanically pinned in guardrails, invariants, and tool tests.

### 6.8 Prohibited

- Declaring the layer closed without recording the measured post-step-`45-47`
  baseline.
- Accepting remaining red metrics or clone clusters without classifying their
  architectural meaning.
- Treating large files as automatically acceptable or automatically bad.
- Reopening production owner splits as a substitute for explicit closure
  documentation and proofs.

## 7. Execution Rules

1. This step starts only after steps `45-47` are closed.
2. This step closes only if the final `model` architecture is both documented
   and mechanically enforced.
3. Scope expansion beyond documentation, proofs, and minimal proof-driven
   adaptations is forbidden.

## 8. Vertical Slices

### Slice 1. [x] Re-document the final internal `model` graph after residual cleanup

#### Slice Contract

The final `model` owner graph is explicit in repo docs and no longer stops at
the earlier step-`44` closure state.

#### Change

Update `ARCHITECTURE.md`, `PLAN.md`, and the linked step documents
so they describe the final builder decode, mapping, validation, document, and
patch owner graph after steps `45-47`.

#### Verification

- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Closure Evidence

- Docs describe one consistent post-step-`45-47` `model` architecture.
- No stale closure language remains that contradicts the residual-step graph.

### Slice 2. [x] Pin the final graph with measured baseline and large-file review

#### Slice Contract

Final closure records actual post-step-`45-47` metrics, clone, and large-file
state, and classifies any residual debt explicitly.

#### Change

Run the listed verification units, record the actual `model` baseline, classify
remaining large files and residual hotspots, and extend guardrails/invariants
when the final graph needs stronger enforcement.

#### Verification

- `dcm calculate-metrics lib/src/model --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/analysis/find_similar_clones.dart lib/src/model`
- `find lib/src/model -maxdepth 1 -name '*.dart' -print0 | xargs -0 wc -l | sort -nr`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Closure Evidence

- The post-step-`45-47` baseline is recorded from actual runs.
- Remaining large files and red metrics are explicitly classified.
- No removed mixed-owner seam is silently re-accepted as final state.

## 9. Measured Closure Baseline (2026-03-28)

### `dcm calculate-metrics lib/src/model --report-all`

- Scanned files: `46`
- No `VERY HIGH` hotspots remain in `lib/src/model/**`.
- Residual `HIGH` hotspots are limited to focused owners and facades:
  - `document.dart`: file `number-of-imports = 14`
  - `document.dart`: `txnInsertNodeInScene` parameter count `= 5`
  - `document_scene_edit.dart`: `txnInsertNodeInScene` parameter count `= 5`
  - `scene_builder_decode_node_family.dart`: file `number-of-imports = 11`
  - `scene_builder_decode_scene.dart`:
    `sceneBuilderDecodeSceneSnapshotFromJson` source lines `= 43`
  - `scene_from_snapshot.dart`: `sceneFromSnapshot` source lines `= 43`
  - `scene_value_validation_node.dart`: file `number-of-imports = 16`
- None of these entries belongs to the removed mixed-owner seams from
  `scene_builder_decode_json.dart`,
  `scene_builder_json_require.dart`,
  `scene_node_boundary_mapping_support.dart`, or
  `document_node_patch.dart`.

### `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`

- Clone clusters found: `15`
- Scan summary: `scannedFiles=46`, `scannedBlocks=153`, `parseErrors=0`
- Reported clusters are concentrated in focused owner families:
  `scene_node_boundary_mapping_common.dart` plus family-local mapping owners,
  `scene_builder_json_parse.dart`,
  `scene_builder_json_require.dart`,
  `scene_builder_decode_*`,
  `scene_value_validation_*`,
  `document_clone.dart`,
  `document_locator.dart` / `document_scene_edit.dart`,
  `document_node_patch_common.dart`,
  and the shared import/export pair
  `scene_from_snapshot.dart` / `scene_snapshot_from_scene.dart`.
- No cluster reopens the removed mixed-owner support seam
  `scene_node_boundary_mapping_support.dart`.

### `dart run tool/analysis/find_similar_clones.dart lib/src/model`

- Similar pairs found: `66`
- The highest-overlap pairs are structural repeats inside focused owners,
  including:
  `scene_value_validation_primitives.dart`,
  `scene_policy.dart`,
  `document_node_patch_common.dart`,
  `document_locator.dart` / `document_scene_edit.dart`,
  `scene_builder_decode_*`,
  and `scene_node_boundary_mapping_*`.
- Final closure accepts these as residual focused-owner repeats rather than
  mixed-owner architecture debt.

### `find lib/src/model -maxdepth 1 -name '*.dart' -print0 | xargs -0 wc -l | sort -nr`

- Large-file review threshold: `> 300` lines
- Reviewed top-level files above the threshold:
  - `scene_value_validation_node.dart`: `603` lines, accepted focused
    node-validation owner
  - `scene_policy.dart`: `380` lines, accepted focused scene semantic owner
  - `scene_value_validation_top_level.dart`: `333` lines, accepted focused
    top-level validation owner
  - `scene_builder_decode_scene.dart`: `320` lines, accepted focused
    scene-topology decode owner
  - `document_scene_edit.dart`: `318` lines, accepted focused scene-edit owner
- No silent acceptance remains for large top-level `model` files.

### `rg -n "^(part|part of) " lib/src/model -g '*.dart'`

- Exit code: `1` (`no matches`)

## 10. Final Verification Checklist

- [x] `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- [x] `flutter analyze`
- [x] `(cd example && flutter analyze lib test)`
- [x] `dcm analyze .`
- [x] `dcm calculate-metrics lib/src/model --report-all`
- [x] `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- [x] `dart run tool/analysis/find_similar_clones.dart lib/src/model`
- [x] `find lib/src/model -maxdepth 1 -name '*.dart' -print0 | xargs -0 wc -l | sort -nr`
- [x] `dart run tool/check_import_boundaries.dart`
- [x] `dart run tool/check_public_api_surface.dart`
- [x] `dart run tool/check_guardrails.dart`
- [x] `dart run tool/check_invariant_coverage.dart`
- [x] `rg -n "^(part|part of) " lib/src/model -g '*.dart'`
- [x] MCP test runner:
      `test/model test/serialization test/contract test/public_api test/entrypoints`
- [x] MCP test runner:
      `test/controller/core test/controller/commands` plus
      `test/controller/scene_invariants_test.dart`
      `test/controller/scene_snapshot_invariant_assertions_test.dart`
      `test/controller/scene_controller_randomized_txn_test.dart`
- [x] MCP test runner:
      `test/render test/view`
- [x] MCP test runner:
      `test/interactive`
- [x] MCP test runner:
      `example/test` with root `example/`
- [x] `flutter test --coverage --no-pub --exclude-tags=tool`
- [x] `dart run tool/check_coverage.dart`
- [x] `dart run tool/run_tool_tests.dart`
