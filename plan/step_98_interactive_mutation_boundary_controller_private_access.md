language: russian

# Шаг 98. Сузить committed mutation seam интерактива до controller-private access contract

## 1. Change Mandate

This change replaces the concrete `SceneStoreController` dependency at the
interactive committed mutation seam with one controller-private access contract
so `SceneControllerMutationBoundary` stops knowing controller command-family
internals directly.

## 2. Change Boundary

### Included in the Change

- introducing one controller-private committed-mutation access contract for the
  interactive mutation boundary
- rewiring `SceneControllerMutationBoundary` to depend on that access contract
  instead of `SceneStoreController`
- rewiring interactive assembly and guardrails/tests to pin the narrowed seam
- updating architecture and roadmap source-of-truth files for the narrowed
  boundary

### Not Included in the Change

- removing all `SceneStoreController` usage from `interactive/**`
- changing spatial query wiring, committed-store listener wiring, or other
  non-mutation `SceneStoreController` usage in
  `SceneControllerInteractionRuntime`
- changing public `SceneController`, `SceneControllerScene`,
  `SceneControllerSelection`, `SceneView`, or package export surface
- changing committed mutation behavior, action payloads, timestamp ordering, or
  gesture policy
- reopening step `85` routing closure for draw/line/erase writes; that routing
  stays valid and this step only narrows the dependency seam beneath it

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/controller/scene_controller_committed_mutation_access.dart`
- `lib/src/interactive/internal/scene_controller_mutation_boundary.dart`
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- `lib/src/interactive/internal/scene_controller_graph.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`
- `tool/invariant_registry.dart`
- `ARCHITECTURE.md`
- `PLAN.md`
- `plan/step_98_interactive_mutation_boundary_controller_private_access.md`

### Test Files

- `test/controller/core/scene_controller_committed_mutation_access_test.dart`
- `test/interactive/core/scene_controller_mutation_boundary_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

### Fixture and Supporting Data Files

- `test/tool/support/guardrails_tool_test_support.dart`
- `VERIFICATION.md`

### Analysis Area

- `lib/src/controller/**`
- `test/controller/**`
- `lib/src/interactive/internal/**`
- `tool/src/guardrails/**`
- `test/interactive/core/**`
- `test/tool/guardrails/**`
- `test/tool/support/**`
- `tool/invariant_registry.dart`
- `ARCHITECTURE.md`
- `PLAN.md`
- `plan/step_85*.md`
- `plan/step_98*.md`

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

1. This step narrows only the committed mutation seam beneath
   `SceneControllerMutationBoundary`; it does not attempt a full removal of
   `SceneStoreController` from `interactive/**`.
2. `SceneControllerMutationBoundary` remains the only interactive owner allowed
   to perform committed scene/selection/draw writes.
3. The new seam is one controller-private access contract with explicit
   first-class mutation methods; it must not preserve `commands` or `draw`
   sub-facades as the interactive dependency surface.
4. `SceneStoreController` remains the concrete owner of the underlying
   transactional core and signal behavior; the new access contract is only a
   narrowed controller-private bridge to that owner.
5. Existing committed mutation behavior, action emission, and draw-family
   routing from step `85` remain behaviorally unchanged.
6. Mechanical enforcement for the narrowed seam must land in the existing
   interactive guardrails and invariant coverage pipeline rather than prose
   only.

## 5. Result Requirements

1. `SceneControllerMutationBoundary` no longer imports or stores
   `SceneStoreController` directly.
2. The committed mutation seam is represented by exactly one controller-private
   access contract in
   `lib/src/controller/scene_controller_committed_mutation_access.dart`.
3. That access contract exposes first-class methods for every committed write
   operation currently used by `SceneControllerMutationBoundary` and does not
   expose `commands` or `draw` sub-facades.
4. `SceneControllerInteractionRuntime` and `scene_controller_graph.dart`
   assemble and pass the narrowed access contract into the mutation boundary
   while preserving the current draw/selection routing through
   `SceneControllerMutationBoundary`.
5. Architecture tests and interactive guardrails no longer pin
   `storeController.commands.*` or `storeController.draw.*` as the required
   implementation shape of `SceneControllerMutationBoundary`; they pin the new
   access contract instead.
6. `ARCHITECTURE.md` states that the mutation boundary depends on one
   controller-private committed mutation access seam instead of a concrete
   `SceneStoreController` shape.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `SceneControllerMutationBoundary` currently imports
  `scene_store_controller.dart`, stores `SceneStoreController`, and reaches
  into `commands`, `draw`, `prepareSceneReplacement`,
  `writePreparedSceneReplacement`, `requestRepaint`, `snapshot`,
  `selectedNodeIds`, and `centerWorldForNodeSnapshots`.
