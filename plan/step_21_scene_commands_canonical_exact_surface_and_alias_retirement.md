# Change Contract

## 1. Change Mandate

Retire the redundant convenience alias methods on `SceneCommands`, make the
exact-result / exact-change methods the only canonical surface for those
operations, and lock that narrower form with tests and tool fixtures without
changing command behavior or widening the cleanup into other controller
forwarders.

## 2. Change Boundary

### Included in the Change

- retire the redundant `SceneCommands` convenience alias methods that only
  forward into exact-result / exact-change variants:
  `writeSelectionReplace`,
  `writeSelectionToggle`,
  `writeSelectionClear`,
  `writeSelectionSelectAll`,
  `writeBackgroundColorSet`,
  `writeGridEnabledSet`,
  `writeGridCellSizeSet`, and
  `writeCameraOffsetSet`
- migrate in-scope controller command tests to the canonical
  `ExactResult` / `ExactChange` methods
- migrate in-scope interactive negative guardrail fixtures to the same
  canonical method names so tool tests describe the checked-in command-owner
  surface accurately
- add explicit structural proof that `SceneCommands` keeps the canonical exact
  surface and does not reintroduce the retired alias declarations
- add this step to `PLAN.md` and update both files together when the step
  closes

### Not Included in the Change

- no change to `SceneWriter`, `SceneWriteTxn`, or
  `SceneWriteTxnPublicAdapter`
- no change to `DrawCommands` or `MoveCommands`
- no change to `SceneStoreControllerCommittedMutationAccess` production
  behavior or public method surface
- no change to target-architecture family docs, owner-map status, or
  controller/interactive architecture boundaries
- no cleanup of other controller forwarders outside `SceneCommands`
- no public API, schema, barrel-export, or supported import-surface change

## 3. Surrounding Code Review

### Inspected Artifacts

- `PLAN.md` - step 20 closes the last target-architecture family, so any
  follow-up here must be an optional local cleanup step rather than a new
  architecture-family cut
- `lib/src/controller/commands/scene_commands.dart` - the checked-in owner
  already exposes exact-result / exact-change methods for selection and scene
  metadata writes, but it still keeps eight convenience aliases that only
  forward into those exact variants with no local logic
- `dart run tool/lsp_find_thin_wrappers.dart lib/src/controller/commands/scene_commands.dart --classification=pure-forwarder`
  - confirms seven of those alias methods as pure forwarders; targeted code
  reading of `writeSelectionClear()` shows the same form even though the tool
  did not classify that single method
- `dcm calculate-metrics lib/src/controller/commands/scene_commands.dart --reporter=console`
  - `SceneCommands` remains locally hot after step 20:
  `25 methods`, `response set 44`, and `weighted complexity 39`
- `lib/src/controller/commands/draw_commands.dart` - adjacent command owner
  that keeps one canonical method per behavior and does not duplicate exact /
  convenience shells
- `lib/src/controller/commands/move_commands.dart` - adjacent command owner
  with the same narrow single-surface form
- `lib/src/controller/scene_controller_committed_mutation_access.dart` -
  production committed mutation routing already uses the canonical
  `SceneCommands` exact methods:
  `writeSelectionReplaceExactResult`,
  `writeSelectionToggleExactChange`,
  `writeSelectionClearExactChange`,
  `writeSelectionSelectAllExactResult`,
  `writeBackgroundColorSetExactChange`,
  `writeGridEnabledSetExactChange`,
  `writeGridCellSizeSetExactChange`, and
  `writeCameraOffsetSetExactChange`
- `rg -n "writeSelectionReplace\\(|writeSelectionToggle\\(|writeSelectionSelectAll\\(|writeBackgroundColorSet\\(|writeGridEnabledSet\\(|writeGridCellSizeSet\\(|writeCameraOffsetSet\\(" lib/src test tool`
  - confirms the convenience alias methods are now consumed only by tests and
  tool fixtures, not by live production command routing
- `rg -n "writeSelectionClear\\(" lib/src test tool`
  - confirms `writeSelectionClear()` is also only retained in tests / fixtures
  plus the `SceneCommands` declaration itself; production mutation routing uses
  `writeSelectionClearExactChange`
- `rg -n "export .*scene_commands|SceneCommands" lib API_GUIDE.md README.md ARCHITECTURE.md CHANGELOG.md`
  - shows `SceneCommands` is not part of the supported package surface or
  user-facing docs
