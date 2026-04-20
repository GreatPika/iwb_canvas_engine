# Guardrails State Map

Generated: 2026-04-21
Scope: `tool/src/guardrails/**`

## Current Layout

```text
tool/src/guardrails/
  core/
    element_violation_builder.dart
    guardrail_rule.dart
    guardrail_run_state.dart
    guardrail_violation.dart
    guardrail_rule_metadata.dart
    guardrail_runner_support.dart
    guardrail_element_utils.dart
    resolved_surface_contract_support.dart
    semantic_sequence_routing_support.dart
    resolved_type_leak_traversal.dart
    signature_leak_support.dart
  rules/
    public/
      public_surface_rules.dart
      public_signature_rules.dart
      entrypoint_layout_rules.dart
    controller/
      write_only_mutation_rules.dart
      prepared_replace_boundary_rules.dart
      committed_read_side_rules.dart
      view_render_state_boundary_rules.dart
    interactive/
      mutation_boundary_rules.dart
      interactive_architecture_boundary_rules.dart
      interactive_mutation_owner_guard_rules.dart
      committed_read_callback_rules.dart
    model/
      model_architecture_rules.dart
      runtime_owner_rules.dart
    contract/
      contract_architecture_rules.dart
  support/
    guardrail_ast_utils.dart
    guardrail_context.dart
    guardrail_path_utils.dart
  guardrail_rule_inventory.dart
  guardrails_runner.dart
```

## Snapshot (Fresh Scan)

- Files scanned: **51**
- Total LOC: **12782**
- Largest files:
  - `rules/controller/write_only_mutation_rules.dart`: **1432**
  - `rules/public/public_surface_rules.dart`: **1071**
  - `rules/controller/prepared_replace_boundary_rules.dart`: **865**
  - `rules/public/public_signature_rules.dart`: **708**
  - `rules/interactive/interactive_mutation_owner_guard_rules.dart`: **557**

Source commands:
- `dart run tool/analysis/find_similar_clones.dart --clusters --top 40 tool/src/guardrails`
- `dcm calculate-metrics --report-all tool/src/guardrails`

## Invariant-to-Rule Map

- `INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY` -> `contract-architecture`
- `INV-ENG-COMMITTED-READ-SIDE-HERMETICITY` -> `controller-api`, `interactive-api`
- `INV-ENG-CONTROLLER-NO-FULL-VIEW-RENDER-STATE` -> `controller-api`
- `INV-ENG-INTERACTIVE-MUTATION-BOUNDARY` -> `interactive-api`
- `INV-ENG-INTERACTIVE-RESOLVER-PURITY` -> `interactive-api`
- `INV-ENG-MODEL-ARCHITECTURE-BOUNDARY` -> `model-architecture`
- `INV-ENG-PREPARED-REPLACE-SCENE-BOUNDARY-HERMETICITY` -> `controller-api`, `interactive-api`
- `INV-ENG-PUBLIC-SIGNATURE-HERMETICITY` -> `public-signature`
- `INV-ENG-PUBLIC-SURFACE-NO-MUTABLE-TYPES` -> `public-signature`, `public-surface`
- `INV-ENG-RUNTIME-NODE-VALUE-OWNERS` -> `model-architecture`
- `INV-ENG-RUNTIME-SCENE-STRUCTURE-OWNER` -> `model-architecture`
- `INV-ENG-SAFE-TXN-API` -> `public-surface`
- `INV-ENG-WRITE-ONLY-MUTATION` -> `controller-api`

Controller note:
- `rules/controller/write_only_mutation_rules.dart` no longer uses name-prefix or `replaceScene`/`controllerEpoch` lexical heuristics; the active proof surface is resolved selection-op routing, resolved committed-read owner/member discovery, resolved spatial payload-owner discovery, and resolved render-state leak detection.

