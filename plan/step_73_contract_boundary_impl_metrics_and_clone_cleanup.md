language: russian

# Шаг 73. Сжать residual metric/clone debt в boundary impl и public surface guardrails

## 1. Change Mandate

Этот шаг сжимает измеренный residual metric/clone debt, оставшийся после шага `72`, в internal contract boundary implementation owner-ах и в `public_surface_guardrails.dart`, не переоткрывая публичный контракт пакета.

## 2. Change Boundary

### Included in the Change

- Сжатие residual hotspot-а в `lib/src/contract/internal/snapshot_boundary_impl.dart`.
- Сжатие residual duplication и metric hotspot-ов в `lib/src/contract/internal/node_spec_boundary_impl.dart` и `lib/src/contract/internal/node_patch_boundary_impl.dart`.
- Сжатие residual duplication в `tool/src/guardrails/public_surface_guardrails.dart` с сохранением current guardrail semantics.
- Точечная адаптация `snapshot_fast_path.dart`, `snapshot_materialization.dart`, `node_spec_fast_path.dart`, `node_spec_materialization.dart`, `node_patch_fast_path.dart`, `node_patch_materialization.dart`, если она нужна для закрытия конкретного slice.
- Точечные contract/public-api/tool regression tests, которые доказывают, что cleanup не ослабил hermetic boundary и fail-fast behavior.
- `PLAN.md` и `plan/step_73_contract_boundary_impl_metrics_and_clone_cleanup.md`.

### Not Included in the Change

