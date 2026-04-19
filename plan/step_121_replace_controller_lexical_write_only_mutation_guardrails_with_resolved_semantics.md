language: english

# Change Contract

## 1. Change Mandate
This change replaces controller-layer lexical write-only mutation guardrails with resolved semantic checks and removes name-only false-positive policing.

### Program End State
The end state for steps 119 through 126 is one symmetric guardrail architecture: rule families prove semantics through resolved analysis instead of token/lexical heuristics, repeated proof mechanics live in explicit shared support seams, runner ordering and shared state are declared through one inventory, and tool-test scaffolds plus their verification enforcement use canonical owned support seams.

### This Step's Role in the Chain
This step moves the weak controller write-only family onto the target resolved semantic form and leaves shared proof-support extraction, declarative runner inventory, and normalized tool-test scaffolds to steps 123 through 126.

## 2. Change Boundary

### Included in the Change
- Replacement of lexical/source-body checks in `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart` with resolved semantic checks for canonical selection writer routing, committed read-side surface presence, spatial candidate payload owners, and forbidden controller/render-state surface leaks.
- Removal of the name-prefix mutating-symbol heuristic and the file-cooccurrence `replaceScene` / `controllerEpoch` heuristic.
- Tool-test updates that stop treating mutating-looking names as violations when they do not resolve to a real forbidden controller boundary or mutation sink.
- `doc/guardrails_state_map.md` updates that record the removal of lexical heuristics from this problematic controller rule family.

### Not Included in the Change
- Prepared replace-scene boundary rules in `prepared_replace_boundary_rules.dart`; those already own the strong structural replace-scene surface contract.
- Runtime epoch invalidation behavior; that remains proved by controller runtime tests.
- Interactive rule migration from steps 118 through 120.
- Broader controller architecture changes outside `write_only_mutation_rules.dart`.

## 3. Surrounding Code Review

### Inspected Artifacts
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart` — current owner of `_sceneWriterSelectionBypassViolation(...)`, `_replaceSceneEpochViolation(...)`, `_mutatingSymbolViolation(...)`, `_checkSpatialCandidateHermeticity(...)`, `_controllerFileDeclaresCommittedReadSurface(...)`, and `ControllerSymbolCollector`; current weak parts still use `body.toSource()`, `readAsStringSync().contains(...)`, `toSource()` interface checks, and name-prefix heuristics.
- `tool/src/guardrails/rules/controller/committed_read_side_rules.dart` — closest repository precedent for resolved executable/type analysis over controller surfaces.
- `tool/src/guardrails/rules/public/public_signature_rules.dart` — closest resolved-library precedent for analyzer-backed structural proof instead of source scanning.
- `tool/src/guardrails/rules/controller/prepared_replace_boundary_rules.dart` — already owns strong replace-scene surface checks and already enforces the canonical `writeReplaceScene(...)` / `replaceScene(...)` owner set without lexical heuristics.
- `lib/src/controller/scene_writer_selection.dart` — canonical selection writer helpers route through `writer.runtime.execute(...)` with `ReplaceSelectionOp`, `ToggleSelectionOp`, `ClearSelectionOp`, and `SelectAllSelectionOp`; the weak guard currently checks this only by searching for `workingSelection` / `changeSet` in source text.
- `lib/src/controller/scene_controller_committed_mutation_access.dart` — canonical committed mutation access owner; structural bridge proof already exists and must not be replaced by naming heuristics.
- `lib/src/controller/scene_store_controller.dart` — current owner of `controllerEpoch`, committed read-side helpers, `SceneStoreControllerSpatialAccess`, and single-phase `writeReplaceScene(...)` surface.
- `lib/src/core/scene_spatial_index.dart` — canonical payload owner for `SceneSpatialCandidateLocation`, `SceneSpatialCandidateReference`, `SceneHitTestSpatialCandidate`, and `ScenePaintSpatialCandidate`.
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart` — existing structural regression harness for controller guardrails, including the current false-positive name-prefix expectations and the current weak selection bypass expectation.
- `test/controller/core/scene_controller_commit_effects_test.dart` — runtime proof that `writeReplaceScene(...)` increments `controllerEpoch`, clears selection, and preserves the expected signal contract.
- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart` — runtime proof for committed read-side helper behavior and spatial candidate resolution across `queryHitTestCandidates(...)`, `queryPaintCandidates(...)`, and `resolveSpatialCandidateSnapshot(...)`.
- `doc/guardrails_state_map.md` — records `write_only_mutation_rules.dart` as a hotspot and part of the committed read-side and write-only mutation invariant map.

### Current Entry Path
- `tool/check_guardrails.dart` -> `tool/src/guardrails/guardrails_runner.dart` -> `runControllerApiGuardrails(...)` -> `_checkControllerFile(...)` plus committed-read-side and prepared-replace checks.

### Current Owner
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart`.

