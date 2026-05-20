# Change Contract

Contract Mode: FULL
Contract Profile: SOURCE_OF_TRUTH_DOCS
Contract Obligations: PUBLIC_API_CHANGE

## 1. Mandate and Boundary

### Mandate

Convert `.design/2026-05-19-double-tap-context-action.md` into accepted
source-of-truth documentation for direct double-tap context actions.

This is a documentation-only roadmap step. It must lock
`CanvasToolPort.handleDoubleTap` as a host-recognized double-tap input boundary
inside the already documented `CanvasRuntime.contextActionRequests` seam. Direct
`handleDoubleTap` must not require pending first-tap history and must not be
implemented or documented as "the second tap" of engine-owned pointer-sample
double-tap recognition.

### In Scope

- Document `CanvasToolPort.handleDoubleTap({required Offset position, int?
  timestampMs})` as a host-recognized double-tap event.
- Document that direct `handleDoubleTap` validates the supplied finite view
  position, resolves the request timestamp through the runtime timestamp cursor,
  clears any existing pending context tap history through
  `PointerToolCleanupCoordinator`, resolves the current context-action target at
  the supplied position, and emits exactly one `CanvasContextActionRequested` for
  either an eligible content target or empty canvas.
- Preserve `CanvasRuntime.contextActionRequests`,
  `CanvasContextActionRequested`, `CanvasContextActionTrigger.doubleTap`,
  `CanvasContextActionTarget`, `CanvasContentElementContextActionTarget`, and
  `CanvasEmptyCanvasContextActionTarget` as the existing public request seam.
- Keep engine-owned pointer-sample two-tap recognition documented separately
  from direct host-recognized `handleDoubleTap`.
- Preserve the current context-action target policy: finite point, visible
  content element, finite invertible transform, exact geometry hit, and topmost
  in content paint order. `element.isSelectable` does not gate context-action
  requests.
- Preserve the rule that background elements never produce content-element
  context targets; a point covered only by background elements is an empty-canvas
  context target.
- Preserve app-owned context menu and text editor choices after request
  delivery, including the application choice to open a menu first or immediately
  show a text editor for a `CanvasTextElement` content target.
- Preserve `CanvasCommandPort.commitTextEdit(requestId, newText, {int?
  timestampMs})` as the guarded request-originated text mutation seam.
- Preserve the rule that `commitTextEdit` accepts only current, unretired context
  request ids whose target is a text content element, and rejects empty-canvas,
  non-text, stale, retired, missing, or family-mismatched request ids without
  document, repaint, or action effects.
- Preserve the rule that context request delivery has no document, selection,
  preview, repaint, spatial, projection, resource, or action effect.
- Update current context-action diagrams so direct `handleDoubleTap` is not
  shown as a pending-flow transition that depends on stored first-tap state.
- Update durable docs, registries, phase guidance, verification docs, indexes,
  and generated documentation navigation only where required to keep the
  source-of-truth map coherent.
- Update this step document and `PLAN.md` checkboxes only after the
  documentation step is executed and proof passes.

### Out of Scope

- No production Dart implementation.
- No production Dart tests or fixtures.
- No Flutter overlay, context menu, text editor, IME, focus, accessibility, text
  selection, hide/show policy, or app-owned UI implementation.
- No new public stream, new public double-tap method, compatibility alias, or
  duplicate request event.
- No document mutation, selection mutation, preview mutation, resource mutation,
  repaint publication, spatial/projection update, or action event from context
  request delivery.
- No change to selection hit eligibility or pointer selection semantics.
- No engine-owned context menu or text editor.
- No broad implementation-file naming decision beyond documenting existing route
  ownership. The later implementation contract owns exact Dart file placement.
- No updates to historical `.research/`, `.design/`, or completed `plan/`
  records except this active step file and `PLAN.md`.

## 2. Evidence Map

### Baseline Evidence

These facts describe repository state before execution. They are evidence for
the change, not target-state requirements.

- `.design/2026-05-19-double-tap-context-action.md` is
  `READY_FOR_CONTRACT` and classifies the next step as
  `SOURCE_OF_TRUTH_DOCS` with `PUBLIC_API_CHANGE`.
