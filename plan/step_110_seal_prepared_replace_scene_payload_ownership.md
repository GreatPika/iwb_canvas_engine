language: english

# Change Contract

## 1. Change Mandate
This change seals prepared replace-scene payload ownership so `replaceScene`
validates/imports exactly once before external-mutation interruption, but the
prepared runtime payload no longer escapes non-controller-private boundaries.

## 2. Change Boundary

### Included in the Change
- Hardening of `PreparedSceneReplacement` so its runtime `Scene` payload and
  revision state are no longer publicly accessible.
- Introduction of one controller-owned prepared-payload adoption helper that
  is the only allowed apply path for prepared replace-scene state.
- Removal of `PreparedSceneReplacement` and the
  `prepareSceneReplacement(...)` / `writePreparedSceneReplacement(...)` verb
  pair from non-controller-private signatures.
- Guardrail, invariant, and documentation updates that pin the sealed
  prepared replace-scene ownership contract.

### Not Included in the Change
- Replacing the prepared runtime payload with immutable snapshot backing or a
  second materialization-on-apply design.
- Broad refactors of transaction execution, write batching, or gesture
  orchestration unrelated to replace-scene payload ownership.
- Changes to the supported public scene capability contract
  `replaceScene(SceneSnapshot snapshot)`.
- Read-side sealing, spatial-index changes, or render-frame resolution work
  already covered by earlier steps.

## 3. File Map and Analysis Areas

### Implementation Files
- `lib/src/controller/scene_snapshot_materializer.dart`
- `lib/src/controller/scene_mutation_applier.dart`
- `lib/src/controller/mutation_op.dart`
- `lib/src/controller/scene_writer_runtime.dart`
- `lib/src/controller/scene_writer_scene.dart`
- `lib/src/controller/scene_writer.dart`
- `lib/src/controller/scene_store_controller.dart`
- `lib/src/controller/scene_controller_committed_mutation_access.dart`
- `lib/src/interactive/internal/scene_controller_mutation_boundary.dart`
- `lib/src/interactive/internal/scene_controller_scene_mutations.dart`
- `tool/invariant_registry.dart`
- `tool/check_guardrails.dart`
- `tool/src/guardrails/controller_api_guardrails.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Test Files
- `test/controller/core/scene_controller_committed_mutation_access_test.dart`
- `test/controller/internal/mutation_executor_test.dart`
- `test/controller/internal/scene_writer_test.dart`
- `test/interactive/core/scene_controller_mutation_boundary_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

### Fixture and Supporting Data Files
- `test/tool/support/guardrails_tool_test_support.dart`

