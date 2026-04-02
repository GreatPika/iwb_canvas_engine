language: russian

# Шаг 76. Привести guardrails claims к реально доказуемому invariant contour

## 1. Change Mandate

Этот шаг приводит `check_guardrails.dart` и `test/tool/guardrails/**` к registry-backed truth: guardrails claim surfaces должны заявлять только те invariants, которые реально объявлены для них как enforcement или executable proof surfaces, а navigation references не должны смешиваться с explicit claim markers.

## 2. Change Boundary

### Included in the Change

- Выравнивание invariant claims в `tool/check_guardrails.dart` с текущими registry-backed `toolProof.enforcementPath`.
- Выравнивание invariant claims в `test/tool/guardrails/**` с текущими registry-backed `primaryProof` / `toolProof.regressionPath`.
- Добавление mechanical claim-honesty check в `tool/check_invariant_coverage.dart` для guardrails claim surfaces.
- Расширение sandbox regression matrix в `test/tool/invariant_coverage_tool_test.dart` под overclaimed guardrails markers.
- Targeted cleanup `tool/invariant_registry.dart`, если точное выравнивание покажет ещё одну переоценённую guardrails-linked binding.

### Not Included in the Change

- Любая новая static-analysis попытка доказывать атомарность коммита, epoch invalidation, copy-on-write, signal ordering или другие runtime semantics через `check_guardrails.dart`.
- Любая смена behavioral semantics самих invariants.
- Любая работа по `tool/check_import_boundaries.dart`, `tool/check_public_api_surface.dart` и их claim surfaces вне guardrails scope этого шага.
- Любая смена CI trigger list, `VERIFICATION.md` или shard composition.

## 3. File Map and Analysis Areas

### Implementation Files

- `tool/check_guardrails.dart`
- `tool/check_invariant_coverage.dart`
- `tool/invariant_registry.dart`

### Test Files

- `test/tool/invariant_coverage_tool_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart`
- `test/tool/guardrails/guardrails_public_surface_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`
- `test/tool/guardrails/guardrails_mutable_type_leaks_tool_test.dart`

### Fixture and Supporting Data Files

- `test/tool/support/tool_process_test_support.dart`
- `test/tool/support/guardrails_tool_test_support.dart`
- `PLAN.md`
- `plan/step_76_guardrails_claim_honesty_and_registry_alignment.md`

### Analysis Area

- `tool/check_guardrails.dart`
- `tool/check_invariant_coverage.dart`
- `tool/invariant_registry.dart`
- `test/tool/invariant_coverage_tool_test.dart`
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

1. Этот шаг закрывает честность текущего guardrails contour, а не добавляет новый guardrail coverage для runtime semantics.
2. `INV-ENG-TXN-ATOMIC-COMMIT`, `INV-ENG-EPOCH-INVALIDATION` и `INV-ENG-NO-EXTERNAL-MUTATION` не становятся guardrails-owned invariants в этом шаге и не должны возвращаться как claims в `check_guardrails.dart`.
3. `INV-G-PUBLIC-ENTRYPOINTS` продолжает быть tool-backed через `tool/check_public_api_surface.dart`, а не через `tool/check_guardrails.dart`.
4. Exact truthful claim set для `tool/check_guardrails.dart` ограничен invariants, у которых `toolProof.enforcementPath == 'tool/check_guardrails.dart'` в registry.
5. Exact truthful claim set для `test/tool/guardrails/**` ограничен invariants, у которых соответствующий файл объявлен как `primaryProof.path` или `toolProof.regressionPath` в registry.
6. Guardrails claim honesty должна механически enforced через `tool/check_invariant_coverage.dart`, а не только через ручную чистку комментариев.

## 5. Result Requirements

