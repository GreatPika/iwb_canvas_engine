# Design: API Surface Invalid Terminal Cleanup

---
date: 2026-06-10
designer: Codex
commit: f1b7a570
branch: new-architecture
design_question: "Design API-002 and SURFACE-002 cleanup from .research/2026-06-10-api-surface-invalid-terminal-cleanup.md; no external users exist, so public API compatibility may be broken for cleaner semantics."
---

## Disposition

READY_FOR_CONTRACT

## Product Outcome

Pointer sessions end reliably when a terminal pointer event has an unusable
position. Public callers and the Flutter surface get the same explicit cleanup
route, while normal pointer samples keep the stronger rule that coordinates are
always finite.

Non-goals: this design does not change pointer gesture behavior for valid
coordinates, does not add multi-pointer support, does not make invalid down or
move input cleanup-capable, and does not update durable public docs or diagrams
during design.

## Target Contract Classification

- Profile: BEHAVIOR_CHANGE
- Obligations: BUG_FIX, PUBLIC_API_CHANGE

## Research Inputs

- `.research/2026-06-10-api-surface-invalid-terminal-cleanup.md` - factual
  current-state research for API-002 and SURFACE-002, including public pointer
  contract, surface adapter routing, runtime cleanup path, and existing tests.
- User clarification on 2026-06-10 - no current external users, so public API
  breakage is acceptable when it improves cleanliness, simplicity, and
  reliability. This is a product constraint supplied in chat, not a repository
  file.

## Repository Evidence

`Evidence Consequence Link`: each fact below states the decision, boundary,
unit, proof surface, or review consequence it supports.

- `.research/2026-06-10-api-surface-invalid-terminal-cleanup.md:13` - API-002
  and SURFACE-002 both concern terminal pointer input whose position is not
  finite -> supports one shared design across public API and Flutter surface
  boundaries, not two local fixes.
- `.research/2026-06-10-api-surface-invalid-terminal-cleanup.md:15` - the
  current public constructor cannot represent non-finite up/cancel terminal
  samples -> supports PUBLIC_API_CHANGE rather than a surface-only repair.
- `.research/2026-06-10-api-surface-invalid-terminal-cleanup.md:17` - the
  current Flutter surface drops non-finite terminal events before runtime
  cleanup -> supports a surface adapter contract change that routes terminal
  cleanup input.
- `.research/2026-06-10-api-surface-invalid-terminal-cleanup.md:13` - API-002 is a public API issue ->
  supports public API owner participation in the future contract.
- `.research/2026-06-10-api-surface-invalid-terminal-cleanup.md:13` - the public API contract expects
  invalid terminal samples to route to cleanup logic -> supports preserving the
  behavior while changing the representation.
- `.research/2026-06-10-api-surface-invalid-terminal-cleanup.md:13` - SURFACE-002 is a Flutter
  surface issue -> supports a surface boundary proof, not only direct
  `CanvasToolPort` tests.
- `.research/2026-06-10-api-surface-invalid-terminal-cleanup.md:13` - dropping non-finite terminal
  events can leave preview/session active until another cleanup path -> supports
  runtime state cleanup as the direct outcome.
- `docs/contracts/public_api_v1.md:1573` - pointer lifecycle phases are
  `down`, `move`, `up`, and `cancel` -> supports restricting terminal cleanup
  input to `up` and `cancel`.
- `docs/contracts/public_api_v1.md:1726` - `CanvasToolPort.handlePointer`
  currently accepts `CanvasPointerSample` -> supports the breaking API handoff
  to change this boundary to a broader pointer input type.
- `docs/contracts/public_api_v1.md:1787` - public validation distinguishes
  finite down/move positions from invalid terminal cleanup routing -> supports
  a representation split between finite samples and terminal cleanup signals.
- `docs/contracts/public_api_v1.md:1793` - pointer id routes samples and rejects
  stale terminal samples -> supports retaining pointer id on cleanup input.
- `docs/contracts/public_api_v1.md:1794` - one runtime has at most one active
  pointer session -> supports cleanup classification against the single active
  session instead of multi-session bookkeeping.
- `docs/contracts/public_api_v1.md:1796` - concurrent pointer sessions are not
  stored -> supports no new queue or synchronizer for invalid terminals.
- `docs/contracts/public_api_v1.md:1466` - no-op, stale rejection, rollback,
  cancel, load cleanup, and dispose close paths do not create timestamped output
  -> supports keeping invalid terminal cleanup timestamp-silent.
- `docs/contracts/public_api_v1.md:1470` - invalid terminals remain
  timestamp-silent -> supports proof that cleanup input does not reserve output
  timestamps.
- `docs/_registry/public_api_v1.yaml:66` - `CanvasPointerSample` is registry
  backed as public API -> supports registry/doc update as mandatory future
  source-of-truth work.
