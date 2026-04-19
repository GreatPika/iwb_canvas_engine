language: english

# Change Contract

## 1. Change Mandate
This change restores the minimal canonical guard-bearing interactive test scaffold in shared tool support and isolates resolved-entrypoint-specific neutral fixtures in a dedicated tool-test suite.

## 2. Change Boundary

### Included in the Change
- `test/tool/support/guardrails_tool_test_support.dart` changes that restore the minimal canonical guard-bearing capability-owner contract used by shared interactive tool suites.
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` changes that keep the general interactive tool suite on shared canonical fixtures only.
- `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart` changes that own the neutral capability shells and the resolved-entrypoint-specific regression cases locally.
- Tool-test additions that make drift back to neutral shared capability owners mechanically visible.

### Not Included in the Change
- Production guardrail logic in `tool/src/guardrails/rules/interactive/**`.
- Runtime behavior in `lib/src/interactive/**`.
- Mutation-owner sequencing migration from step 119.
- Guardrail proof-surface and self-guard work from step 122.

## 3. Surrounding Code Review

### Inspected Artifacts
- `test/tool/support/guardrails_tool_test_support.dart` — current owner of `writeInteractiveArchitectureSupportScaffold(...)`; it now emits neutral `SceneControllerInteractionOwner` and `SceneControllerSelectionOwner` shells while keeping `SceneControllerSceneOwner` minimally canonical.
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` — the broad interactive tool suite still contains step-118 semantic pre-guard cases (`accepts harmless local scaffolding before SceneController purity guard`, `rejects public interactive method when graph interaction happens before guard`, `accepts scene owner purity guard after harmless local scaffolding`, `rejects scene owner delegate call before resolver purity guard`) even though those scenarios are now covered by the dedicated resolved-entrypoint suite.
- `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart` — already owns `_writeNeutralCapabilityOwners(...)`, proving that suite-local neutral fixtures are a viable specialization seam.
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart` — current production guardrail owner; its capability-owner checks still expect canonical guard-bearing public entrypoints for `SceneControllerInteractionOwner`, `SceneControllerSelectionOwner`, and `SceneControllerSceneOwner`.
- `lib/src/interactive/scene_controller_interaction.dart` — real repository owner shape for `SceneControllerInteractionOwner` uses `_access.runtime.ensurePublicSideEffectAllowed(...)` before public mutation/config entrypoints.
- `lib/src/interactive/scene_controller_selection.dart` — real repository owner shape for `SceneControllerSelectionOwner` uses `_runtime.ensurePublicSideEffectAllowed(...)` before public selection entrypoints.
- `lib/src/interactive/scene_controller_scene.dart` — real repository owner shape for `SceneControllerSceneOwner` uses the function-typed `ensurePublicSideEffectAllowed` field before scene mutations.
- `test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart` — existing consumer of `writeInteractiveArchitectureSupportScaffold(...)`; this suite assumes the shared interactive scaffold is a valid canonical default.
- `test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart` — repository precedent for a focused tool-test suite that includes an explicit scaffold-canonicality regression instead of relying on implicit fixture behavior.
- `PLAN.md` — step order is linear and the repository expects a dedicated step document for each execution contract.
- `AGENTS.md` — changed test/tooling work must finish through the required verification preset, and tool tests must run through `dart run tool/run_tool_tests.dart`.

### Current Entry Path
- `createGuardrailsSandbox()` -> `writeInteractiveArchitectureSupportScaffold(...)` -> optional test-local `writeSandboxFile(...)` overrides -> `runSandboxTool(..., 'check_guardrails.dart')`.

### Current Owner
- Shared default interactive sandbox ownership currently sits in `test/tool/support/guardrails_tool_test_support.dart`.
- Resolved-entrypoint-specific specialization already has a local owner in `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`.

### Adjacent Abstractions
- `writeCanonicalPublicExportScaffold(...)` in `test/tool/support/guardrails_tool_test_support.dart` — existing shared canonical scaffold precedent in the same support module.
- `_writeNeutralCapabilityOwners(...)` in `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart` — existing narrow specialization seam that should stay local.
- `writeMinimalControllerStore(...)` in `test/tool/support/guardrails_tool_test_support.dart` — shared low-level sandbox dependency that is neutral and still belongs in support.

### Existing Tests
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` — broad interactive guardrail regression surface.
- `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart` — dedicated resolved-entrypoint regression surface for semantic pre-guard analysis.
- `test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart` — independent suite that uses the shared interactive scaffold and therefore benefits from canonical default owner shapes.

### Analogous Implementation Path
- `test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart` — closest repository precedent for keeping a shared scaffold canonical and adding an explicit regression that proves the shared scaffold still mirrors the intended real shape.

### Governing Repository Rules
- `AGENTS.md` — use the repository wrapper `dart run tool/run_tool_tests.dart` for `test/tool/**`.
- `AGENTS.md` — after code changes, run `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`.
- `PLAN.md` — each execution step must live in its own linked step document.

### Rejected Misleading Local Patterns
- Neutral capability-owner shells inside `writeInteractiveArchitectureSupportScaffold(...)` — wrong owner, because they weaken every suite that relies on the shared default scaffold.
- Moving more specialization into shared support — wrong seam, because resolved-entrypoint fixture neutralization is not a repository-wide default.
- Keeping resolved-entrypoint semantic regressions mixed into `guardrails_interactive_api_tool_test.dart` — wrong level, because the broad suite is supposed to validate canonical interactive guardrails, not opt-in neutralized owner sandboxes.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level
- Tool-test fixture ownership and regression-surface isolation.

#### Selected Architectural Form
- Restore a minimal canonical guard-bearing capability-owner contract in the shared interactive sandbox helper and keep all neutral-owner specialization private to the resolved-entrypoint tool suite.

#### Owning Layer or Module
- Shared canonical fixture ownership: `test/tool/support/guardrails_tool_test_support.dart`.
- Suite-local specialization ownership: `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`.
- Broad canonical regression ownership: `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`.

#### Dependency Direction
- Shared support provides canonical reusable sandbox content to tool suites.
- Focused tool suites may override or supplement the sandbox locally after the shared scaffold is written.
- Shared support must not depend on resolved-entrypoint-specific neutralization rules from any test suite.

#### State and Data Ownership
- Shared support owns only repository-default sandbox files that should be valid for any canonical interactive guardrail consumer.
- Suite-local helpers own opt-in neutral or partial capability-owner files used only for resolved-entrypoint regressions.
- Each test still owns its per-sandbox file overrides and diagnostics.

The shared canonical capability-owner contract is the minimal guard-bearing subset below and no larger production-like scaffold:
- `SceneControllerInteractionOwner` exposes `handlePointer(Object input)`, `handleDoubleTap()`, and `set mode(int value)`; each entrypoint must call `_access.runtime.ensurePublicSideEffectAllowed(...)`.
- `SceneControllerSelectionOwner` exposes `setSelection(Object nodeIds)`, `toggleSelection(Object nodeId)`, `clearSelection()`, `selectAll()`, and `rotateSelection()`; each entrypoint must call `_runtime.ensurePublicSideEffectAllowed(...)`.
- `SceneControllerSceneOwner` exposes `write(Object fn)` and `clearScene()`; each entrypoint must call the function-typed `ensurePublicSideEffectAllowed(...)` field.
- Shared support may include only the minimal helper fields and internal support types needed for those guard-bearing entrypoints to resolve under `check_guardrails.dart`.

#### Entry and Exit Boundaries
- Entry: shared scaffold generation in `writeInteractiveArchitectureSupportScaffold(...)` and suite-local sandbox overrides in the focused tests.
- Exit: `check_guardrails.dart` diagnostics and focused scaffold-canonicality regressions in the affected tool-test suites.

#### Permitted Extension Seam
- Add or adjust private helper functions inside `guardrails_interactive_resolved_entrypoint_guard_tool_test.dart` for neutral capability shells.
- Add explicit canonical-scaffold regression coverage in `guardrails_interactive_api_tool_test.dart`.

#### Rejected Alternatives
- Keep the shared scaffold neutral and rely on specialized suites to cover the missing guard-bearing owners — rejected because other suites already consume the shared scaffold as the default interactive fixture.
- Restore full production-shaped interactive owners in shared support — rejected because this step is about canonical guardrail fixtures for tool tests, not cloning the whole runtime owner surface.
- Introduce a second shared support helper for neutral capability owners — rejected because the neutral form is not a broadly reusable repository default and should stay private to the only suite that needs it.

#### Why This Level Is Correct
- The weakness is in test-fixture ownership, not in production guardrails. Restoring the canonical default in shared support fixes the default once for every consumer, while keeping the resolved-entrypoint suite’s neutralization private preserves isolation without exporting that compromise across unrelated tool suites.

## 5. File Map

### Implementation Files
- `PLAN.md`
- `test/tool/support/guardrails_tool_test_support.dart`

### Test Files
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`

### Analysis Area
- `test/tool/support/**`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`
- `lib/src/interactive/{scene_controller_interaction,scene_controller_selection,scene_controller_scene}.dart`
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart`

### File Rules
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every proposed path must follow the global `File naming`.
- Untied changes are out of scope.

## 6. Locked Decisions

1. `writeInteractiveArchitectureSupportScaffold(...)` must emit guard-bearing canonical default shapes for `SceneControllerInteractionOwner`, `SceneControllerSelectionOwner`, and `SceneControllerSceneOwner`.
2. The shared canonical shape is the minimal subset locked in section 4A `State and Data Ownership`; shared support must not grow to a full production-surface clone in this step.
3. Neutral capability-owner shells remain private to `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`; shared support must not export them.
4. `guardrails_interactive_api_tool_test.dart` must stop owning the four step-118 semantic pre-guard cases named in section 3 `Inspected Artifacts`.
5. Semantic pre-guard coverage belongs only to `guardrails_interactive_resolved_entrypoint_guard_tool_test.dart` through `_registerResolvedRootPreGuardRegressionTests()`, `_registerResolvedCapabilityGuardRegressionTests()`, and `_registerResolvedEntrypointAcceptanceTests()`.
6. The broad interactive API suite must validate canonical interactive scaffolds and adjacent interactive guardrails only.
7. This step changes only test/support ownership and regression coverage; it does not change production guardrail semantics.
8. Verification closes through tool-test execution plus the required verification preset; no ad hoc `dart test` entrypoint is allowed.

## 7. Result Requirements

1. The shared interactive sandbox scaffold mirrors the current canonical capability-owner guard shapes used by the production interactive API.
2. The shared scaffold is limited to the minimal guard-bearing subset locked in section 4A and does not become a full production-surface clone.
3. The general interactive tool suite no longer depends on neutral capability-owner defaults.
4. The resolved-entrypoint suite owns all neutral capability-owner scaffolding and all semantic pre-guard regression scenarios that require it.
5. A mechanical regression fails if the shared interactive scaffold drifts back to neutral capability-owner shells.

## 8. Implementation Rules

### Analysis Scope
- Limit the change to tool-test support and tool-test organization for interactive guardrails.
- Use the current production owner shapes in `lib/src/interactive/**` only as fixture truth, not as a place to implement new behavior.

### Target Verification Units
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`

### Protected States, Data, or Structures
- Canonical shared ownership of interactive guard-bearing capability fixtures.
- Suite-local ownership of neutral capability-owner specializations.
- Existing resolved-entrypoint semantic regression coverage.
- Existing non-resolved interactive guardrail coverage in the broad interactive API suite.

### Allowed Semantic Change Zones
- Shared sandbox fixture content for interactive owners.
- Tool-test case placement between the two interactive guardrail suites.
- Explicit scaffold-canonicality regressions.

### Structural Enforcement
- Add an explicit regression in the broad interactive API suite that proves the shared interactive scaffold still emits guard-bearing capability owners instead of neutral shells.
- Keep neutral capability-owner helpers private to `guardrails_interactive_resolved_entrypoint_guard_tool_test.dart` so their use cannot spread through shared support.
- The broad interactive API suite must not retain the four semantic pre-guard tests named in section 3 once this step closes.

### Required Test Strategy
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`
- A positive shared-scaffold scenario that proves canonical capability-owner fixtures remain accepted by `check_guardrails.dart`.
- A structural scaffold-canonicality regression that fails when the shared scaffold stops emitting guard-bearing capability-owner entrypoints.
- Negative resolved-entrypoint scenarios that continue to require locally neutralized non-target owners.

### Prohibited
- Neutral default capability owners in shared support.
- New shared helpers that export resolved-entrypoint-specific neutralization.
- Production guardrail rule edits in `tool/src/guardrails/rules/interactive/**`.
- Leaving resolved-entrypoint semantic regressions split across both interactive tool suites after this step closes.

## 9. Vertical Slices

### Slice 1. [ ] Shared interactive scaffold is canonical again

#### Slice Contract
`writeInteractiveArchitectureSupportScaffold(...)` emits guard-bearing canonical default capability-owner fixtures, and a dedicated regression makes drift back to neutral shells mechanically visible.

#### Change
- Update `test/tool/support/guardrails_tool_test_support.dart` so the default generated `SceneControllerInteractionOwner`, `SceneControllerSelectionOwner`, and `SceneControllerSceneOwner` exactly match the minimal guard-bearing subset locked in section 4A.
- Add a focused regression in `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` that proves the shared scaffold still generates canonical guard-bearing capability owners rather than empty shells.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- Shared-scaffold acceptance scenario that passes with the canonical default capability owners emitted by `writeInteractiveArchitectureSupportScaffold(...)`.

#### Structural Verification
- The new shared-scaffold regression fails when `SceneControllerInteractionOwner` or `SceneControllerSelectionOwner` drift back to neutral shells in the shared support helper.

#### Positive Scenarios
- A sandbox built from `writeInteractiveArchitectureSupportScaffold(...)` exposes all three capability owners with canonical guard-bearing entrypoints.
- The shared scaffold exposes only the locked minimal public entrypoints and helper seams required for those guard-bearing owners.
- The broad interactive API suite still passes against the shared scaffold without local neutralization.

#### Negative Scenarios
- Replacing the shared interaction owner with `class SceneControllerInteractionOwner {}` fails the scaffold-canonicality regression.
- Replacing the shared selection owner with `class SceneControllerSelectionOwner {}` fails the scaffold-canonicality regression.

#### Closure Evidence
- Green run of the listed behavioral verification.
- Green run of the listed structural verification.
- Shared support no longer contains neutral default capability-owner shells.

### Slice 2. [ ] Resolved-entrypoint regressions own their neutral fixtures locally

#### Slice Contract
All resolved-entrypoint semantic pre-guard regressions live in `guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`, and that suite owns the neutral capability-owner helpers privately.

#### Change
- Remove the four step-118 semantic pre-guard cases from `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`:
- `accepts harmless local scaffolding before SceneController purity guard`
- `rejects public interactive method when graph interaction happens before guard`
- `accepts scene owner purity guard after harmless local scaffolding`
- `rejects scene owner delegate call before resolver purity guard`
- Keep semantic pre-guard ownership in `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart` through `_registerResolvedRootPreGuardRegressionTests()`, `_registerResolvedCapabilityGuardRegressionTests()`, and `_registerResolvedEntrypointAcceptanceTests()`.
- Keep `_writeNeutralCapabilityOwners(...)` and any additional neutral capability-owner helpers private to the resolved-entrypoint suite.
- Remove broad-suite dependencies on neutral capability-owner defaults or resolved-entrypoint-only fixture shapes.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`

#### Structural Verification
- The broad interactive API suite passes using only shared canonical scaffolds, while the resolved-entrypoint suite still passes using its private neutral capability-owner helpers.

#### Positive Scenarios
- Resolved-entrypoint root and capability-owner regressions continue to pass from the dedicated suite after the broad-suite removal.
- The broad interactive API suite remains green without any suite-local neutral capability-owner helper.

#### Negative Scenarios
- None of the four named semantic pre-guard cases remain in the broad interactive API suite.
- Neutral capability-owner helpers are not exported from shared support after the move.

#### Closure Evidence
- Green run of both listed tool-test suites.
- The only neutral capability-owner helper remains private to `guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`.

## 10. Final Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`
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
