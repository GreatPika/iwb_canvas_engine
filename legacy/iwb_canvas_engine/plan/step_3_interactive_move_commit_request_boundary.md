# Change Contract

## 1. Change Mandate

Replace the live-collection `MoveCommitDeltaResolver` callback surface with an
immutable `MoveCommitDeltaRequest` boundary, keep move-commit node ownership
inside the mutation boundary, and mechanically forbid raw collection types
anywhere inside exported public callback-typedef parameter shapes.

## 2. Change Boundary

### Included in the Change

- replace the public `MoveCommitDeltaResolver` typedef with a request-object
  form that accepts `MoveCommitDeltaRequest`
- add a public immutable `MoveCommitDeltaRequest` in
  `lib/src/interactive/scene_controller_interaction.dart`
- freeze `movedNodes` as a detached owned snapshot inside
  `SceneControllerMutationBoundary.commitMoveSelection(...)` and use that same
  frozen snapshot for resolver input and commit iteration
- migrate interactive runtime wiring and internal test access from named
  callback arguments to the request object
- add regression tests that lock immutability and commit-set/order stability
- add a public-signature guardrail that rejects exported callback typedefs with
  raw `List` / `Map` / `Set` types anywhere inside callback-parameter shapes
- update public and architecture documentation plus changelog for the breaking
  callback contract change

### Not Included in the Change

- no dual surface, deprecation bridge, or compatibility shim for the old
  resolver typedef
- no repository-wide conversion of every public `List`-typed return value to
  custom collection wrappers
- no redesign of move-preview eligibility or move-session gesture behavior
- no new analyzer plugin or lint package beyond the existing guardrail tool
- no new background sync seam between helper functions and the mutation
  boundary; boundary ownership remains explicit

## 3. Surrounding Code Review

### Inspected Artifacts

- `PLAN.md` — active plan index currently has step documents for steps 1 and 2
  only, so this change must add a new linked step
- `lib/src/interactive/scene_controller_interaction.dart` — current public
  typedef exposes named parameters with `List<NodeSnapshot> movedNodes`
- `lib/src/interactive/internal/scene_controller_mutation_boundary.dart` —
  `commitMoveSelection(...)` currently builds `movedNodes`, passes that same
  list to `resolveMoveCommitDelta(...)`, then iterates the same list for the
  authoritative commit loop
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart` —
  runtime currently forwards the same `movedNodes` object into the app
  callback and only guards public controller side effects, not list mutation
- `lib/src/interactive/interaction_eligibility_policy.dart` — ordered node
  helper returns a growable list built with `<NodeSnapshot>[]`
- `lib/src/interactive/internal/scene_controller_internal_access.dart` —
  internal test seam mirrors the old named-argument resolver path and must
  migrate with the public seam
- `lib/src/core/immutable_collections.dart` — existing `freezeList(...)`
  helper already provides detached immutable list ownership
- `lib/src/contract/snapshot.dart` — public document boundary already freezes
  collections and documents immutable snapshot semantics
- `lib/src/core/action_events.dart` — committed event payloads already freeze
  `nodeIds` and payload maps before exposure
- `lib/src/controller/scene_writer_runtime.dart` — transaction read boundary
  already returns detached immutable selection sets and is the closest
  repository precedent for boundary-owned immutable read snapshots
- `tool/invariant_registry.dart` — `INV-ENG-COMMITTED-READ-SIDE-HERMETICITY`
  already claims interactive callback contracts expose immutable snapshots
- `tool/src/guardrails/rules/public/public_signature_rules.dart` —
  current public-signature guardrail checks type leaks but has no rule for raw
  collection parameters inside exported callback typedefs
- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
  — current resolver tests prove delta behavior, purity guard, and reentrancy,
  but not immutable request payloads
- `test/interactive/core/scene_controller_mutation_boundary_test.dart` —
  current boundary tests prove move commit semantics, but not that resolver
  input cannot alter commit-set ownership
- `test/interactive/core/scene_controller_interaction_contract_test.dart` —
  existing interaction contract suite is the right structural seam to lock
  internal access and public interaction contract wiring without dropping to
  string-only source assertions
- `test/interactive/core/scene_controller_architecture_boundary_test.dart` —
  existing structural suite proves the interactive/controller/view split and is
  the right reuse point if resolver wiring changes need a structural drift
  detector
- `test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`
  — current tool suite proves hidden-type and mutable-type leaks, and is the
  right owner for new callback-signature collection guard tests
- `test/tool/public_api_surface_tool_test.dart` — existing tool suite locks the
  exported symbol golden and is the executable proof surface for the public API
  symbol update
- `API_GUIDE.md` — public API guide lists `MoveCommitDeltaResolver` as a
  supported runtime integration hook
- `ARCHITECTURE.md` and `README.md` — repository docs already describe the
  public boundary as immutable and callback-scoped values as detached
  immutable snapshots
- `CHANGELOG.md` — `Unreleased` already contains breaking changes, so a
  breaking callback cleanup belongs in the current release line

### Current Entry Path

- `SceneController(moveCommitDeltaResolver: ...)` ->
  `createSceneControllerGraph(...)` ->
  `createSceneControllerInteractionRuntime(...)` ->
  `SceneControllerMutationBoundary.commitMoveSelection(...)` ->
  `callbacks.resolveMoveCommitDelta(...)` ->
  `SceneControllerInteractionRuntime.runMoveCommitDeltaResolver(...)`

### Current Owner

- public callback surface owner:
  `lib/src/interactive/scene_controller_interaction.dart`
- move-commit authoritative node-set owner:
  `lib/src/interactive/internal/scene_controller_mutation_boundary.dart`
- callback dispatch/runtime guard owner:
  `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- exported callback signature enforcement owner:
  `tool/src/guardrails/rules/public/public_signature_rules.dart`