- `.design/2026-05-19-double-tap-context-action.md` states that current docs
  already define double-tap as one application-facing context-action request for
  content targets and empty canvas.
- `.design/2026-05-19-double-tap-context-action.md` identifies the remaining
  documentation defect: `CanvasToolPort.handleDoubleTap` is not locked as a
  host-recognized double-tap event independent of pending first-tap history.
- `.research/2026-05-19-double-tap-docs-current-contract.md:13` records the
  historical pre-migration text-only double-tap contract; this is background
  evidence only because the active docs have already migrated to context-action
  names.
- `.research/2026-05-19-double-tap-docs-current-contract.md:140` records that
  double-tap documentation touches registries, phase docs, verification docs,
  and release gates.

### Entry Paths

- `docs/contracts/public_api_v1.md:1683` exposes
  `CanvasToolPort.handleDoubleTap({required Offset position, int? timestampMs})`
  as the public double-tap entry boundary.
- `docs/contracts/public_api_v1.md:1416` documents nullable timestamp inputs on
  double-tap boundaries as hints.
- `docs/diagrams/seq_context_action_request.mmd:23` through
  `docs/diagrams/seq_context_action_request.mmd:47` currently model the
  context-action flow through first and second pointer-sample taps.
- `docs/diagrams/state_pending_context_action_request.mmd:53` through
  `docs/diagrams/state_pending_context_action_request.mmd:54` currently say
  pending content and empty-canvas targets transition on "second tap or explicit
  double-tap", which can imply direct `handleDoubleTap` consumes pending first
  tap state.

### Current Owners

- `docs/README.md:3` says `docs/` is the durable source of truth for the
  new-engine transition and target architecture.
- `docs/contracts/interaction_engine.md:216` starts the current primary
  `Double-tap context action` contract section.
- `docs/contracts/interaction_engine.md:218` through
  `docs/contracts/interaction_engine.md:222` document that double-tap emits
  exactly one `CanvasContextActionRequested` and that request delivery has no
  document, selection, preview, repaint, spatial, projection, resource, or action
  effect.
- `docs/contracts/interaction_engine.md:224` through
  `docs/contracts/interaction_engine.md:228` document content and empty-canvas
  targets plus app-owned text-editor choice.
- `docs/contracts/interaction_engine.md:230` through
  `docs/contracts/interaction_engine.md:234` document
  `InteractionRequestRegistry` guard facts for context requests.
- `docs/contracts/interaction_engine.md:246` through
  `docs/contracts/interaction_engine.md:253` document
  `CanvasCommandPort.commitTextEdit` as the request-originated text mutation
  path.
- `docs/contracts/public_api_v1.md:361` exposes
  `CanvasRuntime.contextActionRequests`.
- `docs/contracts/public_api_v1.md:2212` through
  `docs/contracts/public_api_v1.md:2257` define the current public
  context-action request event and target union.
- `docs/contracts/public_api_v1.md:2260` through
  `docs/contracts/public_api_v1.md:2292` document the current context-action and
  text editing model.
- `docs/contracts/geometry.md:61` through
  `docs/contracts/geometry.md:78` document context-action target eligibility as
  separate from selection hit eligibility, including non-selectable visible
  content targets, background exclusion, and background-only empty-canvas
  resolution.
- `docs/contracts/operation_matrix.md:85` and
  `docs/contracts/operation_matrix.md:111` through
  `docs/contracts/operation_matrix.md:117` document the current no-effect
  context-action request row.
- `docs/architecture/01_runtime_ownership.md:154` through
  `docs/architecture/01_runtime_ownership.md:162` document
  `InteractionRequestRegistry` as interaction-owned guard state, not app UI
  state.
- `docs/architecture/02_package_boundaries.md:247` through
  `docs/architecture/02_package_boundaries.md:251` document
  `context_action_router.dart` as the future interaction route owner for
  context-action target resolution and request emission.

### Existing Checks

