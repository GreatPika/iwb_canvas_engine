# Change Contract

## Goal

Pointer sessions end reliably when a terminal pointer event has an unusable
position. Public callers and the Flutter surface use one explicit terminal
cleanup input path, while normal pointer samples keep the invariant that
coordinates are finite.

## Source Inputs

- Design: `.design/2026-06-10-api-surface-invalid-terminal-cleanup.md`
- Research: `.research/2026-06-10-api-surface-invalid-terminal-cleanup.md`
- Phase: none
- PLAN: `PLAN.md`
- Other:
  - `AGENTS.md`
  - `docs/README.md`
  - user clarification recorded by the design on 2026-06-10: there are no
    current external users, so public API breakage is acceptable when it
    improves cleanliness, simplicity, and reliability.

## Classification

Profile: BEHAVIOR_CHANGE

Obligations: BUG_FIX, PUBLIC_API_CHANGE

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| D1: Public pointer input becomes a sealed finite-sample / terminal-cleanup union, and `CanvasToolPort.handlePointer` accepts the union instead of only `CanvasPointerSample`. | `Boundaries.Source of Truth`; `Boundaries.Compatibility`; `Unit 1`; `Unit 2` | public API constructor tests, public compile fixture, export/registry checks |
| D2: `CanvasPointerSample` remains finite-only for every phase; invalid terminal cleanup is represented by a no-position cleanup variant. | `Boundaries.Source of Truth`; `Unit 1`; `Unit 2` | finite-sample validation tests and interaction classifier proof that cleanup input never produces a non-finite `NormalizedPointerSample` |
| D3: Surface admission drops non-finite down/move and routes non-finite up/cancel as terminal cleanup input. | `Boundaries.In Scope`; `Unit 3` | surface widget tests through real `Listener` callbacks |
| D4: Runtime interaction branches on cleanup input before coordinate normalization and routes through existing invalid-terminal cleanup admission. | `Boundaries.Order Constraints`; `Unit 2` | direct interaction/runtime tests for cleanup-only or ignored admission before normalization |
| D5: Cleanup input is terminal-only and timestamp-silent: no commits, user actions, context requests, or output timestamp reservations. | `Boundaries.Compatibility`; `Unit 2`; `Unit 3` | runtime and surface observer tests asserting no document/action/context/timestamped output |
| D6: Docs, public registry, durable diagrams, and public compile fixtures must be updated because the public source of truth changes. | `Boundaries.Source of Truth`; `Unit 4` | docs registry checks, generated-doc checks, and semantic search for retired sample-only pointer dispatch wording |
| Repository plan workflow requires linked step contracts to preserve planning/implementation evidence separation. | `Execution Units`; `Completion Check` fields | all execution unit checkboxes remain unchecked until implementation evidence exists |

## Evidence