### Adjacent Abstractions
- `tool/src/guardrails/rules/controller/prepared_replace_boundary_rules.dart` — strong replace-scene structural owner.
- `tool/src/guardrails/rules/controller/committed_read_side_rules.dart` — strong committed read-side type/surface helper family.

### Existing Tests
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart` — tool-side structural regression surface.
- `test/controller/core/scene_controller_commit_effects_test.dart` — runtime epoch invalidation proof.
- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart` — runtime committed read-side proof.

### Analogous Implementation Path
- `tool/src/guardrails/rules/controller/committed_read_side_rules.dart` — resolved executable/type proof over controller boundaries.
- `tool/src/guardrails/rules/public/public_signature_rules.dart` — resolved-library analysis for structural contracts.

### Governing Repository Rules
- `AGENTS.md` — code changes must end with `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`.
- `AGENTS.md` — runtime tests remain the canonical proof for behavioral invariants; guardrails are structural proof and must not substitute for runtime behavior they do not semantically prove.
- `doc/guardrails_state_map.md` — this rule file is already documented as a hotspot, so the migration must reduce fragility rather than add a second lexical checker.

### Rejected Misleading Local Patterns
- `_looksMutatingSymbol(...)` — wrong seam because it infers architectural violation from spelling rather than from a resolved forbidden boundary or sink.
- `_replaceSceneEpochViolation(...)` — wrong seam because it infers epoch invalidation from file-level `replaceScene` / `controllerEpoch` cooccurrence instead of from canonical owner placement and runtime behavior.
- `readAsStringSync().contains(...)` for committed read-side surface and spatial typedef presence — wrong proof level because it validates source spellings rather than declared payload owners and surface members.
- `type.toSource()` and `interfaces.single.toSource()` checks — wrong seam because they compare printed syntax instead of resolved interface identity.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level
- Structural controller guardrail analysis of explicit controller mutation and read-side surfaces.

#### Selected Architectural Form
- Resolved semantic checks inside `write_only_mutation_rules.dart` for known controller surfaces, combined with deletion of name-only heuristics that do not correspond to a real forbidden owner boundary.