### Analysis Area
- `lib/src/controller/{scene_snapshot_materializer,scene_mutation_applier,mutation_op,scene_writer_runtime,scene_writer_scene,scene_writer,scene_store_controller,scene_controller_committed_mutation_access}.dart`
- `lib/src/interactive/internal/{scene_controller_mutation_boundary,scene_controller_scene_mutations}.dart`
- `tool/{check_guardrails.dart,invariant_registry.dart}`
- `tool/src/guardrails/{controller_api_guardrails,interactive_api_guardrails}.dart`
- `test/controller/core/scene_controller_committed_mutation_access_test.dart`
- `test/controller/internal/{mutation_executor,scene_writer}_test.dart`
- `test/interactive/core/{scene_controller_mutation_boundary,scene_controller_architecture_boundary}_test.dart`
- `test/tool/guardrails/{guardrails_controller_api_tool,guardrails_interactive_api_tool}_test.dart`
- `test/tool/support/guardrails_tool_test_support.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

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

1. The supported public scene mutation contract remains
   `replaceScene(SceneSnapshot snapshot)`. This step must not introduce a
   public prepared-payload API or a public second-phase apply verb.
2. `PreparedSceneReplacement` remains the controller-module prepared payload
   type, but after this step it is opaque: no public field or getter may
   expose the runtime `Scene`, `nextInstanceRevision`, or any controller-owned
   token outside the payload owner.
3. The only allowed controller prepared-payload owner remains
   `scene_snapshot_materializer.dart`. It owns payload construction and the
   only helper that may unwrap and apply a prepared payload during replace
   scene. `scene_mutation_applier.dart` must not read payload internals
   directly after this step.
4. The owner token contract is fixed. Prepared payload ownership is bound by
   an opaque object-identity token created by the preparing owner, stored only
   in prepared payload backing, and passed back to the canonical apply helper.
   The token must not be derived from `controllerEpoch`, revision counters,
   snapshot hashes, or any other value-based surrogate.
5. The orchestration owner is fixed. After this step,
   `SceneControllerCommittedMutationAccess.replaceScene(...)` owns the
   sequence `materialize prepared payload -> invoke beforeApply exactly once ->
   apply prepared payload`, while
   `SceneControllerMutationBoundary.replaceScene(...)` and
   `SceneControllerSceneMutations.replaceScene(...)` remain thin routing
   shells over that owner and must not re-own preparation logic.
6. The final non-controller-private replace-scene surface is fixed:
   - `SceneStoreController` keeps exactly one non-controller-private
     single-phase `writeReplaceScene(SceneSnapshot snapshot)` convenience
     entrypoint. It may live either directly on `SceneStoreController` or on a
     dedicated extension over `SceneStoreController`, but guardrails must not
     require one specific declaration form.
   - `SceneControllerCommittedMutationAccess` exposes
     `replaceScene(SceneSnapshot snapshot, {required VoidCallback beforeApply})`
     and does not expose `PreparedSceneReplacement`,
     `prepareSceneReplacement(...)`, or
     `writePreparedSceneReplacement(...)`.
   - `SceneControllerMutationBoundary` exposes
     `replaceScene(SceneSnapshot snapshot, {required VoidCallback interruptBeforeApply})`
     and does not expose `PreparedSceneReplacement`,
     `prepareSceneReplacement(...)`, or
     `writePreparedSceneReplacement(...)`.
   - `SceneControllerSceneMutations` keeps only
     `replaceScene(SceneSnapshot snapshot)`.
7. The only files allowed to mention `PreparedSceneReplacement` after this
   step are:
   `lib/src/controller/scene_snapshot_materializer.dart`,
   `lib/src/controller/scene_mutation_applier.dart`,
   `lib/src/controller/mutation_op.dart`,
   `lib/src/controller/scene_writer_runtime.dart`, and
   `lib/src/controller/scene_writer_scene.dart`.
   `scene_writer.dart`,
   `scene_store_controller.dart`,
   `scene_controller_committed_mutation_access.dart`,
   `scene_controller_mutation_boundary.dart`, and
   `scene_controller_scene_mutations.dart` must not mention it.
8. `SceneWriter` remains a single-phase writer surface on replace-scene after
   this step. `writePreparedDocumentReplace(...)` must not remain on
   `SceneWriter`.
9. `replaceScene(...)` keeps the existing two-phase behavior: snapshot
   validation/import happens exactly once before the external-mutation
   interrupt runs, and apply adopts the prepared runtime payload without a
   second snapshot import.
10. Prepared payload apply must fail fast when the payload owner token does not
   match the controller/runtime that prepared it.
11. Public documentation and changelog updates ship in the same change as the
   sealed prepared replace-scene ownership contract.

## 5. Result Requirements

1. No non-controller-private signature exposes `PreparedSceneReplacement` or
   the `prepareSceneReplacement(...)` / `writePreparedSceneReplacement(...)`
   verb pair after the step is complete.
2. `replaceScene(...)` still validates/imports snapshot input exactly once
   before the external-mutation interrupt and still adopts the prepared
   runtime payload without a second snapshot import.
3. `PreparedSceneReplacement` can no longer be externally mutated into a
   different runtime scene and cannot be applied through a foreign or invalid
   owner.
4. `SceneWriter` and `SceneStoreController` keep only single-phase
   replace-scene entrypoints above controller-private prepared payload
   ownership.
5. Repository-local tooling and docs enforce one non-contradictory rule:
   prepared replace-scene payloads are controller-private implementation
   detail, not a supported boundary contract.

## 6. Implementation Specification

### 6.1 Analysis Scope
- Reuse the existing prepared runtime payload path in
  `scene_snapshot_materializer.dart`, `scene_writer_runtime.dart`,
  `scene_writer_scene.dart`, `mutation_op.dart`, and
  `scene_mutation_applier.dart`; do not redesign replace-scene around
  immutable snapshot backing in this step.
- Keep `SceneStoreController.writeReplaceScene(SceneSnapshot snapshot)` as the
  direct controller/test convenience entrypoint; do not reopen the supported
  public scene capability contract. Guardrails may enforce this through either
  a class member or a dedicated extension method as long as the callable
  surface remains `storeController.writeReplaceScene(snapshot)`.
- Keep replace-scene interruption semantics anchored in the interactive scene
  mutation path. The new non-controller-private method surface must preserve
  “prepare once before interrupt, then apply” rather than moving validation
  after interruption.
- Reuse existing controller and interactive guardrail tooling instead of
  adding a separate replace-scene checker.

### 6.2 Target Verification Units
- Prepared-payload ownership and adopt-path regressions in
  `test/controller/internal/mutation_executor_test.dart` and
  `test/controller/core/scene_controller_committed_mutation_access_test.dart`.
- Writer and controller-surface regressions in
  `test/controller/internal/scene_writer_test.dart`.
- Interactive boundary and architecture regressions in
  `test/interactive/core/scene_controller_mutation_boundary_test.dart` and
  `test/interactive/core/scene_controller_architecture_boundary_test.dart`.
- Guardrail enforcement in
  `test/tool/guardrails/guardrails_controller_api_tool_test.dart` and
  `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`.
- Final repository verification through the canonical command required by
  `AGENTS.md` for code changes.

### 6.3 Protected States, Data, or Structures
- The supported public `SceneControllerScene.replaceScene(SceneSnapshot snapshot)`
  contract.
- Existing external-mutation interruption semantics for `replaceScene(...)`
  and `setCameraOffset(...)`.
- Existing replace-scene commit semantics: document replacement, selection
  clear, and runtime payload adoption through the canonical controller commit
  path.
- Existing malformed-snapshot failure contract for `replaceScene(...)`.

### 6.4 Allowed Semantic Change Zones
- Prepared replace-scene payload visibility and ownership.
- Replace-scene orchestration signatures above controller-private payload
  ownership.
- Prepared-payload apply validation and owner-token checks.
- Replace-scene guardrails, invariants, and published architecture docs.
- Replace-scene sequencing ownership between committed mutation access and the
  thinner interactive routing shells.

### 6.5 Recognition Forms That Must Be Supported Within This Change
- Direct signature leakage of `PreparedSceneReplacement`.
- Leakage through the verb pair
  `prepareSceneReplacement(...)` and `writePreparedSceneReplacement(...)`.
- Direct field leakage of the prepared runtime `Scene` or
  `nextInstanceRevision`.
- Foreign-controller prepared payload apply.
- Apply-path bypass that reads prepared payload internals directly instead of
  going through the canonical prepared-payload helper.

### 6.6 Allowed Forms That Do Not Count as Violations
- Controller-private use of `PreparedSceneReplacement` inside the controller
  files that own prepared payload construction, transport, and apply.
- Direct single-phase `writeReplaceScene(SceneSnapshot snapshot)` on
  `SceneStoreController` for controller/test callers.
- Internal `ReplaceSceneOp` transport inside the controller mutation executor.

### 6.7 Requirements for Resolution of Links and Structural Analysis
- Guardrails introduced or updated by this step must reject
  `PreparedSceneReplacement` and the
  `prepareSceneReplacement(...)` / `writePreparedSceneReplacement(...)` verb
  pair when they appear in:
  `SceneStoreControllerCommittedSceneReplacementAccess`,
  `SceneControllerCommittedMutationAccess`,
  `SceneControllerMutationBoundary`,
  and `SceneControllerSceneMutations`.
- The proof surface for those guardrails is the concrete controller and
  interactive source files plus the sandbox fixtures under
  `test/tool/support/guardrails_tool_test_support.dart`.

### 6.8 Prohibited
- Do not redesign prepared replace-scene around immutable snapshot backing or
  second materialization on apply in this step.
- Do not leave public field or getter access to the prepared runtime `Scene`,
  `nextInstanceRevision`, or owner token on `PreparedSceneReplacement`.
- Do not leave `PreparedSceneReplacement`,
  `prepareSceneReplacement(...)`, or
  `writePreparedSceneReplacement(...)` in non-controller-private signatures at
  step closure.
- Do not move prepared payload materialization above
  `SceneControllerCommittedMutationAccess.replaceScene(...)` or let
  `SceneControllerMutationBoundary` / `SceneControllerSceneMutations` re-own
  replace-scene preparation logic.
- Do not keep `SceneWriter.writePreparedDocumentReplace(...)` after this step.
- Do not re-import a snapshot or defensively clone the prepared runtime scene
  during apply.
- Do not invoke `beforeApply` before prepared payload materialization or more
  than once per replace-scene attempt.
- Do not bypass the canonical prepared-payload helper by reading payload
  internals directly in `scene_mutation_applier.dart`.
- Do not keep any legacy non-controller-private replace-scene fallback
  surface after the step is complete.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. Slice 1 may keep `PreparedSceneReplacement` in non-controller-private
   signatures only while slice 2 remains open. Step closure is forbidden until
   slice 2 deletes that exposure.
7. Any slice that changes replace-scene failure behavior must attach the
   failing diagnostic or thrown error expectation in the same proof surface.
8. Any slice that changes guardrails must update `tool/invariant_registry.dart`
   in the same change where the proof surface is introduced.
9. Scope expansion to immutable prepared backing or broader transaction
   redesign is forbidden until this step is closed as written.
10. The plan must be detailed enough that the implementing agent has no
    material branch in how to execute a slice.
11. Every newly proposed file or directory name must comply with the global
    `AGENTS.md` section `### File naming` before the slice is considered
    valid.