- `docs/_registry/public_api_v1.yaml:67` - `CanvasPointerLifecyclePhase` is
  registry backed as public API -> supports keeping phase names stable while
  changing accepted input shape.
- `lib/src/contracts/public/canvas_pointer.dart:92` - current
  `CanvasPointerSample` factory owns public sample construction -> supports
  placing finite-sample validation at the public DTO boundary.
- `lib/src/contracts/public/canvas_pointer.dart:100` - current public sample
  validates `position` for every phase -> supports replacing the all-phase
  position rule with a finite-sample-only rule and a separate cleanup input.
- `lib/src/surface/pointer_adapter.dart:17` - the Flutter surface uses a
  `Listener` as the pointer event boundary -> supports implementing surface
  admission policy in `CanvasSurfacePointerAdapter`.
- `lib/src/surface/pointer_adapter.dart:25` - `onPointerUp` already routes into
  the adapter phase path -> supports mapping non-finite up to cleanup input.
- `lib/src/surface/pointer_adapter.dart:28` - `onPointerCancel` already routes
  into the adapter phase path -> supports mapping non-finite cancel to cleanup
  input.
- `lib/src/surface/pointer_adapter.dart:37` - the current adapter returns on
  every non-finite local position before routing -> supports changing this guard
  to drop only non-finite down/move and route non-finite terminal cleanup.
- `lib/src/api/canvas_runtime_surface_bridge.dart:60` - the active surface port
  owns the surface-to-runtime pointer entry -> supports changing the port input
  type with the public runtime tool boundary.
- `lib/src/api/canvas_runtime_surface_bridge.dart:61` - active surface token
  guard runs before runtime pointer handling -> supports preserving inactive
  surface no-op behavior for cleanup input.
- `lib/src/runtime/runtime_root.dart:1245` - runtime pointer handling begins at
  `RuntimeRoot.handlePointer` -> supports making runtime admission the single
  owner of public and surface pointer input dispatch.
- `lib/src/runtime/runtime_root.dart:1247` - runtime delegates pointer samples
  to the interaction engine -> supports interaction engine as the cleanup
  classifier owner after runtime mutation admission.
- `lib/src/runtime/runtime_root.dart:1266` - pointer commit delivery is
  admission-driven -> supports proof that cleanup input cannot create document
  commits or user actions.
- `lib/src/runtime/runtime_root.dart:1272` - runtime state publication is
  admission-driven -> supports preview/session cleanup as the expected public
  state outcome when cleanup changes state.
- `lib/src/runtime/runtime_root.dart:2527` - public tool port delegates pointer
  input to `RuntimeRoot.handlePointer` -> supports changing one shared runtime
  path, not separate public/surface behavior.
- `lib/src/interaction/interaction_engine.dart:348` - current interaction
  pointer handling normalizes before phase routing -> supports moving invalid
  terminal cleanup classification before coordinate normalization.
- `lib/src/interaction/interaction_engine.dart:357` - up/cancel phases route to
  terminal handling -> supports terminal-only cleanup semantics.
- `lib/src/interaction/interaction_engine.dart:831` - existing invalid
  terminal decisions route to `_handleInvalidTerminal` -> supports extending
  the existing cleanup decision classifier rather than adding a second cleanup
  mechanism.
- `lib/src/interaction/interaction_engine.dart:1395` - invalid terminal
  handling returns cleanup-only or ignored admissions -> supports the required
  no-commit outcome for cleanup input.
- `lib/src/interaction/interaction_engine.dart:1406` - line invalid-terminal
  stale-pointer cleanup is already specialized in one owner -> supports
  extending the same owner for explicit invalid-position cleanup instead of
  adding surface special cases.
- `lib/src/interaction/interaction_engine.dart:1424` - invalid terminal
  decisions map to cleanup reasons -> supports adding an explicit invalid
  terminal cleanup reason path if the future implementation needs one.
- `lib/src/interaction/pointer_sample_normalizer.dart:45` - public sample
  normalization copies coordinates and computes world position -> supports
  keeping non-finite cleanup input out of `NormalizedPointerSample`.
- `lib/src/interaction/pointer_sample_normalizer.dart:53` - world position is
  computed from sample position and camera offset -> supports rejecting any
  design that allows non-finite terminal coordinates through normalization.
- `lib/src/interaction/pointer_sample_normalizer.dart:61` - invalid terminal
  cleanup classification is already centralized in the normalizer-adjacent
  pointer policy -> supports adding an explicit cleanup-signal classification
  to this owner.
- `lib/src/interaction/pointer_tool_cleanup_coordinator.dart:20` - cleanup
  outcome releases an active session when requested -> supports using existing
  cleanup mechanics.
- `docs/diagrams/dfd_pointer_preview_commit.mmd:72` - durable diagrams already
  describe terminal samples as finite or cleanup-only invalid -> supports
  later diagram/doc alignment rather than inventing new semantics.