- `SceneControllerInteractionRuntimeRequest` currently carries
  `SceneStoreController` and `_createMutationBoundary(...)` passes that
  concrete object directly into the mutation boundary.
- `scene_controller_graph.dart` currently builds the interaction runtime only
  from `storeController` plus read closures; it does not assemble a narrower
  committed mutation seam.
- `test/interactive/core/scene_controller_architecture_boundary_test.dart` and
  `tool/src/guardrails/interactive_api_guardrails.dart` currently hard-pin
  `storeController.commands.*`, `storeController.draw.*`,
  `storeController.prepareSceneReplacement(...)`, and
  `storeController.writePreparedSceneReplacement(...)` as the expected internal
  shape of `SceneControllerMutationBoundary`.
- `ARCHITECTURE.md` currently pins `SceneControllerMutationBoundary` as the
  canonical committed-write owner but does not yet pin a narrowed
  controller-private access seam beneath that owner.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/controller/scene_controller_committed_mutation_access.dart lib/src/interactive/internal/scene_controller_mutation_boundary.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart lib/src/interactive/internal/scene_controller_graph.dart --report-all`
- MCP test runner: `test/interactive/core/scene_controller_mutation_boundary_test.dart`
- MCP test runner: `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

### 6.3 Protected States, Data, or Structures

- current committed write behavior of `SceneControllerMutationBoundary`
- current draw/selection callback routing through `SceneControllerMutationBoundary`
- `SceneStoreController` transactional ownership and signal semantics
- current non-mutation `SceneStoreController` usage inside
  `SceneControllerInteractionRuntime` for spatial queries and committed-store
  listening

### 6.4 Allowed Semantic Change Zones

- controller-private committed mutation dependency shape
- interactive owner-graph assembly for the mutation boundary input seam
- structural guardrail and architecture-proof shape for the narrowed seam
- architecture/roadmap wording for the narrowed dependency boundary

### 6.5 Recognition Forms That Must Be Supported Within This Change

- direct concrete field dependency on `SceneStoreController` inside
  `SceneControllerMutationBoundary`
- direct `storeController.commands.*` committed write calls inside
  `SceneControllerMutationBoundary`
- direct `storeController.draw.*` committed write calls inside
  `SceneControllerMutationBoundary`
- direct `storeController.prepareSceneReplacement(...)`,
  `storeController.writePreparedSceneReplacement(...)`, or
  `storeController.requestRepaint()` calls inside
  `SceneControllerMutationBoundary`
- guardrail fixtures or architecture proofs that still require the old
  `storeController.*` implementation tokens instead of the narrowed access
  contract

### 6.6 Allowed Forms That Do Not Count as Violations

- `SceneStoreController` remaining the concrete implementation behind the new
  controller-private access contract
- `SceneControllerInteractionRuntime` continuing to hold
  `SceneStoreController` for spatial queries and committed-store listener
  wiring in this step
- `SceneControllerMutationBoundary.write(...)` continuing to delegate into the
  transactional core through the narrowed access contract

### 6.7 Requirements for Resolution of Links and Structural Analysis

- Add `lib/src/controller/scene_controller_committed_mutation_access.dart`
  containing exactly:
  - `abstract interface class SceneControllerCommittedMutationAccess`
  - `final class SceneStoreControllerCommittedMutationAccess`
- `SceneControllerCommittedMutationAccess` must expose explicit first-class
  operations matching the current mutation-boundary surface:
  - `T write<T>(T Function(SceneWriteTxn writer) fn);`
  - `NodeId addNode(NodeSpec node, {LayerId? layerId, int? insertIndex});`
  - `bool ensureLayer(LayerId layerId, {int? index});`
  - `bool patchNode(NodePatch patch);`
  - `bool removeNode(NodeId id);`
  - `void setBackgroundColor(Color value);`
  - `void setGridEnabled(bool value);`
  - `void setGridCellSize(double value);`
  - `void setCameraOffset(Offset value);`
  - `ClearSceneResult clearSceneExactResult();`
  - `PreparedSceneReplacement prepareSceneReplacement(SceneSnapshot snapshot);`
  - `void writePreparedSceneReplacement(PreparedSceneReplacement replacement);`
  - `void requestRepaint();`
  - `void replaceSelection(Iterable<NodeId> nodeIds);`
  - `void toggleSelection(NodeId nodeId);`
  - `void clearSelection();`
  - `int selectAll({bool onlySelectable = true});`
  - `int transformSelection(Transform2D delta);`
  - `int deleteSelection();`
  - `NodeId commitDrawStroke({required List<Offset> points, required double thickness, required Color color, required double opacity});`
  - `NodeId commitDrawLineFromWorldSegment({required Offset start, required Offset end, required double thickness, required Color color, required double opacity});`
  - `int commitEraseNodes(Iterable<NodeId> ids);`
  - `SceneSnapshot get snapshot;`
  - `Set<NodeId> get selectedNodeIds;`
  - `Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots);`