## 8. Vertical Slices

### Slice 1. [x] Harden prepared payload implementation and apply ownership

#### Slice Contract
`PreparedSceneReplacement` becomes opaque and can be applied only through one
controller-owned helper that validates owner identity before adoption.

#### Change
- Remove public field/getter access to the prepared runtime `Scene`,
  `nextInstanceRevision`, and any controller-owned token from
  `PreparedSceneReplacement` in
  `lib/src/controller/scene_snapshot_materializer.dart`.
- Bind each prepared payload to the preparing controller/runtime through an
  owner token stored only in the payload backing.
- Add the only allowed prepared-payload apply helper in
  `lib/src/controller/scene_snapshot_materializer.dart`; it must unwrap the
  opaque payload, validate the owner token, call `ctx.txnAdoptScene(...)`, and
  transfer `nextInstanceRevision`.
- Update `lib/src/controller/scene_mutation_applier.dart` so replace-scene
  apply delegates only to that helper and no longer reads payload internals
  directly.
- Keep existing higher-layer signatures temporarily if needed for migration
  sequencing, but after this slice they expose only an opaque payload, not a
  mutable runtime scene.

#### Verification
- `flutter test test/controller/internal/mutation_executor_test.dart`
- `flutter test test/controller/core/scene_controller_committed_mutation_access_test.dart`
- `if rg -n "replacement\\.(scene|nextInstanceRevision)" lib/src/controller/scene_mutation_applier.dart; then exit 1; fi`