- `.design/2026-06-10-api-surface-invalid-terminal-cleanup.md:13` / `Design disposition`: design is marked `READY_FOR_CONTRACT` -> contract can proceed without a blocker.
- `.design/2026-06-10-api-surface-invalid-terminal-cleanup.md:29` / `Classification`: selected profile is `BEHAVIOR_CHANGE` with `BUG_FIX` and `PUBLIC_API_CHANGE` obligations -> contract must preserve those obligations.
- `.design/2026-06-10-api-surface-invalid-terminal-cleanup.md:264` / `Selected form`: selected design keeps `CanvasPointerSample` finite-only and validates `position` for every phase -> public DTO unit must not relax sample coordinate validation.
- `.design/2026-06-10-api-surface-invalid-terminal-cleanup.md:267` / `Selected form`: selected design adds terminal cleanup input with no position -> invalid terminal cleanup must use the cleanup variant instead of non-finite sample coordinates.
- `.design/2026-06-10-api-surface-invalid-terminal-cleanup.md:271` / `Selected form`: `CanvasToolPort.handlePointer` accepts `CanvasPointerInput` instead of `CanvasPointerSample` -> public tool port seam must change as a breaking API update.
- `.design/2026-06-10-api-surface-invalid-terminal-cleanup.md:273` / `Selected form`: surface maps finite events to samples, drops non-finite down/move, and maps non-finite up/cancel to cleanup input -> surface adapter unit owns phase-specific admission policy.
- `.design/2026-06-10-api-surface-invalid-terminal-cleanup.md:276` / `Selected form`: `RuntimeRoot.handlePointer` remains the shared public/surface admission owner -> runtime admission must not split into separate public and surface cleanup paths.
- `.design/2026-06-10-api-surface-invalid-terminal-cleanup.md:277` / `Selected form`: interaction branches on the input variant before coordinate normalization -> runtime/interaction unit must prove cleanup input never enters world-position normalization.
- `.research/2026-06-10-api-surface-invalid-terminal-cleanup.md:13` / `Shared cause`: API-002 and SURFACE-002 both concern terminal pointer input with non-finite position -> one shared public/surface design is required instead of local patches.
- `.research/2026-06-10-api-surface-invalid-terminal-cleanup.md:15` / `Public API gap`: current constructor cannot represent non-finite terminal up/cancel samples -> public API representation must change.
- `.research/2026-06-10-api-surface-invalid-terminal-cleanup.md:17` / `Surface gap`: current Flutter surface drops non-finite terminal events before runtime cleanup -> surface routing must admit terminal cleanup input.
- `.research/2026-06-10-api-surface-invalid-terminal-cleanup.md:13` / `Issue source`: API-002 is classified as a public API issue -> public contract and export surfaces are in scope.
- `.research/2026-06-10-api-surface-invalid-terminal-cleanup.md:13` / `Issue source`: SURFACE-002 is classified as a Flutter surface issue -> surface widget proof is in scope.
- `docs/contracts/public_api_v1.md:1466` / `Timestamp contract`: no-op, stale rejection, rollback, cancel, load cleanup, and dispose close paths do not create timestamped action or context request outputs -> terminal cleanup input must remain timestamp-silent.
- `docs/contracts/public_api_v1.md:1470` / `Timestamp contract`: invalid terminals remain timestamp-silent -> cleanup proof must assert no timestamped output, not only preview cleanup.
- `docs/contracts/public_api_v1.md:166` / `Public equality`: equality behavior is part of the public API contract -> new concrete public pointer input types need an explicit equality policy.
- `docs/contracts/public_api_v1.md:236` / `Future public types`: future public types must choose value or identity equality before implementation -> contract must settle equality for `CanvasPointerTerminalCleanup`.
- `docs/contracts/public_api_v1.md:1573` / `Pointer phases`: pointer lifecycle phases are `down`, `move`, `up`, and `cancel` -> cleanup input is terminal-only for `up` and `cancel`.
- `docs/contracts/public_api_v1.md:1726` / `Public tool seam`: `CanvasToolPort.handlePointer` currently accepts `CanvasPointerSample` -> public API break must update this signature and compile fixture.
- `docs/contracts/public_api_v1.md:1787` / `Validation contract`: public validation distinguishes finite down/move positions from invalid terminal cleanup routing -> selected union preserves this distinction without putting invalid coordinates into samples.
- `docs/contracts/public_api_v1.md:1793` / `Pointer routing`: pointer id routes samples and rejects stale terminal samples -> cleanup input must retain `pointerId`.
- `docs/contracts/public_api_v1.md:1794` / `Pointer session`: one runtime has at most one active pointer session -> cleanup classification targets the single active session and adds no multi-pointer store.
- `docs/_registry/public_api_v1.yaml:66` / `Public registry`: `CanvasPointerSample` is registry-backed public API -> new public input declarations require registry and docs updates.
- `lib/src/contracts/public/canvas_pointer.dart:92` / `Public DTO owner`: `CanvasPointerSample` factory owns public sample construction -> finite-sample validation belongs at this boundary.
- `lib/src/contracts/public/canvas_pointer.dart:100` / `Public DTO invariant`: `CanvasPointerSample` validates `position` for every phase -> implementation must not route non-finite coordinates through this sample.
- `lib/src/contracts/public/canvas_preview.dart:16` / `Public API pattern`: existing public contracts use sealed variants -> public pointer input union matches an established API style.
- `lib/src/contracts/public/canvas_tools.dart:121` / `Public tool seam`: `CanvasToolPort.handlePointer` is sample-only today -> signature migration is required.
- `lib/src/surface/pointer_adapter.dart:13` / `Surface route type`: adapter callback is sample-only today -> surface routing must change to the input union.
- `lib/src/surface/pointer_adapter.dart:25` / `Surface terminal callback`: `onPointerUp` already routes into the phase path -> non-finite up can be mapped at the adapter boundary.
- `lib/src/surface/pointer_adapter.dart:28` / `Surface terminal callback`: `onPointerCancel` already routes into the phase path -> non-finite cancel can be mapped at the adapter boundary.
- `lib/src/surface/pointer_adapter.dart:37` / `Surface finite guard`: current adapter returns on any non-finite local position before routing -> guard must become phase-aware.
- `lib/src/api/canvas_runtime_surface_bridge.dart:60` / `Surface port seam`: surface port pointer entry is sample-only today -> it must accept the same public input as the tool port.
- `lib/src/api/canvas_runtime_surface_bridge.dart:61` / `Surface guard`: active-token guard runs before runtime pointer handling -> inactive-surface no-op behavior must be preserved for cleanup input.
- `lib/src/runtime/runtime_root.dart:1245` / `Runtime admission`: runtime pointer handling begins at `RuntimeRoot.handlePointer` after mutation guard -> runtime remains the shared admission owner.
- `lib/src/runtime/runtime_root.dart:1266` / `Commit delivery`: pointer commit delivery is admission-driven and uses `sample.timestampMs` today -> cleanup input must not force commit delivery or timestamp reservation.
- `lib/src/runtime/runtime_root.dart:1272` / `Public state`: runtime state publication is admission-driven -> cleanup input may publish only when cleanup changes preview/session state.
- `lib/src/interaction/interaction_engine.dart:348` / `Interaction routing`: current interaction handling normalizes before phase routing -> cleanup input needs a pre-normalization branch.
- `lib/src/interaction/interaction_engine.dart:831` / `Cleanup classifier`: existing terminal decisions route to `_handleInvalidTerminal` -> cleanup input should extend existing cleanup classification, not create a parallel mechanism.
- `lib/src/interaction/interaction_engine.dart:1395` / `Cleanup admission`: invalid terminal handling returns `cleanupOnly` or `ignored` -> required behavior has an existing admission shape.
- `lib/src/interaction/interaction_engine.dart:1406` / `Line cleanup exception`: stale-pointer invalid terminal handling has line-specific cleanup behavior -> cleanup input must preserve this existing `stalePointer` line cleanup instead of treating every stale pointer as ignored.
- `lib/src/interaction/interaction_pointer_context.dart:11` / `Admission shape`: `InteractionPointerAdmission` is the bounded pointer admission result -> cleanup input must use this admission result instead of a separate protocol.
- `lib/src/interaction/interaction_pointer_context.dart:28` / `Admission sample`: admission currently requires a `NormalizedPointerSample` -> cleanup-input admission must make this finite-sample payload absent for cleanup-only/ignored cleanup input rather than fabricating coordinates.
- `lib/src/interaction/pointer_sample_normalizer.dart:45` / `Normalization owner`: normalizer copies sample coordinates into normalized view/world positions -> cleanup input must not flow through this path.
- `lib/src/interaction/pointer_sample_normalizer.dart:53` / `Geometry invariant`: world position is computed from sample position and camera offset -> preserving finite sample coordinates protects downstream geometry.
- `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:13` / `Surface proof seam`: existing widget fixture covers finite phase mapping -> extend this seam for terminal cleanup routing.
- `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:211` / `Negative surface proof`: existing fixture covers non-finite surface no-effect behavior -> split down/move no-effect proof from terminal cleanup proof.
- `test/interaction/pointer_session_test.dart:21` / `Interaction proof seam`: interaction tests already cover stale terminal cleanup-only behavior -> add explicit cleanup-input proof at the same owner.
- `test/interaction/fixtures/line_interaction_routing_fixture.dart:311` / `Line cleanup proof`: existing line endpoint invalid terminal clears pending line -> cleanup input must not regress stale/invalid line cleanup.
- `test/interaction/fixtures/line_interaction_routing_fixture.dart:342` / `Line stale proof`: existing line endpoint stale terminal clears pending line -> cleanup input must preserve stale-pointer line cleanup semantics.
- `test/api_contract/public_api_v1_compiles_as_written_test.dart:379` / `Public compile proof`: public API compile fixture constructs `CanvasPointerSample` -> update fixture to cover finite samples and terminal cleanup input.
- `test/api_contract/public_equality_policy_test.dart:25` / `Public equality proof`: public equality policy is tested from consumer code -> new public pointer input equality policy must update this proof.
- `docs/diagrams/dfd_pointer_preview_commit.mmd:12` / `Durable docs`: durable diagram names `CanvasPointerSample` and terminal cleanup via invalid sample -> docs/diagram update or verification is mandatory.