- `test/controller/commands/scene_commands_test.dart` - the main behavioral
  characterization suite for `SceneCommands`; it currently uses the retiring
  alias methods heavily
- `test/controller/commands/move_commands_test.dart` - depends on
  `SceneCommands.writeSelectionReplace(...)` to prepare move-command selection
- `test/controller/commands/draw_commands_test.dart` - adjacent command-owner
  regression coverage that does not use any retiring alias methods and is
  therefore outside the migration scope for this step
- `test/controller/core/scene_controller_commit_effects_test.dart` - still
  contains a live `SceneCommands.writeSelectionSelectAll(...)` consumer
- `test/tool/guardrails/interactive_api/architecture_boundary/runtime_and_draw_ownership_cases.dart`
  and
  `test/tool/guardrails/interactive_api/architecture_boundary/facade_and_boundary_cases.dart`
  - negative guardrail fixtures still model the old convenience names via
  `_sceneCommands.writeSelectionReplace(...)` and `_sceneCommands.writeSelectionClear(...)`
- `test/controller/internal/scene_writer_test.dart` - existing repository
  precedent for source-based structural locking of a controller owner surface

### Current Entry Path

- production scene/selection metadata writes:
  `SceneStoreControllerCommittedMutationAccess` ->
  canonical `SceneCommands` exact methods ->
  `SceneWriter` / `sceneWriterWrite*`
- test and tool-fixture consumers:
  controller command tests or interactive negative fixtures ->
  retiring `SceneCommands` convenience aliases ->
  canonical exact methods

### Current Owner

- the duplicate API surface is owned locally by `SceneCommands` inside
  `lib/src/controller/commands`

### Adjacent Abstractions

- `lib/src/controller/commands/draw_commands.dart` - neighboring command owner
  with one canonical method per behavior
- `lib/src/controller/commands/move_commands.dart` - neighboring command owner
  with one canonical method per behavior
- `lib/src/controller/scene_controller_committed_mutation_access.dart` -
  production adapter that already consumes the canonical exact methods
- `lib/src/controller/scene_writer.dart` - lower-level write owner that must
  remain untouched in this step
- `lib/src/controller/scene_write_txn_public_adapter.dart` - public txn adapter
  that uses writer-owned method names, not `SceneCommands` aliases

### Existing Tests

- `test/controller/commands/scene_commands_test.dart` - characterizes command
  behavior, signals, invariants, and exact-result semantics around
  `SceneCommands`
- `test/controller/commands/move_commands_test.dart` - guards selection setup
  for `MoveCommands`
- `test/controller/commands/draw_commands_test.dart` - adjacent command-owner
  regression coverage next to `SceneCommands`; it remains out of migration
  scope because it does not exercise the retiring alias surface