- `docs/README.md:75` through `docs/README.md:80` define
  `docs/tool/check_docs.dart` as the structural checker for documentation
  entrypoints, registries, ids, paths, diagram catalog membership, and phase
  navigation.
- `docs/README.md:82` through `docs/README.md:87` document the docs verification
  commands:
  `dart run docs/tool/generate_context_capsules.dart --check` and
  `dart run docs/tool/check_docs.dart`.
- `docs/verification/tests.md:263` through `docs/verification/tests.md:268`
  document runtime-created timestamp tests covering context-action requests.
- `docs/verification/tests.md:270` through `docs/verification/tests.md:278`
  document current context-action request tests for content, empty-canvas,
  background-only, no-effect delivery, cleanup, and guarded text commit
  behavior.

### Valid Precedents

- `plan/step_10_interaction_request_text_edit_stale_guard.md` is a prior
  `SOURCE_OF_TRUTH_DOCS` contract that changed the documented request id and
  stale guard seam before implementation.
- `plan/step_11_operation_matrix_field_effect_taxonomy.md` is a prior
  `SOURCE_OF_TRUTH_DOCS` contract that updated operation effects and release
  verification before implementation.
- `plan/step_18_pointer_tool_cleanup_coordinator.md` is a prior
  `SOURCE_OF_TRUTH_DOCS` contract for locking future interaction ownership in
  documentation only.
- `docs/contracts/public_api_v1.md:1411` through
  `docs/contracts/public_api_v1.md:1434` are a valid precedent for documenting
  public timestamp semantics around runtime-created outputs.

### Repository Rules

- `PLAN.md:5` identifies the active roadmap as the plan index, with each step
  represented by a dedicated document.
- `PLAN.md:17` gives the step entry template for roadmap steps.
- `PLAN.md:28` through `PLAN.md:29` require updating both the index and linked
  step document when a step is completed.
- `docs/README.md:35` through `docs/README.md:37` state that role-based files
  and `_registry/sections.yaml` are the current documentation owners.
- Documentation-only changes do not require `dart analyze`, `dcm analyze .`, or
  `dcm calculate-metrics .`; this step's proof is docs structural checks and
  bounded semantic proof.

### Misleading Patterns

- `docs/diagrams/state_pending_context_action_request.mmd:53` through
  `docs/diagrams/state_pending_context_action_request.mmd:54` are misleading
  because "second tap or explicit double-tap" can make direct `handleDoubleTap`
  look like part of the pending candidate path.
- `docs/diagrams/seq_context_action_request.mmd:23` through
  `docs/diagrams/seq_context_action_request.mmd:47` are incomplete for the new
  target state because they only model pointer-sample first and second taps, not
  direct host-recognized `handleDoubleTap`.
- `docs/contracts/geometry.md:57` defines selection-oriented hit eligibility
  with `element.isSelectable`; this is baseline selection evidence, not the
  context-action target policy.
- Historical `.research/`, `.design/`, and completed `plan/step_*.md` files may
  continue to mention earlier text-only or ambiguous double-tap wording as
  historical evidence.

## 3. Architecture Decision

### Selected Form

Lock direct `CanvasToolPort.handleDoubleTap` semantics inside the current
context-action request seam.

Direct `handleDoubleTap(position, timestampMs?)` is a host-recognized
double-tap event. It does not require pending first-tap history. On a valid
finite position, it resolves the request timestamp through the runtime timestamp
cursor, clears any existing pending context tap history through
`PointerToolCleanupCoordinator`, resolves the current context-action target at
the supplied position, issues a `CanvasInteractionRequestId`, records guard
facts in `InteractionRequestRegistry`, and emits exactly one
`CanvasContextActionRequested` through `CanvasRuntime.contextActionRequests` for
either a content-element target or an empty-canvas target.

Engine-owned two-tap recognition from pointer samples remains a separate path:
it may store a first-tap candidate, then require the second tap to revalidate the
same target class and current target facts before emission. The docs must not
merge this pending-flow rule with direct host-recognized `handleDoubleTap`.

The public request surface remains:

