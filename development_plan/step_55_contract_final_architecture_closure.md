language: russian

# Шаг 55. Замкнуть финальную contract architecture на docs, guardrails и baseline

## 1. Change Mandate

Этот шаг завершает `contract`-layer cleanup sequence after steps `52-54`:
финальная архитектура `contract` должна быть явно зафиксирована в in-repo
documentation, подтверждена mechanical guardrails/invariants and proof
surfaces, и закрыта measured baseline без reopening production ownership
slices.

## 2. Change Boundary

### Included in the Change

- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`
- `development_plan/contract_target_architecture.md`
- `development_plan/step_52_node_boundary_schema_explicit_owner_split.md`
- `development_plan/step_53_snapshot_fast_path_explicit_internal_owners.md`
- `development_plan/step_54_node_spec_and_patch_explicit_fast_path_modules.md`
- `development_plan/step_55_contract_final_architecture_closure.md`
- `tool/check_guardrails.dart`
- `tool/src/guardrails/guardrails_runner.dart`
- `tool/src/guardrails/contract_architecture_guardrails.dart`
- `tool/src/guardrail_support/**` only for direct adaptation required by the
  new contract guardrail
- `tool/invariant_registry.dart`
- `test/contract/contract_layer_smoke_test.dart`
- `test/contract/patch_field_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/contract/validated_fast_path_contract_test.dart`
- `test/public_api/node_patch_semantics_test.dart`
- `test/public_api/snapshot_immutability_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/model/document_model_test.dart`
- `test/model/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_fixture_test.dart`
- `test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`
- `test/tool/support/**` only for direct adaptation required by the new
  contract guardrail tests

### Not Included in the Change

- Reopening production refactors from steps `52-54` beyond minimal adaptation
  required to satisfy the proofs introduced by this step
- Public API changes for `SceneSnapshot`, `NodeSpec`, `NodePatch`, or
  serialization entrypoints
- New runtime behavior in `model/**`, `controller/**`, `render/**`, or
  `view/**` outside proof-driven compatibility adaptation
- New backing/materialization owners for `NodeSpec` or `NodePatch`
- `example/**` beyond required verification runs

## 3. File Map and Analysis Areas

### Implementation Files

- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`
- `development_plan/contract_target_architecture.md`
- `tool/check_guardrails.dart`
- `tool/src/guardrails/guardrails_runner.dart`
- `tool/src/guardrails/contract_architecture_guardrails.dart`
- `tool/invariant_registry.dart`

### Test Files

- `test/contract/contract_layer_smoke_test.dart`
- `test/contract/patch_field_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/contract/validated_fast_path_contract_test.dart`
- `test/public_api/node_patch_semantics_test.dart`
- `test/public_api/snapshot_immutability_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/model/document_model_test.dart`
- `test/model/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_fixture_test.dart`
- `test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`

### Fixture and Supporting Data Files

- `test/fixtures/scene.json`
- `development_plan/contract_target_architecture.md`
- `development_plan/step_52_node_boundary_schema_explicit_owner_split.md`
- `development_plan/step_53_snapshot_fast_path_explicit_internal_owners.md`
- `development_plan/step_54_node_spec_and_patch_explicit_fast_path_modules.md`
- `development_plan/step_55_contract_final_architecture_closure.md`

### Analysis Area

- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`
- `development_plan/contract_target_architecture.md`
- `lib/src/contract/**`
- `tool/check_guardrails.dart`
- `tool/src/guardrails/**`
- `tool/invariant_registry.dart`
- `test/contract/**`
- `test/public_api/**`
- `test/model/**`
- `test/serialization/**`
- `test/tool/guardrails/**`
- `development_plan/step_52*.md`
- `development_plan/step_53*.md`
- `development_plan/step_54*.md`
- `development_plan/step_55*.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified documentation file must either describe the final `contract`
  architecture or record the measured final `contract` baseline.
- Every modified guardrail, invariant, or tool-test file must pin one final
  `contract` boundary against regression.
- Every modified proof test must pin either the final public contract shape or
  the final internal validated fast-path ownership rules.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Steps `52-54` define the final production owner graph; this step does not
   reopen them as its main subject.
2. `development_plan/contract_target_architecture.md` is the source of truth
   for the exact post-step-`55` contract file graph, accepted asymmetry, and
   residual policy.
3. `snapshot` keeps the deeper backing/materialization graph introduced by
   step `53`.
4. `NodeSpec` and `NodePatch` stop at explicit internal fast-path modules and
   do not gain snapshot-style backing/materialization owners.
5. The final `contract` layer is completely `part`-free.
6. Non-contract production code may depend on
   `internal/node_boundary_schema.dart`
   and
   `internal/snapshot_fast_path.dart`
   where the current architecture requires them, but it must not bypass those
   canonical surfaces and import lower-level contract owner modules directly.
7. Final closure must be pinned mechanically through the existing
   `check_guardrails.dart` entrypoint and the existing invariant-coverage
   pipeline; separate standalone closure tooling is not introduced.
8. `ARCHITECTURE.md` records the final owner graph and allowed asymmetry, but
   raw metric/clone/large-file numbers belong in this step document rather
   than in release-facing architecture prose.

## 5. Result Requirements

1. `ARCHITECTURE.md` describes the final `contract` owner graph with:
   explicit direction-local node-boundary schema owners,
   snapshot public wrappers plus internal backing/materialization owners,
   and `node_spec.dart` / `node_patch.dart` as `part`-free public boundary
   files over explicit internal fast-path modules.
2. `DEVELOPMENT_PLAN.md`, `development_plan/contract_target_architecture.md`,
   and steps `52-55` describe one consistent final `contract` end-state with
   no stale references to remaining `part`-based or mixed-owner seams.
3. `tool/check_guardrails.dart` runs a dedicated contract architecture
   guardrail that fails when:
   `part` / `part of` reappears under `lib/src/contract/**`,
   removed residual `*.part.dart` contract seams reappear,
   or non-contract production code imports non-canonical internal contract
   owner modules directly, including
   `internal/node_boundary_schema_{common,patch,spec,snapshot}.dart`,
   `internal/snapshot_backing.dart`,
   `internal/snapshot_materialization.dart`,
   `internal/node_spec_fast_path.dart`,
   and
   `internal/node_patch_fast_path.dart`.
4. `tool/invariant_registry.dart` contains an explicit final-architecture
   invariant for `contract`, and
   `dart run tool/check_invariant_coverage.dart` stays green.
5. Final measured `contract` baseline is recorded in this step document from
   actual runs of:
   `dcm calculate-metrics lib/src/contract --report-all`,
   `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract`,
   `dart run tool/analysis/find_similar_clones.dart lib/src/contract`,
   and a large-file review command over `lib/src/contract/*.dart`.
6. `rg -n "^(part|part of) " lib/src/contract -g '*.dart'` returns no
   matches.
7. No accepted residual `HIGH` / `VERY HIGH` hotspot, clone cluster, or large
   file may belong to the mixed-owner shapes explicitly removed by steps
   `52-54`.
8. Any remaining large `contract` file is explicitly classified in the final
   closure notes as an acceptable focused public/value owner rather than being
   silently accepted.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Step `55` starts only after the production owner changes from steps `52-54`
  are already closed.
- The repo already enforces the layer DAG, public surface, mutable-type leak
  rules, interactive architecture, and model architecture through
  `tool/check_guardrails.dart`, but there is currently no dedicated contract
  architecture guardrail in that runner.
- Final contract closure therefore requires a new guardrail integrated into the
  existing runner rather than a separate ad-hoc script.
- `ARCHITECTURE.md` must stay release-ready, so the closure records structural
  conclusions there and keeps raw measured baseline data in this step document.
- The final contract target intentionally accepts asymmetry:
  `snapshot` keeps the deeper internal graph from step `53`,
  while `node_spec.dart` and `node_patch.dart` stop at explicit fast-path
  modules because the current codebase has no analogous producer-side graph
  for them.
- Large-file review is part of closure proof because `snapshot.dart`,
  `node_spec.dart`, and `node_patch.dart` may remain large while still being
  architecturally focused.

### 6.2 Target Verification Units

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/contract --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract`
- `dart run tool/analysis/find_similar_clones.dart lib/src/contract`
- `find lib/src/contract -maxdepth 1 -name '*.dart' -print0 | xargs -0 wc -l | sort -nr`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `rg -n "^(part|part of) " lib/src/contract -g '*.dart'`
- MCP test runner:
  `test/contract test/public_api`
- MCP test runner:
  `test/model test/serialization test/entrypoints`
- MCP test runner:
  `test/controller/core test/controller/commands` plus controller-root
  `*_test.dart` files
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

- Public `SceneSnapshot`, `NodeSpec`, and `NodePatch` contract shapes and
  public constructor behavior.
- Internal canonical contract surfaces consumed by `model/**`.
- Validated helper surfaces used by white-box contract tests.
- Final accepted `contract` residual baseline and large-file classification.

### 6.4 Allowed Semantic Change Zones

- Architecture documentation and roadmap text.
- Guardrail tooling, invariant definitions, and proof surfaces.
- Minimal production adaptations required to satisfy the final proofs without
  reopening the production owner work from steps `52-54`.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- The new contract architecture guardrail must reuse the existing
  `check_guardrails.dart` entrypoint, the shared guardrails runner, and the
  existing tool-test harness rather than creating a second public tool.
- Guardrail assertions must treat package imports, relative imports, and
  re-exports uniformly when resolving whether non-contract production code
  bypasses canonical internal contract surfaces.
- Final measured `contract` baseline must be recorded from actual runs of the
  listed verification units, not from inferred or copied numbers.

### 6.8 Prohibited

- Reopening production refactors from steps `52-54` as a substitute for
  documenting or pinning the final architecture.
- Leaving final contract closure implicit only in step documents without
  updating `ARCHITECTURE.md`.
- Accepting final closure without a dedicated contract architecture guardrail
  and invariant coverage.
- Accepting residual `part` seams, mixed-owner internal buckets, or direct
  non-contract imports of non-canonical internal contract owners as
  closure-state residuals.
- Introducing a second public guardrail/closure entrypoint outside
  `tool/check_guardrails.dart`.

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
9. This step closes only if the final `contract` architecture is both
   documented and mechanically pinned against regression.
10. Rebaseline alone does not count as closure without the corresponding
    docs/guardrail/invariant updates.

## 8. Vertical Slices

### Slice 1. [ ] Add contract architecture guardrails and invariant-backed proof surface

#### Slice Contract

The final `contract` file graph is mechanically enforced and fails on the
architectural regressions removed by steps `52-54`.

#### Change

Add `tool/src/guardrails/contract_architecture_guardrails.dart`, wire it into
`guardrails_runner.dart` and `check_guardrails.dart`, register a final
`contract` architecture invariant, and add tool tests that cover the exact
forbidden regressions. The guardrail must encode the final canonical-import
policy from `contract_target_architecture.md`, not a looser approximation.

#### Verification

- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`

#### Positive Scenarios

- Canonical non-contract imports of
  `internal/node_boundary_schema.dart`
  and
  `internal/snapshot_fast_path.dart`
  remain allowed.

#### Negative Scenarios

- `part` / `part of` under `lib/src/contract/**` is rejected.
- Reappearance of removed residual files such as
  `snapshot_fast_path.part.dart`,
  `node_spec_fast_path.part.dart`,
  or
  `node_patch_fast_path.part.dart`
  is rejected.
- Non-contract production imports of non-canonical internal contract owner
  modules are rejected, including representative checks for
  `internal/node_boundary_schema_spec.dart`,
  `internal/snapshot_backing.dart`,
  `internal/node_spec_fast_path.dart`,
  and
  `internal/node_patch_fast_path.dart`.

#### Closure Evidence

- Green run of the listed verifications.
- Tool diagnostics prove each listed negative scenario fails through
  `check_guardrails.dart`.

### Slice 2. [ ] Re-document the final contract owner graph and residual policy

#### Slice Contract

Repo documentation states one consistent final `contract` architecture after
steps `52-54`, including the accepted asymmetry between snapshot and
spec/patch seams.

#### Change

Update `ARCHITECTURE.md`, `DEVELOPMENT_PLAN.md`,
`development_plan/contract_target_architecture.md`, and the linked step
documents so they describe the final part-free contract layer, canonical
internal surfaces, accepted large focused owners, and forbidden residual
shapes. `ARCHITECTURE.md` records final structure only; raw measured baseline
data is kept in this step document.

#### Verification

- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `rg -n "^(part|part of) " lib/src/contract -g '*.dart'`

#### Closure Evidence

- Green run of the listed verifications.
- No stale closure language remains that contradicts the final
  `contract_target_architecture.md` graph.

### Slice 3. [ ] Record the measured final contract baseline and classify accepted residuals

#### Slice Contract

The final measured `contract` baseline is recorded from actual runs and any
remaining large focused files are explicitly classified instead of being
silently accepted.

#### Change

Run the final metrics, clone, and large-file review commands for
`lib/src/contract`, record the measured closure baseline in this step
document, and classify any remaining large focused contract files according to
the target architecture.

#### Verification

- `dcm calculate-metrics lib/src/contract --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract`
- `dart run tool/analysis/find_similar_clones.dart lib/src/contract`
- `find lib/src/contract -maxdepth 1 -name '*.dart' -print0 | xargs -0 wc -l | sort -nr`

#### Closure Evidence

- Green run of the listed verifications.
- Measured baseline values are recorded in repo docs.
- Remaining large files are explicitly classified as focused accepted owners or
  residual debt; silent acceptance does not remain.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/contract --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract`
- `dart run tool/analysis/find_similar_clones.dart lib/src/contract`
- `find lib/src/contract -maxdepth 1 -name '*.dart' -print0 | xargs -0 wc -l | sort -nr`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `rg -n "^(part|part of) " lib/src/contract -g '*.dart'`
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
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