- `test/controller/core/scene_controller_commit_effects_test.dart` - guards
  selection-side effects and committed change-set behavior while currently using
  one retiring alias
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` - executes
  the interactive negative fixtures that currently model the old convenience
  names
- `test/controller/internal/scene_writer_test.dart` - precedent for a
  controller-layer source-lock test that keeps a narrow owner surface from
  regressing

### Analogous Implementation Path

- `lib/src/controller/commands/draw_commands.dart` and
  `lib/src/controller/commands/move_commands.dart` - the closest checked-in
  precedent for the desired local form: one command-owner method surface per
  behavior, not a duplicate exact-vs-convenience shell pair

### Governing Repository Rules

- `AGENTS.md` - prefer the smallest owner-side change that removes duplication
  instead of widening the cleanup into adjacent abstractions
- `AGENTS.md` - recurring boundary or shape constraints should be locked in
  repository-local tests or tooling, not left only in prose
- `AGENTS.md` / project verification instructions - final verification must use
  `dart run tool/run_verification_preset.dart run --preset=required_code_change`
  rather than plain `dart test`

### Rejected Misleading Local Patterns

- broaden this into `SceneWriter` / `SceneWriteTxnPublicAdapter` cleanup -
  wrong owner because this step is only about duplicate API on `SceneCommands`
- remove the canonical exact methods and keep the convenience aliases -
  wrong direction because production routing already uses the exact forms
- touch `DrawCommands` or `MoveCommands` in the same step - wrong scope because
  those owners already read coherently and are the precedent, not the problem
- keep both names indefinitely and only migrate tests - wrong result because
  the duplicate surface would remain on the checked-in owner
- treat `writeDeleteSelection()` or `writeClearScene()` as equivalent retire
  candidates - wrong grouping because those methods intentionally convert
  structured results into scalar outputs and are not pure aliases

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- one local controller-command cleanup inside the already accepted controller
  layer

#### Selected Architectural Form

- `SceneCommands` remains the owner for scene / selection / scene-metadata
  command orchestration over a write runner
- the canonical surface for the duplicate operations is the existing exact
  method family:
  `writeSelectionReplaceExactResult`,
  `writeSelectionToggleExactChange`,
  `writeSelectionClearExactChange`,
  `writeSelectionSelectAllExactResult`,
  `writeBackgroundColorSetExactChange`,
  `writeGridEnabledSetExactChange`,
  `writeGridCellSizeSetExactChange`, and
  `writeCameraOffsetSetExactChange`
- the redundant convenience aliases for those same operations retire from
  `SceneCommands`
- in-scope tests and tool fixtures adopt the canonical exact names directly
  instead of relying on convenience alias shells
- a focused source-lock test becomes the structural proof that
  `SceneCommands` keeps the canonical exact surface and does not reintroduce
  the retired alias declarations

#### Owning Layer or Module

- production ownership stays in `lib/src/controller/commands/scene_commands.dart`
- no responsibility moves into writer, txn, interactive, or public contract
  layers

#### Dependency Direction

- production adapter path stays:
  `SceneStoreControllerCommittedMutationAccess` ->
  `SceneCommands` exact methods ->
  `SceneWriter`
- test and tool-fixture consumers move directly onto the same canonical exact
  methods
- the new structural proof depends only on source inspection of the
  `SceneCommands` owner file; it does not create a new production dependency

#### State and Data Ownership

- `SceneCommands` remains stateless over its `SceneCommandRunner`
- write state stays owned by `SceneWriter` / transactional runtime
- no result payload ownership changes; only duplicate method entrypoints retire

#### Entry and Exit Boundaries

- production command entry remains `SceneCommands`
- exact result / exact change methods remain the retained entrypoints for the
  retired operations
- command outputs and signal semantics remain unchanged

#### Permitted Extension Seam

- one new focused structural test file for the `SceneCommands` source surface
  is allowed
- test helper rewrites and interactive negative-fixture rewrites are allowed
  only to adopt the retained exact method names
- no new production wrappers, adapters, or helper bags are permitted

#### Rejected Alternatives

- keep the duplicate alias surface and only document the preferred names -
  wrong because it does not remove the local owner duplication
- move exact semantics into `SceneWriter` and collapse `SceneCommands` itself -
  wrong owner because the command owner still owns signal orchestration and is
  not the same abstraction as writer-local mutation primitives
- make `SceneStoreControllerCommittedMutationAccess` hide the duplicate names
  while leaving them on `SceneCommands` - wrong level because the duplicate
  surface lives on `SceneCommands`, not on the adapter
- remove adjacent non-duplicate methods such as `writeDeleteSelection()` or
  `writeClearScene()` in the same step - wrong scope because they are not pure
  aliases and would change the cleanup shape materially

#### Why This Level Is Correct

- the duplicate API is owned entirely by one local class
- production routing already uses the retained exact methods, which makes the
- smallest safe cut an owner-local surface cleanup plus consumer migration
- adjacent command owners already demonstrate the desired one-method-per-
  behavior form
- the remaining consumers are tests and tool fixtures, so the step can lock the
  narrowed form with repository-local proof without touching public behavior

## 5. Locked Decisions

1. `writeSelectionClear()` retires together with the seven tool-flagged alias
   methods because targeted code review confirms it is the same convenience
   shell shape over `writeSelectionClearExactChange()`.
2. `writeDeleteSelection()` and `writeClearScene()` remain in place because
   they intentionally convert structured results into scalar outputs and are
   not pure aliases.
3. `SceneStoreControllerCommittedMutationAccess` stays unchanged in production;
   its checked-in exact-method usage is evidence that the canonical surface is
   already viable.
4. Interactive negative fixtures must migrate to the canonical exact names in
   the same step so tool tests describe the checked-in command-owner surface
   accurately instead of preserving stale convenience names.
5. The structural proof for final retirement is a dedicated `SceneCommands`
   source-lock test, not a new guardrail rule or a widened architecture-family
   document.

## 6. Result Requirements

1. `SceneCommands` no longer declares the eight retired convenience alias
   methods.
2. The exact-result / exact-change methods remain the only retained command
   entrypoints for selection replace/toggle/clear/select-all and for background
   / grid / camera updates.
3. No in-scope controller command tests or interactive negative guardrail
   fixtures still call the retired alias names.
4. `SceneCommands` keeps the existing behavior and signal semantics for the
   retained operations and non-duplicate methods.
5. A repository-local structural test fails if the retired alias declarations
   reappear or if the retained exact methods disappear.

## 7. Execution Order and Gates

### Required Order

- adopt the canonical exact methods in in-scope tests and interactive negative
  fixtures before retiring the alias declarations from `SceneCommands`
- land the structural source-lock proof no later than the slice that removes
  the alias declarations
- reserve broad final verification for the end; do not run the full preset
  after every preparatory edit

### Successor Seam and Retirement Gates

- the successor seam is the existing exact-result / exact-change method family
  on `SceneCommands`
- the alias declarations may retire only after:
  `test/controller/commands/scene_commands_test.dart`,
  `test/controller/commands/move_commands_test.dart`,
  `test/controller/core/scene_controller_commit_effects_test.dart`, and the
  interactive negative guardrail fixture files no longer call the retired
  names
- the cleanup is not closed until the new structural source-lock test proves
  that the alias declarations stay absent from `scene_commands.dart`

### Deferred Broad Verification

- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`
  - reserve for the final gate after all slices land
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
  - reserve as the final broad rerun after the negative-fixture migration and
  alias retirement are both complete