#### Positive Scenarios
- A prepared payload created by the same controller/runtime still replaces the
  scene successfully.
- Direct replace-scene through the committed mutation access happy path still
  updates the committed snapshot correctly.

#### Negative Scenarios
- Applying a prepared payload through a different controller/runtime fails
  fast.
- Replace-scene apply no longer depends on direct payload field reads in the
  apply owner.

#### Closure Evidence
- The listed controller tests stay green with opaque payload access and
  owner-token validation.
- Replace-scene apply runs only through the canonical prepared-payload helper.

### Slice 2. [x] Remove prepared payload from non-controller-private surfaces

#### Slice Contract
Prepared replace-scene payloads no longer cross committed mutation access,
interactive mutation boundary, scene mutation orchestration, store-controller
replace-scene extension, or writer surfaces.

#### Change
- Remove `prepareSceneReplacement(...)` and
  `writePreparedSceneReplacement(...)` from
  `lib/src/controller/scene_controller_committed_mutation_access.dart`.
- Replace them with the exact single verb
  `replaceScene(SceneSnapshot snapshot, {required VoidCallback beforeApply})`
  on `SceneControllerCommittedMutationAccess`. That method owns the exact
  sequence `materialize -> beforeApply -> apply`.
- Remove `prepareSceneReplacement(...)` and the payload-taking
  `replaceScene(...)` overload from
  `lib/src/interactive/internal/scene_controller_mutation_boundary.dart`.