## Boundaries

Owner:

- Public pointer input representation is owned by
  `lib/src/contracts/public/canvas_pointer.dart` and exported through the
  existing public API facade/barrel path.
- Public dispatch signature is owned by `CanvasToolPort` and the matching
  surface/runtime port seams that call `RuntimeRoot.handlePointer`.
- Flutter event admission is owned by `CanvasSurfacePointerAdapter`.
- Runtime pointer admission remains owned by `RuntimeRoot.handlePointer`.
- Invalid terminal cleanup classification and preview/session cleanup remain
  owned by the interaction pointer path and existing cleanup coordinator.
- Durable public meaning is owned by `docs/contracts/public_api_v1.md`,
  `docs/_registry/public_api_v1.yaml`, docs registries, durable diagrams, and
  generated docs derived from those sources.

In Scope:

- Add a public sealed pointer input owner, shaped as `CanvasPointerInput`, with
  `CanvasPointerSample` as the finite coordinate variant and terminal cleanup
  input, shaped as `CanvasPointerTerminalCleanup`, as the no-position terminal
  variant.
- Keep `CanvasPointerSample` finite-only for every phase, including `up` and
  `cancel`.
- Validate terminal cleanup input at the public boundary: `phase` is only
  `up` or `cancel`, `pointerId` and optional `timestampMs` satisfy existing
  public value rules, and `kind` is preserved.