```dart
final class CanvasRuntime {
  Stream<CanvasContextActionRequested> get contextActionRequests;
}

enum CanvasContextActionTrigger { doubleTap }

final class CanvasContextActionRequested {
  CanvasContextActionRequested({
    required this.requestId,
    required this.trigger,
    required this.target,
    required this.controllerEpoch,
    required this.documentRevision,
    required this.timestampMs,
    required this.viewPosition,
    required this.worldPosition,
  });

  final CanvasInteractionRequestId requestId;
  final CanvasContextActionTrigger trigger;
  final CanvasContextActionTarget target;
  final int controllerEpoch;
  final int documentRevision;
  final int timestampMs;
  final Offset viewPosition;
  final Offset worldPosition;
}

sealed class CanvasContextActionTarget {
  const CanvasContextActionTarget();
}

final class CanvasContentElementContextActionTarget
    extends CanvasContextActionTarget {
  CanvasContentElementContextActionTarget({
    required this.elementSnapshot,
    required this.boundsWorld,
  });

  final CanvasElement elementSnapshot;
  final Rect boundsWorld;
}

final class CanvasEmptyCanvasContextActionTarget
    extends CanvasContextActionTarget {
  const CanvasEmptyCanvasContextActionTarget();
}
```

The exact prose may refine wording only if the final docs preserve these locked
semantics: no new stream, no duplicate public double-tap method, direct
`handleDoubleTap` does not depend on pending first-tap state, request delivery is
effect-only, app UI remains app-owned, and request-originated text edits remain
guarded by `commitTextEdit`.

### Ownership

Interaction documentation owns double-tap target detection, direct
host-recognized input semantics, pending tap cleanup, request emission, request
guard facts, and no-effect delivery. Public API documentation owns the exported
method, request stream, payload shape, and public timestamp contract. Geometry
documentation owns context-action target eligibility. Operation matrix
documentation owns effect rows. Architecture documentation owns registry and
route ownership. The application owns context menus, text editor overlays, IME,
focus, accessibility, text selection, hide/show policy, and menu/editor
lifetime.

### Seam

The existing public request seam remains `CanvasRuntime.contextActionRequests`
plus `CanvasContextActionRequested`. `CanvasInteractionRequestId` remains the
request identity seam. The guarded text mutation seam remains
`CanvasCommandPort.commitTextEdit(requestId, newText, {int? timestampMs})`.

This is a public API documentation change to the behavior of an existing public
method, not a public seam migration. It is compatibility-preserving for the
target public surface because it clarifies the already exposed
`handleDoubleTap` entry boundary and the already exposed context-action request
stream. No compatibility alias, duplicate stream, extra method, or versioned
transition window is documented because the repository is still rebuilding
unreleased target architecture docs.

### Dependency Direction

The documented direction remains interaction-owned request detection through
narrow read-only document/selection/runtime facts and
`InteractionRequestRegistry` guard facts. Direct `handleDoubleTap` may clear
pending context tap history through `PointerToolCleanupCoordinator` before
current-target resolution and request emission. Request delivery exits through
the runtime stream to application UI. Later text mutation re-enters through the
public command port, consumes registry facts through a narrow boundary, and
delegates accepted text changes to `EditKernel`.

The docs step must not document app UI state, Flutter state, or menu/editor
lifetime as engine-owned data, and must not make context request delivery depend
on document mutation or repaint publication.

### State and Data Ownership

Pending double-tap target history is interaction state. Direct
host-recognized `handleDoubleTap` does not require that state, but it clears any
existing pending context tap history before issuing the current request. Context
request guard facts are registry state: request id, request target kind,
controllerEpoch, retired status, and, for content targets, target element id,
generation, elementRevision, and family. The emitted content target snapshot is
immutable public DTO data. Empty-canvas targets carry no element snapshot. App
menu/editor state is application state. `documentRevision` on the emitted
request is observation and diagnostics only, not a stale guard.

### Entry and Exit Boundaries

The direct entry boundary is
`CanvasToolPort.handleDoubleTap({required Offset position, int? timestampMs})`
as a host-recognized double-tap event.

The pointer-sample entry boundary remains `CanvasToolPort.handlePointer` with
normalized finite tap samples from the surface/tool boundary for engine-owned
two-tap recognition.