- Replace them with the exact single verb
  `replaceScene(SceneSnapshot snapshot, {required VoidCallback interruptBeforeApply})`.
  That method must remain a thin shell: it passes the callback into
  `mutationAccess.replaceScene(...)`, clears pointer-normalization state only
  after successful apply, and must not materialize prepared payloads itself.
- Update
  `lib/src/interactive/internal/scene_controller_scene_mutations.dart` so it
  delegates public `replaceScene(SceneSnapshot snapshot)` through that exact
  boundary verb and no longer stores a prepared payload. It must continue to
  pass `interruptForExternalMutation` into the boundary instead of re-owning
  preparation or apply sequencing.
- Remove `prepareSceneReplacement(...)` and
  `writePreparedSceneReplacement(...)` from
  `lib/src/controller/scene_store_controller.dart`; keep only
  `writeReplaceScene(SceneSnapshot snapshot)` on the committed scene
  replacement access extension.
- Remove `writePreparedDocumentReplace(...)` from
  `lib/src/controller/scene_writer.dart`.
- Keep the materialize/apply split only inside controller-private replace-scene
  implementation files.

#### Verification
- `flutter test test/controller/core/scene_controller_committed_mutation_access_test.dart`
- `flutter test test/controller/internal/scene_writer_test.dart`
- `flutter test test/interactive/core/scene_controller_mutation_boundary_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `if rg -n "PreparedSceneReplacement|prepareSceneReplacement|writePreparedSceneReplacement" lib/src/controller/scene_controller_committed_mutation_access.dart lib/src/interactive/internal/scene_controller_mutation_boundary.dart lib/src/interactive/internal/scene_controller_scene_mutations.dart lib/src/controller/scene_writer.dart lib/src/controller/scene_store_controller.dart; then exit 1; fi`
- `if rg -n "prepareSceneReplacement\\(|materializeSceneReplacement\\(" lib/src/interactive/internal/scene_controller_mutation_boundary.dart lib/src/interactive/internal/scene_controller_scene_mutations.dart; then exit 1; fi`

#### Positive Scenarios
- Public scene mutation still replaces the scene from one `SceneSnapshot`
  input.
- External mutation interrupt still happens only after replace-scene preflight
  succeeds.
- Direct `SceneStoreController.writeReplaceScene(SceneSnapshot snapshot)`
  still works for controller/test callers.

#### Negative Scenarios
- `SceneControllerCommittedMutationAccess` no longer exposes
  `PreparedSceneReplacement` or prepare/writePrepared verbs.
- `SceneControllerMutationBoundary` no longer exposes
  `PreparedSceneReplacement` or prepare/writePrepared verbs.
- `SceneWriter` no longer exposes `writePreparedDocumentReplace(...)`.

#### Closure Evidence
- The listed controller and interactive tests stay green with the new
  single-verb replace-scene surfaces.
- No non-controller-private replace-scene signature still mentions
  `PreparedSceneReplacement`.

### Slice 3. [x] Guardrail prepared replace-scene boundary hermeticity

#### Slice Contract
Repository-local tooling fails when prepared replace-scene payloads or their
two-phase verbs reappear above controller-private ownership.

#### Change
- Add a new invariant entry in `tool/invariant_registry.dart` for prepared
  replace-scene boundary hermeticity with exact proof surfaces in the
  guardrail regression tests added by this slice.
- Extend `tool/check_guardrails.dart`,
  `tool/src/guardrails/controller_api_guardrails.dart`, and
  `tool/src/guardrails/interactive_api_guardrails.dart` so they reject
  `PreparedSceneReplacement` and the
  `prepareSceneReplacement(...)` / `writePreparedSceneReplacement(...)` verb
  pair on the surfaces locked in section 4.
- Update `test/tool/support/guardrails_tool_test_support.dart` so the accepted
  fixture surface uses only the new single-verb replace-scene contracts.
- Add positive and negative regressions in
  `test/tool/guardrails/guardrails_controller_api_tool_test.dart` and
  `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` that prove
  the new single-verb contracts pass while the old prepared-payload surfaces
  fail.

#### Verification
- `flutter test test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `flutter test test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

#### Positive Scenarios
- Controller and interactive fixtures using only the new single-verb
  replace-scene contracts pass the guardrails.

#### Negative Scenarios
- A committed mutation access surface exposing
  `PreparedSceneReplacement` fails.
- A mutation boundary surface using
  `prepareSceneReplacement(...)` or
  `writePreparedSceneReplacement(...)` fails.
- A store-controller replacement extension exposing prepared-payload verbs
  fails.

#### Closure Evidence
- Guardrail regression tests prove the old prepared-payload boundary surfaces
  are mechanically rejected.
- The invariant registry contains the new prepared replace-scene hermeticity
  rule with matching proof surfaces.

### Slice 4. [x] Publish the sealed prepared replace-scene ownership contract

#### Slice Contract
Repository documentation describes one non-contradictory rule: `replaceScene`
is the only supported scene replacement verb outside controller-private code,
and prepared payloads are internal implementation detail.

#### Change
- Update `ARCHITECTURE.md` so the replace-scene ownership section explicitly
  states that prepared payloads remain controller-private, `replaceScene(...)`
  validates/imports once before interruption, and apply adopts the prepared
  runtime payload through the canonical controller helper only.
- Update `README.md` and `API_GUIDE.md` where they describe
  `replaceScene(...)` so they no longer imply a supported two-phase prepared
  payload contract outside controller-private code.
- Add an `## Unreleased` changelog entry in `CHANGELOG.md` describing that
  prepared replace-scene payloads are now controller-private and replace-scene
  boundary signatures were sealed.

#### Verification
- `rg -n "controller-private|prepareSceneReplacement|writePreparedSceneReplacement|replaceScene\\(SceneSnapshot snapshot\\)" README.md API_GUIDE.md ARCHITECTURE.md CHANGELOG.md`

#### Closure Evidence
- The listed documentation files describe one consistent replace-scene
  ownership rule with no wording that blesses prepared payloads as a supported
  boundary contract.

## 9. Final Verification

- `flutter test test/controller/core/scene_controller_committed_mutation_access_test.dart`
- `flutter test test/controller/internal/mutation_executor_test.dart`
- `flutter test test/controller/internal/scene_writer_test.dart`
- `flutter test test/interactive/core/scene_controller_mutation_boundary_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `flutter test test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `flutter test test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_verification_preset.dart run --preset required_code_change --changed-paths-file=<path-or->`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