1. `tool/check_guardrails.dart` больше не содержит invariant claims, которые не backed current registry tool enforcement mapping.
2. `test/tool/guardrails/**` больше не содержит invariant claims для invariants, которые не declared to that exact file as `primaryProof` or `toolProof.regressionPath`.
3. `dart run tool/check_invariant_coverage.dart` fails on overclaimed explicit guardrails claim markers after declared proof-path and missing-proof diagnostics have already passed.
4. Any remaining guardrails-linked registry bindings are truthful to the actual claim surfaces after the cleanup.
5. The repository no longer presents guardrails as proving commit atomicity, epoch invalidation, or runtime immutability through `check_guardrails.dart`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `tool/check_guardrails.dart` currently declares a wider invariant set than the registry-backed `toolProof` mapping for that tool.
- `test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart`, `test/tool/guardrails/guardrails_public_surface_tool_test.dart`, and `test/tool/guardrails/guardrails_mutable_type_leaks_tool_test.dart` currently carry markers for invariants that are not declared to those files in the registry.
- `tool/check_invariant_coverage.dart` currently validates declared proof surfaces but does not validate that guardrails claim files match the registry-derived expected invariant set exactly or distinguish explicit claim markers from navigation references.
- `tool/invariant_registry.dart` already distinguishes `primaryProof` and `toolProof`, so the expected guardrails claim set can be derived mechanically from the registry instead of being hardcoded twice.

### 6.2 Target Verification Units