The exit boundary remains `CanvasRuntime.contextActionRequests`. The only later
mutation boundary for request-originated text editing remains
`CanvasCommandPort.commitTextEdit(requestId, newText, {int? timestampMs})`.

### Verification Strategy

Use documentation structural checks plus bounded semantic proof. Structural
proof must cover generated docs navigation, registries, diagram references, and
phase navigation. Semantic proof must show that direct `handleDoubleTap` is
documented as a host-recognized event with no pending first-tap requirement, and
that current context-action diagrams no longer place "explicit double-tap"
inside pending-flow transitions.

Do not add production tests to this documentation-only step. Instead, update
verification docs to require later implementation tests for direct
`handleDoubleTap` content targets, empty-canvas targets, pending-history
cleanup, invalid/non-finite position handling, no-effect delivery, and timestamp
monotonicity.

### Decision Ledger

| ID | Decision | Owner | Proof |
|---|---|---|---|
| D1 | Direct `CanvasToolPort.handleDoubleTap` is a host-recognized double-tap event that does not require pending first-tap history. | `docs/contracts/public_api_v1.md`, `docs/contracts/interaction_engine.md` | P2 |
| D2 | Direct `handleDoubleTap` clears any pending context tap history, resolves the current target, and emits one context request through the existing context-action seam for content or empty canvas. | `docs/contracts/interaction_engine.md`, `docs/diagrams/seq_context_action_request.mmd`, `docs/diagrams/state_pending_context_action_request.mmd` | P2, P3 |
| D3 | Pointer-sample two-tap recognition remains separate and still revalidates pending content or empty-canvas candidates before request emission. | `docs/contracts/interaction_engine.md`, `docs/diagrams/state_pending_context_action_request.mmd`, `docs/diagrams/seq_context_action_request.mmd` | P3 |
| D4 | The public context-action request seam stays unchanged; no new stream, public method, alias, or duplicate text/context request seam is introduced. | `docs/contracts/public_api_v1.md`, `docs/_registry/public_api_v1.yaml` | P4 |

### Rejected Alternatives

- Treat direct `handleDoubleTap` as the second pending tap. Rejected because a
  host-recognized double-tap from Flutter would be dropped unless the engine
  happened to have stored a first tap, creating host-dependent behavior.
- Add a separate host double-tap public method. Rejected because the current
  public API already exposes `handleDoubleTap`; adding a near-duplicate method
  expands the public surface without improving the product behavior.
- Keep diagram wording ambiguous and rely on prose elsewhere. Rejected because
  durable diagrams are source-of-truth navigation surfaces and the current
  ambiguity originates in their pending-flow wording.
- Reopen the retired text-only request stream migration. Rejected because the
  active docs already expose `contextActionRequests` and
  `CanvasContextActionRequested`; this step fixes the remaining input-boundary
  semantics rather than replacing the request seam again.

## 4. Execution Guardrails

### Required Order

1. Update the public API and interaction contracts before downstream diagrams,
   phase docs, and verification docs.
2. Update the sequence and state diagrams in the same slice as their registry or
   catalog references if diagram ids, titles, or paths change.
3. Update operation matrix and architecture wording only where needed to align
   direct pending-history cleanup with existing no-effect request delivery.
4. Update phase, verification, guardrail, release-gate, and index surfaces after
   the public method semantics and diagram wording are stable.
5. Run semantic proof before final docs structural checks so stale wording is
   caught before registry/navigation verification.
6. Mark this step complete in `PLAN.md` and in this step document only after all
   documentation proof passes.

### Cross-Slice Constraints

- Keep the step documentation-only. Do not edit `lib/`, `test/`, `example/`, or
  runtime analyzer/guardrail source files.
- Keep `CanvasToolPort.handleDoubleTap` as the public input boundary.
- Keep `CanvasRuntime.contextActionRequests` as the only context-action request
  stream.
- Keep `CanvasInteractionRequestId` generic and shared by context requests and
  guarded text commit.
- Keep `CanvasCommandPort.commitTextEdit` as the request-originated text commit
  seam.