- Любое изменение публичной surface `SceneWriteTxn`, `SceneSnapshot`, `NodeSpec`, `NodePatch` или root export surface `lib/iwb_canvas_engine.dart`.
- Любой новый public API, документация public API, changelog или migration notes.
- Любая read-side, controller-side, render-side или interactive-side работа вне точечной адаптации импортов/вызовов, без которой нельзя закрыть конкретный slice.
- Любая metric-only декомпозиция, которая ухудшает читаемость owner boundary или заменяет явные type-safe paths на registry/lookup indirection.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/internal/snapshot_boundary_impl.dart`
- `lib/src/contract/internal/snapshot_fast_path.dart`
- `lib/src/contract/internal/snapshot_materialization.dart`
- `lib/src/contract/internal/node_spec_boundary_impl.dart`
- `lib/src/contract/internal/node_spec_fast_path.dart`
- `lib/src/contract/internal/node_spec_materialization.dart`
- `lib/src/contract/internal/node_patch_boundary_impl.dart`
- `lib/src/contract/internal/node_patch_fast_path.dart`
- `lib/src/contract/internal/node_patch_materialization.dart`
- `tool/src/guardrails/public_surface_guardrails.dart`

### Test Files

- `test/contract/contract_layer_smoke_test.dart`
- `test/contract/validated_fast_path_contract_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/tool/guardrails/guardrails_public_surface_tool_test.dart`

### Fixture and Supporting Data Files

- `PLAN.md`
- `plan/step_72_public_contract_boundary_hermeticity_and_signal_txn_cleanup.md`
- `plan/step_73_contract_boundary_impl_metrics_and_clone_cleanup.md`
- `test/tool/support/guardrails_tool_test_support.dart`
- `test/tool/support/public_entrypoint_contract.dart`

### Analysis Area

- `lib/src/contract/internal/**`
- `tool/src/guardrails/**`
- `test/contract/**`
- `test/public_api/validated_boundary_value_test.dart`
- `test/tool/guardrails/**`
- `PLAN.md`
- `plan/step_72*.md`
- `plan/step_73*.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific slice and its verification cannot be closed.

### File Change Rule

- Каждый изменённый implementation file должен быть привязан к конкретному slice.
- Каждый новый helper file допустим только если он остаётся внутри already allowed internal/tool зон и уменьшает measured duplication без размывания owner boundary.
- Каждый новый или изменённый test должен быть привязан к конкретной verification цели этого cleanup.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Public contract semantics, закрытые в шаге `72`, не переоткрываются в этом шаге.
2. Internal fast-path backing/materialization graph остаётся authoritative internal path.
3. Unsupported public subtypes и unsupported public subclasses известных boundary types должны продолжать fail-fast behavior.
4. `tool/src/guardrails/public_surface_guardrails.dart` остаётся owner-ом member-level hermeticity enforcement для публичной surface.
5. Cleanup должен уменьшать measured metric/clone debt через focused owner decomposition или shared internal helper substrate, а не через opaque registries, reflection-like dispatch или rebuild-through-public-getters.
6. Tool diagnostics для ban-правил `writeSignalEnqueue`, `internalBacking` и `materialize(...)` должны оставаться совместимыми с существующими sandbox tool-tests.

## 5. Result Requirements

1. `lib/src/contract/internal/snapshot_boundary_impl.dart` больше не держит весь snapshot boundary seam как один oversized owner с текущим `VERY HIGH` hotspot на `_publicNodeSnapshotBackingOf(...)`.
2. `lib/src/contract/internal/node_spec_boundary_impl.dart` и `lib/src/contract/internal/node_patch_boundary_impl.dart` больше не держат дублированный carrier/cache/fallback/materialization substrate как independent near-copies.
3. Targeted clone analysis для `lib/src/contract/internal` больше не показывает текущий normalized-exact strongest pair между `nodeSpecBackingOf(...)` и `nodeSnapshotBackingOf(...)`.
4. `tool/src/guardrails/public_surface_guardrails.dart` использует один canonical member-ban path для exported `SceneWriteTxn` и exported contract hermeticity checks вместо локально дублированных scanners.
5. Guardrail positive/negative sandbox scenarios по-прежнему доказывают, что exported surface запрещает `writeSignalEnqueue`, `internalBacking` и `materialize(...)`, но допускает internal-only helpers вне exported surface.
6. `dcm calculate-metrics --report-all` по targeted implementation files больше не показывает current `HIGH` / `VERY HIGH` hotspots, которые мотивировали этот шаг.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current measured hotspots:
  `snapshot_boundary_impl.dart::_publicNodeSnapshotBackingOf(...)` (`VERY HIGH` SLOC),
  `node_spec_boundary_impl.dart::_publicNodeSpecBackingOf(...)` (`VERY HIGH` SLOC),
  `node_patch_boundary_impl.dart::_publicNodePatchBackingOf(...)` (`HIGH` SLOC).
- Current measured clone debt inside `lib/src/contract/internal`:
  exact duplication in carrier/cache/fallback helpers,
  especially `nodeSpecBackingOf(...)` <-> `nodeSnapshotBackingOf(...)`.
- Current measured clone debt inside `tool/src/guardrails/public_surface_guardrails.dart`:
  partially duplicated member-ban scanners for exported txn bans and exported contract hermetic bans.
- Existing fast-path and boundary regression tests already cover fallback reconstruction, materialized getters, subclass rejection, and unsupported subtype fail-fast behavior; this step must reuse and extend that proof surface instead of inventing a new one.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/contract/internal/snapshot_boundary_impl.dart lib/src/contract/internal/snapshot_fast_path.dart lib/src/contract/internal/snapshot_materialization.dart lib/src/contract/internal/node_spec_boundary_impl.dart lib/src/contract/internal/node_spec_fast_path.dart lib/src/contract/internal/node_spec_materialization.dart lib/src/contract/internal/node_patch_boundary_impl.dart lib/src/contract/internal/node_patch_fast_path.dart lib/src/contract/internal/node_patch_materialization.dart tool/src/guardrails/public_surface_guardrails.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract/internal`
- `dart run tool/analysis/find_similar_clones.dart lib/src/contract/internal`
- `dart run tool/analysis/find_similar_clones.dart --clusters tool/src/guardrails`
- `dart run tool/analysis/find_similar_clones.dart tool/src/guardrails`
- `dart run tool/check_guardrails.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_public_surface_tool_test.dart`
- MCP test runner:
  `test/contract/contract_layer_smoke_test.dart`
  `test/contract/validated_fast_path_contract_test.dart`
  `test/public_api/validated_boundary_value_test.dart`

### 6.3 Protected States, Data, or Structures

- Backing identity for materialized internal boundary objects.
- Public fallback reconstruction from public boundary values.
- Unsupported subtype and subclass fail-fast behavior.
- Root public export owner set and guardrail scan ownership through `lib/iwb_canvas_engine.dart`.
- Existing diagnostic strings asserted by `guardrails_public_surface_tool_test.dart`.

### 6.4 Allowed Semantic Change Zones

- Internal carrier/cache helper ownership.
- Internal fallback reconstruction ownership.
- Internal materialization helper ownership and fast-path barrel assembly.
- Guardrail member-ban rule composition and AST scan helper ownership.
- Regression test structure for the above behaviors.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- direct exported txn member ban: `writeSignalEnqueue(...)` on exported `SceneWriteTxn`;
- direct exported contract getter ban: `internalBacking` on exported contract types;
- direct exported contract factory/constructor ban: `materialize(...)` on exported contract types;
- internal-only contrast case: backing/materialization helpers under `lib/src/contract/internal/**` that are not exported through `lib/iwb_canvas_engine.dart`;
- shared scanner path: one rule mechanism that can recognize both txn-surface bans and contract-type member bans.

### 6.6 Allowed Forms That Do Not Count as Violations

- Focused helper extraction inside `lib/src/contract/internal/**` to remove duplication.
- Focused helper extraction inside `tool/src/guardrails/**` to unify duplicated AST/member-ban logic.
- Typed family-specific builders/materializers that remain explicit and do not hide boundary ownership.
- Separate focused owner files for scene/layer/palette/node snapshot bridging if they remain non-exported internal files.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- Guardrail scan must continue to resolve exported files from `lib/iwb_canvas_engine.dart`, not from ad hoc file lists.
- Member-level hermeticity checks must continue to analyze declarations in exported owner files, not only top-level symbol visibility.
- Clone cleanup in `lib/src/contract/internal/**` must be evaluated against cluster and pair output, not against intuition-only visual review.

### 6.8 Prohibited

- Reopening `snapshot.dart`, `node_spec.dart`, `node_patch.dart`, `scene_write_txn.dart`, or public controller semantics just to make the internal files smaller.
- Replacing explicit typed dispatch with map-based registries keyed by runtime names or strings.
- Solving clone output by moving duplication into a giant generic helper that becomes a new hotspot owner.
- Weakening or deleting existing fail-fast tests to make cleanup easier.
- Changing tool-test diagnostic wording unless the corresponding assertions are updated in the same slice and still prove the same policy.

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

### Slice 1. [ ] Snapshot Boundary Impl Decomposition

#### Slice Contract

Snapshot boundary seam is split into focused internal owners so `snapshot_boundary_impl.dart` no longer carries the current oversized fallback/materialization matrix, while fallback reconstruction and materialized getter behavior remain unchanged.

#### Change

Разделить current snapshot boundary owner на focused internal modules по реальным responsibility seams:
scene/layer/palette carrier-cache ownership,
node snapshot fallback reconstruction,
materialized snapshot wrappers.
Оставить fast-path barrel and materialization entrypoints stable for existing internal callers.

#### Verification

- `dcm calculate-metrics lib/src/contract/internal/snapshot_boundary_impl.dart lib/src/contract/internal/snapshot_fast_path.dart lib/src/contract/internal/snapshot_materialization.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract/internal`
- `dart run tool/analysis/find_similar_clones.dart lib/src/contract/internal`
- MCP test runner:
  `test/contract/validated_fast_path_contract_test.dart`
  `test/public_api/validated_boundary_value_test.dart`

#### Positive Scenarios

- Materialized snapshot families still expose the same supported public getters.
- Public snapshot values still reconstruct into backing objects with cached identity on repeated access.

#### Negative Scenarios

- Unsupported `NodeSnapshot` subtypes still throw `StateError`.
- Public subclasses of known snapshot boundary types still do not silently bypass the fallback path.

#### Closure Evidence

- Green run of the listed verifications.
- Measured metrics no longer report the current `VERY HIGH` hotspot on `_publicNodeSnapshotBackingOf(...)`.
- Clone output for `lib/src/contract/internal` no longer reports the old strongest duplication path rooted in snapshot fallback/carrier helpers.

### Slice 2. [ ] Shared Spec/Patch Boundary Substrate

#### Slice Contract

`node_spec_boundary_impl.dart` and `node_patch_boundary_impl.dart` share one focused internal substrate for carrier/cache/fallback/materialization flow, while each file keeps only family-specific mapping rules.

#### Change

Вынести общий internal helper substrate для повторяющегося шаблона:
carrier access,
expando cache lookup,
fallback reconstruction,
typed materialization dispatch.
Сохранить явные family-specific builders и type-safe return values для spec/patch families.

#### Verification

- `dcm calculate-metrics lib/src/contract/internal/node_spec_boundary_impl.dart lib/src/contract/internal/node_spec_fast_path.dart lib/src/contract/internal/node_spec_materialization.dart lib/src/contract/internal/node_patch_boundary_impl.dart lib/src/contract/internal/node_patch_fast_path.dart lib/src/contract/internal/node_patch_materialization.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract/internal`
- `dart run tool/analysis/find_similar_clones.dart lib/src/contract/internal`
- MCP test runner:
  `test/contract/contract_layer_smoke_test.dart`
  `test/contract/validated_fast_path_contract_test.dart`
  `test/public_api/validated_boundary_value_test.dart`

#### Positive Scenarios

- Materialized spec/patch families still preserve backing identity and typed getters.
- Public spec/patch values still reconstruct into the same canonical backing shape.

#### Negative Scenarios

- Unsupported `NodeSpec` / `NodePatch` subtypes still fail fast.
- Public subclasses of known spec/patch families still do not silently materialize through the fallback path.

#### Closure Evidence

- Green run of the listed verifications.
- Measured metrics no longer report the current large SLOC hotspots on `_publicNodeSpecBackingOf(...)` and `_publicNodePatchBackingOf(...)`.
- Targeted clone output no longer reports the current normalized-exact strongest pair between `nodeSpecBackingOf(...)` and `nodeSnapshotBackingOf(...)`.

### Slice 3. [ ] Canonical Guardrail Member-Ban Path

#### Slice Contract

`public_surface_guardrails.dart` uses one canonical rule path for exported member-level bans, and tool tests prove the same policy for txn bans and contract hermeticity bans after the refactor.

#### Change

Свести duplicated exported-member scanners к одному canonical rule representation, который покрывает:
exported `SceneWriteTxn` member bans,
exported contract hermetic member bans,
positive internal-only contrast cases.
Сохранить existing policy scope and sandbox coverage.

#### Verification

- `dcm calculate-metrics tool/src/guardrails/public_surface_guardrails.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters tool/src/guardrails`
- `dart run tool/analysis/find_similar_clones.dart tool/src/guardrails`
- `dart run tool/check_guardrails.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_public_surface_tool_test.dart`

#### Fixtures Used

- `test/tool/support/guardrails_tool_test_support.dart`
- `test/tool/support/public_entrypoint_contract.dart`

#### Positive Scenarios

- Exported surface still rejects banned members on exported txn and exported contract owners.
- Internal-only backing helpers and internal-only signal helpers still pass the guardrail.

#### Negative Scenarios

- Reintroducing `writeSignalEnqueue(...)` on exported `SceneWriteTxn` still fails the tool.
- Reintroducing `internalBacking` or `materialize(...)` on exported contract types still fails the tool.

#### Closure Evidence

- Green run of the listed tooling and tool-test verifications.
- Clone output for `tool/src/guardrails` no longer reports the current partial duplication between `_sceneWriteTxnMemberViolation(...)` and `_exportedContractHermeticMemberViolation(...)`.

## 9. Final Verification

- `dcm calculate-metrics lib/src/contract/internal/snapshot_boundary_impl.dart lib/src/contract/internal/snapshot_fast_path.dart lib/src/contract/internal/snapshot_materialization.dart lib/src/contract/internal/node_spec_boundary_impl.dart lib/src/contract/internal/node_spec_fast_path.dart lib/src/contract/internal/node_spec_materialization.dart lib/src/contract/internal/node_patch_boundary_impl.dart lib/src/contract/internal/node_patch_fast_path.dart lib/src/contract/internal/node_patch_materialization.dart tool/src/guardrails/public_surface_guardrails.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract/internal`
- `dart run tool/analysis/find_similar_clones.dart lib/src/contract/internal`
- `dart run tool/analysis/find_similar_clones.dart --clusters tool/src/guardrails`
- `dart run tool/analysis/find_similar_clones.dart tool/src/guardrails`
- `dart run tool/check_guardrails.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_public_surface_tool_test.dart`
- MCP test runner:
  `test/contract/contract_layer_smoke_test.dart`
  `test/contract/validated_fast_path_contract_test.dart`
  `test/public_api/validated_boundary_value_test.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