## 8. File Map

### Implementation Files

- `PLAN.md`
- `plan/step_21_scene_commands_canonical_exact_surface_and_alias_retirement.md`
- `lib/src/controller/commands/scene_commands.dart`

### Test Files

- `test/controller/commands/scene_commands_test.dart`
- `test/controller/commands/move_commands_test.dart`
- `test/controller/commands/scene_commands_surface_test.dart`
- `test/controller/core/scene_controller_commit_effects_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/runtime_and_draw_ownership_cases.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/facade_and_boundary_cases.dart`

### Fixtures and Supporting Data

- none

### Registry, Inventory, and Workflow Files

- none

### Analysis Area

- `lib/src/controller/commands/scene_commands.dart`
- `test/controller/commands/**`
- `test/controller/core/scene_controller_commit_effects_test.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/**`

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-TXN-ATOMIC-COMMIT`
- `INV-ENG-SIGNALS-AFTER-COMMIT`

### Required Proof

- behavioral proof:
  `SceneCommands`, `MoveCommands`, and committed effect tests must stay green
  after consumer migration and alias retirement
- structural proof:
  the repository must gain an executable source-lock test that fails if
  `scene_commands.dart` reintroduces the retired alias declarations or loses
  the retained exact methods
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract
- for refactors: existing locking tests must be named or missing
  characterization tests must be added before structural edits, plus 1 to 3
  guard tests for neighboring branches when needed

### Allowed Change Surface

- only `scene_commands.dart` and the tests / tool fixtures listed in section 8
- one new focused source-lock test file is allowed
- fixture-method signature changes are allowed only when they are needed to
  adopt the retained exact methods

### Forbidden Moves

- do not change `SceneWriter`, `SceneWriteTxnPublicAdapter`,
  `SceneStoreControllerCommittedMutationAccess`, `DrawCommands`, or
  `MoveCommands` production files in this step
- do not retire `writeDeleteSelection()` or `writeClearScene()` in this step
- do not change command signal types, payload semantics, or transaction
  behavior while removing aliases
- do not widen this cleanup into a generic controller-forwarder sweep

## 10. Vertical Slices

### Slice 1. [ ] Adopt Canonical Exact Methods In Tests And Fixtures

#### Slice Contract

Move the directly migratable command tests and interactive negative fixtures
off the retiring `SceneCommands` alias names and onto the canonical exact
methods while command behavior and diagnostics stay unchanged.

#### Change

- migrate `scene_commands_test.dart` to call the canonical exact methods where
  it currently uses the retiring aliases
- migrate `move_commands_test.dart` off
  `writeSelectionReplace(...)`
- migrate interactive negative fixtures to the canonical exact names and adjust
  their local stub return types as needed
- leave the alias declarations in `scene_commands.dart` temporarily so the next
  slice can retire them after consumer adoption is complete

#### Behavioral Verification

- `flutter test test/controller/commands/scene_commands_test.dart`
- `flutter test test/controller/commands/move_commands_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

#### Structural Verification