- Do not document `documentRevision` as a stale guard for context requests.
- Do not make background elements context content targets.
- Do not make `element.isSelectable` a context-action target gate.
- Do not add app UI ownership to `InteractionRequestRegistry` or any runtime
  state owner.
- Do not update historical `.research/`, `.design/`, or completed `plan/`
  records to satisfy negative proof.

### Seam Migration

No seam migration is part of this contract. The current context-action request
seam is retained and clarified. The public API obligation is closed by updating
the documented semantics of the existing public method and proving that no new
public stream, method, alias, or duplicate request seam was introduced.

### Forbidden Moves

- Do not implement direct `handleDoubleTap` behavior in Dart.
- Do not add runtime tests, fixtures, or analyzer rules.
- Do not add runtime compatibility shims, aliases, adapters, or synchronizers.
- Do not add a second public double-tap method.
- Do not document direct `handleDoubleTap` as requiring stored pending first-tap
  state.
- Do not weaken text stale guards to use `documentRevision`.
- Do not move text editing UI ownership into the engine.
- Do not satisfy semantic proof by editing historical evidence files.
- Do not rename unrelated diagrams or phase files.

### Deferred Broad Verification

The later implementation contract owns runtime behavior tests for direct
`handleDoubleTap` request emission, pending-history cleanup, invalid/non-finite
position handling, hit policy, registry facts, stream delivery, text commit
acceptance and rejection, timestamp monotonicity, operation effects, cleanup
behavior, and public API code shape. This docs-only step only updates the
source-of-truth docs that define those future checks.

## 5. Proof Plan

### P1. Documentation Structure

This proves generated documentation navigation, registries, diagram membership,
ids, paths, and phase navigation are structurally coherent after the docs-only
source-of-truth change.

```sh
dart run docs/tool/generate_context_capsules.dart --check
dart run docs/tool/check_docs.dart
```

Expected signal: both commands exit successfully.

### P2. Direct Double-Tap Public Boundary

This proves active source-of-truth docs define direct `handleDoubleTap` as a
host-recognized event with no pending first-tap requirement and with current
target resolution into the context-action request seam.

```sh
rg -n "handleDoubleTap" docs/contracts/public_api_v1.md docs/contracts/interaction_engine.md docs/implementation docs/verification docs/indexes
rg -n "host-recognized" docs/contracts/public_api_v1.md docs/contracts/interaction_engine.md docs/implementation docs/verification docs/indexes
rg -n "no pending first-tap|does not require pending first-tap|without pending first-tap" docs/contracts/public_api_v1.md docs/contracts/interaction_engine.md docs/implementation docs/verification docs/indexes
rg -n "pending context tap|pending-history cleanup|PointerToolCleanupCoordinator" docs/contracts/public_api_v1.md docs/contracts/interaction_engine.md docs/implementation docs/verification docs/indexes
rg -n "current context-action target|current context target|current-target resolution|resolves the current" docs/contracts/public_api_v1.md docs/contracts/interaction_engine.md docs/implementation docs/verification docs/indexes
! rg -n "handleDoubleTap.*second tap|second tap.*handleDoubleTap|handleDoubleTap.*requires pending|requires pending first-tap|explicit double-tap" docs/contracts/public_api_v1.md docs/contracts/interaction_engine.md docs/implementation docs/verification docs/indexes
```

Expected signal: the positive commands find host-recognized direct input, no
pending first-tap requirement, pending-history cleanup, and current-target
resolution in active source-of-truth surfaces; the negative command finds no
active wording that treats `handleDoubleTap` as a second pending tap or requires
pending first-tap state.

### P3. Pending-Flow Diagram Separation

This proves current diagrams distinguish direct host-recognized `handleDoubleTap`
from pointer-sample pending two-tap recognition and no longer place "explicit
double-tap" inside pending candidate transitions.