- `docs/diagrams/dfd_pointer_preview_commit.mmd:73` - non-finite down/move
  facts are no-route invalid events -> supports preserving down/move drop
  semantics.
- `docs/diagrams/state_pointer_session.mmd:61` - terminal gate already names
  non-finite facts and invalid terminal as cleanup-only -> supports the selected
  form as source-of-truth alignment, not a new runtime behavior concept.
- `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:13`
  - existing surface fixture covers finite phase mapping -> supports extending
  that fixture for cleanup-input mapping.
- `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:211`
  - existing fixture covers non-finite surface no-effect behavior -> supports
  splitting no-effect down/move proof from terminal cleanup proof.
- `test/interaction/pointer_session_test.dart:21` - interaction tests already
  cover stale terminal cleanup-only behavior -> supports adding direct explicit
  invalid-terminal cleanup proof at the same seam.
- `test/interaction/pointer_sample_normalizer_test.dart:12` - normalizer tests
  already cover invalid terminal cleanup decisions -> supports adding classifier
  proof for explicit invalid terminal cleanup.
- `test/api_contract/public_api_v1_compiles_as_written_test.dart:379` - public
  API compile fixture constructs a pointer sample -> supports updating public
  compile proof for the breaking `handlePointer` input shape.
- `lib/src/contracts/public/canvas_preview.dart:16` - public contracts already
  use sealed union API for variant data -> supports using a sealed public
  pointer input union as an established repository pattern.
- `docs/contracts/public_api_v1.md:328` - public API contract already documents
  sealed `CanvasFieldUpdate` variants -> supports sealed union documentation as
  established public contract style.

## Design Form Candidates

### Candidate A. Relax CanvasPointerSample terminal position validation

- Form: keep `CanvasToolPort.handlePointer(CanvasPointerSample sample)`, allow
  non-finite `position` only when `phase` is `up` or `cancel`, then branch in
  interaction before world normalization.
- Why it could work: it is the smallest public API change and matches the
  existing wording that says "invalid terminal samples" route to cleanup logic.
- Gate failures or risks: it weakens `CanvasPointerSample` as a coordinate
  sample, puts invalid coordinates in a public DTO that otherwise looks usable
  by geometry code, and requires every future consumer to remember a
  phase-dependent position invariant. It passes minimal compatibility but is
  weaker for source-of-truth singularity and future maintainability now that
  compatibility is not required.

### Candidate B. Add a surface-only cleanup method

- Form: keep public `CanvasPointerSample` finite-only, add an internal surface
  method such as `handleInvalidTerminalPointer(...)` from
  `CanvasRuntimeSurfacePort` to `RuntimeRoot`.
- Why it could work: it fixes SURFACE-002 without exposing non-finite values in
  public API.
- Gate failures or risks: it leaves API-002 unresolved because direct public
  callers still cannot express documented invalid terminal cleanup. It creates
  two entry semantics for the same pointer problem and violates owner-level fix.

### Candidate C. Replace pointer dispatch with a finite-sample / terminal-cleanup union

- Form: introduce a public sealed pointer input owner, for example
  `sealed class CanvasPointerInput`, with `CanvasPointerSample` as the finite
  coordinate variant and a terminal cleanup variant, for example
  `CanvasPointerTerminalCleanup`, that carries pointer id, terminal phase,
  device kind, and optional timestamp but no position. Change
  `CanvasToolPort.handlePointer` and `CanvasRuntimeSurfacePort.handlePointer`
  to accept the union. The Flutter adapter maps finite events to
  `CanvasPointerSample`, drops non-finite down/move, and maps non-finite
  up/cancel to the terminal cleanup variant. The interaction engine classifies
  cleanup input before coordinate normalization and routes it through existing
  invalid-terminal cleanup admissions.
- Why it could work: it gives invalid terminal cleanup a first-class public
  representation without allowing non-finite coordinates into sample/world
  normalization. It uses the repository's existing sealed public API style and
  repairs both public and surface boundaries with one owner-level design.
- Gate failures or risks: it is a breaking public API change and requires
  docs/registry/compile fixture updates. The user explicitly allowed public API
  breakage because there are no current users, so this cost is acceptable.

## Known Future Pressures

