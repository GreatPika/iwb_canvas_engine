language: russian

# Шаг 84. Закрыть остаточные invariant gaps для write, interactive, boundary, model и view contracts

## 1. Change Mandate

Этот шаг backfill-ит explicit invariant contour для уже существующих write, interactive, boundary, model и view contracts, которые уже защищены кодом и тестами, но ещё не оформлены как самостоятельные registry-backed invariants или как явно задокументированный test-probe contract.

## 2. Change Boundary

### Included in the Change

- Добавление missing invariants и primary proof bindings в `tool/invariant_registry.dart` для write protocol, interactive non-reentrancy, boundary hermeticity, model invariants и view debug probes.
- Добавление explicit `// INV:<id>` markers в существующие proof files или вынос этих proof surfaces в dedicated test files без изменения runtime semantics.
- Targeted doc alignment в `ARCHITECTURE.md` и, если нужно для runtime-contract clarity, в `API_GUIDE.md` для boundary hermeticity и статуса view debug probes.

### Not Included in the Change

- Любая новая write, interactive, contract, model или view runtime behavior.
- Любой breaking public API change, включая запрет наследования публичных boundary types через изменение constructors или class hierarchy.
- Любой новый static-analysis tool или новый `toolProof`, если соответствующий контракт уже не tool-backed сегодня.
- Любая работа по CI trigger surface, shard composition или verification pipeline.

## 3. File Map and Analysis Areas

### Implementation Files

- `tool/invariant_registry.dart`
- `ARCHITECTURE.md`
- `API_GUIDE.md`

### Test Files

- `test/controller/core/scene_controller_writer_lifecycle_test.dart`
- `test/controller/core/scene_controller_core_dispose_fail_fast_test.dart`
- `test/interactive/core/scene_controller_interactive_basics_test.dart`
- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
- `test/contract/validated_fast_path_contract_test.dart`
- `test/controller/scene_invariants_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/view/scene_view_test.dart`

### Fixture and Supporting Data Files

- `PLAN.md`
- `plan/step_84_residual_invariant_contour_backfill.md`

### Analysis Area