- Change `CanvasToolPort.handlePointer`, `CanvasRuntimeSurfacePort.handlePointer`,
  `RuntimeRoot.handlePointer`, and interaction admission to accept the public
  input union.
- Keep active-surface and runtime mutation guards before cleanup admission.
- Route cleanup input before coordinate normalization and through existing
  invalid-terminal cleanup admissions.
- Update Flutter surface routing so finite events create samples, non-finite
  down/move remain no-effect, and non-finite up/cancel create terminal cleanup
  input.
- Update tests, public compile fixtures, public API registry/export checks,
  public contract docs, durable diagrams, generated docs, and verification docs
  that encode sample-only pointer dispatch or invalid-terminal sample wording.
- Prove cleanup input is commit-silent, action-silent, context-request-silent,
  timestamp-silent, and does not create non-finite normalized geometry.

Out of Scope:

- Changing pointer behavior for valid finite coordinates.
- Adding multi-pointer storage, queues, synchronizers, or concurrent session
  handling.
- Making non-finite down or move input cleanup-capable.
- Adding a surface-only cleanup API or bridge that bypasses shared runtime
  pointer admission.
- Relaxing `CanvasPointerSample` so non-finite coordinates are valid for any
  phase.
- Changing document schema, committed document formats, resource persistence,
  draw/select/move/eraser semantics for finite samples, or public timestamp
  semantics unrelated to pointer cleanup.
- Preserving backward compatibility with the old sample-only
  `handlePointer(CanvasPointerSample sample)` signature through adapter overloads
  or duplicate public entry points.

Source of Truth:

- `CanvasPointerInput` is the single public source of truth for pointer dispatch
  input shape. As the sealed owner, it adds no separate equality contract beyond
  the concrete variant instances.
- `CanvasPointerSample` owns finite coordinate samples only.
- `CanvasPointerTerminalCleanup` owns invalid terminal cleanup intent and carries
  no coordinate data. It uses value equality over `pointerId`, `phase`, `kind`,
  and `timestampMs`.
- Runtime and surface ports must consume the same public input union; no second
  source of truth may be introduced for surface-only cleanup.
- `InvalidTerminalCleanupKind.invalidTerminalPosition` is the cleanup classifier
  source for no-position terminal cleanup input; it maps to existing
  `PointerCleanupReason.invalidTerminal`.
- `docs/contracts/public_api_v1.md` and `docs/_registry/public_api_v1.yaml`
  must describe and register the public API shape after implementation.