#### Owning Layer or Module
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart`.

#### Dependency Direction
- The rule reads resolved controller/core units through `GuardrailContext`.
- `prepared_replace_boundary_rules.dart` remains an adjacent structural owner and is not weakened or bypassed.
- Runtime controller code stays read-only input.

#### State and Data Ownership
- No runtime state changes.
- Controller guardrail policy for canonical selection write helpers, committed read-side surface presence, spatial candidate payload owners, and render-state/controller surface leaks remains owned by `write_only_mutation_rules.dart`.
- Runtime epoch invalidation stays owned by runtime tests.

#### Entry and Exit Boundaries
- Entry: resolved declarations under `lib/src/controller/**` and `lib/src/core/scene_spatial_index.dart`.
- Exit: `GuardrailViolation` diagnostics from `runControllerApiGuardrails(...)`.

#### Permitted Extension Seam
- Private resolved helper functions inside `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart`.
- Private shared controller-surface, interface-identity, and routing helpers/specs inside `write_only_mutation_rules.dart` when they remove repeated proof shape across more than one migrated check.

#### Rejected Alternatives
- Port the existing name-prefix and file-cooccurrence heuristics to different string lists — rejected because the rule would remain lexical and would keep reinforcing the wrong architectural form.
- Remove the weak controller checks and rely only on runtime tests — rejected because canonical controller surfaces and forbidden render-state leaks still require a structural gate.

#### Why This Level Is Correct
- The weak enforcement already lives in `write_only_mutation_rules.dart`, and the strong neighboring rule families show that the correct repair is semantic analysis in the same owner module. Removing the false-positive name heuristics and replacing the real structural checks with resolved proofs fixes the fragile seam once.

## 5. File Map

### Implementation Files
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart`
- `doc/guardrails_state_map.md`

### Test Files
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`

### Fixtures and Supporting Data
- `test/tool/support/guardrails_tool_test_support.dart`

### Analysis Area
- `lib/src/controller/**`
- `lib/src/core/scene_spatial_index.dart`
- `tool/src/guardrails/rules/controller/**`
- `test/controller/core/{scene_controller_commit_effects,scene_controller_spatial_candidate_resolution}_test.dart`

### File Rules
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Every proposed path must follow the global `File naming`.
- Untied changes are out of scope.

## 6. Locked Decisions

1. `_mutatingSymbolViolation(...)` and `_looksMutatingSymbol(...)` are removed. Name-prefix policing is not reintroduced under another lexical heuristic.
2. `_replaceSceneEpochViolation(...)` is removed. Epoch invalidation remains proved by `test/controller/core/scene_controller_commit_effects_test.dart` and by the existing strong replace-scene boundary rules, not by file-text cooccurrence.
3. `sceneWriterWriteSelectionReplaceResult`, `sceneWriterWriteSelectionToggle`, `sceneWriterWriteSelectionClear`, and `sceneWriterWriteSelectionSelectAllResult` are validated by resolved detection of `writer.runtime.execute(...)` with the expected op constructor targets (`ReplaceSelectionOp`, `ToggleSelectionOp`, `ClearSelectionOp`, and `SelectAllSelectionOp`).
4. Committed read-side surface presence in `scene_store_controller.dart` is determined from resolved public members and extensions, not from raw file text.
5. Spatial candidate payload ownership in `scene_spatial_index.dart` is determined from resolved type aliases and classes, not from `readAsStringSync().contains(...)`.
6. Interface and type checks for `SceneStoreController implements SceneViewRenderState` and `SceneStoreControllerCommittedMutationAccess implements SceneControllerCommittedMutationAccess` must use resolved interface identity, not `toSource()` equality.
7. Controller tool regressions must explicitly allow mutating-looking names that do not resolve to a forbidden controller mutation sink or forbidden public boundary.
8. Where the migrated controller checks share the same proof shape (owner/member surface, interface identity, exact signature, resolved routing), the step must extract one shared local helper/spec in `write_only_mutation_rules.dart` instead of landing separate bespoke scans for each category.
9. This step must not duplicate behavior already structurally owned by `prepared_replace_boundary_rules.dart` or by runtime tests merely to make `write_only_mutation_rules.dart` look self-sufficient.

## 7. Result Requirements

1. `write_only_mutation_rules.dart` no longer uses lexical/source-body heuristics for the migrated controller checks.
2. Canonical selection writer routing, committed read-side surface presence, spatial candidate payload owners, and forbidden render-state/controller interface leaks are validated from resolved semantic information.
3. Unrelated mutating-looking names such as `clearSelectionCache()` or `replaceScene()` no longer fail the controller guardrail solely because of their spelling.
4. Controller tool regressions cover both semantic failures and allowed look-alike names.
5. `doc/guardrails_state_map.md` records the removal of the lexical heuristics from this controller rule family.
6. Repeated controller proof shapes inside the migrated rule are factored into shared local helpers/specs rather than three unrelated mini-checker forms.

## 8. Implementation Rules

### Analysis Scope
- Limit structural repair to the weak checks currently inside `write_only_mutation_rules.dart`.
- Keep `prepared_replace_boundary_rules.dart` as the replace-scene structural owner.
- Keep runtime behavior unchanged.

### Target Verification Units
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/controller/core/scene_controller_commit_effects_test.dart`
- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`

### Protected States, Data, or Structures
- Canonical selection writer op routing.
- Canonical committed read-side helper surface.
- Spatial candidate payload-owner declarations.
- The prohibition on `SceneStoreController` implementing `SceneViewRenderState`.
- Runtime epoch invalidation behavior already proved by controller runtime tests.

### Allowed Semantic Change Zones
- Controller guardrail logic for the migrated checks.
- Controller tool-test scenarios and fixtures.
- Documentation that records the migrated proof surface.
- Shared local helper/spec extraction inside `write_only_mutation_rules.dart` for repeated resolved proof shapes.

### Structural Enforcement
- Resolve library members from analyzer results rather than from raw source scans.
- Resolve constructor targets and `SceneWriterRuntime.execute(...)` invocations for canonical selection writer helpers.
- Resolve interface identity from analyzer elements rather than from `toSource()` output.
- Remove the name-prefix and file-cooccurrence heuristics instead of translating them into new lexical rules.
- Prefer spec-driven owner/member/signature/routing helpers when the same proof shape appears across more than one migrated controller check.

### Required Test Strategy
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `flutter test test/controller/core/scene_controller_commit_effects_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- Negative structural scenarios for wrong selection op routing, missing spatial payload owners, and `SceneStoreController` implementing `SceneViewRenderState`.
- Positive structural scenarios for the current canonical selection writer helpers, the current committed read-side extension surface, and mutating-looking names with no forbidden sink or boundary.

### Prohibited
- Name-prefix mutation heuristics.
- File-level `replaceScene` / `controllerEpoch` cooccurrence checks.
- Raw source scans in the migrated controller rule paths.
- `toSource()` equality for interface or type proof in this rule file.
- Landing separate bespoke controller proof walkers for repeated shapes that can be expressed through one shared local helper/spec.

### Optional: Recognition Forms That Must Be Supported
- `writer.runtime.execute(ReplaceSelectionOp(...))`
- `writer.runtime.execute(ToggleSelectionOp(...))`
- `writer.runtime.execute(const ClearSelectionOp())`
- `writer.runtime.execute(SelectAllSelectionOp(...))`
- `SceneStoreControllerSpatialAccess` as the committed read-side helper owner.
- `SceneSpatialCandidateLocation` and `SceneSpatialCandidateReference` as declared type aliases in `scene_spatial_index.dart`.

### Optional: Allowed Forms That Are Not Violations
- Public or top-level names that begin with `set`, `clear`, `replace`, `remove`, or similar prefixes when they do not resolve to a forbidden controller mutation sink or boundary surface.
- Runtime tests proving epoch invalidation without a lexical guardrail that scans arbitrary `replaceScene` spellings.

### Optional: Resolution Rules
- The selection writer routing check must resolve both the `SceneWriterRuntime.execute(...)` target and the constructor element of the op passed into it.
- The committed read-side surface-presence check must enumerate public members from the resolved `SceneStoreController` class and `SceneStoreControllerSpatialAccess` extension.
- The spatial payload check must resolve type aliases and classes from the `scene_spatial_index.dart` library element.

## 9. Vertical Slices

### Slice 1. [ ] Resolved canonical selection-writer routing

#### Slice Contract
Canonical selection-writer helpers are accepted and rejected from resolved op-routing analysis instead of source-body substring checks.

#### Change
- Replace `_sceneWriterSelectionBypassViolation(...)` with a resolved check that each canonical selection-writer helper invokes `writer.runtime.execute(...)` with the expected op constructor target.
- Keep the current canonical function set unchanged.
- Remove any dependency on `workingSelection` or `changeSet` source-text matching for those functions.
- Reuse the same routing-proof helper shape for every canonical selection writer helper instead of embedding per-helper special logic.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`

#### Structural Verification
- Tool sandbox scenario that fails when a canonical selection-writer helper bypasses the expected op routing.

#### Fixtures Used
- Existing sandbox harness in `test/tool/guardrails/guardrails_controller_api_tool_test.dart`.

#### Positive Scenarios
- The current canonical selection-writer helpers pass with their expected op routing.
- Equivalent constructor argument formatting does not affect the result because the rule resolves constructor targets.

#### Negative Scenarios
- A canonical selection-writer helper that mutates selection state without the expected op routing fails.
- A canonical selection-writer helper that routes through the wrong op type fails.

#### Closure Evidence
- Green run of the listed behavioral verification.
- Green run of the listed structural verification.
- Diagnostics identify the offending helper rather than a body substring.

### Slice 2. [ ] Resolved committed read-side and spatial payload-owner surface checks

#### Slice Contract
Committed read-side surface presence and spatial payload-owner presence are validated from resolved declarations rather than from file text.

#### Change
- Replace `_controllerFileDeclaresCommittedReadSurface(...)` and the lexical spatial-type presence checks with resolved library/member discovery.
- Replace `toSource()`-based interface checks in `ControllerSymbolCollector` with resolved interface identity checks.
- Preserve the existing violation categories and owner files.
- Factor repeated owner/member/signature checks into shared local helper/spec forms rather than separate controller-surface and spatial-surface ad hoc loops.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`

#### Structural Verification
- Tool sandbox scenarios that fail when `SceneStoreController` implements `SceneViewRenderState` or when required spatial payload owners are removed.

#### Fixtures Used
- Existing sandbox harness in `test/tool/guardrails/guardrails_controller_api_tool_test.dart`.

#### Positive Scenarios
- The current committed read-side helper owner surface passes.
- The current spatial payload-owner family passes.

#### Negative Scenarios
- Missing `SceneSpatialCandidateLocation` or `SceneSpatialCandidateReference` declarations fail.
- `SceneStoreController` implementing `SceneViewRenderState` fails.
- `SceneStoreControllerCommittedMutationAccess` implementing the wrong interface identity fails.

#### Closure Evidence
- Green run of the listed behavioral verifications.
- Green run of the listed structural verification.
- Diagnostics identify missing or leaked resolved owners rather than missing source tokens.

### Slice 3. [ ] False-positive lexical heuristics are removed and replaced by semantic regressions

#### Slice Contract
The controller guardrail no longer fails on mutating-looking names alone, and tool regressions prove that only real forbidden sinks or boundary leaks remain violations.

#### Change
- Remove `_mutatingSymbolViolation(...)`, `_looksMutatingSymbol(...)`, and `_replaceSceneEpochViolation(...)` from `write_only_mutation_rules.dart`.
- Update `test/tool/guardrails/guardrails_controller_api_tool_test.dart` so mutating-looking names with no forbidden sink or boundary are accepted.
- Keep runtime epoch invalidation proof in `scene_controller_commit_effects_test.dart` as the behavioral owner for `controllerEpoch` behavior.
- Update `doc/guardrails_state_map.md` to record that the lexical heuristics were removed.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `flutter test test/controller/core/scene_controller_commit_effects_test.dart`

#### Structural Verification
- Tool sandbox scenarios that accept a mutating-looking name with no forbidden sink and still fail a real forbidden boundary leak.

#### Fixtures Used
- Existing sandbox harness in `test/tool/guardrails/guardrails_controller_api_tool_test.dart`.

#### Positive Scenarios
- `clearSelectionCache()` with no forbidden sink or boundary passes.
- An unrelated `replaceScene()` spelling with no forbidden sink or boundary passes.
- Runtime epoch invalidation proof remains green.

#### Negative Scenarios
- A real forbidden controller/render-state leak still fails.
- A real canonical selection writer bypass still fails.
- Documentation does not claim that name-prefix policing still exists.

#### Closure Evidence
- Green run of the listed behavioral verifications.
- Green run of the listed structural verification.
- Controller tool diagnostics no longer report violations based solely on mutating-looking names.

## 10. Final Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `flutter test test/controller/core/scene_controller_commit_effects_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`

## 11. Acceptance Criteria

- The change mandate is satisfied.
- The surrounding code review records actual repository evidence.
- The architectural form is explicit, justified, and locked at the correct level.
- No material architectural choice remains to the implementing agent.
- Result requirements are satisfied.
- Implementation rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