- `lib/src/controller/scene_controller_commit_write_runner.dart`
- `lib/src/interactive/internal/interactive_runtime.dart`
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- `lib/src/contract/internal/boundary_impl_support.dart`
- `lib/src/contract/internal/node_spec_boundary_fallback.dart`
- `lib/src/contract/internal/node_patch_boundary_fallback.dart`
- `lib/src/contract/internal/snapshot_node_boundary_fallback.dart`
- `lib/src/controller/scene_invariants.dart`
- `lib/src/core/scene.dart`
- `lib/src/view/scene_view_runtime_host.dart`
- `lib/src/view/scene_view_interactive.dart`
- `tool/invariant_registry.dart`
- `ARCHITECTURE.md`
- `API_GUIDE.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `tool/invariant_registry.dart` remains the single source of truth for invariant ids and declared proof surfaces.
2. This step backfills already enforced or already tested contracts; it does not introduce new runtime semantics for write, pointer handling, boundary fallback, scene invariants, or view helper behavior.
3. The write protocol contract stays separate from `INV-ENG-TXN-WRITER-LIFETIME`, `INV-ENG-TXN-ATOMIC-COMMIT`, and `INV-ENG-DISPOSE-FAIL-FAST`; this step does not merge those contracts.
4. Interactive resolver purity stays separate from interactive non-reentrancy; this step does not fold `moveCommitDeltaResolver` purity and resolver reentrancy into one invariant.
5. Boundary hermeticity is formalized against the current exact-runtime-type fail-fast behavior in fallback seam helpers; changing public inheritance compatibility is out of scope for this step.
6. `debugSceneViewInteractive*` and `debugSceneViewRuntimeHost*` helpers are treated as deliberate stable test probes, not as accidental temporary hooks.

## 5. Result Requirements

1. `tool/invariant_registry.dart` declares a dedicated write protocol invariant whose proof surface explicitly covers nested `write(...)`, async `write(...)`, and `dispose()` during active write.
2. `tool/invariant_registry.dart` declares explicit interactive non-reentrancy invariants for public `handlePointer(...)` reentrancy and for `moveCommitDeltaResolver` reentrancy plus cleanup-after-failure, with matching markers in their declared proof files.
3. `tool/invariant_registry.dart` and repo docs explicitly state that fallback/public boundary seam helpers support only the built-in concrete boundary types and reject unsupported public subtypes.
4. `tool/invariant_registry.dart` declares explicit model invariants for selection normalization and the runtime grid enable/cell-size relation, with matching proof markers in `test/controller/scene_invariants_test.dart`.
5. Repo docs explicitly state that `debugSceneViewInteractive*` and `debugSceneViewRuntimeHost*` helpers are stable test probes, and their proof files carry the matching invariant markers if a registry invariant is added for them.
6. `dart run tool/check_invariant_coverage.dart` passes with the added invariant declarations and proof markers.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `SceneControllerCommitWriteRunner.run(...)` already rejects nested `write(...)` and async callbacks, and `dispose()` already rejects active-write teardown.
- `InteractiveRuntime.handlePointer(...)` already rejects same-stack reentrancy, and `SceneControllerInteractionRuntime.runMoveCommitDeltaResolver(...)` already rejects resolver reentrancy and clears its active flag in `finally`.
- Boundary fallback helpers already reject unsupported public subtypes through exact-runtime-type checks and `StateError`.
- `scene_invariants.dart` already treats normalized selection as committed-store invariant state, while `Scene.grid` runtime code already enforces the `isEnabled` / `cellSize` relation eagerly.
- View debug helpers are already used directly in `test/view/**`, but their stable status is not yet made explicit in docs or in the registry.

### 6.2 Target Verification Units

- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/run_tool_tests.dart`
- MCP test runner: root `.` paths `test/controller/core/scene_controller_writer_lifecycle_test.dart`
- MCP test runner: root `.` paths `test/controller/core/scene_controller_core_dispose_fail_fast_test.dart`
- MCP test runner: root `.` paths `test/interactive/core/scene_controller_interactive_basics_test.dart`
- MCP test runner: root `.` paths `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
- MCP test runner: root `.` paths `test/contract/validated_fast_path_contract_test.dart`
- MCP test runner: root `.` paths `test/controller/scene_invariants_test.dart`
- MCP test runner: root `.` paths `test/view/scene_view_interactive_test.dart`
- MCP test runner: root `.` paths `test/view/scene_view_test.dart`

### 6.3 Protected States, Data, or Structures

- Existing invariant ids, scopes, titles, and current proof bindings.
- Existing write, interactive, boundary, scene-invariant, and view helper runtime behavior.
- Existing tool-backed invariants and their current `toolProof` mappings.
- Existing public API compatibility of boundary types.

### 6.4 Allowed Semantic Change Zones

- New invariant ids, scopes, and titles for already existing proof-backed contracts.
- Explicit proof-marker placement in existing proof files.
- Tight proof-file extraction only when a dedicated proof surface is needed to keep one invariant owner clear.
- Targeted architectural or runtime-contract documentation for boundary hermeticity and view debug probe status.

### 6.8 Prohibited

- Replacing current runtime guards with weaker semantics while preserving only the new registry markers.
- Declaring one broad invariant that collapses write protocol, atomicity, writer lifetime, and dispose semantics into a single proof surface.
- Reusing `INV-ENG-INTERACTIVE-RESOLVER-PURITY` as a substitute for explicit reentrancy and cleanup contracts.
- Turning the boundary hermeticity slice into a breaking public API change.
- Leaving selection normalization and grid runtime relation as implicit behavior after this step is closed.
- Treating view debug probes as stable test dependencies without an explicit architectural status.

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

### Slice 1. [x] Write Protocol Invariant

#### Slice Contract

The write-side protocol is represented in the registry as its own invariant instead of being only an implicit combination of writer lifetime and dispose fail-fast proofs.

#### Change

Добавить dedicated write protocol invariant в `tool/invariant_registry.dart` и привязать к нему explicit proof markers в `test/controller/core/scene_controller_writer_lifecycle_test.dart` и `test/controller/core/scene_controller_core_dispose_fail_fast_test.dart`, либо вынести эти assertions в dedicated proof file без смены runtime semantics.

#### Verification

- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: root `.` paths `test/controller/core/scene_controller_writer_lifecycle_test.dart`
- MCP test runner: root `.` paths `test/controller/core/scene_controller_core_dispose_fail_fast_test.dart`

#### Positive Scenarios

- Nested `write(...)` throws and does not commit.
- Async `write(...)` throws and rolls back state and side effects.
- `dispose()` during active write throws and the next write still succeeds.

#### Negative Scenarios

- `check_invariant_coverage` fails if the new invariant is declared without matching markers in its proof files.
- Any proof split that drops one of the three guarded scenarios leaves the slice open.

#### Closure Evidence

- Green run of the listed verifications.
- Failure diagnostics from `check_invariant_coverage` for missing or misplaced proof markers, if any proof-file split is introduced.

### Slice 2. [x] Interactive Non-Reentrancy Contracts

#### Slice Contract

Interactive public pointer dispatch reentrancy and resolver reentrancy/cleanup are represented as explicit invariants separate from resolver purity.

#### Change

Добавить dedicated interactive invariants для same-stack `handlePointer(...)` reentrancy и для `moveCommitDeltaResolver` reentrancy plus cleanup-after-failure, расставить explicit proof markers в `test/interactive/core/scene_controller_interactive_basics_test.dart` и `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`, и сохранить `INV-ENG-INTERACTIVE-RESOLVER-PURITY` как отдельный contract.

#### Verification

- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: root `.` paths `test/interactive/core/scene_controller_interactive_basics_test.dart`
- MCP test runner: root `.` paths `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`

#### Positive Scenarios

- Same-stack reentrant `handlePointer(...)` throws `StateError`.
- Reentrant `moveCommitDeltaResolver` throws `StateError`.
- After resolver failure or invalid resolved delta, a new gesture can start cleanly.

#### Negative Scenarios

- Resolver purity markers alone do not satisfy the new non-reentrancy invariants.
- A proof layout that covers reentrancy but not cleanup-after-failure leaves the resolver contract open.

#### Closure Evidence

- Green run of the listed verifications.
- Failure diagnostics from invariant coverage if a declared interactive proof file misses the new marker.

### Slice 3. [x] Boundary Hermeticity Invariant

#### Slice Contract

The public boundary fallback seam is explicitly documented and registry-backed as supporting only built-in concrete boundary types.

#### Change

Добавить explicit invariant entry for boundary hermeticity, привязать `test/contract/validated_fast_path_contract_test.dart` как proof surface, расставить matching markers на unsupported subtype and public subclass scenarios, и зафиксировать current concrete-only rule в `ARCHITECTURE.md` и, если нужен runtime-contract note, в `API_GUIDE.md`.

#### Verification

- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: root `.` paths `test/contract/validated_fast_path_contract_test.dart`

#### Positive Scenarios

- Unsupported boundary subtypes fail fast across seam helpers.
- Public subclasses of known boundary types are rejected by fallback/backing helpers.

#### Negative Scenarios

- The slice stays open if the rule is proven only by tests and not stated in repo docs.
- The slice stays open if docs claim hermeticity but the dedicated proof markers are absent.

#### Closure Evidence

- Green run of the listed verifications.
- The declared proof file contains explicit markers for the boundary hermeticity contract.

### Slice 4. [x] Model Invariant Ownership Backfill

#### Slice Contract

Selection normalization and the runtime grid enable/cell-size relation are represented as explicit model invariants with one clear proof surface.

#### Change

Добавить explicit invariant entries для normalized `selectedNodeIds` и для runtime relation `grid.isEnabled <-> grid.cellSize`, расставить matching markers в `test/controller/scene_invariants_test.dart`, и не оставлять эти rules только как local assertions without registry ownership.

#### Verification

- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: root `.` paths `test/controller/scene_invariants_test.dart`

#### Positive Scenarios

- Committed-store invariant collection reports non-normalized `selectedNodeIds`.
- Runtime grid owner rejects invalid enable/size transitions eagerly.

#### Negative Scenarios

- The slice stays open if only one of the two model rules receives a registry entry.
- A marker placed only in comments or only in docs does not satisfy the proof requirement.

#### Closure Evidence

- Green run of the listed verifications.
- Registry and proof markers both resolve to `test/controller/scene_invariants_test.dart`.

### Slice 5. [x] View Debug Probe Status

#### Slice Contract

View debug helpers used by `test/view/**` have explicit stable test-probe status in repo docs and, if promoted to registry status, a dedicated proof-backed invariant.

#### Change

Зафиксировать status `debugSceneViewInteractive*` и `debugSceneViewRuntimeHost*` helpers в `ARCHITECTURE.md`, добавить low-priority invariant entry if the repo keeps them as stable probes, и расставить matching markers в `test/view/scene_view_interactive_test.dart` и `test/view/scene_view_test.dart`.

#### Verification

- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: root `.` paths `test/view/scene_view_interactive_test.dart`
- MCP test runner: root `.` paths `test/view/scene_view_test.dart`

#### Positive Scenarios

- Descendant and runtime-owner contexts can read the declared debug helpers.
- Missing host/render-surface context continues to fail fast with the documented `StateError`.
- Pending tap and live raw-pointer debug reads remain observable through the declared probe helpers.

#### Negative Scenarios

- The slice stays open if the helpers remain test dependencies without an explicit architectural status.
- The slice stays open if a new registry invariant is added but the view proof files do not carry the matching markers.

#### Closure Evidence

- Green run of the listed verifications.
- Updated architecture note and, if chosen, registry-backed proof markers align with the declared probe contract.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test shard presets: `core`, `model_contract`, `controller_internal`, `controller`, `render_view`, `interactive`, `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