Compatibility:

- This is an intentional breaking public API change: callers of
  `CanvasToolPort.handlePointer(CanvasPointerSample)` must pass
  `CanvasPointerInput` instead.
- The break is accepted only because the design records the product constraint
  that no current external users exist.
- Runtime behavior for finite pointer samples remains compatible.
- Public lifecycle phase names remain stable.
- Invalid terminal cleanup remains timestamp-silent and output-silent.

Order Constraints:

1. Introduce the public input union declarations, validation, equality policy,
   exports, and registry entries without changing `handlePointer` signatures.
2. Atomically migrate `CanvasToolPort.handlePointer`, `_RuntimeToolPort`,
   `RuntimeRoot.handlePointer`, and interaction admission to the union input so
   the public tool seam remains compilable and verified in one unit.
3. Branch terminal cleanup input before coordinate normalization and route it
   through existing invalid-terminal cleanup admission as part of the same
   atomic public/runtime migration.
4. Update surface non-finite admission and `CanvasRuntimeSurfacePort` after the
   runtime cleanup input path exists, using the same public input union.
5. Update public contract docs, registry, compile fixture, durable diagrams, and
   generated docs after the public type names and signatures are settled.
6. Run semantic search for old sample-only dispatch and invalid-terminal sample
   wording after docs/code updates, then run required code/docs checks.

Temporal Surface Closure:

- Temporal invariant: pointer handling remains synchronous from direct public
  call or Flutter `Listener` callback through runtime admission, cleanup
  classification, optional cleanup mutation, and optional public state
  publication.
- Synchronous callback surfaces: `Listener` pointer callbacks,
  `CanvasSurfacePointerAdapter.routeSample` or replacement input callback,
  `CanvasRuntimeSurfacePort.handlePointer`, `CanvasToolPort.handlePointer`,
  `RuntimeRoot.handlePointer`, and interaction pointer admission.
- Guard owners: active-surface token guard in `CanvasRuntimeSurfacePort` and
  runtime mutation guard in `RuntimeRoot`.
- Allowed public observation order: input validation and guard checks complete
  before interaction admission; cleanup mutation happens before runtime state
  publication; cleanup input produces no commit/action/context-request delivery.
- Reentrant or interleaved mutation expectation: inactive surface input and
  runtime mutation guard rejection remain no-mutation paths; cleanup input with
  no active cleanup need returns ignored/no-op.

All-Or-Nothing Failure Boundary:

- Fallible work before the irreversible point: public input construction and
  validation, surface event admission and input construction, active-surface
  guard, and runtime mutation guard.
- Irreversible point: applying interaction cleanup and publishing runtime state
  for cleanup that changes preview/session state.
- Later work: cleanup input is failure-contained because no document commit,
  resolver request, user action, context request, or timestamped output is
  created after cleanup-only admission.
- Failure projection: stale preview/session state if cleanup is not applied, or
  unexpected document/action/context/timestamp output if cleanup escapes its
  boundary.
- Proof surface: runtime and surface tests with preview/session, document,
  action, context request, and timestamp-sensitive observers.

## Execution Units

### [x] Unit 1: Public pointer input declarations and equality

Owner:

- Public pointer contract declarations, public exports, public equality policy,
  and public API registry proof.

Boundary:

- `lib/src/contracts/public/canvas_pointer.dart`, public pointer facade/barrel
  exports, `docs/_registry/public_api_v1.yaml` entries for the new pointer input
  declarations only, public API registry/export tests, public constructor tests,
  and
  `test/api_contract/public_equality_policy_test.dart`.

Change:

- Introduce the public sealed `CanvasPointerInput` owner.
- Keep `CanvasPointerSample` as the finite coordinate input variant with
  existing finite position validation for every phase.
- Add `CanvasPointerTerminalCleanup` as the no-position terminal cleanup input
  variant with public validation for `pointerId`, terminal-only phase, `kind`,
  and optional non-negative `timestampMs`.
- Give `CanvasPointerTerminalCleanup` value equality over `pointerId`, `phase`,
  `kind`, and `timestampMs`; do not add an additional equality contract to the
  sealed `CanvasPointerInput` owner.
