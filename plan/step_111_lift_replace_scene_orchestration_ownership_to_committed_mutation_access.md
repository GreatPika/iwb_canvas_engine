language: english

# Change Contract

## 1. Change Mandate
This change lifts replace-scene orchestration ownership to
`SceneControllerCommittedMutationAccess` so the committed mutation boundary,
the writer boundary, and guardrail/test support all state one consistent rule.

## 2. Change Boundary

### Included in the Change
- Realignment of replace-scene sequencing ownership so
  `SceneControllerCommittedMutationAccess.replaceScene(...)` owns the ordered
  sequence `prepare once -> invoke beforeApply once -> apply prepared payload`.
- Reduction of `SceneWriter` back to a true single-phase replace-scene surface
  with no boundary-level interruption callback contract.
- Replacement of the current writer-runtime orchestration seam with one exact
  controller-private staged helper form that keeps one-time prepare/apply
  semantics without exposing prepared payload state.
- Guardrail, architecture-boundary, and test-support updates that pin the new
  ownership rule and remove false failures from stale scaffolding.
- Source-of-truth updates for repository-local architecture and invariants if
  they still describe the old ownership seam.

### Not Included in the Change
- Redesign of `PreparedSceneReplacement` around immutable snapshot backing or a
  second materialization-on-apply strategy.
- Public API changes to `SceneControllerScene.replaceScene(...)`,
  `SceneStoreController.writeReplaceScene(...)`, or `SceneWriteTxn`.
- Broad refactors of commit runtime, mutation execution, signals, or gesture
  orchestration beyond the replace-scene ownership seam.
- New prepared-payload types, public apply handles, or extra replace-scene
  verbs above controller-private code.

## 3. File Map and Analysis Areas

### Implementation Files
- `lib/src/controller/scene_writer_runtime.dart`
- `lib/src/controller/scene_writer_scene.dart`
- `lib/src/controller/scene_writer.dart`
- `lib/src/controller/scene_controller_committed_mutation_access.dart`
- `tool/invariant_registry.dart`
- `tool/src/guardrails/controller_api_guardrails.dart`
- `ARCHITECTURE.md`

### Test Files
- `test/controller/core/scene_controller_committed_mutation_access_test.dart`
- `test/controller/internal/scene_writer_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

### Fixture and Supporting Data Files
- `test/tool/support/guardrails_tool_test_support.dart`

### Analysis Area
- `lib/src/controller/{scene_writer_runtime,scene_writer_scene,scene_writer,scene_controller_committed_mutation_access}.dart`
- `tool/invariant_registry.dart`
- `tool/src/guardrails/controller_api_guardrails.dart`
- `test/controller/{core/scene_controller_committed_mutation_access_test.dart,internal/scene_writer_test.dart}`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/tool/{guardrails/guardrails_controller_api_tool_test.dart,guardrails/guardrails_interactive_api_tool_test.dart,support/guardrails_tool_test_support.dart}`
- `ARCHITECTURE.md`

### Outside the Change Boundary
- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. The supported public replace-scene contracts remain unchanged:
   `SceneControllerScene.replaceScene(SceneSnapshot snapshot)`,
   `SceneStoreController.writeReplaceScene(SceneSnapshot snapshot)`, and
   `SceneWriteTxn.writeDocumentReplace(SceneSnapshot snapshot)`.
2. `PreparedSceneReplacement` remains controller-private implementation
   detail. This step must not expose prepared payload state, owner tokens, or
   a public/stable second-phase apply handle above controller-private code.
3. The approved ownership rule is fixed: the boundary-level sequence
   `prepare once -> invoke beforeApply once -> apply prepared payload` belongs
   to `SceneControllerCommittedMutationAccess.replaceScene(...)`, while
   `SceneWriter` remains a single-phase writer surface.
4. `SceneWriterRuntime` keeps exactly one controller-private callback-style
   staged helper for replace-scene. The helper takes
   `SceneSnapshot snapshot` plus a callback that receives one controller-private
   `applyPreparedReplacement` closure, prepares the payload exactly once before
   invoking that callback, and never invokes `beforeApply` itself.
5. Snapshot validation/import must still happen exactly once before
   `beforeApply`, and prepared payload apply must still adopt the prepared
   runtime scene without a second snapshot import.
6. The thin routing rule remains fixed:
   `SceneControllerMutationBoundary.replaceScene(...)` and
   `SceneControllerSceneMutations.replaceScene(...)` stay orchestration-light
   shells over committed mutation access and must not re-own preparation.