- `dart run tool/run_tool_tests.dart test/tool/invariant_coverage_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart test/tool/guardrails/guardrails_public_surface_tool_test.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart test/tool/guardrails/guardrails_contract_architecture_tool_test.dart test/tool/guardrails/guardrails_mutable_type_leaks_tool_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

### 6.3 Protected States, Data, or Structures

- Current invariant ids, scopes, titles, and legitimate `primaryProof` / `toolProof` mappings.
- Current guardrails tool behavior and diagnostics outside claim-marker cleanup.
- Product-test ownership of runtime semantics such as commit atomicity and epoch invalidation.

### 6.4 Allowed Semantic Change Zones

- Guardrails claim-set declaration in `tool/check_guardrails.dart`.
- Explicit guardrails claim-marker placement in `test/tool/guardrails/**`.
- Registry-backed claim-set derivation logic in `tool/check_invariant_coverage.dart`.
- Targeted removal of overestimated guardrails-linked registry mappings if exact alignment reveals one.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- overclaimed explicit line-comment marker in `tool/check_guardrails.dart`;
- overclaimed explicit line-comment marker in `test/tool/guardrails/**/*_test.dart`;
- navigation-only `INV:` reference in a guardrails file;
- missing declared proof file for a guardrails claim surface.

### 6.6 Allowed Forms That Do Not Count as Violations

- Runtime or product tests outside `test/tool/guardrails/**` remaining the authoritative proofs for behavioral invariants.
- Guardrails tool tests carrying more than one explicit claim marker when every claimed invariant is declared to that exact file in the registry.
- Repeated explicit claim-marker occurrences for the same invariant inside one declared guardrails proof file.
- Navigation-only `INV:` references in comments or string literals inside guardrails files when they are not standalone `// INV:<id>` claim markers.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- The expected guardrails claim set must be derived only from `tool/invariant_registry.dart`.
- For `tool/check_guardrails.dart`, the expected invariant set is the set of invariants whose `toolProof.enforcementPath` equals `tool/check_guardrails.dart`.
- For each file under `test/tool/guardrails/**`, the expected invariant set is the union of invariants whose `primaryProof.path` equals that file and invariants whose `toolProof.regressionPath` equals that file.
- Guardrails claim-set comparison must use only standalone line-comment markers of the form `// INV:<id>`.
- Guardrails claim-set comparison must use unique invariant ids per file; repeated explicit claim markers for the same id in the same file do not create a mismatch.
- A marker found in `tool/check_guardrails.dart` or `test/tool/guardrails/**` that is not in that file’s expected set is a claim-honesty failure.
- Missing declared proof files and missing explicit proof markers in declared guardrails surfaces must fail before claim-honesty checks run.

### 6.8 Prohibited

- Reintroducing `INV-ENG-TXN-ATOMIC-COMMIT`, `INV-ENG-EPOCH-INVALIDATION`, or `INV-ENG-NO-EXTERNAL-MUTATION` as guardrails claims to make the contour look broader.
- Adding new static heuristics in `check_guardrails.dart` to “prove” atomic commit behavior in this step.
- Hardcoding the truthful guardrails claim set in two places when it can be derived from the registry.
- Expanding this step into non-guardrails tool claim cleanup for `check_import_boundaries.dart` or `check_public_api_surface.dart`.

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

### Slice 1. [x] Registry-Driven Guardrails Claim Check

#### Slice Contract

`tool/check_invariant_coverage.dart` mechanically validates that `tool/check_guardrails.dart` and `test/tool/guardrails/**` claim exactly the registry-backed invariant set for those files.

#### Change

Добавить в invariant coverage tool derivation expected guardrails claim sets from the registry, считать claim только из standalone `// INV:<id>` markers, и запускать guardrails claim-honesty только после successful declared-proof validation.

#### Verification

- `dart run tool/run_tool_tests.dart test/tool/invariant_coverage_tool_test.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Fixtures Used

- `test/tool/invariant_coverage_tool_test.dart`
- `test/tool/support/tool_process_test_support.dart`

#### Positive Scenarios

- A guardrails enforcement file passes when its claimed invariants exactly match the registry-backed `toolProof.enforcementPath` set.
- A guardrails proof file passes when its standalone `// INV:<id>` claim markers exactly match the union of declared `primaryProof` and `toolProof.regressionPath` entries for that file.
- A guardrails file may contain navigation-only `INV:` references outside standalone claim-marker lines without triggering overclaim failures.

#### Negative Scenarios

- `tool/check_guardrails.dart` claims an invariant whose `toolProof.enforcementPath` points elsewhere or is absent.
- A `test/tool/guardrails/**` file claims an invariant whose declared proof surfaces point to a different file.
- A missing declared guardrails proof file still reports the missing-file proof diagnostic before any claim-honesty failure.

#### Closure Evidence

- Green run of the listed verifications.
- Failure diagnostics from sandbox tests identify overclaimed and missing guardrails claim markers.

### Slice 2. [x] Repository Guardrails Claim Cleanup

#### Slice Contract

The repository’s current guardrails claim files are aligned with the registry-backed truth and no longer overclaim behavioral invariants outside the actual guardrails contour.

#### Change

Почистить завышенные markers в `tool/check_guardrails.dart` и `test/tool/guardrails/**`, затем сделать targeted registry cleanup only if exact alignment reveals one remaining overestimated guardrails-linked proof binding.

#### Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart test/tool/guardrails/guardrails_public_surface_tool_test.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart test/tool/guardrails/guardrails_contract_architecture_tool_test.dart test/tool/guardrails/guardrails_mutable_type_leaks_tool_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Fixtures Used

- `test/tool/support/guardrails_tool_test_support.dart`
- `test/tool/support/tool_process_test_support.dart`

#### Positive Scenarios

- `tool/check_guardrails.dart` claims only its registry-backed enforcement invariants.
- `guardrails_controller_api_tool_test.dart`, `guardrails_interactive_api_tool_test.dart`, `guardrails_model_architecture_tool_test.dart`, and `guardrails_contract_architecture_tool_test.dart` keep their legitimate invariant markers.
- `guardrails_layout_and_entrypoints_tool_test.dart` and `guardrails_public_surface_tool_test.dart` retain only the markers that are actually declared to those files.

#### Negative Scenarios

- Reintroducing `INV-ENG-TXN-ATOMIC-COMMIT` or `INV-ENG-EPOCH-INVALIDATION` into `tool/check_guardrails.dart` fails the new guardrails claim-honesty check.
- Keeping `INV-ENG-NO-EXTERNAL-MUTATION` in `guardrails_mutable_type_leaks_tool_test.dart` fails the new guardrails claim-honesty check if that file remains undeclared for the invariant in the registry.

#### Closure Evidence

- Green run of the listed verifications.
- The repository-wide invariant coverage run passes after the guardrails claim cleanup.

## 9. Final Verification

- `dart run tool/run_tool_tests.dart test/tool/invariant_coverage_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart test/tool/guardrails/guardrails_public_surface_tool_test.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart test/tool/guardrails/guardrails_contract_architecture_tool_test.dart test/tool/guardrails/guardrails_mutable_type_leaks_tool_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
