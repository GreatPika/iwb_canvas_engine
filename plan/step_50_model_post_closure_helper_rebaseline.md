language: russian

# Шаг 50. Замкнуть post-closure helper cleanup на measured baseline и обновлённый residual review

## 1. Change Mandate

Этот шаг закрывает post-closure helper sequence after step `49`: он должен
подтвердить, что helper cleanup действительно уменьшил residual clone debt,
не изменил `model` owner graph, и обновить measured post-step baseline без
возврата к metric-only решениям.

## 2. Change Boundary

### Included in the Change

- `PLAN.md`
- `plan/model_target_architecture.md`
- `plan/step_49_json_helper_and_document_locator_residual_cleanup.md`
- `plan/step_50_model_post_closure_helper_rebaseline.md`
- Minimal documentation updates tied directly to the measured post-step-`49`
  residual state

### Not Included in the Change

- New production refactors beyond minimal proof-driven adaptation
- Guardrail or public API changes unless the measured closure state requires
  stronger enforcement
- Reopening accepted focused-owner residuals outside the helper seams closed by
  step `49`

## 3. File Map and Analysis Areas

### Implementation Files

- `PLAN.md`
- `plan/model_target_architecture.md`

### Test Files

- `test/model/**`
- `test/public_api/**`
- `test/serialization/**`
- `test/controller/internal/scene_writer_test.dart`
- `test/controller/commands/scene_commands_test.dart`

### Fixture and Supporting Data Files

- `plan/model_target_architecture.md`
- `plan/step_48_model_residual_architecture_closure.md`
- `plan/step_49_json_helper_and_document_locator_residual_cleanup.md`
- `plan/step_50_model_post_closure_helper_rebaseline.md`

### Analysis Area

- `lib/src/model/**`
- `PLAN.md`
- `plan/model_target_architecture.md`
- `plan/step_48*.md`
- `plan/step_49*.md`
- `plan/step_50*.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified planning document must either record the measured post-step
  residual state or update the exact target state it is validated against.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `plan/model_target_architecture.md` remains the source of truth
   for the post-step-`50` target graph and residual policy.
2. Step `49` is helper cleanup inside the existing graph, not a new
   architecture rewrite.
3. Closure success depends on measured baseline and residual classification,
   not on claiming that clone count must become zero.

## 5. Result Requirements

1. `PLAN.md` and the linked step docs describe one consistent
   post-step-`50` state.
2. `plan/model_target_architecture.md` is updated if, and only if,
   the measured result justifies a narrower residual policy than the one
   locked today.
3. The helper family around
   `scene_builder_json_require.dart`
   and
   `scene_builder_json_parse.dart`
   is no longer reported as an open significant residual seam.
4. The named locator/index duplicate pairs between
   `document_locator.dart`
   and
   `document_scene_edit.dart`
   are no longer reported as open residual seams.
5. No new `HIGH` / `VERY HIGH` hotspot appears outside the accepted residual
   set in `model_target_architecture.md`.
6. Remaining clone clusters are explicitly classified as:
   acceptable focused symmetry,
   or
   still-open debt.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Step `48` already closed the broader residual `model` sequence and recorded a
  post-closure target graph.
- Step `49` narrows only two remaining helper-level seams inside that graph.
- This step records whether that narrow cleanup materially improved the
  residual state and whether any target-spec residual clauses can now be
  tightened.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/model --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/analysis/find_similar_clones.dart lib/src/model`
- `find lib/src/model -maxdepth 1 -name '*.dart' -print0 | xargs -0 wc -l | sort -nr`
- `dart run tool/check_import_boundaries.dart`
- MCP test runner:
  `test/model test/public_api test/serialization`
- MCP test runner:
  `test/controller/internal/scene_writer_test.dart test/controller/commands/scene_commands_test.dart`

### 6.3 Protected States, Data, or Structures

- The post-step-`48` `model` owner graph.
- Accepted focused-owner residual metrics and large files.
- Builder decode diagnostics and document edit semantics.

### 6.4 Allowed Semantic Change Zones

- Planning docs and target-spec residual policy.
- Minimal proof-driven code adaptation required to finish step `49`.

### 6.8 Prohibited

- Reopening the accepted focused-owner residual metrics just because they are
  still red.
- Treating the helper cleanup as justification for a broader architecture pass.
- Declaring closure without recording the measured post-step baseline.

## 7. Execution Rules

1. This step starts only after step `49` is closed.
2. This step closes only if the post-step residual state is measured and
   classified explicitly.
3. Scope expansion beyond residual review, baseline, and minimal proof-driven
   adaptation is forbidden.

## 8. Vertical Slices

### Slice 1. [x] Rebaseline the helper residual seams against the target spec

#### Slice Contract

Post-step-`49` closure is based on measured metrics and clone data, not on
assumptions.

#### Change

Run the listed verification units, compare the result with
`model_target_architecture.md`, and update the residual policy only when the
measured result justifies it.

#### Verification

- `dcm calculate-metrics lib/src/model --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/analysis/find_similar_clones.dart lib/src/model`
- `find lib/src/model -maxdepth 1 -name '*.dart' -print0 | xargs -0 wc -l | sort -nr`

#### Closure Evidence

- The measured post-step baseline is recorded.
- The helper seams targeted by step `49` are no longer treated as open
  significant residuals.
- Remaining residuals are classified explicitly.
- Measured clone output reports `13` clusters / `66` similar pairs, but no
  current cluster or pair reopens the
  `scene_builder_json_require.dart` <-> `scene_builder_json_parse.dart`
  seam.
- The named duplicate pairs between `document_locator.dart` and
  `document_scene_edit.dart` are absent from the measured post-step baseline.
- The only remaining `HIGH` metrics in `lib/src/model` are the already
  accepted focused-owner residuals:
  `document.dart` import count,
  `document.dart::txnInsertNodeInScene`,
  `document_scene_edit.dart::txnInsertNodeInScene`,
  `scene_builder_decode_node_family.dart` import count,
  `scene_builder_decode_scene.dart::sceneBuilderDecodeSceneSnapshotFromJson`,
  `scene_from_snapshot.dart::sceneFromSnapshot`,
  and
  `scene_value_validation_node.dart` import count.
- Large-file review over top-level `lib/src/model/*.dart` keeps only
  `scene_value_validation_node.dart` (`603`),
  `scene_policy.dart` (`380`),
  `scene_value_validation_top_level.dart` (`333`),
  and
  `scene_builder_decode_scene.dart` (`320`)
  above the `300`-line threshold; `document_scene_edit.dart` is now `287`
  lines and leaves the accepted large-file set.

## 9. Final Verification Checklist

- [x] `dcm calculate-metrics lib/src/model --report-all`
- [x] `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- [x] `dart run tool/analysis/find_similar_clones.dart lib/src/model`
- [x] `find lib/src/model -maxdepth 1 -name '*.dart' -print0 | xargs -0 wc -l | sort -nr`
- [x] `dart run tool/check_import_boundaries.dart`
- [x] MCP test runner:
      `test/model test/public_api test/serialization`
- [x] MCP test runner:
      `test/controller/internal/scene_writer_test.dart test/controller/commands/scene_commands_test.dart`