### Adjacent Abstractions

- `lib/src/interactive/internal/scene_controller_graph.dart` — wires the
  public controller constructor to runtime and internal test access
- `lib/src/interactive/internal/interactive_move_callbacks.dart` — owns move
  commit result plumbing adjacent to the resolver seam
- `lib/src/interactive/interaction_eligibility_policy.dart` — shared ordered
  selection helpers used by interactive move and transform logic
- `lib/src/core/immutable_collections.dart` — shared detached-freeze helper
  already used by read-side payload boundaries

### Existing Tests

- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
  — locks resolver-applied delta, zero-delta skip, purity guard, invalid delta
  rejection, and reentrancy
- `test/interactive/core/scene_controller_mutation_boundary_test.dart` —
  locks move commit behavior at the mutation-boundary owner
- `test/interactive/core/interaction_eligibility_policy_test.dart` — locks
  ordered snapshot helper semantics and compatibility wrappers
- `test/interactive/core/scene_controller_interaction_contract_test.dart` —
  locks public interaction/runtime contract wiring and internal access seams
- `test/interactive/core/scene_controller_architecture_boundary_test.dart` —
  locks structural split across `scene_controller.dart`, graph assembly, and
  runtime/view seams
- `test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`
  — locks public-signature tool diagnostics with sandbox fixtures
- `test/tool/public_api_surface_tool_test.dart` — locks the exported public API
  symbol golden workflow

### Analogous Implementation Path

- `lib/src/core/action_events.dart` — freezes boundary payload collections
  before exposure and is the closest valid precedent for a detached immutable
  callback payload snapshot
- `lib/src/controller/scene_writer_runtime.dart` — owns boundary reads and
  returns detached immutable values rather than exposing mutable owner state

### Governing Repository Rules

- repository instructions — bugs must be fixed at the owning layer, not at
  one downstream call site