- Export and register only the new public input declarations needed for
  `CanvasPointerInput` and `CanvasPointerTerminalCleanup`.
- Update public constructor, equality, registry, and export tests for the new
  public input declarations without changing `handlePointer` signatures yet.

Completion Check:

- Claim: public callers can express invalid terminal cleanup without allowing
  non-finite coordinates into `CanvasPointerSample`.
- Direct outcome: `CanvasPointerTerminalCleanup` can be constructed for `up` and
  `cancel` without `position`; construction rejects `down` and `move`;
  `CanvasPointerSample` still rejects non-finite position for all phases; two
  independently-created `CanvasPointerTerminalCleanup` instances with the same
  `pointerId`, `phase`, `kind`, and `timestampMs` compare equal and have the
  same `hashCode`.
- Proxy risk: export or compile success alone could pass while validation allows
  invalid phases or sample coordinates.
- Required proof: focused public constructor tests for finite sample and
  terminal cleanup validation, public export/registry tests that include
  `CanvasPointerInput` and `CanvasPointerTerminalCleanup`, and
  `dart test test/api_contract/public_equality_policy_test.dart` updated for
  `CanvasPointerTerminalCleanup` value equality.

Depends On:

- none

### [x] Unit 2: Atomic public runtime pointer seam migration

Owner:

- Public tool pointer seam, runtime pointer admission, and interaction
  invalid-terminal cleanup classification.

Boundary:

- `lib/src/contracts/public/canvas_tools.dart`,
  `lib/src/runtime/runtime_root.dart`,
  `lib/src/interaction/interaction_engine.dart`,
  `lib/src/interaction/pointer_sample_normalizer.dart`,
  `lib/src/interaction/interaction_pointer_context.dart`, direct runtime/API
  tests, public API compile fixture, and interaction classifier/session tests.

Change:

- Change `CanvasToolPort.handlePointer`, `_RuntimeToolPort.handlePointer`,
  `RuntimeRoot.handlePointer`, and the interaction pointer entry to accept
  `CanvasPointerInput` in one compilable unit.
- Branch cleanup input before `PointerSampleNormalizer.normalizePublicSample`.
- Extend the existing `InvalidTerminalCleanupKind` /
  `InvalidTerminalCleanupDecision` classifier with exactly one explicit cleanup
  signal kind named `invalidTerminalPosition`.
- Classify `CanvasPointerTerminalCleanup` as `invalidTerminalPosition` with
  `shouldCleanupActiveSession: true` only when the cleanup input targets the
  current active pointer session and current controller epoch.
- Preserve existing `noActiveSession` and `stalePointer` decisions for missing
  or mismatched active sessions. `noActiveSession` remains ignored/no-cleanup;
  `stalePointer` must continue through `_shouldCleanupLineInvalidTerminal`, so
  line first-tap/endpoint sessions still clear pending line and preview while
  non-line stale pointers remain ignored/no-cleanup.
- Preserve existing `staleControllerEpoch` behavior for cleanup input when the
  pointer id matches the active session but the interaction context epoch is
  stale; this remains cleanup-only, keeps the existing cleanup reason, and stays
  output/timestamp-silent.
- Route `invalidTerminalPosition` through the existing invalid-terminal cleanup
  admission and map it to `PointerCleanupReason.invalidTerminal`; do not add a
  second cleanup protocol, surface-only bridge, or alternative classifier owner.
- Update `InteractionPointerAdmission` so cleanup-only/ignored cleanup-input
  admissions can carry no `NormalizedPointerSample`; finite-sample admissions
  and all commit-producing admissions must still carry a finite normalized
  sample.
- Preserve runtime mutation guard, cleanup-only/ignored admission behavior, and
  optional state publication only when cleanup changes preview/session state.
- Ensure cleanup input creates no document commit, user action, context request,
  resolver request, or output timestamp reservation.

Completion Check:

- Claim: direct public runtime cleanup uses the shared cleanup owner and never
  sends non-finite coordinates through normalized geometry or output delivery.