- `SceneStoreControllerCommittedMutationAccess` must be a thin adapter over one
  `SceneStoreController` instance and must flatten current `commands` / `draw`
  families into those first-class methods without re-owning write behavior.
- `SceneControllerMutationBoundary` must depend only on
  `SceneControllerCommittedMutationAccess` plus its existing callback surface.
  It must not import `scene_store_controller.dart`.
- `scene_controller_graph.dart` must assemble
  `SceneStoreControllerCommittedMutationAccess(request.storeController)` and
  pass it into `SceneControllerInteractionRuntimeRequest` as a dedicated
  `mutationAccess` field.
- `SceneControllerInteractionRuntimeRequest` must carry both:
  - `SceneStoreController storeController` for unchanged spatial-query and
    listenable usage
  - `SceneControllerCommittedMutationAccess mutationAccess` for the committed
    mutation seam
- `tool/src/guardrails/interactive_api_guardrails.dart` and
  `test/interactive/core/scene_controller_architecture_boundary_test.dart`
  must stop requiring old `storeController.commands.*` /
  `storeController.draw.*` tokens inside the mutation boundary and must pin the
  new access-contract shape instead.
- Extend `INV-ENG-INTERACTIVE-MUTATION-BOUNDARY` so it covers the narrowed
  controller-private access seam and add a matching `// INV:` marker to
  `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` when
  `toolProof.regressionPath` is added for that invariant.

### 6.8 Prohibited

- exposing `commands` or `draw` as members of the new access contract
- making `SceneControllerMutationBoundary` depend on both the new access
  contract and `SceneStoreController`
- broadening this step into a full `interactive/** -> controller/**`
  deconcretization outside the committed mutation seam
- changing committed mutation behavior while narrowing the dependency shape

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the
   trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must be
   covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.
9. The plan must be detailed enough that the implementing agent has no
   material branch in how to execute a slice.
10. Every newly proposed file or directory name must comply with the global
    `AGENTS.md` section `### File naming` before the slice is considered valid.
11. If implementation reveals that spatial-query or listener wiring must be
    narrowed together with the committed mutation seam to keep the code
    coherent, execution must stop and that broader architectural move must be
    explicitly confirmed before the slice is expanded.

## 8. Vertical Slices

### Slice 1. [x] Introduce Controller-Private Committed Mutation Access

#### Slice Contract

The controller layer exposes one explicit controller-private committed mutation
access contract that flattens the current write families needed by the
interactive mutation boundary.

#### Change

Add `lib/src/controller/scene_controller_committed_mutation_access.dart` with
the exact interface and adapter shape fixed in section `6.7`.

The adapter must delegate to the existing `SceneStoreController` command and
draw families, plus `prepareSceneReplacement(...)`,
`writePreparedSceneReplacement(...)`, `requestRepaint()`, `snapshot`,
`selectedNodeIds`, and `centerWorldForNodeSnapshots(...)`, without moving
write behavior out of the controller layer.

#### Verification

- `dcm calculate-metrics lib/src/controller/scene_controller_committed_mutation_access.dart --report-all`
- MCP test runner: `test/controller/core/scene_controller_committed_mutation_access_test.dart`

#### Positive Scenarios

- The adapter preserves add/patch/remove, clear/delete/transform selection,
  draw-family commits, replace-scene preparation/apply, and repaint requests.
- A real `SceneStoreController` still exhibits the same committed results when
  exercised through `SceneStoreControllerCommittedMutationAccess`.

#### Negative Scenarios

- The new access contract does not expose `commands` or `draw` members.
- The adapter does not re-own signals or transaction semantics outside simple
  delegation.

#### Closure Evidence

- green run of the listed verifications
- new controller-private access file present with the exact interface/adapter
  shape fixed by this contract
- dedicated controller-level proof that the adapter is thin over
  `SceneStoreController` and does not re-own mutation behavior

### Slice 2. [x] Rewire Mutation Boundary And Interactive Assembly To The Narrowed Seam

#### Slice Contract

`SceneControllerMutationBoundary` and its assembly path consume the narrowed
controller-private access contract instead of a concrete `SceneStoreController`.