| Pressure | Evidence | How the selected form responds | Accepted cost or risk |
|---|---|---|---|
| Public API contract and registry must stay aligned with exported types. | `docs/_registry/public_api_v1.yaml:66`, `docs/_registry/public_api_v1.yaml:67`, `docs/contracts/public_api_v1.md:1726` | Requires future contract work to update public docs, registry, and compile fixtures in the same change as the API break. | More public docs churn now; lower future ambiguity because the input union owns the distinction. |
| Durable diagrams already mention cleanup-only invalid terminal paths. | `docs/diagrams/dfd_pointer_preview_commit.mmd:72`, `docs/diagrams/state_pointer_session.mmd:61` | Keeps the documented architecture concept, but later docs/diagram sync must rename the public representation from invalid sample to cleanup input where needed. | Future contract must include SOURCE_OF_TRUTH_DOCS work or mixed docs/code work. |
| Runtime geometry and hit-test code assumes finite positions. | `lib/src/interaction/pointer_sample_normalizer.dart:53`, `docs/contracts/public_api_v1.md:1787` | Cleanup input has no position and is classified before normalization, so finite geometry remains a strong invariant. | Adds one branch at pointer admission before current normalization. |
| Invalid terminal cleanup must not create timestamped outputs. | `docs/contracts/public_api_v1.md:1466`, `docs/contracts/public_api_v1.md:1470`, `lib/src/runtime/runtime_root.dart:1266` | Cleanup input routes to cleanup-only/ignored admission and must bypass commit/action/context request timestamp reservation. | Future tests must prove negative timestamp/output behavior, not just preview cleanup. |
| Surface and direct public callers must not drift again. | `.research/2026-06-10-api-surface-invalid-terminal-cleanup.md:13`, `lib/src/runtime/runtime_root.dart:2527`, `lib/src/api/canvas_runtime_surface_bridge.dart:60` | Both public tool port and surface port accept the same pointer input union and share `RuntimeRoot.handlePointer`. | Future implementation touches more call sites than a surface-only patch. |
| No multi-pointer storage exists. | `docs/contracts/public_api_v1.md:1794`, `docs/contracts/public_api_v1.md:1796` | Cleanup input is classified against the single active session and does not introduce queues or multi-session sync. | Stale cleanup signal behavior remains intentionally conservative. |

## Selected Form

Select Candidate C: replace pointer dispatch with a public finite-sample /
terminal-cleanup union.

The future API should make the model explicit:

- `CanvasPointerSample` remains the finite coordinate variant. Its public
  constructor validates `position` for every phase, including `up` and
  `cancel`.
- A new terminal cleanup variant, named in the future contract but shaped as
  `CanvasPointerTerminalCleanup`, carries `pointerId`, terminal `phase`
  (`up` or `cancel` only), `kind`, and optional `timestampMs`, and carries no
  position.
- `CanvasToolPort.handlePointer` accepts the union owner, shaped as
  `CanvasPointerInput`, instead of `CanvasPointerSample`.
- `CanvasSurfacePointerAdapter` maps finite down/move/up/cancel to finite
  samples, drops non-finite down/move with no runtime effects, and maps
  non-finite up/cancel to terminal cleanup input.
- `RuntimeRoot.handlePointer` remains the shared public/surface admission
  owner. The interaction engine branches on the input variant before
  coordinate normalization. Cleanup input must not produce
  `NormalizedPointerSample` with non-finite view/world positions.
- Existing invalid-terminal cleanup machinery remains the cleanup owner, with
  one explicit decision kind or equivalent classifier result for an invalid
  terminal cleanup signal that targets the active session.

This form is the best fit because it fixes the owning boundary, keeps finite
coordinates as a stable invariant, uses an established sealed public API
pattern, and accepts the public API break only because the product constraint
says there are no current users.

## Decision Trace

Preserve `Decision Chain Of Custody`: source inputs and locked decisions must
map to the future contract field, execution unit, or proof surface that carries
them forward.

| Decision ID | Decision | Evidence | Contract handoff target |
|---|---|---|---|
| D1 | Public pointer input becomes a sealed finite-sample / terminal-cleanup union; `CanvasToolPort.handlePointer` accepts the union instead of only `CanvasPointerSample`. | User clarification on 2026-06-10; `docs/contracts/public_api_v1.md:1726`; `lib/src/contracts/public/canvas_preview.dart:16`; `docs/contracts/public_api_v1.md:328` | `Target Profile`, `Public API Compatibility`, public API execution unit, public compile proof |
| D2 | `CanvasPointerSample` remains finite-only for every phase; invalid terminal cleanup is represented by a no-position cleanup variant. | `lib/src/contracts/public/canvas_pointer.dart:100`; `docs/contracts/public_api_v1.md:1787`; `lib/src/interaction/pointer_sample_normalizer.dart:53` | `Boundaries.Source of Truth`, public DTO unit, constructor validation tests |
| D3 | Surface admission drops non-finite down/move and routes non-finite up/cancel as terminal cleanup input. | `lib/src/surface/pointer_adapter.dart:25`; `lib/src/surface/pointer_adapter.dart:28`; `lib/src/surface/pointer_adapter.dart:37`; `.research/2026-06-10-api-surface-invalid-terminal-cleanup.md:13` | surface adapter unit, surface widget tests |
| D4 | Runtime interaction branches on cleanup input before coordinate normalization and routes through existing invalid-terminal cleanup admission. | `lib/src/interaction/interaction_engine.dart:348`; `lib/src/interaction/interaction_engine.dart:831`; `lib/src/interaction/interaction_engine.dart:1395`; `lib/src/interaction/pointer_sample_normalizer.dart:61` | interaction unit, normalizer/classifier tests, runtime cleanup proof |
| D5 | Cleanup input is terminal-only and timestamp-silent: no commits, user actions, context requests, or output timestamp reservations. | `docs/contracts/public_api_v1.md:1466`; `docs/contracts/public_api_v1.md:1470`; `lib/src/runtime/runtime_root.dart:1266`; `lib/src/runtime/runtime_root.dart:1272` | verification strategy, negative runtime/API tests |
| D6 | Docs, public registry, durable diagrams, and public compile fixtures must be updated by the future Change Contract because the public source of truth changes. | `docs/_registry/public_api_v1.yaml:66`; `docs/_registry/public_api_v1.yaml:67`; `docs/diagrams/dfd_pointer_preview_commit.mmd:72`; `test/api_contract/public_api_v1_compiles_as_written_test.dart:379` | `Source-Of-Truth Impact`, docs/registry unit, documentation checks |

