language: russian

# Шаг 75. Ввести симметричный primary/tool proof contract для invariant coverage

## 1. Change Mandate

Этот шаг переводит invariant proof coverage с single untyped `proofPath` на симметричный proof contract, где каждый invariant обязан иметь один `primaryProof` в executable `test/**`, а tool-backed invariants дополнительно обязаны иметь `toolProof` с `enforcementPath` в `tool/*.dart` и `regressionPath` в `test/tool/**`.

## 2. Change Boundary

### Included in the Change

- Симметричный proof contract `primaryProof + optional toolProof` в `tool/invariant_registry.dart`.
- Kind-aware validation в `tool/check_invariant_coverage.dart`.
- Sandbox regression matrix для нового proof contract в `test/tool/invariant_coverage_tool_test.dart`.
- Миграция current tool-backed invariants на explicit `primaryProof` и `toolProof.regressionPath` в existing `test/tool/import_boundaries/**` и `test/tool/guardrails/**`.

### Not Included in the Change

- Любые новые invariant ids, semantic changes существующих invariant rules, или пересмотр `scope` / `title`.
- Любые behavioral changes в `tool/check_guardrails.dart`, `tool/check_import_boundaries.dart` и `tool/check_public_api_surface.dart`, кроме marker wiring, необходимого для нового proof contract.
- Любые изменения `.github/workflows/ci.yaml`, `VERIFICATION.md` или trigger list для tool tests.
- Любые non-tool runtime or Flutter tests вне `test/tool/**`.

## 3. File Map and Analysis Areas

### Implementation Files

- `tool/invariant_registry.dart`
- `tool/check_invariant_coverage.dart`

### Test Files

- `test/tool/invariant_coverage_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart`
- `test/tool/guardrails/guardrails_public_surface_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`

### Fixture and Supporting Data Files

- `test/tool/support/tool_process_test_support.dart`
- `test/tool/support/guardrails_tool_test_support.dart`
- `PLAN.md`
- `plan/step_75_typed_invariant_proof_surface_and_tool_companions.md`

### Analysis Area

- `tool/invariant_registry.dart`
- `tool/check_invariant_coverage.dart`
- `test/tool/invariant_coverage_tool_test.dart`
- `test/tool/import_boundaries/**`
- `test/tool/guardrails/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `tool/invariant_registry.dart` остаётся single source of truth для invariant ids и declared proof surfaces.
2. Navigation marker format остаётся `// INV:<id>`.
3. Navigation markers вне declared proof surfaces могут оставаться в кодовой базе, но не считаются proof coverage.
4. Каждый invariant обязан иметь ровно один `primaryProof`, и он всегда должен быть executable test proof.
5. Tool-backed invariant не считается доказанным только по marker-у в `tool/*.dart`; ему нужен `toolProof` с `enforcementPath` и `regressionPath`, а основной proof всё равно остаётся `primaryProof`.
6. `tool/*.dart` является enforcement surface, а не заменой executable proof.
7. Этот шаг не сохраняет parallel fallback contract через legacy `proofPath`.

## 5. Result Requirements

1. Каждый invariant в registry декларирует ровно один explicit `primaryProof` вместо single untyped `proofPath`.
2. `dart run tool/check_invariant_coverage.dart` отклоняет invalid proof-kind/path combinations с точной диагностикой.
3. Any declared `toolProof` without valid `enforcementPath` и `regressionPath` fails invariant coverage.
4. Existing tool-backed invariants в repository имеют `primaryProof` и `toolProof.regressionPath`, согласованные с current sandbox regression surfaces.
5. Comment-only `INV:` markers вне declared proof surfaces не засчитываются как invariant coverage.
6. Sandbox regression matrix покрывает как минимум три failure classes: comment-only marker, invalid primary/tool proof shape, tool proof without tool regression.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current registry хранит ровно один `proofPath` на invariant.
- Current coverage tool проверяет только existence declared proof file и matching `// INV:<id>` marker в нём.
- Current tool-backed invariants указывают на top-level entrypoints `tool/check_import_boundaries.dart`, `tool/check_guardrails.dart` и `tool/check_public_api_surface.dart`.
- Existing executable regression surfaces для этих tools уже живут под `test/tool/import_boundaries/**` и `test/tool/guardrails/**`, но часть соответствующих markers пока отсутствует.

### 6.2 Target Verification Units

- `dart run tool/run_tool_tests.dart test/tool/invariant_coverage_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart test/tool/guardrails/guardrails_public_surface_tool_test.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`
- `dart run tool/check_invariant_coverage.dart`

### 6.3 Protected States, Data, or Structures

- Existing invariant ids, scopes, and titles.
- Existing marker syntax `// INV:<id>`.
- Existing non-tool invariant coverage through executable `test/**` proof files.
- Existing behavior of guardrail and import-boundary tools outside proof declaration and marker wiring.

### 6.4 Allowed Semantic Change Zones