#### Change

Update:

- `lib/src/interactive/internal/scene_controller_mutation_boundary.dart`
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- `lib/src/interactive/internal/scene_controller_graph.dart`

so that:

- the mutation boundary field/constructor type becomes
  `SceneControllerCommittedMutationAccess`
- all direct `storeController.commands.*`, `storeController.draw.*`,
  `storeController.prepareSceneReplacement(...)`,
  `storeController.writePreparedSceneReplacement(...)`, and
  `storeController.requestRepaint()` calls are replaced with the matching
  first-class access methods
- `SceneControllerInteractionRuntimeRequest` receives a dedicated
  `mutationAccess` field
- `scene_controller_graph.dart` owns construction of
  `SceneStoreControllerCommittedMutationAccess(request.storeController)`

Leave `request.storeController` in place only for unchanged spatial-query and
committed-store listener wiring in this step.

#### Verification

- `dcm calculate-metrics lib/src/interactive/internal/scene_controller_mutation_boundary.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart lib/src/interactive/internal/scene_controller_graph.dart --report-all`
- MCP test runner: `test/interactive/core/scene_controller_mutation_boundary_test.dart`
- MCP test runner: `test/interactive/core/scene_controller_architecture_boundary_test.dart`

#### Positive Scenarios

- Interactive scene/selection shells still route committed writes through
  `SceneControllerMutationBoundary`.
- Draw-family commits still route through the mutation boundary and preserve
  current action/result behavior.

#### Negative Scenarios

- `SceneControllerMutationBoundary` no longer imports
  `scene_store_controller.dart`.
- The mutation boundary no longer contains direct `storeController.commands.*`
  or `storeController.draw.*` calls.
- `scene_controller_graph.dart` and
  `SceneControllerInteractionRuntimeRequest` no longer leave mutation-boundary
  construction to a concrete `SceneStoreController` dependency alone.

#### Closure Evidence

- green run of the listed verifications
- source proof that the narrowed access contract is the only committed mutation
  seam beneath `SceneControllerMutationBoundary`

### Slice 3. [x] Update Mechanical Proofs And Architecture Source Of Truth

#### Slice Contract

Guardrails, structural proofs, invariants, and architecture documentation pin
the narrowed controller-private committed mutation seam and reject return of
the old concrete controller dependency.

#### Change

Update:

- `tool/src/guardrails/interactive_api_guardrails.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/support/guardrails_tool_test_support.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `tool/invariant_registry.dart`
- `ARCHITECTURE.md`
- `PLAN.md`
- this step file

so the repository mechanically rejects the old shape and accepts the new one.

The interactive guardrails and architecture test must reject:

- concrete `SceneStoreController` field typing in the mutation boundary
- old `storeController.commands.*` and `storeController.draw.*` implementation
  tokens in the mutation boundary

They must accept:

- `SceneControllerCommittedMutationAccess`
- the dedicated `mutationAccess` wiring in the interaction runtime request
- first-class access method calls from the mutation boundary

Extend `INV-ENG-INTERACTIVE-MUTATION-BOUNDARY` in
`tool/invariant_registry.dart` with:

- `tool/check_guardrails.dart` as `toolProof.enforcementPath`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` as
  `toolProof.regressionPath`

and add the corresponding `// INV:` marker to that tool test file.

#### Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/interactive/core/scene_controller_architecture_boundary_test.dart`

#### Fixtures Used

- `test/tool/support/guardrails_tool_test_support.dart`

#### Positive Scenarios

- Guardrails accept the narrowed access-contract shape and the routing-only
  scene/selection shells.
- Invariant coverage passes with the extended mutation-boundary proof surface.

#### Negative Scenarios

- Sandbox mutation-boundary fixtures that reintroduce concrete
  `SceneStoreController` dependency fail `check_guardrails.dart`.
- Sandbox/runtime proof fixtures that reintroduce direct
  `storeController.commands.*` or `storeController.draw.*` calls in the
  mutation boundary fail `check_guardrails.dart`.

#### Closure Evidence

- green run of the listed verifications
- guardrail diagnostics naming the old concrete controller seam as invalid
- updated invariant registry entry and matching `// INV:` markers

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/controller/scene_controller_committed_mutation_access.dart lib/src/interactive/internal/scene_controller_mutation_boundary.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart lib/src/interactive/internal/scene_controller_graph.dart --report-all`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP shard preset `core`
- MCP shard preset `model_contract`
- MCP shard preset `controller_internal`
- MCP shard preset `controller`
- MCP shard preset `render_view`
- MCP shard preset `interactive`
- MCP shard preset `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