## Outcome-Proof Fit

| Claim | Direct outcome | Proxy risk | Required proof surface or strategy |
|---|---|---|---|
| Public callers can express invalid terminal cleanup without non-finite coordinates in `CanvasPointerSample`. | Code can construct terminal cleanup input without `position`, and cannot construct non-finite `CanvasPointerSample`. | Compile success alone could pass while runtime ignores the cleanup variant. | Public API constructor tests and public compile fixture covering both finite sample and terminal cleanup input. |
| Surface non-finite up/cancel clears an active session. | A finite down creates preview/session; a non-finite terminal event through `CanvasSurfacePointerAdapter` clears preview/session and publishes state if cleanup changed state. | Testing only adapter sample counts could miss runtime cleanup behavior. | Widget/runtime integration test: finite down then non-finite up/cancel via `Listener`, assert preview/session cleared and no document/action output. |
| Non-finite down/move remain no-effect input. | Non-finite down/move through the surface produce no preview, state tick, document mutation, action, or route callback. | A route callback count could pass while runtime state changes elsewhere. | Existing no-effect surface fixture split/extended to assert no runtime side effects for down/move. |
| Cleanup input never enters world-position normalization. | No non-finite `NormalizedPointerSample.viewPosition` or `.worldPosition` is produced for terminal cleanup input. | Preview cleanup could pass even if NaN flows through geometry first. | Interaction unit test or structural test around pointer admission/classifier proving cleanup input branches before `normalizePublicSample`. |
| Cleanup input is timestamp-silent and commit-silent. | Cleanup-only/ignored admission creates no document commit, user action, context request, resolver request, or output timestamp reservation. | Asserting preview is cleared could miss a stray timestamped output. | Runtime/API integration test with action/context observers and timestamp-sensitive paths asserting no output events. |
| Public and surface routes share one runtime semantics. | Direct `runtime.tools.handlePointer(terminalCleanup)` and surface non-finite terminal both reach the same runtime cleanup owner and produce equivalent cleanup/no-output outcomes. | Separate tests could pass with duplicated divergent logic. | Tests cover direct public API and surface adapter through `RuntimeRoot.handlePointer`; semantic search or structural test ensures no separate surface cleanup-only bridge bypasses pointer admission. |

## Hard Gate Check