- Direct outcome: at the interaction seam, same-active-pointer terminal cleanup
  input records `invalidTerminalPosition` cleanup-only admission; no-active or
  stale-pointer cleanup input records the existing decision, including
  line-owned stale-pointer cleanup for pending line sessions and ignored/no-op
  behavior for non-line stale pointers; matching-pointer cleanup input with a
  stale interaction context epoch records the existing `staleControllerEpoch`
  cleanup-only decision.
  Through the public `runtime.tools.handlePointer(...)` void seam, finite down
  creates an active preview/session and terminal cleanup input clears that
  preview/session with no return-value change, and public consumer code compiles
  with `CanvasToolPort.handlePointer(CanvasPointerInput)`. No
  `NormalizedPointerSample` is created from cleanup input; no
  document/action/context/timestamped output is created.
- Proxy risk: asserting only preview cleanup could hide NaN geometry flow or
  stray timestamped outputs.
- Required proof: interaction tests around the classifier/admission seam proving
  `invalidTerminalPosition` is emitted only for same-active-pointer cleanup
  input at the current interaction context epoch and branches before
  `normalizePublicSample`, cleanup-input tests proving matching-pointer stale
  context epoch preserves `staleControllerEpoch` cleanup-only behavior and
  no-output/timestamp-silent semantics, admission tests proving cleanup-input
  cleanup-only/ignored results have no normalized sample while finite
  commit-producing admissions still have one, direct runtime/API tests with
  preview/session, document, action, context request, and timestamp observers,
  focused line interaction tests proving cleanup input preserves
  `_shouldCleanupLineInvalidTerminal` behavior for stale line terminals, and
  focused tests that cleanup-only and ignored admissions preserve the existing
  no-output behavior. Also run
  `dart test test/api_contract/public_api_v1_compiles_as_written_test.dart`
  updated to compile both finite sample and terminal cleanup input through the
  public tool seam.

Depends On:

- Unit 1

### [x] Unit 3: Flutter surface terminal admission

Owner:

- Flutter surface pointer adapter and active surface routing.

Boundary:

- `lib/src/surface/pointer_adapter.dart`,
  `lib/src/surface/canvas_surface_widget.dart`,
  `lib/src/api/canvas_runtime_surface_bridge.dart`, surface adapter fixtures,
  and surface widget tests through real `Listener` callbacks.

Change:

- Change the surface pointer route callback and `CanvasRuntimeSurfacePort` to
  accept `CanvasPointerInput`.
- Preserve active-surface token guard before runtime admission.
- Keep finite down/move/up/cancel mapping to `CanvasPointerSample`.
- Keep non-finite down/move as no-effect input.
- Map non-finite up/cancel to `CanvasPointerTerminalCleanup` with pointer id,
  terminal phase, device kind, and optional timestamp.

Completion Check:

- Claim: the Flutter surface routes non-finite terminal input to shared runtime
  cleanup while preserving down/move no-effect behavior and inactive-surface
  no-op behavior.
- Direct outcome: through real `Listener` callbacks, finite down creates
  preview/session, non-finite up/cancel clears preview/session through runtime
  cleanup and produces no document/action/context/timestamped output; non-finite
  down/move produce no preview, state tick, document mutation, action, or route
  side effect; stale or inactive surface callbacks remain no-op.
- Proxy risk: testing only adapter callback payloads could miss runtime cleanup,
  state publication, or inactive-token guard regressions.
- Required proof: extend
  `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart` or a
  focused sibling surface fixture to drive `PointerDownEvent` followed by
  non-finite `PointerUpEvent` and `PointerCancelEvent` through `Listener`, assert
  preview/session cleanup and no document/action/context output, keep existing
  non-finite down/move no-effect assertions, cover inactive/stale surface
  no-op behavior, and add a structural test or reviewed semantic-search proof
  over `lib/src/surface` and `lib/src/api/canvas_runtime_surface_bridge.dart`
  showing the surface terminal cleanup route calls `CanvasRuntimeSurfacePort.handlePointer`
  and no separate invalid-terminal cleanup bridge or surface-only cleanup method
  bypasses `RuntimeRoot.handlePointer`.

Depends On:

- Unit 1
- Unit 2

### [x] Unit 4: Public source-of-truth docs and retirement proof

Owner:

- Public API contract, registries, durable diagrams, generated docs, and
  verification documentation that describe pointer input shape.

Boundary:

- `docs/contracts/public_api_v1.md`, `docs/contracts/interaction_engine.md`,
  docs registries other than the Unit 1 declaration-registration entries,
  `docs/diagrams/*.mmd`, generated docs/indexes, verification docs,
  architecture docs only where they encode pointer dispatch shape, and docs
  checks.