- repository instructions — public behavior changes must update
  `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, and `CHANGELOG.md`
- project execution rules — important invariants must be enforced with
  repository-local tests or tooling rather than prose-only guidance
- `tool/invariant_registry.dart` — committed read-side controller and
  interactive callback contracts must expose immutable snapshots
- user instruction for this change — remove the old typedef shape entirely,
  introduce `MoveCommitDeltaRequest`, keep freeze ownership in
  `commitMoveSelection(...)`, and add a guardrail against raw collection
  parameters in exported callback typedefs

### Rejected Misleading Local Patterns

- freezing only in `selectedNodesInSnapshotOrder(...)` — wrong primary owner
  because the authoritative guarantee must live in
  `commitMoveSelection(...)`, not be spread across helper call sites
- `UnmodifiableListView` over a live internal list — wrong seam because it
  preserves aliasing to boundary-owned mutable storage
- keeping the old typedef with frozen `List<NodeSnapshot>` — too weak because
  the public callback contract would still advertise a mutable collection
  surface and the guardrail could not close the class of defects
- adding a deprecated bridge typedef or constructor overload — wrong for this
  repository because it keeps two supported callback seams without a user-base
  need

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- interactive public callback boundary ownership and exported callback
  signature enforcement

#### Selected Architectural Form

- replace the raw-parameter callback typedef with a single immutable request
  value object:
  `Offset Function(MoveCommitDeltaRequest request)`
- keep authoritative move-commit node-set ownership in
  `SceneControllerMutationBoundary.commitMoveSelection(...)`, where the ordered
  node list is frozen exactly once and reused for both resolver input and
  commit iteration
- enforce the public-surface policy mechanically in the existing public
  signature guardrail by rejecting exported callback typedef parameter types
  whose resolved shape contains SDK collection types `List`, `Map`, or `Set`
  anywhere inside the callback parameter graph

#### Owning Layer or Module

- public callback contract:
  `lib/src/interactive/scene_controller_interaction.dart`
- authoritative move-commit request construction:
  `lib/src/interactive/internal/scene_controller_mutation_boundary.dart`
- runtime callback dispatch and internal access wiring:
  `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`,
  `lib/src/interactive/internal/scene_controller_graph.dart`, and
  `lib/src/interactive/internal/scene_controller_internal_access.dart`
- structural enforcement:
  `tool/src/guardrails/rules/public/public_signature_rules.dart`

#### Dependency Direction

- `SceneController` constructor surface depends on the public typedef and
  request object only
- runtime and mutation-boundary internals depend on the public request object
  but remain the owners of snapshot collection freezing and callback dispatch
- the public signature guardrail depends on analyzer-resolved exported
  signatures and forbids raw collection parameters without introducing runtime
  dependencies

#### State and Data Ownership

- authoritative ordered move-commit nodes are owned by
  `SceneControllerMutationBoundary.commitMoveSelection(...)`
- `MoveCommitDeltaRequest` owns a detached immutable snapshot of those nodes
  via `freezeList(...)`
- resolver code owns only the returned `Offset`; it never owns or mutates the
  commit-set itself

#### Entry and Exit Boundaries

- entry boundary:
  `commitMoveSelection(...)` freezes the ordered node set and constructs
  `MoveCommitDeltaRequest`
- callback boundary:
  app code receives only `MoveCommitDeltaRequest`
- exit boundary:
  resolver returns only `Offset resolvedDelta`; commit iteration consumes the
  boundary-owned frozen node snapshot

#### Permitted Extension Seam

- future interactive public callbacks that need structured engine-owned data
  must use immutable request/value objects instead of raw `List` / `Map` /
  `Set` parameters
- future move-commit request fields may be added inside
  `MoveCommitDeltaRequest` without reopening ownership of the node-set itself

#### Rejected Alternatives

- keep named callback parameters and freeze only at runtime dispatch — rejected
  because the public surface would still express a raw collection callback
  contract
- freeze in helper functions only and leave boundary code unchanged — rejected
  because it spreads a critical ownership guarantee outside the owner of the
  commit-set
- introduce a custom immutable list type for `movedNodes` — rejected because
  `Iterable<NodeSnapshot>` over a detached frozen list is sufficient and keeps
  the public contract simpler

#### Why This Level Is Correct

- the bug exists because the public callback surface and the authoritative
  commit-set share collection identity; both ownerships meet exactly at the
  mutation boundary and the public callback typedef
- moving to a request object fixes the behavior once at the shared owner and
  gives the guardrail a stable form to enforce across future exported callback
  typedefs
- the repository already treats public read-side values as immutable detached
  snapshots, so this change aligns interactive callback payloads with the
  dominant architectural model instead of inventing a special exception

### 4B. Architecture Decision Gate

Not needed. The user selected the breaking request-object form, and inspected
repository evidence fixes the owner and enforcement seams.

## 5. Locked Decisions

1. `MoveCommitDeltaRequest.movedNodes` is typed as
   `Iterable<NodeSnapshot>` in the public contract, but its constructor stores
   a detached frozen list produced by `freezeList(...)`.
2. `commitMoveSelection(...)` remains the primary owner of freeze timing; it
   constructs the authoritative ordered node snapshot, passes it into the
   request object, and iterates that same frozen snapshot for the commit loop.
3. The old named-parameter `MoveCommitDeltaResolver` shape is removed
   completely from public API, runtime wiring, internal test seams, and tests.
4. The new public-signature rule resolves typedef aliases and recursively
   rejects exported callback typedef parameter types whose effective SDK type
   graph contains `List`, `Map`, or `Set`; ordinary method returns or
   non-callback API shapes remain governed by existing rules.
5. Structural proof is split by owner:
   the callback raw-collection prohibition is proved in the public-signature
   guardrail tool suite, while resolver seam retirement is proved by the
   existing interaction-contract and architecture-boundary structural tests plus
   the public API surface check.

## 6. Result Requirements

1. App code can only receive move-commit resolver input through
   `MoveCommitDeltaRequest`, and `movedNodes` is detached immutable data.
2. Resolver code cannot affect the move commit-set or order by mutating
   callback payload collections, because the authoritative commit loop uses the
   boundary-owned frozen snapshot.
3. Interactive runtime purity and reentrancy behavior remain unchanged apart
   from the new request-object parameter shape.
4. Exported public callback typedefs with raw `List` / `Map` / `Set` types
   anywhere inside callback-parameter shapes, including typedef-alias,
   record-field, and nested-callback forms, fail `tool/check_guardrails.dart`.
5. Public docs and changelog describe the breaking resolver migration and the
   immutable request semantics.

## 7. Execution Order and Gates

### Required Order

- first, add a failing owner-side behavioral reproducer for move-commit
  payload mutability plus neighboring guard tests
- second, migrate the public typedef, request object, runtime wiring, and
  boundary ownership to the immutable request seam
- third, add the public-signature guardrail and its negative sandbox proof
- fourth, sync docs and release notes after the public surface is final

### Successor Seam and Retirement Gates

- successor seam:
  `MoveCommitDeltaRequest` plus `Offset Function(MoveCommitDeltaRequest
  request)`
- retirement gate:
  the old named-parameter resolver shape may be considered retired only after
  public API exports, internal test access, runtime wiring, and all interactive
  tests use the request object and the public API symbol golden is updated
- structural retirement gate:
  the raw-collection callback prohibition is retired only if the public
  signature guardrail and its sandbox tests still reject exported callback
  typedefs with `List` / `Map` / `Set` collection parameters both when written
  directly and when hidden behind typedef aliases

### Deferred Broad Verification

- `dart run tool/run_verification_preset.dart run --preset=required_code_change`
  is reserved for the final gate after code, guardrails, tests, and docs are
  all in place
- full guardrail tool execution is reserved for the final gate rather than
  mid-slice parallel runs

## 8. File Map

### Implementation Files

- `lib/src/interactive/scene_controller_interaction.dart`
- `lib/src/interactive/scene_controller.dart`
- `lib/src/interactive/internal/scene_controller_mutation_boundary.dart`
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- `lib/src/interactive/internal/scene_controller_graph.dart`
- `lib/src/interactive/internal/scene_controller_internal_access.dart`
- `tool/src/guardrails/rules/public/public_signature_rules.dart`

### Test Files

- `test/interactive/core/scene_controller_mutation_boundary_test.dart`
- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
- `test/interactive/core/scene_controller_interaction_contract_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/interactive/test_support/interactive_controller_fixtures.dart`
- `test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`
- `test/tool/public_api_surface_tool_test.dart`

### Fixtures and Supporting Data

- inline sandbox fixtures in
  `test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`
- `tool/goldens/public_api_symbols.txt`

### Registry, Inventory, and Workflow Files

- `PLAN.md`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `lib/iwb_canvas_engine.dart`

### Analysis Area

- `lib/src/interactive/**`
- `tool/src/guardrails/rules/public/**`
- `test/interactive/**`
- `test/tool/guardrails/**`

## 9. Implementation Rules

### Protected Invariants

- move-commit resolver purity guard remains active and reentrancy remains
  rejected
- committed read-side callback payloads remain immutable snapshots rather than
  live runtime aliases
- public interactive callback seams must not expose raw mutable collection
  parameters

### Required Proof

- behavioral proof:
  one failing reproducer first at the owner proving resolver payload mutation
  can currently affect commit ownership, plus 1 to 3 neighboring guard tests on
  the current seam for unchanged delta semantics, zero-delta skip, and existing
  resolver purity/reentrancy behavior
- structural proof:
  a guardrail sandbox test that fails when an exported callback typedef uses a
  raw collection parameter directly, through a typedef alias, or inside a
  nested callback/record parameter shape, plus an executable
  interaction-contract or architecture-boundary proof for the request-object
  resolver seam and the public API surface check for export retirement
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract
- for refactors: existing locking tests must be named or missing
  characterization tests must be added before structural edits, plus 1 to 3
  guard tests for neighboring branches when needed

### Allowed Change Surface

- the public interactive callback contract and its direct constructor wiring
- the move-commit owner boundary and its direct runtime plumbing
- internal test support needed to exercise the new request seam
- public-signature guardrail logic and sandbox tests
- required public docs and changelog for the breaking API change

### Forbidden Moves

- no `UnmodifiableListView` over a live internal list for `movedNodes`
- no duplicate authoritative node-set copy owned by the callback
- no legacy typedef alias, deprecated bridge, or compatibility overload
- no helper-only freeze that leaves `commitMoveSelection(...)` dependent on a
  caller-visible mutable collection

### Optional: Recognition Forms That Must Be Supported

- exported callback typedef with one request-object parameter must remain
  allowed
- request object fields may expose immutable collections through
  `Iterable<T>` backed by a detached frozen list

### Optional: Allowed Forms That Are Not Violations

- public methods or constructors with non-callback `List` parameters remain
  governed by existing public-surface rules and are not part of this new
  callback-specific prohibition
- exported callback typedefs that use SDK scalar types, public request/value
  objects, or immutable iterables are allowed

### Optional: Resolution Rules

- when the public-signature guardrail sees an exported callback typedef
  parameter whose resolved type graph contains SDK collection type `List`,
  `Map`, or `Set`, whether written directly, through a typedef alias, or
  inside a nested callback/record parameter shape, it must report a public
  signature hermeticity violation at the typedef source element

## 10. Vertical Slices

### Slice 1. [x] Lock the Defect at the Boundary Owner

#### Slice Contract

Add a failing reproducer at the move-commit boundary that demonstrates the old
resolver payload can alter commit ownership, plus neighboring guard coverage
for unchanged behavior on the current resolver seam.

#### Change

- add or update mutation-boundary and interactive resolver tests so the defect
  is executable before the owner-side fix lands

#### Behavioral Verification

- `flutter test test/interactive/core/scene_controller_mutation_boundary_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_actions_effects_test.dart`

#### Structural Verification

- existing source ownership remains unchanged for this slice; no new
  structural check is closed yet

#### Fixtures Used

- existing interactive controller fixtures and internal resolver-test access

#### Positive Scenarios

- resolver can still inspect snapshot, proposed delta, and ordered moved nodes
- existing zero-delta skip and purity guard behavior stay locked before the
  seam migration

#### Negative Scenarios

- resolver payload mutation must not be able to alter commit-set ownership once
  the owner fix lands

#### Closure Evidence

- the reproducer fails before the implementation change and passes after the
  owner-side fix

### Slice 2. [x] Replace the Public Resolver Seam with MoveCommitDeltaRequest

#### Slice Contract

Move the public resolver contract and runtime plumbing to the immutable
request-object seam and keep authoritative move-node ownership in the boundary.

#### Change

- add `MoveCommitDeltaRequest`
- replace the public typedef shape
- migrate runtime dispatch, graph wiring, internal access, and tests
- freeze the authoritative ordered node snapshot inside
  `commitMoveSelection(...)` and reuse it for resolver input and commit
  iteration

#### Behavioral Verification

- `flutter test test/interactive/core/scene_controller_mutation_boundary_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_actions_effects_test.dart`

#### Structural Verification

- `flutter test test/interactive/core/scene_controller_interaction_contract_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/check_public_api_surface.dart`

#### Fixtures Used

- `test/interactive/test_support/interactive_controller_fixtures.dart`
- `tool/goldens/public_api_symbols.txt`

#### Positive Scenarios

- resolver receives immutable moved-node iteration data through the request
  object
- resolved delta continues to drive commit translation and action payloads
- moved-node iteration order stays stable through request construction and
  commit application

#### Negative Scenarios

- no code path may still call `runMoveCommitDeltaResolver(...)` with the old
  named-parameter form
- request payload collections cannot be mutated to change commit-set ownership

#### Closure Evidence

- all interactive resolver tests pass on the request-object seam and the public
  API golden matches the new export surface

### Slice 3. [x] Enforce Raw-Collection Callback Prohibition

#### Slice Contract

Make raw `List` / `Map` / `Set` types anywhere inside exported callback
typedef parameter shapes fail the public-signature guardrail.

#### Change

- extend `public_signature_rules.dart`
- add sandbox tests for allowed request-object callbacks and rejected raw
  collection callback parameter shapes

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`

#### Structural Verification

- the guardrail itself is the structural proof and must fail on negative
  sandbox fixtures

#### Fixtures Used

- inline sandbox files inside
  `test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`

#### Positive Scenarios

- exported callback typedef using a public request object remains valid

#### Negative Scenarios

- exported callback typedef with `List<T>` parameter is rejected
- exported callback typedef with `Map<K, V>` or `Set<T>` parameter is rejected
- exported callback typedef with a typedef alias to `List<T>`, `Map<K, V>`, or
  `Set<T>` is rejected
- exported callback typedef with a record field typed as `List<T>`, `Map<K, V>`,
  or `Set<T>` is rejected
- exported callback typedef with a nested callback parameter typed as
  `List<T>`, `Map<K, V>`, or `Set<T>` is rejected

#### Closure Evidence

- the sandbox suite passes only when the new guardrail rule is active

### Slice 4. [x] Sync Public Contract Documents and Release Notes

#### Slice Contract

Update public docs and release notes to describe the new breaking resolver
contract and immutable request semantics.

#### Change

- update `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, and `CHANGELOG.md`
- update plan status after the implementation and proof are complete

#### Behavioral Verification

- `flutter test test/interactive/core/scene_controller_mutation_boundary_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`

#### Structural Verification

- `dart run tool/check_public_api_surface.dart`

#### Fixtures Used

- none

#### Positive Scenarios

- docs describe the breaking request-object migration accurately

#### Negative Scenarios

- no documentation may still describe the old named-parameter resolver shape

#### Closure Evidence

- docs and changelog align with the final code and plan step is marked
  complete

## 11. Final Verification

- write the actual repo-relative changed paths for this step into a temporary
  file such as `/tmp/step3_changed_paths.txt`, then run
  `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=/tmp/step3_changed_paths.txt`
- `flutter test test/interactive/core/scene_controller_mutation_boundary_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
- `flutter test test/interactive/core/scene_controller_interaction_contract_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`

## 12. Acceptance Criteria

- `MoveCommitDeltaResolver` is exported only as
  `Offset Function(MoveCommitDeltaRequest request)`
- `MoveCommitDeltaRequest` is a public immutable value object that freezes
  `movedNodes` as detached data
- `SceneControllerMutationBoundary.commitMoveSelection(...)` owns the
  authoritative frozen move-node snapshot and uses it for both resolver input
  and commit iteration
- interactive tests prove resolver input cannot change commit-set ownership
- guardrails reject exported callback typedefs with raw collection types
  anywhere inside callback-parameter shapes, including typedef-alias,
  record-field, and nested-callback forms
- `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `PLAN.md`,
  and the new step document reflect the final state