- Registry proof declaration schema.
- `primaryProof` validation rules.
- `toolProof` validation rules.
- Coverage diagnostics for invalid proof declarations.
- Marker placement inside existing tool regression tests.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- declared `primaryProof` in `test/**/*_test.dart`;
- declared `toolProof.enforcementPath` in `tool/*.dart`;
- declared `toolProof.regressionPath` in `test/tool/**/*_test.dart`;
- invariant with only `primaryProof`;
- invariant with `primaryProof` plus `toolProof`;
- navigation-only `// INV:<id>` marker outside declared proof surfaces.

### 6.6 Allowed Forms That Do Not Count as Violations

- An invariant declaring only `primaryProof` and no `toolProof`.
- Extra `// INV:<id>` markers outside the declared proof surfaces.
- A `test/tool/**/*_test.dart` file carrying markers for more than one invariant.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- Proof declarations must remain repo-relative POSIX paths.
- `primaryProof.path` is valid only for `test/**/*_test.dart`.
- `toolProof.enforcementPath` is valid only for top-level `tool/*.dart`; `tool/src/**` and non-Dart paths are invalid enforcement surfaces.
- `toolProof.regressionPath` is valid only for `test/tool/**/*_test.dart`.
- Every invariant must declare exactly one `primaryProof`.
- If an invariant declares `toolProof`, both `enforcementPath` and `regressionPath` are required.
- Every declared proof file must exist and contain a matching `// INV:<id>` marker.
- Proof satisfaction must be resolved by the explicit `primaryProof` / `toolProof` slots, not by marker placement alone or filename similarity.

### 6.8 Prohibited

- Keeping legacy `proofPath` as a parallel fallback after typed proofs are introduced.
- Counting arbitrary `// INV:<id>` markers as coverage without a declared proof entry.
- Counting markers in helper/support files as proof coverage when the file is not a declared proof surface.
- Declaring more than one `primaryProof` for one invariant.
- Declaring `toolProof` without `primaryProof`.
- Using `tool/*.dart` as a substitute for `primaryProof`.
- Satisfying `toolProof.regressionPath` with a `test/**` file that is not an executable `test/tool/**/*_test.dart`.
- Expanding the change into invariant-semantic rewrites, CI rewiring, or verification-surface changes outside this proof contract.

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

### Slice 1. [x] Typed Proof Contract

#### Slice Contract

Registry и coverage tool работают на explicit `primaryProof` / `toolProof` slots и отклоняют invalid comment-only или invalid proof-shape declarations в sandbox regression matrix.

#### Change

Заменить single `proofPath` contract на explicit `primaryProof` и optional `toolProof`, обновить coverage checker под новый contract и расширить sandbox tool test под validation этого shape.

#### Verification

- `dart run tool/run_tool_tests.dart test/tool/invariant_coverage_tool_test.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Fixtures Used

- `test/tool/invariant_coverage_tool_test.dart`
- `test/tool/support/tool_process_test_support.dart`

#### Positive Scenarios

- Declared `primaryProof` in `test/sample_test.dart` passes when the file exists and carries the matching marker.
- Declared `primaryProof` plus declared `toolProof` passes when all declared files exist and carry the matching marker.

#### Negative Scenarios

- Comment-only marker outside the declared proof surface does not satisfy coverage.
- `primaryProof` or `toolProof` declared with an invalid path shape fails coverage.
- Declared `toolProof` without a declared `test/tool` regression path fails coverage.

#### Closure Evidence

- Green run of the listed verifications.
- Failure diagnostics from the sandbox matrix show the expected categories for comment-only, wrong-kind, and missing-tool-test cases.

### Slice 2. [x] Repository Tool-Proof Migration

#### Slice Contract

All current tool-backed invariants declare `primaryProof` plus `toolProof`, and the existing import-boundary and guardrail tool tests carry the corresponding invariant markers.

#### Change

Обновить tool-backed registry entries на explicit `primaryProof` плюс `toolProof`, и добавить matching `// INV:<id>` markers в existing import-boundary и guardrail tool tests, которые уже exercise these invariants.

#### Verification

- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart test/tool/guardrails/guardrails_public_surface_tool_test.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Fixtures Used

- `test/tool/support/guardrails_tool_test_support.dart`
- `test/tool/support/tool_process_test_support.dart`

#### Positive Scenarios

- Import-boundary invariants declared against `tool/check_import_boundaries.dart` resolve to `toolProof.regressionPath` in the existing import-boundary tool tests.
- Guardrail invariants declared against `tool/check_guardrails.dart` or `tool/check_public_api_surface.dart` resolve to `toolProof.regressionPath` in the existing guardrail tool tests.

#### Negative Scenarios

- A tool-backed invariant cannot remain covered only by its tool entrypoint marker after the migration.
- Removing a declared `toolProof.regressionPath` from a tool-backed invariant causes `check_invariant_coverage` to fail.

#### Closure Evidence

- Green run of the listed verifications.
- Repository-wide invariant coverage run passes with the migrated tool-backed invariant entries.

## 9. Final Verification

- `dart run tool/run_tool_tests.dart test/tool/invariant_coverage_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart test/tool/guardrails/guardrails_public_surface_tool_test.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`
- `dart run tool/check_invariant_coverage.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