```sh
rg -n "handleDoubleTap|host-recognized|DirectDoubleTap|direct double-tap|pointer-sample|first tap|second tap|pending context" docs/diagrams/seq_context_action_request.mmd docs/diagrams/state_pending_context_action_request.mmd docs/contracts/interaction_engine.md
! rg -n "second tap or explicit double-tap|explicit double-tap" docs/diagrams/seq_context_action_request.mmd docs/diagrams/state_pending_context_action_request.mmd docs/contracts/interaction_engine.md
```

Expected signal: the first command finds separate direct and pointer-sample
flows; the second command finds no stale pending-flow wording that treats
explicit double-tap as a second pending tap.

### P4. Public Seam Preservation

This proves the active public source-of-truth surfaces keep the existing
context-action request seam and do not introduce a duplicate public stream,
method, alias, or text-only request seam.

```sh
rg -n "contextActionRequests|CanvasContextActionRequested|CanvasContextActionTrigger|CanvasContextActionTarget|CanvasContentElementContextActionTarget|CanvasEmptyCanvasContextActionTarget|handleDoubleTap" docs/contracts/public_api_v1.md docs/_registry/public_api_v1.yaml docs/contracts/interaction_engine.md
! rg -n "hostDoubleTap|handleHostDoubleTap|doubleTapRequests|textEditRequests|CanvasTextEditRequested|Stream<CanvasTextEditRequested>|final class CanvasTextEditRequested" docs/contracts/public_api_v1.md docs/_registry/public_api_v1.yaml docs/contracts/interaction_engine.md
```

Expected signal: the first command finds the retained public context-action
seam and `handleDoubleTap`; the second command finds no duplicate host method,
duplicate double-tap stream, or retired text-only request seam in active public
source-of-truth surfaces.

### P5. No-Effect and App-Owned UI Preservation

This proves direct double-tap documentation preserves the current effect model,
app-owned UI model, context target policy, and guarded text commit model.

```sh
rg -n "no document, selection, preview, repaint, spatial, projection, resource, or action effect|application owns|context menus|text editor|commitTextEdit|empty-canvas|background-only|isSelectable does not gate|CanvasTextElement" docs/contracts/interaction_engine.md docs/contracts/public_api_v1.md docs/contracts/geometry.md docs/contracts/operation_matrix.md docs/architecture/01_runtime_ownership.md docs/architecture/02_package_boundaries.md docs/implementation docs/verification docs/indexes
```

Expected signal: active docs keep no-effect request delivery, app-owned
menu/editor behavior, target eligibility, and guarded text commit semantics.

## 6. Vertical Slices

### Slice 1. [x] Public And Interaction Contract Lock

#### Implements

D1, D2, D4

#### Obligations Covered

PUBLIC_API_CHANGE

#### Files

- Primary public contract edit: `docs/contracts/public_api_v1.md` - document
  `CanvasToolPort.handleDoubleTap` as host-recognized direct double-tap input,
  keep the existing context-action request public surface, and preserve timestamp
  behavior.
- Primary interaction contract edit: `docs/contracts/interaction_engine.md` -
  document direct `handleDoubleTap` execution order, pending-history cleanup,
  current-target resolution, request emission, no-effect delivery, app-owned UI,
  and guarded text commit preservation.
- Public registry verification or sync: `docs/_registry/public_api_v1.yaml` -
  verify that retained public names remain registered and no duplicate host
  method or retired text-only request event is introduced.

#### Change

The public and interaction contracts define direct `handleDoubleTap` as a
host-recognized event that resolves the current content or empty-canvas target
without pending first-tap history, while retaining the existing
`contextActionRequests` public request seam.

#### Proof

Run P2 and P4.

#### Closure

The slice is closed when the public method semantics, retained public request
seam, timestamp behavior, no duplicate method/stream, and interaction execution
order are documented and proven by P2 and P4.

### Slice 2. [x] Diagram And State-Flow Alignment

#### Implements

D2, D3

#### Files

- Primary sequence diagram edit: `docs/diagrams/seq_context_action_request.mmd`
  - show direct `handleDoubleTap` as a host-recognized path that clears pending
  context tap history and emits through the current context request stream,
  while preserving pointer-sample first/second tap recognition.
- Primary state diagram edit:
  `docs/diagrams/state_pending_context_action_request.mmd` - remove pending
  transition wording that treats explicit double-tap as a second pending tap and
  add a separate direct double-tap path when needed.