7. Acceptance scaffolding used by guardrail tests is part of the enforced
   contract for this step and must declare the same committed-mutation
   top-level surface and replace-scene boundary shape that production
   guardrails require, so a passing repository cannot fail sandbox acceptance
   tests because of stale fixture declarations.

## 5. Result Requirements

1. `SceneControllerCommittedMutationAccess.replaceScene(...)` is the unique
   non-controller-private owner of the ordered boundary sequence
   `prepare once -> beforeApply once -> apply`.
2. `SceneWriter.writeDocumentReplace(...)` is a true single-phase replace
   entrypoint and no longer accepts or routes a boundary-level `beforeApply`
   callback.
3. `SceneWriterRuntime` no longer hides the boundary orchestration rule behind
   `writeReplaceScene(...)` or `prepareSceneReplacement(...)`; it exposes only
   the fixed callback-style staged helper and that helper does not own
   interruption sequencing.
4. Replace-scene behavior remains unchanged for callers: malformed snapshots
   still fail before interruption, valid snapshots still import exactly once,
   and committed apply still clears selection and adopts the prepared runtime
   payload without a second import.
5. Repository-local enforcement is coherent: production guardrails, acceptance
   scaffolds, and architecture/invariant wording describe the same ownership
   rule with no stale false-negative path.

## 6. Implementation Specification

### 6.1 Analysis Scope
- Reuse the existing prepared payload machinery in
  `scene_snapshot_materializer.dart`, `mutation_op.dart`, and
  `scene_mutation_applier.dart`; do not redesign payload transport or owner
  token validation in this step.
- Move only orchestration ownership. Keep low-level payload construction and
  `ReplaceSceneOp` execution inside controller-private write/runtime layers.
- Preserve the current commit/write lifecycle shape based on
  `writeWithSceneWriter(...)`; do not widen `SceneControllerCommittedMutationAccess`
  with direct `TxnContext` or `MutationExecutor` access.
- Keep `SceneStoreController.writeReplaceScene(...)` as a convenience wrapper
  over the single-phase writer surface.
- The exact writer-runtime helper shape for this step is fixed: one
  callback-style staged helper that prepares once and passes a
  controller-private apply closure inward. Returning a staged object, returning
  an apply closure, keeping a public/private `writeReplaceScene(...)` wrapper,
  or keeping a standalone `prepareSceneReplacement(...)` entrypoint are not
  allowed implementations for this step.

### 6.2 Target Verification Units
- Boundary-sequencing regression coverage in
  `test/controller/core/scene_controller_committed_mutation_access_test.dart`.
- Single-phase writer-surface regression coverage in
  `test/controller/internal/scene_writer_test.dart`.
- Structural ownership assertions in
  `test/interactive/core/scene_controller_architecture_boundary_test.dart`.
- Boundary-surface enforcement in
  `test/tool/guardrails/guardrails_controller_api_tool_test.dart`.
- Acceptance-scaffold parity in
  `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`.
- Final repository verification through
  `dart run tool/check_guardrails.dart` and the required verification preset.

### 6.3 Protected States, Data, or Structures
- Owner-token validation and single-consume semantics for prepared scene
  replacement.
- Existing replace-scene commit semantics: document replacement, selection
  clear, and runtime payload adoption through `ReplaceSceneOp`.
- External-mutation interruption timing for interactive `replaceScene(...)`.
- The single-phase public `SceneWriteTxn.writeDocumentReplace(...)` contract.

### 6.4 Allowed Semantic Change Zones
- Replace-scene sequencing ownership between committed mutation access and
  writer runtime.
- Writer replace-scene method shape and its controller-private helpers.
- Guardrail recognition of allowed replace-scene surfaces and banned helper
  shapes.
- Acceptance-scaffold parity with the sealed replace-scene boundary.
- Architecture/invariant wording that names replace-scene ownership.

### 6.5 Recognition Forms That Must Be Supported Within This Change
- Direct `beforeApply` ownership in `SceneWriter.writeDocumentReplace(...)`.
- Helper-based `beforeApply` ownership hidden in `SceneWriterRuntime`.
- Local-function or callback-wrapper ownership in committed mutation access.
- Stale scaffold forms that omit
  `SceneControllerCommittedMutationWriteResult` or keep outdated replace-scene
  signatures.

### 6.6 Allowed Forms That Do Not Count as Violations
- Controller-private staged helpers in `SceneWriterRuntime` that prepare once
  and expose only controller-private inward apply execution through the fixed
  callback-style helper.
- Direct `writer.writeDocumentReplace(snapshot)` from
  `SceneStoreController.writeReplaceScene(...)`.
- `SceneControllerCommittedMutationAccess.replaceScene(...)` using the writer
  runtime inside the existing `writeWithSceneWriter(...)` write scope.