- `rg -n "\\bwriteSelectionReplace\\(|\\bwriteSelectionToggle\\(|\\bwriteSelectionClear\\(|\\bwriteSelectionSelectAll\\(|\\bwriteBackgroundColorSet\\(|\\bwriteGridEnabledSet\\(|\\bwriteGridCellSizeSet\\(|\\bwriteCameraOffsetSet\\(" test/controller/commands/scene_commands_test.dart test/controller/commands/move_commands_test.dart test/tool/guardrails/interactive_api/architecture_boundary/runtime_and_draw_ownership_cases.dart test/tool/guardrails/interactive_api/architecture_boundary/facade_and_boundary_cases.dart`

#### Fixtures Used

- `test/tool/guardrails/interactive_api/architecture_boundary/runtime_and_draw_ownership_cases.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/facade_and_boundary_cases.dart`

#### Positive Scenarios

- command tests still lock scene / selection / metadata command behavior using
  the canonical exact methods
- interactive negative fixtures still produce the same architecture diagnostics
  while using the checked-in canonical method names

#### Negative Scenarios

- no in-scope migrated command test still relies on a retiring alias method
- no migrated interactive negative fixture still models the retired alias names

#### Closure Evidence

- the in-scope migrated files contain no remaining calls to the retiring alias
  names

### Slice 2. [ ] Retire SceneCommands Alias Declarations And Lock The Surface

#### Slice Contract

Retire the alias declarations from `SceneCommands` and add executable
structural proof that the exact methods are the only retained surface for the
retired operation group.

#### Change

- delete the eight retiring alias declarations from `scene_commands.dart`
- add `test/controller/commands/scene_commands_surface_test.dart` as a
  source-lock test that keeps the retained exact methods present and the alias
  declarations absent
- migrate the last in-scope consumer in
  `scene_controller_commit_effects_test.dart` if any retired alias remains

#### Behavioral Verification

- `flutter test test/controller/commands/scene_commands_test.dart`
- `flutter test test/controller/commands/move_commands_test.dart`
- `flutter test test/controller/core/scene_controller_commit_effects_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

#### Structural Verification

- `flutter test test/controller/commands/scene_commands_surface_test.dart`
- `dart run tool/lsp_find_thin_wrappers.dart lib/src/controller/commands/scene_commands.dart --classification=pure-forwarder`

#### Fixtures Used

- none

#### Positive Scenarios

- `SceneCommands` keeps the canonical exact methods and all command behavior
  stays green
- the new source-lock test makes alias reintroduction mechanically visible

#### Negative Scenarios

- `scene_commands.dart` no longer declares
  `writeSelectionReplace`,
  `writeSelectionToggle`,
  `writeSelectionClear`,
  `writeSelectionSelectAll`,
  `writeBackgroundColorSet`,
  `writeGridEnabledSet`,
  `writeGridCellSizeSet`, or
  `writeCameraOffsetSet`
- `lsp_find_thin_wrappers` no longer reports the retired alias wrappers on
  `scene_commands.dart`

#### Closure Evidence

- the source-lock test passes and the thin-wrapper probe for
  `scene_commands.dart` no longer reports the retired alias methods

## 11. Final Verification

- `flutter test test/controller/commands/scene_commands_test.dart`
- `flutter test test/controller/commands/move_commands_test.dart`
- `flutter test test/controller/commands/scene_commands_surface_test.dart`
- `flutter test test/controller/core/scene_controller_commit_effects_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `printf '%s\n' 'PLAN.md' 'plan/step_21_scene_commands_canonical_exact_surface_and_alias_retirement.md' 'lib/src/controller/commands/scene_commands.dart' 'test/controller/commands/scene_commands_test.dart' 'test/controller/commands/move_commands_test.dart' 'test/controller/commands/scene_commands_surface_test.dart' 'test/controller/core/scene_controller_commit_effects_test.dart' 'test/tool/guardrails/guardrails_interactive_api_tool_test.dart' 'test/tool/guardrails/interactive_api/architecture_boundary/runtime_and_draw_ownership_cases.dart' 'test/tool/guardrails/interactive_api/architecture_boundary/facade_and_boundary_cases.dart' | dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`

## 12. Acceptance Criteria

- `SceneCommands` keeps only the canonical exact methods for the retired
  operation group
- no in-scope tests or interactive negative fixtures call the retired alias
  names
- command behavior and signal semantics remain green under the named tests
- the new `SceneCommands` source-lock test fails on alias reintroduction or
  exact-method removal