Proof ownership note:
- `INV-ENG-INTERACTIVE-RESOLVER-PURITY` now keeps its runtime primary proof in `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`.
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` remains the tool-side regression proof for `tool/check_guardrails.dart`, not the runtime primary proof.

## Declarative Runner Inventory

- `public-surface` | area=`public` | file=`rules/public/public_surface_rules.dart` | invariants=`INV-ENG-SAFE-TXN-API, INV-ENG-PUBLIC-SURFACE-NO-MUTABLE-TYPES` | reads=`none` | writes=`exportedSurfaces`
- `public-signature` | area=`public` | file=`rules/public/public_signature_rules.dart` | invariants=`INV-ENG-PUBLIC-SURFACE-NO-MUTABLE-TYPES, INV-ENG-PUBLIC-SIGNATURE-HERMETICITY` | reads=`exportedSurfaces` | writes=`none`
- `interactive-api` | area=`interactive` | file=`rules/interactive/mutation_boundary_rules.dart` | invariants=`INV-ENG-INTERACTIVE-RESOLVER-PURITY, INV-ENG-INTERACTIVE-MUTATION-BOUNDARY, INV-ENG-COMMITTED-READ-SIDE-HERMETICITY, INV-ENG-PREPARED-REPLACE-SCENE-BOUNDARY-HERMETICITY` | reads=`none` | writes=`none`
- `controller-api` | area=`controller` | file=`rules/controller/write_only_mutation_rules.dart` | invariants=`INV-ENG-WRITE-ONLY-MUTATION, INV-ENG-CONTROLLER-NO-FULL-VIEW-RENDER-STATE, INV-ENG-COMMITTED-READ-SIDE-HERMETICITY, INV-ENG-PREPARED-REPLACE-SCENE-BOUNDARY-HERMETICITY` | reads=`none` | writes=`none`
- `model-architecture` | area=`model` | file=`rules/model/model_architecture_rules.dart` | invariants=`INV-ENG-MODEL-ARCHITECTURE-BOUNDARY, INV-ENG-RUNTIME-SCENE-STRUCTURE-OWNER, INV-ENG-RUNTIME-NODE-VALUE-OWNERS` | reads=`none` | writes=`none`
- `contract-architecture` | area=`contract` | file=`rules/contract/contract_architecture_rules.dart` | invariants=`INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY` | reads=`none` | writes=`none`

## Explicit Module Coverage (Completeness)

The following modules are present in the tree and now explicitly tracked here,
even if they are utility/thin wrappers and not primary invariant owners:

- `core/guardrail_element_utils.dart` (shared element-order/name/constructor/path helpers)
- `core/guardrail_rule.dart` (rule metadata contract type)
- `core/guardrail_rule_metadata.dart` (rule metadata value object)
- `core/guardrail_runner_support.dart` (shared parse/scan/fail-fast support)
- `core/guardrail_violation.dart` (violation/tool failure primitives)
- `core/element_violation_builder.dart` (shared element-backed violation construction)
- `core/resolved_surface_contract_support.dart` (shared resolved surface-contract validation for top-level/member/constructor/interface/signature proof)
- `core/semantic_sequence_routing_support.dart` (shared semantic sequence, prelude, and direct invocation-routing proof)
- `core/resolved_type_leak_traversal.dart` (shared recursive resolved-type traversal)
- `core/signature_leak_support.dart` (shared signature leak detection helpers)
- `rules/public/entrypoint_layout_rules.dart` (layout-check adapter to `layer_guardrails`)
- `rules/controller/view_render_state_boundary_rules.dart` (view/render-state boundary constants)
- `rules/interactive/interactive_architecture_boundary_rules.dart` (interactive architecture family entrypoint/orchestration)
- `rules/interactive/resolved_entrypoint_guard_rules.dart` (resolved entrypoint purity checks)
- `rules/model/runtime_owner_rules.dart` (runtime-owner scope model)
- `support/guardrail_ast_utils.dart` (AST directive parsing and offsets)
- `support/guardrail_context.dart` (analysis context/cache access)
- `support/guardrail_path_utils.dart` (path normalization and repo-rel resolution)

## Clone Clusters (Top Risk)

1. Public signature family still contains the largest semantic-overlap cluster:
- `rules/public/public_signature_rules.dart`
- `rules/controller/committed_read_side_rules.dart`
- plus shared support in `core/resolved_type_leak_traversal.dart`
- plus shared support in `core/signature_leak_support.dart`

2. Prepared-replace boundary checks are still triple-shaped structural siblings in:
- `_checkCommittedMutationAccessPreparedReplaceBoundary`
- `_checkSceneStorePreparedReplaceBoundary`
- `_checkSceneWriterPreparedReplaceBoundary`
(all in `rules/controller/prepared_replace_boundary_rules.dart`)

3. Interactive mutation family now routes repeated prelude/order/routing mechanics through:
- `core/semantic_sequence_routing_support.dart`
- local interactive policy classifiers still live in `rules/interactive/interactive_mutation_owner_guard_rules.dart`
- controller selection-writer routing also consumes the same shared invocation-routing seam

4. Contract/model architecture families now share common support, but top-level runners still mirror each other:
- `runContractArchitectureGuardrails`
- `runModelArchitectureGuardrails`

5. Resolved surface-contract and semantic sequence/routing mechanics now
converge through `core/resolved_surface_contract_support.dart` and
`core/semantic_sequence_routing_support.dart`, while interactive architecture
still keeps family-local structural proof around its remaining semantic checks.

## Metrics Hotspots (HIGH/VERY HIGH counts)

- `rules/controller/prepared_replace_boundary_rules.dart`: **13**
- `rules/controller/write_only_mutation_rules.dart`: **8**
- `rules/public/public_signature_rules.dart`: **7**
- `rules/interactive/interactive_architecture_boundary_flow_support.dart`: **6**
- `rules/interactive/mutation_boundary_rules.dart`: **4**
- `core/resolved_type_leak_traversal.dart`: **4**
- `core/guardrail_runner_support.dart`: **3**
- `rules/interactive/interactive_architecture_boundary_matcher_support.dart`: **3**

Notable very-high functions:
- `rules/controller/write_only_mutation_rules.dart`:
  - `_checkControllerReadHelperHermeticity`
- `rules/controller/prepared_replace_boundary_rules.dart`:
  - `_checkSceneStorePreparedReplaceBoundary`
  - `_checkCommittedMutationAccessPreparedReplaceBoundary`
- `rules/public/public_signature_rules.dart`:
  - `_findLeakInType`
- `rules/interactive/interactive_architecture_boundary_flow_support.dart`:
  - `_collectInvocationTargetsWithinFunctionBody`
- `core/resolved_type_leak_traversal.dart`:
  - `findFirstResolvedTypeLeak`

## Reliability Buckets

- **High reliability (resolved AST dominant)**
  - `rules/public/public_signature_rules.dart`
  - `rules/controller/committed_read_side_rules.dart`

- **Medium reliability (parsed AST + path constraints)**
  - `rules/model/model_architecture_rules.dart`
  - `rules/contract/contract_architecture_rules.dart`
  - `rules/public/public_surface_rules.dart`

- **Mixed reliability**
  - `rules/interactive/mutation_boundary_rules.dart`
    - runner wiring plus committed-read callback checks delegate into resolved support families
  - `rules/interactive/interactive_architecture_boundary_rules.dart`
    - architecture-boundary enforcement now lives in semantic category-scoped parts
    - deleted seams are still checked as explicit file-absence facts, not as source tokens
  - `rules/interactive/interactive_mutation_owner_guard_rules.dart`
    - mutation-owner enforcement now classifies local policy into the shared semantic sequence/routing seam
    - `setCameraOffset(...)` and `replaceScene(...)` remain narrow special-form validators

- **Retired token/source-order seams**
  - `rules/interactive/boundary_shape_token_rules.dart` (deleted in step 120)
  - `rules/interactive/resolver_purity_rules.dart` (deleted in step 120)

## 6-Step Plan Status

1. **Fix map of rules**: **DONE**
- Invariant coverage, ownership map, clone and metrics refresh are recorded in this file.

2. **Split monoliths without behavior changes**: **DONE (first major cut)**
- Rule layout is now separated by domains under `rules/*`.
- Shared primitives/support moved to `core/` + `support/`.

3. **Remove explicit clones and repeated templates**: **IN PROGRESS**
- Removed in this pass:
  - shared resolved-type traversal
  - shared signature leak helpers
  - shared element-backed violation builder
  - shared resolved surface-contract validator
  - shared semantic sequence/routing validator
  - shared architecture-file parse/part/directive helpers
- Clone clusters reduced from **19 -> 8** across the current refactor campaign.
- Major remaining clones are now structural siblings, not broad copy-paste utility duplication.

4. **Migrate fragile token checks to AST/resolved**: **STEP-120 DONE FOR INTERACTIVE FAMILY**
- Mutation-owner guardrails now use resolved sequence/routing proof.
- Entrypoint purity, mutation-owner ordering, and controller selection routing now share the same core sequence/routing seam.
- Interactive architecture-boundary guardrails now use semantic category-scoped analysis via `interactive_architecture_boundary_rules.dart`.
- The legacy `boundary_shape_token_rules.dart` and `resolver_purity_rules.dart` helpers are retired.

5. **Decide what to merge/delete**: **NOT STARTED**
- Decision postponed until step 3 and step 4 reduce accidental overlap.

6. **Meta-control for guardrails itself**: **TARGETED SELF-GUARD ACTIVE**
- `test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart` now protects the migrated weak rule owners from steps 118 through 121 plus the retained interactive host file against reintroducing `readAsStringSync`, `toSource()`, `requireSourceTokens`, `requireTokenOrder`, or `resolver_purity_rules.dart`.
- This is intentionally narrower than repository-wide clone/metrics governance; broader guardrails meta-control is still outstanding.

## Next Cutting Queue (Recommended)

1. Extract shared resolved-type traversal engine for:
   Status: **DONE**

2. Template the prepared-replace boundary checks into one parameterized checker:
   Status: **PARTIAL**
   - common owner/surface/signature scaffolding already extracted
   - remaining duplication is mostly file-specific policy logic

3. Collapse duplicate violation builders into a shared helper module.
   Status: **DONE**

4. Continue AST migration of remaining non-interactive token-heavy rules.
   Status: **NEXT**
   - interactive architecture, mutation-owner families, and controller write-only mutation enforcement are already on resolved/semantic proof
   - resolved guardrail proof-surface ownership and targeted self-guard follow-up are now closed by Step 122
   - next remaining focus is shared proof-support extraction and runner/scaffold consolidation in steps 123 through 126

## Verification Snapshot

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart` -> passed
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart` -> passed
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart` -> passed
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=/tmp/step120_changed_paths.txt` -> passed