Change:

- Update public contract docs to describe `CanvasPointerInput`,
  `CanvasPointerSample`, `CanvasPointerTerminalCleanup`, terminal-only cleanup
  validation, and `CanvasToolPort.handlePointer(CanvasPointerInput)`.
- Update the public equality policy section so `CanvasPointerTerminalCleanup`
  is listed as a value-equality type and `CanvasPointerInput` is not listed as a
  separate concrete equality contract.
- Verify the Unit 1 registry/export entries are reflected in generated docs; do
  not use Unit 4 to add a second owner for public declaration registration.
- Update durable diagrams and docs that encode sample-only pointer dispatch or
  invalid-terminal sample wording.
- Run and resolve a semantic search over at least `CanvasPointerSample`,
  `handlePointer(CanvasPointerSample`, `terminal sample`,
  `invalid terminal sample`, and `invalid terminal samples` under
  `docs/contracts`, `docs/diagrams`, `docs/architecture`, generated-doc
  surfaces, public registry surfaces, `lib`, and `test`.
- Run and resolve a structural/semantic search over surface and runtime bridge
  entry points proving no surface-only invalid-terminal cleanup bridge exists
  outside `CanvasRuntimeSurfacePort.handlePointer` and `RuntimeRoot.handlePointer`.
- Do not create a duplicate prose-only source of truth for cleanup behavior.

Completion Check:

- Claim: durable public source-of-truth surfaces describe the new pointer input
  shape and no retained sample-only wording contradicts the implemented API.
- Direct outcome: public contract, registry, generated docs, and diagrams name
  the union input and terminal cleanup variant where they describe pointer
  dispatch; old sample-only signature and invalid-terminal sample wording are
  absent or intentionally retained only where referring to finite samples or
  historical source inputs outside active docs.
- Proxy risk: docs checks can pass while stale diagrams or generated indexes
  still teach the old public seam.
- Required proof: `dart run docs/tool/sync_generated_docs.dart --check`,
  `dart run docs/tool/check_docs.dart`,
  `dart test test/api_contract/public_equality_policy_test.dart`, semantic
  search results for the terms listed above with no contradictory active-doc
  hits, surface/runtime bridge semantic-search or structural-test proof that no
  invalid-terminal surface cleanup bypass exists, and architecture graph checks
  only if architecture graph sources or generated architecture views are
  touched.

Depends On:

- Unit 1
- Unit 2
- Unit 3

### [x] Unit 5: Final mixed-change verification

Owner:

- Repository verification for the changed Dart, Flutter, docs, and public API
  surfaces.

Boundary:

- Focused API, runtime, interaction, surface, docs, analyzer, DCM, and
  architecture checks triggered by Units 1-4.

Change:

- Run the required focused tests and repository checks after implementation and
  docs updates.
- Run architecture graph checks only if architecture-owned production seams,
  architecture graph source, generated architecture diagrams, architecture docs,
  or release gates depending on current graph closure are touched.
- Record any environment limitation explicitly instead of marking unit
  checkboxes complete without proof.

Completion Check:

- Claim: the implemented change is verified across behavior, public API, docs,
  and static analysis surfaces required by repository policy.
- Direct outcome: focused tests for public constructors, public compile fixture,
  interaction cleanup, direct runtime cleanup, and surface terminal routing pass;
  `dart analyze`, `dcm analyze .`, owner-scoped `dcm calculate-metrics`, and
  required docs checks pass; architecture checks pass if triggered.
- Proxy risk: broad analysis can pass while the bug path remains untested, and
  focused tests can pass while docs/source-of-truth are stale.
- Required proof: run focused tests named in Units 1-3,
  `dart analyze`, `dcm analyze .`, `dcm calculate-metrics` for changed
  production/test/tool owners, `dart run docs/tool/sync_generated_docs.dart --check`,
  `dart run docs/tool/check_docs.dart`,
  `dart test test/api_contract/public_equality_policy_test.dart`,
  surface/runtime bridge no-bypass structural proof, and architecture graph
  checks if triggered by touched sources.

Depends On:

- Unit 1
- Unit 2
- Unit 3
- Unit 4