| Gate | Result | Evidence |
|---|---|---|
| Owner-Level Fix | pass | API-002 and SURFACE-002 share one cause, proven by `.research/2026-06-10-api-surface-invalid-terminal-cleanup.md:13`; selected form fixes the shared public/surface pointer input owner. |
| Ownership | pass | Public DTO construction owner is `lib/src/contracts/public/canvas_pointer.dart:92`; runtime admission owner is `lib/src/runtime/runtime_root.dart:1245`; cleanup owner is `lib/src/interaction/interaction_engine.dart:831`. |
| Source-Of-Truth Singularity | pass | The public input union owns pointer input shape; registry and public contract must be updated from that owner, supported by `docs/_registry/public_api_v1.yaml:66` and `docs/contracts/public_api_v1.md:1726`. |
| Boundary-Owned Policy | pass | Public validation stays in `lib/src/contracts/public/canvas_pointer.dart:92`; surface admission stays in `lib/src/surface/pointer_adapter.dart:17`; runtime cleanup classification stays before interaction normalization at `lib/src/interaction/interaction_engine.dart:348`. |
| Negative Proof And Fixture Quarantine | pass | Negative proof uses real public API and real surface `Listener` seams from `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:13` and direct interaction seams from `test/interaction/pointer_session_test.dart:21`; no fixture-only values enter public registries. |
| Dependency direction | pass | Surface already imports public pointer contracts at `lib/src/surface/pointer_adapter.dart:3`; runtime bridge already imports public pointer contracts at `lib/src/api/canvas_runtime_surface_bridge.dart:7`; interaction already consumes public pointer contracts at `lib/src/interaction/pointer_sample_normalizer.dart:3`. |
| State/data | pass | Committed document state is unchanged; transient active pointer session is owned by interaction cleanup, evidenced by `lib/src/interaction/pointer_tool_cleanup_coordinator.dart:20`; public runtime state publication remains admission-driven at `lib/src/runtime/runtime_root.dart:1272`. |
| Sequenced Migration And Retirement | pass | Shared seam migration is: introduce public input union, change `handlePointer` signatures, update surface callback type, branch interaction before normalization, update docs/registry/tests, retire old sample-only `handlePointer` signature. |
| Temporal Surface Closure | pass | Pointer handling remains synchronous: surface `Listener` callback constructs input, active surface guard runs at `lib/src/api/canvas_runtime_surface_bridge.dart:61`, runtime mutation guard runs at `lib/src/runtime/runtime_root.dart:1246`, cleanup admission applies before optional state publication at `lib/src/runtime/runtime_root.dart:1272`. Reentrant mutation remains owned by `ensureRuntimeMutationAllowed()`, and rejection/no-mutation for inactive surface remains the active-token return. |
| All-Or-Nothing Failure Boundary | pass | Public input construction validates before runtime mutation; surface input construction happens before route callback; runtime cleanup admission computes outcome before state publication. The irreversible point is interaction cleanup application/state publication; later work is admission-contained and no commit delivery occurs for cleanup-only input. |
| Outcome-Proof Fit | pass | Direct outcomes and non-proxy proof surfaces are listed in `Outcome-Proof Fit`, including runtime state cleanup, no timestamped output, and no normalization of invalid coordinates. |
| Verification | pass | Future proof surfaces are existing focused Dart/Flutter tests plus docs checks: `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:13`, `test/interaction/pointer_session_test.dart:21`, `test/interaction/pointer_sample_normalizer_test.dart:12`, and public API compile tests at `test/api_contract/public_api_v1_compiles_as_written_test.dart:379`. |
| Future pressure | pass | Public API breakage and docs/diagram churn are assessed in `Known Future Pressures`; the user explicitly accepted API breakage on 2026-06-10. |

## Lock-Required Facts

- Owner: public pointer input representation is owned by the public pointer
  contract declarations; runtime pointer admission is owned by `RuntimeRoot`;
  invalid terminal cleanup classification is owned by the interaction pointer
  cleanup path.
- Owning layer/module/document family: public API contract and registry for API
  shape; surface adapter for Flutter event admission; interaction engine for
  cleanup classification and state cleanup.
- Seam: `CanvasToolPort.handlePointer` and `CanvasRuntimeSurfacePort.handlePointer`
  accept the same public pointer input union.
- Dependency/import direction: public contracts are imported by surface,
  runtime bridge, runtime, and interaction; no public API type imports surface
  or runtime implementation.
- State/data ownership: finite pointer coordinates are input data owned by
  `CanvasPointerSample`; invalid terminal cleanup input owns no coordinate data;
  active pointer session/preview are transient interaction state; document,
  action, and context-request outputs are unchanged and must not be produced by
  cleanup input.
- Entry boundaries: public direct entry is `CanvasToolPort.handlePointer`;
  Flutter entry is `CanvasSurfacePointerAdapter` `Listener` callbacks; internal
  shared entry is `RuntimeRoot.handlePointer`.
- Exit boundaries: cleanup-only/ignored `InteractionPointerAdmission`, optional
  runtime state publication for preview/session cleanup, no commit/action/context
  request output.
- File placement basis: public union variants belong with pointer public
  contracts because `CanvasPointerSample` already lives there; surface mapping
  belongs in `CanvasSurfacePointerAdapter`; classifier changes belong beside
  existing invalid terminal decision logic.
- Execution order constraints: validate/construct public input first; surface
  active token guard before runtime mutation; runtime mutation guard before
  interaction admission; cleanup input branch before coordinate normalization;
  cleanup admission before optional state publication; no commit delivery for
  cleanup input.
- `Temporal Surface Closure` invariant, synchronous callback surfaces,
  guard/boundary owner, public observation order, and expected
  rejection/no-mutation signal: all pointer input handling remains synchronous
  from `Listener` or direct public call through runtime admission. Synchronous
  callback surfaces are `Listener` event callbacks, surface route callback,
  `CanvasRuntimeSurfacePort.handlePointer`, `RuntimeRoot.handlePointer`, and
  `InteractionEngine.handlePointer...`. Guard owners are active-surface token
  guard and runtime mutation guard. Public observation order is cleanup state
  mutation before `ValueListenable` state publication. Inactive surface or
  invalid down/move input returns with no mutation; cleanup input with no
  matching cleanup need returns ignored/no-op.