### 6.7 Requirements for Resolution of Links and Structural Analysis
- Controller guardrails must reject `SceneWriter.writeDocumentReplace(...)`
  signatures that keep a `beforeApply` parameter.
- Controller guardrails must continue to require
  `SceneControllerCommittedMutationAccess.replaceScene(...)` with the named
  `beforeApply` parameter.
- Structural tests must assert that `SceneControllerCommittedMutationAccess`
  owns the replace-scene sequence and that `SceneWriterRuntime` no longer
  declares `writeReplaceScene(...)` or `prepareSceneReplacement(...)`.
- Architecture-boundary tests and guardrail support scaffolds must include
  `SceneControllerCommittedMutationWriteResult` and the production replace-scene
  boundary declarations wherever the real boundary now requires them.

### 6.8 Prohibited
- Returning `PreparedSceneReplacement`, a prepared apply closure, or owner
  tokens from non-controller-private surfaces.
- Giving `SceneControllerCommittedMutationAccess` direct `TxnContext` or
  `MutationExecutor` ownership.
- Keeping two boundary-level replace-scene orchestration owners in parallel.
- Keeping `SceneWriterRuntime.writeReplaceScene(...)` or
  `SceneWriterRuntime.prepareSceneReplacement(...)` after this step.
- Updating only production guardrails while leaving acceptance scaffolds on the
  stale shape.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice changes an analysis rule, negative and positive scenarios must
   both be covered where applicable.
7. Scope expansion is forbidden until the mandatory slices are closed.
8. The implementing change must keep the replace-scene behavior contract green
   while ownership moves; sequencing relocation without behavioral proof does
   not close a slice.

## 8. Vertical Slices

### Slice 1. [ ] Move Replace-Scene Sequencing Ownership

#### Slice Contract
`SceneControllerCommittedMutationAccess.replaceScene(...)` becomes the unique
boundary-level owner of `prepare once -> beforeApply once -> apply`, while
`SceneWriterRuntime` retains only controller-private staged payload mechanics.

#### Change
- Replace `SceneWriterRuntime.writeReplaceScene(...)` and
  `prepareSceneReplacement(...)` with one exact controller-private
  callback-style staged helper that prepares a payload once and passes one
  inward-only `applyPreparedReplacement` closure within the same write scope.
- Update `SceneControllerCommittedMutationAccess.replaceScene(...)` so it
  stages the replace-scene payload, invokes `beforeApply` exactly once after
  successful preparation, and then applies the prepared payload.
- Keep owner-token validation and one-time consume checks on the existing
  `PreparedSceneReplacement` path.
- Add structural assertions proving that the committed mutation access file
  owns replace-scene sequencing and the writer runtime file no longer declares
  `writeReplaceScene(...)` or `prepareSceneReplacement(...)`.

#### Verification
- `flutter test test/controller/core/scene_controller_committed_mutation_access_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`

### Slice 2. [ ] Restore Single-Phase Writer Surface

#### Slice Contract
`SceneWriter` and writer-local scene helpers expose replace-scene as a true
single-phase writer operation with no boundary-level interruption callback.

#### Change
- Remove the optional `beforeApply` parameter from
  `SceneWriter.writeDocumentReplace(...)` and its writer-local helper path.
- Keep `SceneStoreController.writeReplaceScene(...)` routing through that
  single-phase writer surface without changing its callable shape.
- Update writer tests so replace-scene still finalizes selection/document
  replacement on the single-phase writer surface, and move any boundary-level
  interruption proof to the committed mutation access tests instead of simply
  deleting that proof.

#### Verification
- `flutter test test/controller/internal/scene_writer_test.dart`

### Slice 3. [ ] Pin Guardrails And Scaffold Parity

#### Slice Contract
Repository-local guardrails, acceptance scaffolds, and source-of-truth wording
agree on the new replace-scene ownership rule and do not produce stale false
negatives.

#### Change
- Update controller guardrails to reject `beforeApply` on
  `SceneWriter.writeDocumentReplace(...)` while still requiring it on
  `SceneControllerCommittedMutationAccess.replaceScene(...)`.
- Update guardrail scaffolds so acceptance tests mirror the real committed
  mutation boundary exactly for the committed-mutation top-level typedef and
  replace-scene method surfaces, including
  `SceneControllerCommittedMutationWriteResult`.
- Update `ARCHITECTURE.md` and `tool/invariant_registry.dart` if their current
  wording still attributes replace-scene orchestration to the wrong owner.

#### Verification
- `flutter test test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `flutter test test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/check_guardrails.dart`