- Diagram catalog sync: `docs/diagrams/README.md` - update only if diagram
  titles, ids, or descriptions change.
- Section registry sync: `docs/_registry/sections.yaml` - update only if diagram
  ids, titles, paths, or section references change.

#### Change

The durable context-action diagrams distinguish direct host-recognized
`handleDoubleTap` from engine-owned pointer-sample pending recognition, and no
active diagram implies direct double-tap depends on stored first-tap state.

#### Proof

Run P3. If diagram ids, titles, paths, or registry entries changed, also run P1.

#### Closure

The slice is closed when the context-action sequence and state diagrams have no
stale "explicit double-tap" pending-flow wording and any affected diagram
catalog or registry entries remain structurally valid.

### Slice 3. [x] Downstream Guidance And Verification Alignment

#### Implements

D1, D2, D3

#### Obligations Covered

PUBLIC_API_CHANGE

#### Files

- Phase guidance edit: `docs/implementation/p12_eraser_and_text_request.md` -
  require later implementation coverage for direct `handleDoubleTap` content,
  empty-canvas, pending-history cleanup, and no-effect delivery.
- Verification contract edit: `docs/verification/tests.md` - add direct
  `handleDoubleTap` behavior expectations to the context-action and timestamp
  test descriptions.
- Guardrail index alignment: `docs/verification/guardrails.md` and
  `docs/indexes/by_guardrail.md` - update only if existing guardrail references
  need direct double-tap wording.
- Test-area index alignment: `docs/indexes/by_test_area.md` - update only if
  test names or test-area descriptions need direct double-tap wording.
- Release gate alignment: `docs/verification/release_gates.md` - update only if
  release gates need direct `handleDoubleTap` coverage.
- Operation and architecture alignment:
  `docs/contracts/operation_matrix.md`,
  `docs/architecture/01_runtime_ownership.md`, and
  `docs/architecture/02_package_boundaries.md` - update only if direct
  pending-history cleanup or route ownership wording needs clarification.

#### Change

Downstream implementation, verification, guardrail, release, operation, and
architecture docs require the future code step to prove direct `handleDoubleTap`
behavior separately from pointer-sample recognition while preserving no-effect
delivery and app-owned UI.

#### Proof

Run P2, P3, and P5.

#### Closure

The slice is closed when downstream source-of-truth surfaces require direct
`handleDoubleTap` implementation coverage, preserve existing context-action
semantics, and contain no stale wording that makes direct double-tap dependent
on pending first-tap history.

### Slice 4. [x] Final Documentation Gate And Roadmap Closure

#### Implements

D1, D2, D3, D4

#### Obligations Covered

PUBLIC_API_CHANGE

#### Files

- Final step status edit:
  `plan/step_19_double_tap_context_action_documentation.md` - mark all completed
  slice checkboxes only after proof passes.
- Plan index edit: `PLAN.md` - mark Step 19 complete only after proof passes.
- Verify-only historical evidence exclusion: `.research/`, `.design/`, and
  completed `plan/step_*.md` - do not edit historical evidence to satisfy
  negative proof.

#### Change

The completed documentation step is reflected in both the step contract and the
roadmap index after all semantic and structural proof passes.

#### Proof

Run P1, P2, P3, P4, and P5.

#### Closure

The slice is closed when all proof passes, no out-of-scope files were changed,
and the step checkbox state matches between this file and `PLAN.md`.

## 7. Final Gate

### Run Proof Set

P1, P2, P3, P4, and P5 must pass before closure.

### Done When

- D1, D2, D3, and D4 have passing proof through P1, P2, P3, P4, and P5;
- `PUBLIC_API_CHANGE` is satisfied by the public contract owner, registry proof,
  compatibility-preserving documentation, downstream verification expectations,
  and the no-new-public-seam proof in P4;
- no out-of-scope production code, runtime tests, analyzer rules, historical
  evidence, or unrelated diagrams were changed;
- this step and `PLAN.md` are marked complete only after proof passes;
- whitespace validation passes.