- `All-Or-Nothing Failure Boundary` irreversible point,
  fallible-before-irreversible work, later infallible/failure-contained/accepted
  work, failure projection, and proof surface: fallible work is public input
  validation and surface event admission before callback routing. The
  irreversible point is applying interaction cleanup and publishing runtime
  state. Later work for cleanup input is failure-contained because no commit,
  resolver, action, or context request is created. Failure projection is stale
  preview/session or unexpected output; proof is runtime/surface integration
  tests with state, document, action, and context observers.
- Rejected alternatives: relaxing `CanvasPointerSample` terminal validation;
  adding surface-only cleanup method.
- Verification strategy: constructor/API compile tests, interaction classifier
  tests, runtime direct cleanup tests, surface finite-down/non-finite-terminal
  widget tests, negative no-output observers, public registry/docs checks, and
  semantic search for retired sample-only pointer dispatch.

## Diagram Need Assessment

| Design question | Needed? | Diagram kind | Reason |
|---|---:|---|---|
| Does the design change ownership, layer, package, or component boundaries? | no | none | The public pointer input seam changes shape, but ownership remains public contracts -> runtime admission -> interaction cleanup. `Decision Trace` and `Lock-Required Facts` are sufficient for contract authoring; durable diagrams are future source-of-truth updates, not design-stage provisional diagrams. |
| Does it change data flow, state ownership, cache ownership, resource movement, or lifecycle movement? | no | none | Data flow changes from single sample DTO to finite sample or cleanup input, but the selected form states every boundary and state owner. A provisional diagram would duplicate the handoff; durable data-flow diagrams must be checked and updated later. |
| Does it depend on call order, lifecycle order, sync/async ordering, failure ordering, or migration order? | no | none | The required order is locked textually: cleanup input branches before coordinate normalization and before commit delivery. No additional provisional sequence diagram is needed to remove ambiguity. |
| Does it introduce or alter observer/listener/callback delivery, guard windows, public-state publication, or reentrancy-sensitive ordering? | no | none | Listener, active-surface guard, runtime mutation guard, and state publication order are explicitly named under `Temporal Surface Closure`. |
| Does it introduce or alter modes, statuses, terminal states, sessions, or transition rules? | no | none | The selected form adds an explicit terminal cleanup input at the boundary, but pointer session transition meaning is already captured by existing cleanup-only semantics and future durable state diagrams must be synced. |
| Does it create, replace, migrate, or retire a shared seam under `Sequenced Migration And Retirement`? | no | none | It replaces `handlePointer(CanvasPointerSample)` with a union input seam, and the migration order is listed in hard gates and handoff. Contract authoring does not need a provisional diagram to execute that order. |
| Does it change public API consumer flow, payload shape, or compatibility behavior? | no | none | Public callers must construct one of two pointer input variants; the public docs and compile fixtures are the durable source-of-truth surfaces that must show the flow in the future contract. |
| Does it introduce or change analyzer, guardrail, or structural-recognition pipeline behavior? | no | none | No analyzer or guardrail pipeline is selected by this design. |

## Provisional Diagrams

No provisional Mermaid diagram is included. The design hinges on a small
public input union and a pre-normalization branch, both captured more directly
in `Selected Form`, `Decision Trace`, and `Lock-Required Facts`. Durable
diagrams under `docs/diagrams/` must be reviewed and updated by the future
Change Contract because they are source-of-truth artifacts, not design-stage
deliverables.

## Source-Of-Truth Impact

`Source-Of-Truth Singularity`: durable meaning must have one owning source of
truth and a real human or machine consumer. The public pointer input union is
the single source of truth for pointer dispatch shape. No cache/performance
duplication is introduced.

A later Change Contract must update:

- `lib/src/contracts/public/canvas_pointer.dart` for the public pointer input
  union and validation invariants.
- `lib/src/contracts/public/canvas_tools.dart` and public facade exports as
  needed for the `handlePointer` signature.
- `docs/contracts/public_api_v1.md` for the public API contract and validation
  text.
- `docs/_registry/public_api_v1.yaml` for any new public exports such as
  `CanvasPointerInput` and `CanvasPointerTerminalCleanup`.
- `test/api_contract/public_api_v1_compiles_as_written_test.dart` and related
  public API registry/export tests.
- All durable contracts, diagrams, verification docs, generated docs, and
  architecture docs that encode the old sample-only pointer dispatch shape or
  old terminal wording. The future contract must run and resolve a semantic
  search over at least `CanvasPointerSample`, `handlePointer(CanvasPointerSample`,
  `terminal sample`, `invalid terminal sample`, and `invalid terminal samples`
  under `docs/contracts`, `docs/diagrams`, `docs/architecture`, generated-doc
  surfaces, and public registry surfaces. Current confirmed hits include
  `docs/contracts/public_api_v1.md:1726`,
  `docs/contracts/interaction_engine.md:120`,
  `docs/diagrams/dfd_pointer_preview_commit.mmd:12`,
  `docs/diagrams/seq_selected_move_preview_commit.mmd:34`,
  `docs/diagrams/seq_selected_move_cancel.mmd:31`,
  `docs/diagrams/seq_context_action_request.mmd:85`,
  `docs/diagrams/seq_eraser_commit.mmd:28`,
  `docs/diagrams/seq_pencil_marker_commit.mmd:26`,
  `docs/diagrams/seq_marquee_select.mmd:28`,
  `docs/diagrams/seq_line_two_tap_commit.mmd:28`,
  `docs/diagrams/seq_hit_test_candidate_resolution.mmd:16`, and
  `docs/diagrams/state_select_marquee.mmd:110`.

## Verification Impact

Future proof must include:

- Public API constructor tests proving finite `CanvasPointerSample` validation
  and terminal-only cleanup input validation.
- Public compile fixture updates for the breaking `CanvasToolPort.handlePointer`
  input shape.
- Direct runtime/API tests proving finite down followed by terminal cleanup
  input clears active preview/session and creates no document/action/context
  output.
- Interaction classifier tests proving cleanup input is classified before
  coordinate normalization and does not create a non-finite
  `NormalizedPointerSample`.
- Surface widget tests proving non-finite down/move remain no-effect and
  finite-down followed by non-finite up/cancel routes cleanup.
- Documentation checks after public contract, registry, verification docs, or
  durable diagrams change.
- A semantic search or structural test to prevent reintroducing
  `handlePointer(CanvasPointerSample sample)` as the only public/surface seam.

## Verification Strategy

Use focused behavior tests before broad checks:

1. Public contract/API tests for the new sealed union shape and invalid
   constructor cases.
2. Interaction tests for cleanup input classification and cleanup-only/ignored
   admissions.
3. Runtime integration tests for direct public cleanup with observers on
   preview, state, document, actions, context requests, and timestamped output.
4. Surface widget tests through real `Listener` callbacks for finite and
   non-finite paths.
5. Repository checks required for mixed Dart/docs changes: `dart analyze`,
   `dcm analyze .`, owner-scoped `dcm calculate-metrics`, focused tests,
   documentation sync/checks, and architecture graph checks only if durable
   architecture graph artifacts are touched.

## Change Contract Handoff

- Required profile: BEHAVIOR_CHANGE
- Required obligations: BUG_FIX, PUBLIC_API_CHANGE
- Decision IDs / Decision Trace rows to preserve: D1, D2, D3, D4, D5, D6
- Evidence to cite:
  `.research/2026-06-10-api-surface-invalid-terminal-cleanup.md:13`,
  `.research/2026-06-10-api-surface-invalid-terminal-cleanup.md:15`,
  `.research/2026-06-10-api-surface-invalid-terminal-cleanup.md:17`,
  `.research/2026-06-10-api-surface-invalid-terminal-cleanup.md:13`,
  `docs/contracts/public_api_v1.md:1726`,
  `docs/contracts/public_api_v1.md:1787`,
  `docs/contracts/public_api_v1.md:1466`,
  `docs/contracts/public_api_v1.md:1470`,
  `docs/_registry/public_api_v1.yaml:66`,
  `lib/src/contracts/public/canvas_pointer.dart:92`,
  `lib/src/contracts/public/canvas_pointer.dart:100`,
  `lib/src/surface/pointer_adapter.dart:37`,
  `lib/src/runtime/runtime_root.dart:1245`,
  `lib/src/interaction/interaction_engine.dart:348`,
  `lib/src/interaction/interaction_engine.dart:831`,
  `lib/src/interaction/interaction_engine.dart:1395`,
  `lib/src/interaction/pointer_sample_normalizer.dart:53`,
  `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:13`,
  `test/interaction/pointer_session_test.dart:21`,
  `test/api_contract/public_api_v1_compiles_as_written_test.dart:379`.
- Contract constraints or sequencing facts:
  introduce the public pointer input union first; update public/surface/runtime
  signatures together; branch cleanup input before normalization; preserve
  active-surface and runtime mutation guards; update docs/registry/compile
  fixtures in the same public API change; prove no non-finite coordinates enter
  normalized world geometry; prove cleanup input is commit/action/context
  request/timestamp silent; update or explicitly verify every durable
  source-of-truth hit for `CanvasPointerSample`,
  `handlePointer(CanvasPointerSample`, `terminal sample`,
  `invalid terminal sample`, and `invalid terminal samples` across
  `docs/contracts`, `docs/diagrams`, `docs/architecture`, generated-doc
  surfaces, and public registry surfaces.
- Required proof surfaces:
  public API constructor and compile tests, interaction classifier tests,
  direct runtime cleanup tests, surface widget tests, no-output observers,
  docs/registry checks, generated-doc checks, and semantic search for retired
  sample-only pointer dispatch in durable source-of-truth surfaces.

## Open Decisions

None. The user supplied the product decision that public API breakage is
acceptable because there are no current users.
